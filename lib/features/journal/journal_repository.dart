import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';

final journalRepositoryProvider = Provider(
  (ref) => JournalRepository(ref.watch(databaseProvider)),
);
final journalProvider = StreamProvider.family<List<JournalEntry>, String>(
  (ref, worldId) => ref.watch(journalRepositoryProvider).watch(worldId),
);

class JournalRepository {
  JournalRepository(this.database);
  final AppDatabase database;
  Stream<List<JournalEntry>> watch(String worldId, {String query = ''}) =>
      (database.select(database.journalEntries)
            ..where((e) => e.worldId.equals(worldId))
            ..orderBy([
              (e) => OrderingTerm.desc(e.occurredAt),
              (e) => OrderingTerm.desc(e.updatedAt),
            ]))
          .watch()
          .map((entries) {
            final search = query.trim().toLowerCase();
            return entries
                .where(
                  (e) =>
                      search.isEmpty ||
                      e.title.toLowerCase().contains(search) ||
                      e.body.toLowerCase().contains(search),
                )
                .toList();
          });

  Future<String> save({
    required String worldId,
    String? id,
    required String title,
    required String body,
    required DateTime occurredAt,
    Set<String>? locationIds,
    Set<String>? projectIds,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 200) {
      throw ArgumentError('Enter a title between 1 and 200 characters.');
    }
    return database.transaction(() async {
      // Validate all references before changing the entry or either tag collection.
      for (final locationId in locationIds ?? <String>{}) {
        final row =
            await (database.select(database.locations)..where(
                  (l) => l.id.equals(locationId) & l.worldId.equals(worldId),
                ))
                .getSingleOrNull();
        if (row == null) {
          throw StateError('A tagged location is unavailable in this world.');
        }
      }
      for (final projectId in projectIds ?? <String>{}) {
        final row =
            await (database.select(database.projects)..where(
                  (p) => p.id.equals(projectId) & p.worldId.equals(worldId),
                ))
                .getSingleOrNull();
        if (row == null) {
          throw StateError('A tagged project is unavailable in this world.');
        }
      }
      final now = DateTime.now().toUtc();
      if (id != null) {
        final count =
            await (database.update(
              database.journalEntries,
            )..where((e) => e.id.equals(id) & e.worldId.equals(worldId))).write(
              JournalEntriesCompanion(
                title: Value(trimmed),
                body: Value(body),
                occurredAt: Value(occurredAt.toUtc()),
                updatedAt: Value(now),
              ),
            );
        if (count != 1) {
          throw StateError('This entry no longer exists in this world.');
        }
        await _replaceTags(
          id,
          locationIds: locationIds,
          projectIds: projectIds,
        );
        return id;
      }
      final newId = const Uuid().v4();
      await database
          .into(database.journalEntries)
          .insert(
            JournalEntriesCompanion.insert(
              id: newId,
              worldId: worldId,
              title: trimmed,
              body: Value(body),
              occurredAt: occurredAt.toUtc(),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceTags(
        newId,
        locationIds: locationIds,
        projectIds: projectIds,
      );
      return newId;
    });
  }

  Future<void> _replaceTags(
    String entryId, {
    Set<String>? locationIds,
    Set<String>? projectIds,
  }) async {
    if (locationIds != null) {
      await (database.delete(
        database.journalLocationTags,
      )..where((t) => t.entryId.equals(entryId))).go();
      for (final id in locationIds) {
        await database
            .into(database.journalLocationTags)
            .insert(
              JournalLocationTagsCompanion.insert(
                entryId: entryId,
                locationId: id,
              ),
            );
      }
    }
    if (projectIds != null) {
      await (database.delete(
        database.journalProjectTags,
      )..where((t) => t.entryId.equals(entryId))).go();
      for (final id in projectIds) {
        await database
            .into(database.journalProjectTags)
            .insert(
              JournalProjectTagsCompanion.insert(
                entryId: entryId,
                projectId: id,
              ),
            );
      }
    }
  }

  Future<void> delete({required String worldId, required String id}) async {
    final count = await (database.delete(
      database.journalEntries,
    )..where((e) => e.id.equals(id) & e.worldId.equals(worldId))).go();
    if (count != 1) {
      throw StateError('This entry no longer exists in this world.');
    }
  }
}
