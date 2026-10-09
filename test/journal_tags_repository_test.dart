import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  test('schema 4 migration, tag persistence, replacement and deletion cleanup', () async {
    final dir = await Directory.systemTemp.createTemp('journal-tags');
    final file = File('${dir.path}/db.sqlite');
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
      "CREATE TABLE projects (id TEXT NOT NULL PRIMARY KEY, world_id TEXT NOT NULL REFERENCES worlds(id) ON DELETE CASCADE, name TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', status TEXT NOT NULL, location_id TEXT REFERENCES locations(id) ON DELETE SET NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)",
    );
    old.execute(
      "INSERT INTO worlds VALUES ('w','Home','','Java',1700000000,1700000000)",
    );
    old.execute(
      "INSERT INTO journal_entries VALUES ('j','w','Adventure','Keep these notes',1700000000,1700000000,1700000000)",
    );
    old.execute(
      "INSERT INTO locations VALUES ('l','w','Base',-125,64,402,'Overworld','Location notes',1700000000,1700000000)",
    );
    old.execute(
      "INSERT INTO projects VALUES ('p','w','Bridge','Project notes','Complete','l',1700000000,1700000000)",
    );
    old.execute('PRAGMA user_version=4');
    old.close();
    var db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      var repo = JournalRepository(db);
      final entry = (await repo.watch('w').first).single;
      expect(entry.body, 'Keep these notes');
      expect((await db.select(db.projects).get()).single.locationId, 'l');
      expect((await db.select(db.locations).get()).single.x, -125);
      await repo.save(
        worldId: 'w',
        id: 'j',
        title: entry.title,
        body: entry.body,
        occurredAt: entry.occurredAt,
        locationIds: {'l'},
        projectIds: {'p'},
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      repo = JournalRepository(db);
      expect(
        (await db.select(db.journalLocationTags).get()).single.locationId,
        'l',
      );
      expect(
        (await db.select(db.journalProjectTags).get()).single.projectId,
        'p',
      );
      expect(
        (await db.customSelect('PRAGMA user_version').getSingle())
            .data
            .values
            .single,
        6,
      );
      // Calls that omit tags preserve existing associations.
      await repo.save(
        worldId: 'w',
        id: 'j',
        title: 'Updated',
        body: entry.body,
        occurredAt: entry.occurredAt,
      );
      expect(await db.select(db.journalLocationTags).get(), hasLength(1));
      await repo.save(
        worldId: 'w',
        id: 'j',
        title: 'Updated',
        body: entry.body,
        occurredAt: entry.occurredAt,
        locationIds: {},
        projectIds: {},
      );
      expect(await db.select(db.journalLocationTags).get(), isEmpty);
      expect(await db.select(db.journalProjectTags).get(), isEmpty);
      await repo.save(
        worldId: 'w',
        id: 'j',
        title: 'Updated',
        body: entry.body,
        occurredAt: entry.occurredAt,
        locationIds: {'l'},
        projectIds: {'p'},
      );
      await LocationRepository(db).delete(worldId: 'w', id: 'l');
      expect(await db.select(db.journalLocationTags).get(), isEmpty);
      expect((await db.select(db.projects).get()).single.locationId, isNull);
      expect((await repo.watch('w').first).single.body, entry.body);
      await ProjectRepository(db).delete(worldId: 'w', id: 'p');
      expect(await db.select(db.journalProjectTags).get(), isEmpty);
      final l2 = await LocationRepository(
        db,
      ).save(worldId: 'w', name: 'Other', x: 1, y: 2, z: 3, dimension: 'End');
      await repo.save(
        worldId: 'w',
        id: 'j',
        title: 'Updated',
        body: entry.body,
        occurredAt: entry.occurredAt,
        locationIds: {l2},
      );
      await repo.delete(worldId: 'w', id: 'j');
      expect(await db.select(db.journalLocationTags).get(), isEmpty);
      expect(await db.select(db.locations).get(), hasLength(1));
    } finally {
      await db.close();
      await dir.delete(recursive: true);
    }
  });
  test(
    'cross-world and stale tags fail atomically without changing entry',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final worlds = WorldRepository(db);
        final journals = JournalRepository(db);
        final a = await worlds.save(name: 'A', edition: 'Java');
        final b = await worlds.save(name: 'B', edition: 'Java');
        final l = await LocationRepository(
          db,
        ).save(worldId: a, name: 'Home', x: 1, y: 2, z: 3, dimension: 'End');
        final foreignL = await LocationRepository(
          db,
        ).save(worldId: b, name: 'Home', x: 1, y: 2, z: 3, dimension: 'End');
        final p = await ProjectRepository(db).save(worldId: a, name: 'Bridge');
        final foreignP = await ProjectRepository(
          db,
        ).save(worldId: b, name: 'Bridge');
        final date = DateTime(2026);
        final id = await journals.save(
          worldId: a,
          title: 'Original',
          body: 'Notes',
          occurredAt: date,
          locationIds: {l},
          projectIds: {p},
        );
        for (final tags in [
          {foreignL},
          {'missing'},
        ]) {
          await expectLater(
            journals.save(
              worldId: a,
              id: id,
              title: 'Wrong',
              body: 'Wrong',
              occurredAt: date,
              locationIds: tags,
              projectIds: {},
            ),
            throwsStateError,
          );
        }
        await expectLater(
          journals.save(
            worldId: a,
            id: id,
            title: 'Wrong',
            body: 'Wrong',
            occurredAt: date,
            locationIds: {},
            projectIds: {foreignP},
          ),
          throwsStateError,
        );
        await expectLater(
          journals.save(
            worldId: b,
            id: id,
            title: 'Wrong',
            body: '',
            occurredAt: date,
            locationIds: {},
            projectIds: {},
          ),
          throwsStateError,
        );
        expect((await journals.watch(a).first).single.title, 'Original');
        expect(
          (await db.select(db.journalLocationTags).get()).single.locationId,
          l,
        );
        expect(
          (await db.select(db.journalProjectTags).get()).single.projectId,
          p,
        );
        expect(await journals.watch(b).first, isEmpty);
        await worlds.delete(a);
        expect(await db.select(db.journalLocationTags).get(), isEmpty);
        expect(await db.select(db.journalProjectTags).get(), isEmpty);
        expect(await db.select(db.projects).get(), hasLength(1));
      } finally {
        await db.close();
      }
    },
  );
}
