import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  test('schema 3 upgrade preserves records; projects and links survive reopen', () async {
    final directory = await Directory.systemTemp.createTemp(
      'projects-migration',
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
      "CREATE TABLE locations (id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id) ON DELETE CASCADE, name TEXT NOT NULL, x INTEGER NOT NULL, y INTEGER NOT NULL, z INTEGER NOT NULL, dimension TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
    );
    old.execute(
      "INSERT INTO worlds VALUES ('w','Home','','Java',1700000000,1700000000)",
    );
    old.execute(
      "INSERT INTO journal_entries VALUES ('j','w','Adventure','Journal preserved',1700000000,1700000000,1700000000)",
    );
    old.execute(
      "INSERT INTO locations VALUES ('l','w','Base',-125,64,402,'Overworld','Location preserved',1700000000,1700000000)",
    );
    old.execute('PRAGMA user_version=3');
    old.close();
    var db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      var repo = ProjectRepository(db);
      final id = await repo.save(
        worldId: 'w',
        name: ' Bridge ',
        notes: 'Use spruce',
        locationId: 'l',
      );
      await repo.save(
        worldId: 'w',
        id: id,
        name: 'River bridge',
        notes: 'Use oak',
        status: 'In progress',
        locationId: 'l',
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      repo = ProjectRepository(db);
      final restored = (await repo.watch('w').first).single;
      expect(restored.name, 'River bridge');
      expect(restored.notes, 'Use oak');
      expect(restored.status, 'In progress');
      expect(restored.locationId, 'l');
      expect((await db.select(db.worlds).get()).single.name, 'Home');
      expect(
        (await db.select(db.journalEntries).get()).single.body,
        'Journal preserved',
      );
      expect((await db.select(db.locations).get()).single.x, -125);
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        5,
      );
      await LocationRepository(db).delete(worldId: 'w', id: 'l');
      final detached = (await repo.watch('w').first).single;
      expect(detached.locationId, isNull);
      expect(detached.notes, 'Use oak');
      await repo.delete(worldId: 'w', id: id);
      expect(await repo.watch('w').first, isEmpty);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
  test(
    'world ownership, invalid links, validation and world cascade',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final worlds = WorldRepository(db);
        final repo = ProjectRepository(db);
        final a = await worlds.save(name: 'A', edition: 'Java');
        final b = await worlds.save(name: 'B', edition: 'Bedrock');
        final location = await LocationRepository(
          db,
        ).save(worldId: b, name: 'Base', x: 1, y: 64, z: 2, dimension: 'End');
        final id = await repo.save(worldId: a, name: 'Bridge');
        await repo.save(worldId: b, name: 'Tower', locationId: location);
        await expectLater(
          repo.save(worldId: a, id: id, name: 'Bridge', locationId: location),
          throwsStateError,
        );
        await expectLater(
          repo.save(worldId: a, name: 'Bridge', locationId: 'missing'),
          throwsStateError,
        );
        await expectLater(
          repo.save(worldId: b, id: id, name: 'Wrong'),
          throwsStateError,
        );
        await expectLater(repo.delete(worldId: b, id: id), throwsStateError);
        await expectLater(
          repo.save(worldId: a, name: ' '),
          throwsArgumentError,
        );
        await expectLater(
          repo.save(worldId: a, name: 'x' * 101),
          throwsArgumentError,
        );
        await expectLater(
          repo.save(worldId: a, name: 'Bridge', status: 'Unknown'),
          throwsArgumentError,
        );
        await expectLater(
          repo.save(worldId: 'missing', name: 'Bridge'),
          throwsA(isA<SqliteException>()),
        );
        expect((await repo.watch(a).first).single.name, 'Bridge');
        await worlds.delete(a);
        expect(await repo.watch(a).first, isEmpty);
        expect((await repo.watch(b).first).single.name, 'Tower');
        await worlds.delete(b);
        expect(await repo.watch(b).first, isEmpty);
      } finally {
        await db.close();
      }
    },
  );
}
