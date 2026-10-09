import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';

final taskRepositoryProvider = Provider(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);
final projectTasksProvider =
    StreamProvider.family<List<ProjectTask>, (String, String)>(
      (ref, key) => ref.watch(taskRepositoryProvider).watch(key.$1, key.$2),
    );

class TaskRepository {
  TaskRepository(this.db);
  final AppDatabase db;
  Stream<List<ProjectTask>> watch(String worldId, String projectId) =>
      (db.select(db.projectTasks).join([
              innerJoin(
                db.projects,
                db.projects.id.equalsExp(db.projectTasks.projectId),
              ),
            ])
            ..where(
              db.projects.worldId.equals(worldId) &
                  db.projects.id.equals(projectId),
            )
            ..orderBy([
              OrderingTerm.asc(db.projectTasks.position),
              OrderingTerm.asc(db.projectTasks.id),
            ]))
          .watch()
          .map(
            (rows) => rows.map((r) => r.readTable(db.projectTasks)).toList(),
          );
  Future<void> checkOwner(String worldId, String projectId) async {
    final project =
        await (db.select(
              db.projects,
            )..where((p) => p.id.equals(projectId) & p.worldId.equals(worldId)))
            .getSingleOrNull();
    if (project == null) {
      throw StateError('This project no longer exists in this world.');
    }
  }

  Future<void> touch(String projectId) =>
      (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
        ProjectsCompanion(updatedAt: Value(DateTime.now().toUtc())),
      );
  Future<String> save({
    required String worldId,
    required String projectId,
    String? id,
    required String title,
  }) async {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 200) {
      throw ArgumentError('Enter a task between 1 and 200 characters.');
    }
    return db.transaction(() async {
      await checkOwner(worldId, projectId);
      if (id != null) {
        final count =
            await (db.update(db.projectTasks)..where(
                  (t) => t.id.equals(id) & t.projectId.equals(projectId),
                ))
                .write(ProjectTasksCompanion(title: Value(clean)));
        if (count != 1) {
          throw StateError('This task no longer exists in this project.');
        }
        await touch(projectId);
        return id;
      }
      final last =
          await (db.select(db.projectTasks)
                ..where((t) => t.projectId.equals(projectId))
                ..orderBy([(t) => OrderingTerm.desc(t.position)])
                ..limit(1))
              .getSingleOrNull();
      final newId = const Uuid().v4();
      await db
          .into(db.projectTasks)
          .insert(
            ProjectTasksCompanion.insert(
              id: newId,
              projectId: projectId,
              title: clean,
              position: (last?.position ?? -1) + 1,
            ),
          );
      await touch(projectId);
      return newId;
    });
  }

  Future<void> setCompleted({
    required String worldId,
    required String projectId,
    required String id,
    required bool completed,
  }) => db.transaction(() async {
    await checkOwner(worldId, projectId);
    final count =
        await (db.update(db.projectTasks)
              ..where((t) => t.id.equals(id) & t.projectId.equals(projectId)))
            .write(ProjectTasksCompanion(completed: Value(completed)));
    if (count != 1) {
      throw StateError('This task no longer exists in this project.');
    }
    await touch(projectId);
  });
  Future<void> delete({
    required String worldId,
    required String projectId,
    required String id,
  }) => db.transaction(() async {
    await checkOwner(worldId, projectId);
    final count = await (db.delete(
      db.projectTasks,
    )..where((t) => t.id.equals(id) & t.projectId.equals(projectId))).go();
    if (count != 1) {
      throw StateError('This task no longer exists in this project.');
    }
    await touch(projectId);
  });
}
