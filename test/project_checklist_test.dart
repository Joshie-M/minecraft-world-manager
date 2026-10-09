import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/projects/projects_screen.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('checklist CRUD, completion, discard and reopen at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final world = await WorldRepository(
        db,
      ).save(name: 'Home', edition: 'Java');
      final project = await ProjectRepository(
        db,
      ).save(worldId: world, name: 'River bridge');
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
      await tester.tap(find.text('River bridge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.text('Give this task a name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Gather wood',
      );
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.text('0 of 1 complete'), findsOneWidget);
      final id = (await db.select(db.projectTasks).get()).single.id;
      await tester.tap(find.byKey(ValueKey('complete-$id')));
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 complete'), findsOneWidget);
      expect((await db.select(db.projects).get()).single.status, 'Planned');
      await tester.tap(find.byKey(ValueKey('task-actions-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Gather oak',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(find.text('Gather oak'), findsOneWidget);
      expect(find.text('1 of 1 complete'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Discard me',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(await db.select(db.projectTasks).get(), hasLength(1));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('River bridge'));
      await tester.pumpAndSettle();
      expect(find.text('Gather oak'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.byKey(ValueKey('complete-$id'))).value,
        isTrue,
      );
      await tester.tap(find.byKey(ValueKey('complete-$id')));
      await tester.pumpAndSettle();
      expect(find.text('0 of 1 complete'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('task-actions-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Gather oak'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('task-actions-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        find.text('Break this project into a few small steps.'),
        findsOneWidget,
      );
      // A project removed while a task editor is open must retain unsaved task input on failure.
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title')),
        'Keep this text',
      );
      await ProjectRepository(db).delete(worldId: world, id: project);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not save this task. Your text is still here; please try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Keep this text'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
