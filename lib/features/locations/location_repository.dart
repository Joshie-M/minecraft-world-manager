import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';

final locationRepositoryProvider = Provider(
  (ref) => LocationRepository(ref.watch(databaseProvider)),
);
final locationsProvider = StreamProvider.family<List<Location>, String>(
  (ref, worldId) => ref.watch(locationRepositoryProvider).watch(worldId),
);
const dimensions = ['Overworld', 'Nether', 'End'];
String coordinateText(Location location) =>
    '${location.x} ${location.y} ${location.z}';

class LocationRepository {
  LocationRepository(this.database);
  final AppDatabase database;
  Stream<List<Location>> watch(String worldId) =>
      (database.select(database.locations)
            ..where((l) => l.worldId.equals(worldId))
            ..orderBy([
              (l) => OrderingTerm.asc(l.name.lower()),
              (l) => OrderingTerm.asc(l.id),
            ]))
          .watch();
  Future<String> save({
    required String worldId,
    String? id,
    required String name,
    required int x,
    required int y,
    required int z,
    required String dimension,
    String notes = '',
  }) async {
    final cleanName = name.trim();
    final cleanDimension = dimension.trim();
    if (cleanName.isEmpty || cleanName.length > 100) {
      throw ArgumentError('Enter a name between 1 and 100 characters.');
    }
    if (cleanDimension.isEmpty || cleanDimension.length > 100) {
      throw ArgumentError('Enter a dimension between 1 and 100 characters.');
    }
    // Deliberately not Minecraft world limits: editions/custom worlds vary.
    for (final value in [x, y, z]) {
      if (value < -2147483648 || value > 2147483647) {
        throw ArgumentError('Coordinates must be 32-bit whole numbers.');
      }
    }
    final now = DateTime.now().toUtc();
    if (id != null) {
      final count =
          await (database.update(
            database.locations,
          )..where((l) => l.id.equals(id) & l.worldId.equals(worldId))).write(
            LocationsCompanion(
              name: Value(cleanName),
              x: Value(x),
              y: Value(y),
              z: Value(z),
              dimension: Value(cleanDimension),
              notes: Value(notes),
              updatedAt: Value(now),
            ),
          );
      if (count != 1) {
        throw StateError('This location no longer exists in this world.');
      }
      return id;
    }
    final newId = const Uuid().v4();
    await database
        .into(database.locations)
        .insert(
          LocationsCompanion.insert(
            id: newId,
            worldId: worldId,
            name: cleanName,
            x: x,
            y: y,
            z: z,
            dimension: cleanDimension,
            notes: Value(notes),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return newId;
  }

  Future<void> delete({required String worldId, required String id}) async {
    final count = await (database.delete(
      database.locations,
    )..where((l) => l.id.equals(id) & l.worldId.equals(worldId))).go();
    if (count != 1) {
      throw StateError('This location no longer exists in this world.');
    }
  }
}
