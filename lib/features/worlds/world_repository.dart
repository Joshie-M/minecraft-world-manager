import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

class WorldRepository {
  WorldRepository(this.database);
  final AppDatabase database;

  Stream<List<World>> watchAll() => (database.select(
    database.worlds,
  )..orderBy([(w) => OrderingTerm.desc(w.updatedAt)])).watch();

  Future<String> save({
    String? id,
    required String name,
    required String edition,
    String description = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 100) {
      throw ArgumentError('Enter a world name between 1 and 100 characters.');
    }
    if (!{'Java', 'Bedrock'}.contains(edition)) {
      throw ArgumentError('Choose Java or Bedrock.');
    }
    final now = DateTime.now().toUtc();
    if (id != null) {
      final count =
          await (database.update(
            database.worlds,
          )..where((w) => w.id.equals(id))).write(
            WorldsCompanion(
              name: Value(trimmed),
              description: Value(description.trim()),
              edition: Value(edition),
              updatedAt: Value(now),
            ),
          );
      if (count != 1) throw StateError('This world no longer exists.');
      return id;
    }
    final newId = const Uuid().v4();
    await database
        .into(database.worlds)
        .insert(
          WorldsCompanion.insert(
            id: newId,
            name: trimmed,
            description: Value(description.trim()),
            edition: edition,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return newId;
  }

  Future<void> delete(String id) async {
    await (database.delete(
      database.worlds,
    )..where((w) => w.id.equals(id))).go();
  }
}
