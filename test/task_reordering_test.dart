import 'dart:io';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/projects/task_repository.dart';
import 'package:minecraft_world_manager/features/projects/projects_screen.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/backup/backup_repository.dart';

Future<List<ProjectTask>> ordered(AppDatabase db, String project) =>
    (db.select(db.projectTasks)
          ..where((t) => t.projectId.equals(project))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();

void main() {
  test(
    'task moves persist, isolate ownership and roll back on failure',
    () async {
      final dir = await Directory.systemTemp.createTemp('task-order-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/worlds.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      final world = await WorldRepository(
        db,
      ).save(name: 'Home', edition: 'Java');
      final other = await WorldRepository(
        db,
      ).save(name: 'Other', edition: 'Java');
      final p = await ProjectRepository(db).save(
        worldId: world,
        name: 'Bridge',
        initialTasks: ['One', 'Two', 'Three'],
      );
      final q = await ProjectRepository(
        db,
      ).save(worldId: other, name: 'Tower', initialTasks: ['Other task']);
      var repo = TaskRepository(db);
      final tasks = await ordered(db, p);
      final one = tasks[0].id, two = tasks[1].id, three = tasks[2].id;
      await repo.setCompleted(
        worldId: world,
        projectId: p,
        id: two,
        completed: true,
      );
      await repo.move(worldId: world, projectId: p, id: three, up: true);
      expect((await ordered(db, p)).map((t) => t.id), [one, three, two]);
      await repo.move(worldId: world, projectId: p, id: one, up: false);
      expect((await ordered(db, p)).map((t) => t.id), [three, one, two]);
      // Moving first up or last down is a harmless no-op.
      await repo.move(worldId: world, projectId: p, id: three, up: true);
      await repo.move(worldId: world, projectId: p, id: two, up: false);
      await expectLater(
        repo.move(worldId: other, projectId: p, id: one, up: true),
        throwsStateError,
      );
      await expectLater(
        repo.move(
          worldId: world,
          projectId: p,
          id: (await ordered(db, q)).single.id,
          up: true,
        ),
        throwsStateError,
      );
      await expectLater(
        repo.move(worldId: world, projectId: p, id: 'missing', up: true),
        throwsStateError,
      );
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(db.close);
      repo = TaskRepository(db);
      expect((await ordered(db, p)).map((t) => t.title), [
        'Three',
        'One',
        'Two',
      ]);
      expect((await ordered(db, p)).last.completed, isTrue);
      expect((await db.select(db.projects).get()).first.status, 'Planned');
      // Abort after an earlier position update to verify transaction rollback.
      await db.customStatement(
        "CREATE TRIGGER fail_order BEFORE UPDATE OF position ON project_tasks WHEN OLD.id = '$one' BEGIN SELECT RAISE(ABORT, 'write failure'); END",
      );
      await expectLater(
        repo.move(worldId: world, projectId: p, id: two, up: true),
        throwsA(anything),
      );
      expect((await ordered(db, p)).map((t) => t.id), [three, one, two]);
      await db.customStatement('DROP TRIGGER fail_order');
      await repo.delete(worldId: world, projectId: p, id: one);
      final added = await repo.save(
        worldId: world,
        projectId: p,
        title: 'Four',
      );
      await repo.move(worldId: world, projectId: p, id: added, up: true);
      expect((await ordered(db, p)).map((t) => t.title), [
        'Three',
        'Four',
        'Two',
      ]);
      expect((await ordered(db, p)).map((t) => t.position), [0, 1, 2]);
      await BackupRepository(
        db,
      ).restore(WorldBackup.parse(await BackupRepository(db).export()));
      final copy = (await db.select(db.projects).get()).singleWhere(
        (project) => project.name == 'Bridge' && project.id != p,
      );
      expect((await ordered(db, copy.id)).map((t) => t.title), [
        'Three',
        'Four',
        'Two',
      ]);
      expect((await ordered(db, q)).single.title, 'Other task');
    },
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('saved and draft task moves at $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final world = await WorldRepository(
        db,
      ).save(name: 'Home', edition: 'Java');
      final p = await ProjectRepository(db).save(
        worldId: world,
        name: 'Bridge',
        initialTasks: ['One', 'Two', 'Three'],
      );
      final tasks = await ordered(db, p);
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
      Future<void> menu(String id, String action) async {
        await tester.tap(find.byKey(ValueKey('task-actions-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await menu(tasks[2].id, 'Move up');
      expect(
        tester.getTopLeft(find.text('Three')).dy,
        lessThan(tester.getTopLeft(find.text('Two')).dy),
      );
      await menu(tasks[0].id, 'Move down');
      expect((await ordered(db, p)).map((t) => t.title), [
        'Three',
        'One',
        'Two',
      ]);
      await tester.tap(find.byKey(ValueKey('complete-${tasks[1].id}')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 3 complete'), findsOneWidget);
      await db.customStatement(
        "CREATE TRIGGER fail_order BEFORE UPDATE OF position ON project_tasks BEGIN SELECT RAISE(ABORT, 'failure'); END",
      );
      await menu(tasks[1].id, 'Move up');
      expect(
        find.text('Could not update this task. Please try again.'),
        findsOneWidget,
      );
      expect((await ordered(db, p)).map((t) => t.title), [
        'Three',
        'One',
        'Two',
      ]);
      await db.customStatement('DROP TRIGGER fail_order');
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bridge'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Three')).dy,
        lessThan(tester.getTopLeft(find.text('One')).dy),
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-name')),
        'Tower',
      );
      for (final title in ['Gather stone', 'Build walls']) {
        await tester.ensureVisible(find.text('Add task'));
        await tester.tap(find.text('Add task'));
        await tester.pumpAndSettle();
        final field = find.widgetWithText(TextFormField, 'Task name').last;
        await tester.ensureVisible(field);
        await tester.enterText(field, title);
      }
      await tester.ensureVisible(find.byTooltip('Task order').last);
      await tester.tap(find.byTooltip('Task order').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save project'));
      await tester.pumpAndSettle();
      final tower = (await db.select(db.projects).get()).singleWhere(
        (p) => p.name == 'Tower',
      );
      expect((await ordered(db, tower.id)).map((t) => t.title), [
        'Build walls',
        'Gather stone',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
