import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';

void main() {
  test(
    'migrates version 1, preserves worlds, and persists journal edits across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'journal-migration',
      );
      final file = File('${directory.path}/worlds.sqlite');
      final old = sqlite3.open(file.path);
      old.execute(
        'CREATE TABLE worlds (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT \'\', edition TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
      );
      old.execute(
        "INSERT INTO worlds VALUES ('existing', 'Existing world', 'Keep me', 'Java', 1700000000, 1700000000)",
      );
      old.execute('PRAGMA user_version = 1');
      old.close();
      var database = AppDatabase.forTesting(NativeDatabase(file));
      try {
        expect(
          (await WorldRepository(database).watchAll().first).single.description,
          'Keep me',
        );
        var repository = JournalRepository(database);
        final id = await repository.save(
          worldId: 'existing',
          title: ' First adventure ',
          body: '**A cave**',
          occurredAt: DateTime.utc(2026, 1, 2),
        );
        await repository.save(
          worldId: 'existing',
          id: id,
          title: 'Found a cave',
          body: 'Diamonds and **gold**',
          occurredAt: DateTime.utc(2026, 1, 3),
        );
        await database.close();
        database = AppDatabase.forTesting(NativeDatabase(file));
        repository = JournalRepository(database);
        final restored = (await repository.watch('existing').first).single;
        expect(restored.id, id);
        expect(restored.title, 'Found a cave');
        expect(restored.body, 'Diamonds and **gold**');
        expect(restored.occurredAt.toUtc(), DateTime.utc(2026, 1, 3));
        expect(
          (await database.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          3,
        );
        await repository.delete(worldId: 'existing', id: id);
        expect(await repository.watch('existing').first, isEmpty);
      } finally {
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'isolates worlds, searches literal text, orders dates and cascades only owned entries',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final worlds = WorldRepository(database);
        final journal = JournalRepository(database);
        final a = await worlds.save(name: 'A', edition: 'Java');
        final b = await worlds.save(name: 'B', edition: 'Bedrock');
        final first = await journal.save(
          worldId: a,
          title: 'Old',
          body: '100% gold',
          occurredAt: DateTime.utc(2025),
        );
        final latest = await journal.save(
          worldId: a,
          title: 'New',
          body: 'a cave',
          occurredAt: DateTime.utc(2026),
        );
        final other = await journal.save(
          worldId: b,
          title: 'Other',
          body: 'gold',
          occurredAt: DateTime.utc(2027),
        );
        expect((await journal.watch(a).first).map((e) => e.id), [
          latest,
          first,
        ]);
        expect((await journal.watch(a, query: 'GOLD').first).single.id, first);
        expect((await journal.watch(a, query: '%').first).single.id, first);
        await expectLater(
          journal.save(
            worldId: b,
            id: first,
            title: 'Wrong world',
            body: '',
            occurredAt: DateTime.now(),
          ),
          throwsStateError,
        );
        await expectLater(
          journal.delete(worldId: b, id: first),
          throwsStateError,
        );
        await worlds.delete(a);
        expect(await journal.watch(a).first, isEmpty);
        expect((await journal.watch(b).first).single.id, other);
      } finally {
        await database.close();
      }
    },
  );

  test('rejects invalid titles and missing parent worlds', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final journal = JournalRepository(database);
      await expectLater(
        journal.save(
          worldId: 'missing',
          title: ' ',
          body: '',
          occurredAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
      await expectLater(
        journal.save(
          worldId: 'missing',
          title: 'Valid',
          body: '',
          occurredAt: DateTime.now(),
        ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      await database.close();
    }
  });
}
