import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/features/projects/material_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/projects/projects_screen.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/backup/backup_repository.dart';

void main() {
  test(
    'schema 6 migration preserves projects/tasks; materials persist and roundtrip backups',
    () async {
      final dir = await Directory.systemTemp.createTemp('materials-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/worlds.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final world = await WorldRepository(
        db,
      ).save(name: 'Home', edition: 'Java');
      final project = await ProjectRepository(
        db,
      ).save(worldId: world, name: 'Bridge', initialTasks: ['Build supports']);
      await db.close();
      final old = sqlite3.open(file.path);
      old.execute('DROP TABLE project_materials');
      old.execute('PRAGMA user_version=6');
      old.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      var repo = MaterialRepository(db);
      expect(
        (await db.select(db.projectTasks).get()).single.title,
        'Build supports',
      );
      final material = await repo.save(
        worldId: world,
        projectId: project,
        name: ' Spruce logs ',
        needed: 128,
        gathered: 32,
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      repo = MaterialRepository(db);
      expect((await repo.watch(world, project).first).single.gathered, 32);
      await repo.markGathered(worldId: world, projectId: project, id: material);
      expect((await repo.watch(world, project).first).single.gathered, 128);
      await repo.save(
        worldId: world,
        projectId: project,
        id: material,
        name: 'Spruce logs',
        needed: 128,
        gathered: 150,
      );
      await repo.markGathered(worldId: world, projectId: project, id: material);
      expect((await repo.watch(world, project).first).single.gathered, 150);
      expect((await db.select(db.projects).get()).single.status, 'Planned');
      final bytes = await BackupRepository(db).export();
      final backup = WorldBackup.parse(bytes);
      expect(backup.materials.single.name, 'Spruce logs');
      await BackupRepository(db).restore(backup);
      final copy = (await db.select(db.projects).get()).singleWhere(
        (p) => p.id != project,
      );
      final restored = (await repo.watch(copy.worldId, copy.id).first).single;
      expect(restored.id, isNot(material));
      expect(restored.needed, 128);
      expect(restored.gathered, 150);
      final legacy = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      legacy['version'] = 1;
      legacy.remove('materials');
      final legacyBackup = WorldBackup.parse(
        Uint8List.fromList(utf8.encode(jsonEncode(legacy))),
      );
      expect(legacyBackup.materials, isEmpty);
      final invalid = jsonDecode(utf8.decode(bytes));
      invalid['materials'][0]['needed'] = 0;
      expect(
        () => WorldBackup.parse(
          Uint8List.fromList(utf8.encode(jsonEncode(invalid))),
        ),
        throwsFormatException,
      );
      await ProjectRepository(db).delete(worldId: world, id: project);
      expect(
        (await db.select(db.projectMaterials).get()).single.id,
        restored.id,
      );
      await WorldRepository(db).delete(copy.worldId);
      expect(await db.select(db.projectMaterials).get(), isEmpty);
    },
  );
  test(
    'material validation, ownership, deletion and missing records',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final world = await WorldRepository(
        db,
      ).save(name: 'Home', edition: 'Java');
      final p = await ProjectRepository(
        db,
      ).save(worldId: world, name: 'Bridge');
      final q = await ProjectRepository(db).save(worldId: world, name: 'Tower');
      final repo = MaterialRepository(db);
      for (final quantities in [
        (0, 0),
        (-1, 0),
        (1000001, 0),
        (1, -1),
        (1, 1000001),
      ]) {
        await expectLater(
          repo.save(
            worldId: world,
            projectId: p,
            name: 'Stone',
            needed: quantities.$1,
            gathered: quantities.$2,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        repo.save(worldId: world, projectId: p, name: ' ', needed: 1),
        throwsArgumentError,
      );
      final id = await repo.save(
        worldId: world,
        projectId: p,
        name: 'Stone',
        needed: 64,
      );
      await expectLater(
        repo.save(worldId: 'foreign', projectId: p, name: 'Stone', needed: 1),
        throwsStateError,
      );
      await expectLater(
        repo.markGathered(worldId: 'foreign', projectId: p, id: id),
        throwsStateError,
      );
      await expectLater(
        repo.delete(worldId: world, projectId: q, id: id),
        throwsStateError,
      );
      await expectLater(
        repo.save(
          worldId: world,
          projectId: q,
          id: id,
          name: 'Stone',
          needed: 1,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.markGathered(worldId: world, projectId: p, id: 'missing'),
        throwsStateError,
      );
      expect(await repo.watch('foreign', p).first, isEmpty);
      await repo.delete(worldId: world, projectId: p, id: id);
      expect(await repo.watch(world, p).first, isEmpty);
    },
  );
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'materials CRUD, quantities, discard and save failure at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        final p = await ProjectRepository(
          db,
        ).save(worldId: world, name: 'Bridge');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: appTheme(width < 600 ? Brightness.dark : Brightness.light),
              home: ProjectsScreen(worldId: world, worldName: 'Home'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bridge'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add material'));
        await tester.tap(find.text('Add material'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(find.text('Give this material a name.'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('material-name')),
          'Stone',
        );
        await tester.enterText(
          find.byKey(const ValueKey('material-needed')),
          '1.5',
        );
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a whole number from 1 to 1000000.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const ValueKey('material-needed')),
          '64',
        );
        await tester.enterText(
          find.byKey(const ValueKey('material-gathered')),
          '16',
        );
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(find.text('16 of 64 gathered'), findsOneWidget);
        final id = (await db.select(db.projectMaterials).get()).single.id;
        await tester.ensureVisible(
          find.byKey(ValueKey('material-actions-$id')),
        );
        await tester.tap(find.byKey(ValueKey('material-actions-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mark gathered'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 1 materials ready'), findsOneWidget);
        expect((await db.select(db.projects).get()).single.status, 'Planned');
        await tester.tap(find.text('Stone'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('material-gathered')),
          '32',
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(find.text('32 of 64 gathered'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('material-actions-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete material'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Stone'), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('material-actions-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete material'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(
          find.text('Keep track of supplies for this build.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Add material'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('material-name')),
          'Logs',
        );
        await ProjectRepository(db).delete(worldId: world, id: p);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Could not save this material.'),
          findsOneWidget,
        );
        expect(find.text('Logs'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
