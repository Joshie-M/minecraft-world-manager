import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';
import 'task_repository.dart';

const maxMaterialQuantity = 1000000;
final materialRepositoryProvider = Provider(
  (ref) => MaterialRepository(ref.watch(databaseProvider)),
);
final projectMaterialsProvider =
    StreamProvider.family<List<ProjectMaterial>, (String, String)>(
      (ref, key) => ref.watch(materialRepositoryProvider).watch(key.$1, key.$2),
    );

class MaterialRepository {
  MaterialRepository(this.db);
  final AppDatabase db;
  Stream<List<ProjectMaterial>> watch(String worldId, String projectId) =>
      (db.select(db.projectMaterials).join([
              innerJoin(
                db.projects,
                db.projects.id.equalsExp(db.projectMaterials.projectId),
              ),
            ])
            ..where(
              db.projects.worldId.equals(worldId) &
                  db.projects.id.equals(projectId),
            )
            ..orderBy([
              OrderingTerm.asc(db.projectMaterials.name.lower()),
              OrderingTerm.asc(db.projectMaterials.id),
            ]))
          .watch()
          .map(
            (rows) =>
                rows.map((r) => r.readTable(db.projectMaterials)).toList(),
          );
  Future<String> save({
    required String worldId,
    required String projectId,
    String? id,
    required String name,
    required int needed,
    int gathered = 0,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty ||
        clean.length > 100 ||
        needed < 1 ||
        needed > maxMaterialQuantity ||
        gathered < 0 ||
        gathered > maxMaterialQuantity) {
      throw ArgumentError('Enter a material name and valid whole quantities.');
    }
    return db.transaction(() async {
      await TaskRepository(db).checkOwner(worldId, projectId);
      final materialId = id ?? const Uuid().v4();
      if (id == null) {
        await db
            .into(db.projectMaterials)
            .insert(
              ProjectMaterialsCompanion.insert(
                id: materialId,
                projectId: projectId,
                name: clean,
                needed: needed,
                gathered: Value(gathered),
              ),
            );
      } else {
        final count =
            await (db.update(db.projectMaterials)..where(
                  (m) => m.id.equals(id) & m.projectId.equals(projectId),
                ))
                .write(
                  ProjectMaterialsCompanion(
                    name: Value(clean),
                    needed: Value(needed),
                    gathered: Value(gathered),
                  ),
                );
        if (count != 1) {
          throw StateError('This material no longer exists in this project.');
        }
      }
      await TaskRepository(db).touch(projectId);
      return materialId;
    });
  }

  Future<void> markGathered({
    required String worldId,
    required String projectId,
    required String id,
  }) => db.transaction(() async {
    await TaskRepository(db).checkOwner(worldId, projectId);
    final material =
        await (db.select(db.projectMaterials)
              ..where((m) => m.id.equals(id) & m.projectId.equals(projectId)))
            .getSingleOrNull();
    if (material == null) {
      throw StateError('This material no longer exists in this project.');
    }
    if (material.gathered >= material.needed) return;
    await (db.update(db.projectMaterials)..where((m) => m.id.equals(id))).write(
      ProjectMaterialsCompanion(gathered: Value(material.needed)),
    );
    await TaskRepository(db).touch(projectId);
  });
  Future<void> delete({
    required String worldId,
    required String projectId,
    required String id,
  }) => db.transaction(() async {
    await TaskRepository(db).checkOwner(worldId, projectId);
    final count = await (db.delete(
      db.projectMaterials,
    )..where((m) => m.id.equals(id) & m.projectId.equals(projectId))).go();
    if (count != 1) {
      throw StateError('This material no longer exists in this project.');
    }
    await TaskRepository(db).touch(projectId);
  });
}
