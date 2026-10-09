import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';

const projectStatuses = ['Planned', 'In progress', 'Complete'];
final projectRepositoryProvider = Provider(
  (ref) => ProjectRepository(ref.watch(databaseProvider)),
);
final projectsProvider = StreamProvider.family<List<Project>, String>(
  (ref, worldId) => ref.watch(projectRepositoryProvider).watch(worldId),
);

class ProjectRepository {
  ProjectRepository(this.database);
  final AppDatabase database;
  Stream<List<Project>> watch(String worldId) =>
      (database.select(database.projects)
            ..where((p) => p.worldId.equals(worldId))
            ..orderBy([
              (p) => OrderingTerm.desc(p.updatedAt),
              (p) => OrderingTerm.asc(p.id),
            ]))
          .watch();

  Future<String> save({
    required String worldId,
    String? id,
    required String name,
    String notes = '',
    String status = 'Planned',
    String? locationId,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw ArgumentError('Enter a name between 1 and 100 characters.');
    }
    if (!projectStatuses.contains(status)) {
      throw ArgumentError('Choose a project status.');
    }
    return database.transaction(() async {
      if (locationId != null) {
        final location =
            await (database.select(database.locations)..where(
                  (l) => l.id.equals(locationId) & l.worldId.equals(worldId),
                ))
                .getSingleOrNull();
        if (location == null) {
          throw StateError('Choose a saved location in this world.');
        }
      }
      final now = DateTime.now().toUtc();
      if (id != null) {
        final count =
            await (database.update(
              database.projects,
            )..where((p) => p.id.equals(id) & p.worldId.equals(worldId))).write(
              ProjectsCompanion(
                name: Value(cleanName),
                notes: Value(notes),
                status: Value(status),
                locationId: Value(locationId),
                updatedAt: Value(now),
              ),
            );
        if (count != 1) {
          throw StateError('This project no longer exists in this world.');
        }
        return id;
      }
      final newId = const Uuid().v4();
      await database
          .into(database.projects)
          .insert(
            ProjectsCompanion.insert(
              id: newId,
              worldId: worldId,
              name: cleanName,
              notes: Value(notes),
              status: status,
              locationId: Value(locationId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return newId;
    });
  }

  Future<void> delete({required String worldId, required String id}) async {
    final count = await (database.delete(
      database.projects,
    )..where((p) => p.id.equals(id) & p.worldId.equals(worldId))).go();
    if (count != 1) {
      throw StateError('This project no longer exists in this world.');
    }
  }
}
