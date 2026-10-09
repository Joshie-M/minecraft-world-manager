import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';

void main() {
  test(
    'version 2 migration preserves worlds/journal and locations survive reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'locations-migration',
      );
      final file = File('${directory.path}/db.sqlite');
      final old = sqlite3.open(file.path);
      old.execute(
        "CREATE TABLE worlds (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', edition TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
      );
      old.execute(
        "CREATE TABLE journal_entries (id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id) ON DELETE CASCADE, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '', occurred_at INTEGER NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
      );
      old.execute(
        "INSERT INTO worlds VALUES ('world', 'Home', '', 'Java', 1700000000, 1700000000)",
      );
      old.execute(
        "INSERT INTO journal_entries VALUES ('entry','world','Adventure','Keep my notes',1700000000,1700000000,1700000000)",
      );
      old.execute('PRAGMA user_version=2');
      old.close();
      var database = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await WorldRepository(database).watchAll().first).single.name,
          'Home',
        );
        expect(
          (await JournalRepository(database).watch('world').first).single.body,
          'Keep my notes',
        );
        var locations = LocationRepository(database);
        final id = await locations.save(
          worldId: 'world',
          name: ' Base ',
          x: -123,
          y: 64,
          z: 400,
          dimension: 'Overworld',
          notes: 'Near a river',
        );
        await locations.save(
          worldId: 'world',
          id: id,
          name: 'River base',
          x: -125,
          y: 70,
          z: 402,
          dimension: 'My custom realm',
          notes: 'Safe landing',
        );
        await database.close();
        database = AppDatabase.forTesting(NativeDatabase(file));
        locations = LocationRepository(database);
        final restored = (await locations.watch('world').first).single;
        expect(restored.name, 'River base');
        expect(restored.dimension, 'My custom realm');
        expect(restored.notes, 'Safe landing');
        expect(coordinateText(restored), '-125 70 402');
        expect(
          (await database.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          6,
        );
        await locations.delete(worldId: 'world', id: id);
        expect(await locations.watch('world').first, isEmpty);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'isolates update/delete ownership and cascades only the deleted world',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final worlds = WorldRepository(database);
        final repo = LocationRepository(database);
        final a = await worlds.save(name: 'A', edition: 'Java');
        final b = await worlds.save(name: 'B', edition: 'Bedrock');
        final id = await repo.save(
          worldId: a,
          name: 'Base',
          x: -1,
          y: -64,
          z: 2,
          dimension: 'Nether',
        );
        final other = await repo.save(
          worldId: b,
          name: 'Base',
          x: 3,
          y: 64,
          z: 4,
          dimension: 'End',
        );
        await expectLater(
          repo.save(
            worldId: b,
            id: id,
            name: 'Wrong',
            x: 0,
            y: 0,
            z: 0,
            dimension: 'End',
          ),
          throwsStateError,
        );
        await expectLater(repo.delete(worldId: b, id: id), throwsStateError);
        expect((await repo.watch(a).first).single.x, -1);
        await worlds.delete(a);
        expect(await repo.watch(a).first, isEmpty);
        expect((await repo.watch(b).first).single.id, other);
      } finally {
        await database.close();
      }
    },
  );
  test('rejects invalid values and missing worlds', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = LocationRepository(database);
    try {
      await expectLater(
        repo.save(
          worldId: 'missing',
          name: ' ',
          x: 0,
          y: 0,
          z: 0,
          dimension: 'End',
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.save(
          worldId: 'missing',
          name: 'Base',
          x: 2147483648,
          y: 0,
          z: 0,
          dimension: 'End',
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.save(
          worldId: 'missing',
          name: 'Base',
          x: 0,
          y: 0,
          z: 0,
          dimension: ' ',
        ),
        throwsArgumentError,
      );
      await expectLater(
        repo.save(
          worldId: 'missing',
          name: 'Base',
          x: 0,
          y: 0,
          z: 0,
          dimension: 'End',
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      await database.close();
    }
  });
}
