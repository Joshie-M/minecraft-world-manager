import 'package:drift/drift.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';
import '../projects/project_repository.dart';
import '../journal/mention_controller.dart';

const maxBackupBytes = 20 * 1024 * 1024;
final backupRepositoryProvider = Provider(
  (ref) => BackupRepository(ref.watch(databaseProvider)),
);

class WorldBackup {
  WorldBackup._(
    this.worlds,
    this.entries,
    this.locations,
    this.projects,
    this.tasks,
    this.locationTags,
    this.projectTags,
  );
  final List<World> worlds;
  final List<JournalEntry> entries;
  final List<Location> locations;
  final List<Project> projects;
  final List<ProjectTask> tasks;
  final List<JournalLocationTag> locationTags;
  final List<JournalProjectTag> projectTags;

  static WorldBackup parse(Uint8List bytes) {
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Backup exceeds the 20 MB limit.');
    }
    try {
      final root = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (root['format'] != 'minecraft-world-manager' || root['version'] != 1) {
        throw const FormatException(
          'This file is not a supported World Manager backup.',
        );
      }
      List<T> rows<T>(String key, T Function(Map<String, dynamic>) decode) {
        final list = root[key] as List;
        if (list.length > 100000) {
          throw const FormatException('Too many records.');
        }
        return list.map((row) => decode(row as Map<String, dynamic>)).toList();
      }

      final backup = WorldBackup._(
        rows('worlds', World.fromJson),
        rows('entries', JournalEntry.fromJson),
        rows('locations', Location.fromJson),
        rows('projects', Project.fromJson),
        rows('tasks', ProjectTask.fromJson),
        rows('locationTags', JournalLocationTag.fromJson),
        rows('projectTags', JournalProjectTag.fromJson),
      );
      backup._validate();
      return backup;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'This backup is incomplete or contains invalid data.',
      );
    }
  }

  void _validate() {
    void require(bool valid) {
      if (!valid) {
        throw const FormatException(
          'This backup contains invalid or disconnected records.',
        );
      }
    }

    Map<String, T> index<T>(List<T> rows, String Function(T) id) {
      final map = <String, T>{};
      for (final row in rows) {
        final key = id(row);
        require(key.isNotEmpty && key.length <= 200 && !map.containsKey(key));
        map[key] = row;
      }
      return map;
    }

    bool name(String text, int max) =>
        text.trim().isNotEmpty && text.length <= max;
    final w = index(worlds, (w) => w.id);
    final e = index(entries, (e) => e.id);
    final l = index(locations, (l) => l.id);
    final p = index(projects, (p) => p.id);
    index(tasks, (t) => t.id);
    for (final world in worlds) {
      require(
        name(world.name, 100) && ['Java', 'Bedrock'].contains(world.edition),
      );
    }
    for (final entry in entries) {
      require(w.containsKey(entry.worldId) && name(entry.title, 200));
    }
    for (final location in locations) {
      require(
        w.containsKey(location.worldId) &&
            name(location.name, 100) &&
            name(location.dimension, 100),
      );
    }
    for (final project in projects) {
      require(
        w.containsKey(project.worldId) &&
            name(project.name, 100) &&
            projectStatuses.contains(project.status),
      );
      require(
        project.locationId == null ||
            l[project.locationId]?.worldId == project.worldId,
      );
    }
    final positions = <(String, int)>{};
    for (final task in tasks) {
      require(
        p.containsKey(task.projectId) &&
            name(task.title, 200) &&
            task.position >= 0,
      );
      require(positions.add((task.projectId, task.position)));
    }
    final lt = <(String, String)>{};
    for (final tag in locationTags) {
      require(
        e.containsKey(tag.entryId) &&
            l.containsKey(tag.locationId) &&
            e[tag.entryId]!.worldId == l[tag.locationId]!.worldId &&
            lt.add((tag.entryId, tag.locationId)),
      );
    }
    final pt = <(String, String)>{};
    for (final tag in projectTags) {
      require(
        e.containsKey(tag.entryId) &&
            p.containsKey(tag.projectId) &&
            e[tag.entryId]!.worldId == p[tag.projectId]!.worldId &&
            pt.add((tag.entryId, tag.projectId)),
      );
    }
  }
}

class BackupRepository {
  BackupRepository(this.db);
  final AppDatabase db;

  Future<Uint8List> export() => db.transaction(() async {
    final data = {
      'format': 'minecraft-world-manager',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'worlds': (await db.select(db.worlds).get())
          .map((r) => r.toJson())
          .toList(),
      'entries': (await db.select(db.journalEntries).get())
          .map((r) => r.toJson())
          .toList(),
      'locations': (await db.select(db.locations).get())
          .map((r) => r.toJson())
          .toList(),
      'projects': (await db.select(db.projects).get())
          .map((r) => r.toJson())
          .toList(),
      'tasks': (await db.select(db.projectTasks).get())
          .map((r) => r.toJson())
          .toList(),
      'locationTags': (await db.select(db.journalLocationTags).get())
          .map((r) => r.toJson())
          .toList(),
      'projectTags': (await db.select(db.journalProjectTags).get())
          .map((r) => r.toJson())
          .toList(),
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    // Ensure every exported file can be restored by this version.
    WorldBackup.parse(bytes);
    return bytes;
  });

  Future<void> restore(WorldBackup backup) async {
    backup._validate();
    final worlds = {for (final w in backup.worlds) w.id: const Uuid().v4()};
    final entries = {for (final e in backup.entries) e.id: const Uuid().v4()};
    final locations = {
      for (final l in backup.locations) l.id: const Uuid().v4(),
    };
    final projects = {for (final p in backup.projects) p.id: const Uuid().v4()};
    String body(String text) => text.replaceAllMapped(mentionPattern, (match) {
      if (inCode(text, match.start)) return match[0]!;
      final map = match[2] == 'location' ? locations : projects;
      // Missing targets stay unavailable, rather than linking to existing data.
      final id = map.putIfAbsent(match[3]!, () => const Uuid().v4());
      return '[${match[1]}](world-manager://${match[2]}/$id)';
    });
    await db.transaction(() async {
      for (final w in backup.worlds) {
        final base = w.name.length > 89 ? w.name.substring(0, 89) : w.name;
        await db
            .into(db.worlds)
            .insert(w.copyWith(id: worlds[w.id]!, name: '$base (restored)'));
      }
      for (final l in backup.locations) {
        await db
            .into(db.locations)
            .insert(
              l.copyWith(id: locations[l.id]!, worldId: worlds[l.worldId]!),
            );
      }
      for (final p in backup.projects) {
        await db
            .into(db.projects)
            .insert(
              p.copyWith(
                id: projects[p.id]!,
                worldId: worlds[p.worldId]!,
                locationId: p.locationId == null
                    ? const Value(null)
                    : Value(locations[p.locationId]!),
              ),
            );
      }
      for (final e in backup.entries) {
        await db
            .into(db.journalEntries)
            .insert(
              e.copyWith(
                id: entries[e.id]!,
                worldId: worlds[e.worldId]!,
                body: body(e.body),
              ),
            );
      }
      for (final t in backup.tasks) {
        await db
            .into(db.projectTasks)
            .insert(
              t.copyWith(
                id: const Uuid().v4(),
                projectId: projects[t.projectId]!,
              ),
            );
      }
      for (final t in backup.locationTags) {
        await db
            .into(db.journalLocationTags)
            .insert(
              JournalLocationTag(
                entryId: entries[t.entryId]!,
                locationId: locations[t.locationId]!,
              ),
            );
      }
      for (final t in backup.projectTags) {
        await db
            .into(db.journalProjectTags)
            .insert(
              JournalProjectTag(
                entryId: entries[t.entryId]!,
                projectId: projects[t.projectId]!,
              ),
            );
      }
    });
  }
}
