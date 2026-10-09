import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('projects create, read, edit, filters and delete at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue = width < 600
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final world = await WorldRepository(
        db,
      ).save(name: 'My world', edition: 'Java');
      await LocationRepository(db).save(
        worldId: world,
        name: 'River base',
        x: -125,
        y: 64,
        z: 402,
        dimension: 'Overworld',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const WorldManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My world'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open projects'));
      await tester.tap(find.text('Open projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save project'));
      await tester.pumpAndSettle();
      expect(find.text('Give this project a name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('project-name')),
        'River bridge',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('project-notes')));
      await tester.enterText(
        find.byKey(const ValueKey('project-notes')),
        'Use spruce and stone',
      );
      await tester.ensureVisible(find.text('No location'));
      await tester.tap(find.text('No location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('River base · Overworld').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save project'));
      await tester.pumpAndSettle();
      expect(find.text('River bridge'), findsOneWidget);
      expect((await db.select(db.projects).get()).single.locationId, isNotNull);
      await tester.enterText(find.byType(TextField), 'spruce');
      await tester.pumpAndSettle();
      expect(find.text('River bridge'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'castle');
      await tester.pumpAndSettle();
      expect(find.text('No matching projects.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('All statuses'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete').last);
      await tester.pumpAndSettle();
      expect(find.text('No matching projects.'), findsOneWidget);
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All statuses').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('River bridge'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Use spruce and stone'), findsOneWidget);
      expect(find.text('Overworld · -125 64 402'), findsOneWidget);
      await tester.tap(find.text('Edit project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-name')),
        'Oak bridge',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('project-status')));
      await tester.tap(find.byKey(const ValueKey('project-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save project'));
      await tester.pumpAndSettle();
      expect(find.text('Oak bridge'), findsNWidgets(2));
      expect(find.text('Complete'), findsNWidgets(2));
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Project actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('project-name')),
        'Discard me',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.text('Oak bridge'), findsOneWidget);
      expect(find.text('Discard me'), findsNothing);
      await tester.tap(find.byTooltip('Project actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Oak bridge'), findsOneWidget);
      await tester.tap(find.byTooltip('Project actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Plan your next build or adventure.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
