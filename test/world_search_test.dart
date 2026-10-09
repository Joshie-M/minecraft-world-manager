import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/features/search/world_search.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_editor.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';

void main() {
  test('search matches words literally and excludes stored mention URLs', () {
    expect(matchesWorldSearch('River bridge spruce', ' SPRUCE river '), isTrue);
    expect(matchesWorldSearch('River bridge', 'river town'), isFalse);
    expect(
      matchesWorldSearch(
        '[River](world-manager://project/secret-id)',
        'secret-id',
      ),
      isFalse,
    );
    expect(
      matchesWorldSearch('[River](world-manager://project/secret-id)', 'river'),
      isTrue,
    );
    expect(matchesWorldSearch('abc', '%'), isFalse);
  });
  test('initial tasks validate and persist with project atomically', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final world = await WorldRepository(
      db,
    ).save(name: 'World', edition: 'Java');
    final repo = ProjectRepository(db);
    await expectLater(
      repo.save(worldId: world, name: 'Invalid', initialTasks: ['Good', ' ']),
      throwsArgumentError,
    );
    expect(await db.select(db.projects).get(), isEmpty);
    await expectLater(
      repo.save(worldId: 'missing', name: 'Invalid', initialTasks: ['Good']),
      throwsA(anything),
    );
    expect(await db.select(db.projectTasks).get(), isEmpty);
    final id = await repo.save(
      worldId: world,
      name: 'Bridge',
      initialTasks: [' Gather wood ', 'Build supports'],
    );
    final tasks = await db.select(db.projectTasks).get();
    expect(tasks.map((t) => t.title), ['Gather wood', 'Build supports']);
    expect(tasks.map((t) => t.position), [0, 1]);
    expect(tasks.every((t) => t.projectId == id && !t.completed), isTrue);
    await expectLater(
      repo.save(
        worldId: world,
        id: id,
        name: 'Changed',
        initialTasks: ['Extra'],
      ),
      throwsArgumentError,
    );
    expect((await db.select(db.projects).getSingle()).name, 'Bridge');
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'world search reads scoped results and updates live at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        final other = await WorldRepository(
          db,
        ).save(name: 'Other', edition: 'Java');
        final projects = ProjectRepository(db);
        final id = await projects.save(
          worldId: world,
          name: 'River bridge',
          initialTasks: ['Gather wood'],
        );
        await projects.save(worldId: other, name: 'River secret');
        await LocationRepository(db).save(
          worldId: world,
          name: 'River base',
          x: 1,
          y: 64,
          z: 3,
          dimension: 'Overworld',
        );
        await JournalRepository(db).save(
          worldId: world,
          title: 'River trip',
          body: 'Quiet waters',
          occurredAt: DateTime.now(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: appTheme(Brightness.light),
              darkTheme: appTheme(Brightness.dark),
              themeMode: width < 600 ? ThemeMode.dark : ThemeMode.light,
              home: WorldSearch(worldId: world, worldName: 'Home'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byKey(const ValueKey('world-search'));
        await tester.enterText(field, 'river');
        await tester.pumpAndSettle();
        expect(find.text('3 results'), findsOneWidget);
        expect(find.text('River secret'), findsNothing);
        await tester.tap(find.text('River bridge'));
        await tester.pumpAndSettle();
        expect(find.text('Gather wood'), findsOneWidget);
        expect(find.text('Edit project'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('River base'));
        await tester.pumpAndSettle();
        expect(find.text('Copy coordinates'), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('River trip'));
        await tester.pumpAndSettle();
        expect(find.text('Quiet waters'), findsOneWidget);
        await tester.tap(find.byTooltip('Back to entries'));
        await tester.pumpAndSettle();
        await projects.delete(worldId: world, id: id);
        await tester.pumpAndSettle();
        expect(find.text('2 results'), findsOneWidget);
        await tester.enterText(field, 'nothing matches');
        await tester.pumpAndSettle();
        expect(
          find.text('No matches. Try another name or phrase.'),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(
          find.text('Find journal entries, locations, and projects.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'draft checklist creation validates, removes, and saves at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: appTheme(Brightness.light),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showProjectEditor(context, worldId: world),
                    child: const Text('Create'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('project-name')),
          'Bridge',
        );
        await tester.ensureVisible(find.text('Add task'));
        await tester.tap(find.text('Add task'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save project'));
        await tester.pumpAndSettle();
        expect(find.text('Give this task a name.'), findsOneWidget);
        final task = find.widgetWithText(TextFormField, 'Task name');
        await tester.ensureVisible(task);
        await tester.enterText(task, 'Gather wood');
        await tester.ensureVisible(find.text('Add task'));
        await tester.tap(find.text('Add task'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip('Remove task').last);
        await tester.tap(find.byTooltip('Remove task').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save project'));
        await tester.pumpAndSettle();
        expect((await db.select(db.projects).getSingle()).name, 'Bridge');
        expect(
          (await db.select(db.projectTasks).getSingle()).title,
          'Gather wood',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
