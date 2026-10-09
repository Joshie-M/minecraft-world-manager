import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  test('create, edit, reopen and delete a world on disk', () async {
    final directory = await Directory.systemTemp.createTemp(
      'world-manager-test',
    );
    final file = File('${directory.path}/test.sqlite');
    var database = AppDatabase.forTesting(NativeDatabase(file));
    try {
      var repository = WorldRepository(database);
      final id = await repository.save(name: '  Survival  ', edition: 'Java');
      final second = await repository.save(
        name: 'Creative',
        edition: 'Bedrock',
      );
      final original = (await repository.watchAll().first).firstWhere(
        (w) => w.id == id,
      );
      expect(original.name, 'Survival');
      await repository.save(
        id: id,
        name: 'Home',
        edition: 'Java',
        description: 'My base',
      );
      await database.close();
      database = AppDatabase.forTesting(NativeDatabase(file));
      repository = WorldRepository(database);
      final worlds = await repository.watchAll().first;
      expect(worlds, hasLength(2));
      final restored = worlds.firstWhere((w) => w.id == id);
      expect(restored.name, 'Home');
      expect(restored.description, 'My base');
      expect(restored.createdAt, original.createdAt);
      await repository.delete(id);
      expect((await repository.watchAll().first).single.id, second);
    } finally {
      await database.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'reject invalid names, editions and updates of missing worlds',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = WorldRepository(database);
      try {
        await expectLater(
          repository.save(name: ' ', edition: 'Java'),
          throwsArgumentError,
        );
        await expectLater(
          repository.save(name: 'World', edition: 'Unknown'),
          throwsArgumentError,
        );
        await expectLater(
          repository.save(id: 'missing', name: 'World', edition: 'Java'),
          throwsStateError,
        );
        expect(await repository.watchAll().first, isEmpty);
      } finally {
        await database.close();
      }
    },
  );
}
