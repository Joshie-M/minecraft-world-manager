import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/backup/backup_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/projects/task_repository.dart';

Future<String> seed(AppDatabase db) async {
  final world = await WorldRepository(
    db,
  ).save(name: 'Mosswood', edition: 'Java', description: 'My story');
  final location = await LocationRepository(db).save(
    worldId: world,
    name: 'River base',
    x: -125,
    y: 64,
    z: 402,
    dimension: 'Overworld',
    notes: 'Home',
  );
  final project = await ProjectRepository(db).save(
    worldId: world,
    name: 'River bridge',
    notes: 'Use spruce',
    status: 'In progress',
    locationId: location,
    initialTasks: ['Gather wood', 'Build supports'],
  );
  final task = (await db.select(db.projectTasks).get()).first;
  await TaskRepository(db).setCompleted(
    worldId: world,
    projectId: project,
    id: task.id,
    completed: true,
  );
  final entry = await JournalRepository(db).save(
    worldId: world,
    title: 'A new crossing',
    body:
        'Built [@River bridge](world-manager://project/$project) near '
        '[@River base](world-manager://location/$location). Unavailable '
        '[@Old tower](world-manager://project/missing-id). Ordinary @hello.',
    occurredAt: DateTime.utc(2026, 10, 9),
  );
  await db
      .into(db.journalLocationTags)
      .insert(JournalLocationTag(entryId: entry, locationId: location));
  await db
      .into(db.journalProjectTags)
      .insert(JournalProjectTag(entryId: entry, projectId: project));
  return world;
}

Uint8List encode(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

void main() {
  test(
    'backup restores copies, connections, completion and timestamps across disk reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('world-backup-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/worlds.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final original = await seed(db);
      final before = await db.select(db.worlds).getSingle();
      final repo = BackupRepository(db);
      final bytes = await repo.export();
      final backup = WorldBackup.parse(bytes);
      await repo.restore(backup);
      // Repeat restore cannot collide with existing IDs.
      await repo.restore(backup);
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      final worlds = await db.select(db.worlds).get();
      expect(worlds.length, 3);
      expect(worlds.singleWhere((w) => w.id == original), before);
      for (final world in worlds.where((w) => w.id != original)) {
        expect(world.name, 'Mosswood (restored)');
        expect(world.createdAt, before.createdAt);
        expect(world.description, 'My story');
        final location = await (db.select(
          db.locations,
        )..where((l) => l.worldId.equals(world.id))).getSingle();
        final project = await (db.select(
          db.projects,
        )..where((p) => p.worldId.equals(world.id))).getSingle();
        final entry = await (db.select(
          db.journalEntries,
        )..where((e) => e.worldId.equals(world.id))).getSingle();
        expect(location.x, -125);
        expect(location.notes, 'Home');
        expect(project.locationId, location.id);
        expect(project.status, 'In progress');
        final tasks =
            await (db.select(db.projectTasks)
                  ..where((t) => t.projectId.equals(project.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        expect(tasks.map((t) => t.title), ['Gather wood', 'Build supports']);
        expect(tasks.map((t) => t.completed), [true, false]);
        expect(entry.body, contains('world-manager://project/${project.id}'));
        expect(entry.body, contains('world-manager://location/${location.id}'));
        expect(entry.body, contains('Ordinary @hello.'));
        expect(entry.body, isNot(contains('/missing-id')));
        expect(entry.occurredAt.toUtc(), DateTime.utc(2026, 10, 9));
        final lt = await (db.select(
          db.journalLocationTags,
        )..where((t) => t.entryId.equals(entry.id))).getSingle();
        final pt = await (db.select(
          db.journalProjectTags,
        )..where((t) => t.entryId.equals(entry.id))).getSingle();
        expect(lt.locationId, location.id);
        expect(pt.projectId, project.id);
      }
      // The restored library is itself a valid, portable backup.
      expect(
        WorldBackup.parse(await BackupRepository(db).export()).worlds.length,
        3,
      );
    },
  );

  test(
    'rejects malformed, future, duplicate and disconnected backups without writes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      final bytes = await BackupRepository(db).export();
      Map<String, dynamic> data() =>
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(
        () => WorldBackup.parse(Uint8List.fromList([255])),
        throwsFormatException,
      );
      expect(() => WorldBackup.parse(encode({})), throwsFormatException);
      expect(
        () => WorldBackup.parse(Uint8List(maxBackupBytes + 1)),
        throwsFormatException,
      );
      final future = data()..['version'] = 999;
      expect(() => WorldBackup.parse(encode(future)), throwsFormatException);
      final duplicate = data();
      (duplicate['worlds'] as List).add((duplicate['worlds'] as List).first);
      expect(() => WorldBackup.parse(encode(duplicate)), throwsFormatException);
      final orphan = data();
      orphan['projects'][0]['worldId'] = 'missing-world';
      expect(() => WorldBackup.parse(encode(orphan)), throwsFormatException);
      final blank = data();
      blank['tasks'][0]['title'] = ' ';
      expect(() => WorldBackup.parse(encode(blank)), throwsFormatException);
      final status = data();
      status['projects'][0]['status'] = 'Unknown';
      expect(() => WorldBackup.parse(encode(status)), throwsFormatException);
      final wrongType = data();
      wrongType['tasks'][0]['completed'] = 'yes';
      expect(() => WorldBackup.parse(encode(wrongType)), throwsFormatException);
      final otherWorld = await WorldRepository(
        db,
      ).save(name: 'Other', edition: 'Bedrock');
      final otherLocation = await LocationRepository(db).save(
        worldId: otherWorld,
        name: 'Other base',
        x: 0,
        y: 0,
        z: 0,
        dimension: 'Nether',
      );
      final crossWorld = jsonDecode(
        utf8.decode(await BackupRepository(db).export()),
      );
      crossWorld['projects'][0]['locationId'] = otherLocation;
      expect(
        () => WorldBackup.parse(encode(crossWorld)),
        throwsFormatException,
      );
      expect((await db.select(db.worlds).get()).length, 2);
      expect((await db.select(db.projectTasks).get()).length, 2);
    },
  );

  test('late restore failure rolls back every inserted table', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db);
    final backup = WorldBackup.parse(await BackupRepository(db).export());
    await db.customStatement(
      "CREATE TRIGGER fail_restore BEFORE INSERT ON project_tasks BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(BackupRepository(db).restore(backup), throwsA(anything));
    expect((await db.select(db.worlds).get()).length, 1);
    expect((await db.select(db.locations).get()).length, 1);
    expect((await db.select(db.projects).get()).length, 1);
    expect((await db.select(db.journalEntries).get()).length, 1);
    expect((await db.select(db.projectTasks).get()).length, 2);
    expect((await db.select(db.journalLocationTags).get()).length, 1);
  });

  test('empty library exports a valid backup', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final backup = WorldBackup.parse(await BackupRepository(db).export());
    expect(backup.worlds, isEmpty);
    await BackupRepository(db).restore(backup);
    expect(await db.select(db.worlds).get(), isEmpty);
  });
}
