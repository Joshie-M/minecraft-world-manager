import 'dart:ui' show PointerDeviceKind;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/journal/entry_reader.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'journal tags, hover/tap previews and reverse projects at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        final otherWorld = await WorldRepository(
          db,
        ).save(name: 'Other', edition: 'Java');
        final locations = LocationRepository(db);
        final projects = ProjectRepository(db);
        final l = await locations.save(
          worldId: world,
          name: 'River base',
          x: -125,
          y: 64,
          z: 402,
          dimension: 'Overworld',
          notes: 'Beside the old willow.',
        );
        final p = await projects.save(
          worldId: world,
          name: 'River bridge',
          notes: 'Oak and stone arches.',
          status: 'In progress',
          locationId: l,
        );
        await projects.save(
          worldId: world,
          name: 'Finished dock',
          status: 'Complete',
          locationId: l,
        );
        await projects.save(worldId: world, name: 'Unrelated tower');
        await locations.save(
          worldId: otherWorld,
          name: 'Foreign place',
          x: 1,
          y: 2,
          z: 3,
          dimension: 'End',
        );
        await projects.save(worldId: otherWorld, name: 'Foreign build');
        final j = await JournalRepository(db).save(
          worldId: world,
          title: 'A day by the river',
          body: 'Journal notes',
          occurredAt: DateTime(2026),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: appTheme(width < 600 ? Brightness.dark : Brightness.light),
              home: EntryReader(worldId: world, worldName: 'Home', entryId: j),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit entry'));
        await tester.pumpAndSettle();
        expect(find.text('Foreign place'), findsNothing);
        expect(find.text('Foreign build'), findsNothing);
        await tester.ensureVisible(find.byKey(ValueKey('pick-location-$l')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('pick-location-$l')));
        await tester.ensureVisible(find.byKey(ValueKey('pick-project-$p')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('pick-project-$p')));
        // Tag-only edits must participate in discard confirmation.
        await tester.tap(find.byTooltip('Close editor'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('tag-location-$l')), findsOneWidget);
        expect(find.byKey(ValueKey('tag-project-$p')), findsOneWidget);
        if (width > 600) {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(
            tester.getCenter(find.byKey(ValueKey('tag-location-$l'))),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(find.text('Beside the old willow.'), findsOneWidget);
          expect(find.text('Overworld · -125 64 402'), findsOneWidget);
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          await mouse.moveTo(
            tester.getCenter(find.byKey(ValueKey('tag-project-$p'))),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(find.text('Oak and stone arches.'), findsOneWidget);
          await mouse.removePointer();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey('tag-location-$l')));
        await tester.pumpAndSettle();
        expect(find.text('Projects at this location'), findsOneWidget);
        expect(find.text('Finished dock'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        expect(find.text('Unrelated tower'), findsNothing);
        await tester.tap(find.widgetWithText(ListTile, 'River bridge'));
        await tester.pumpAndSettle();
        expect(find.text('Oak and stone arches.'), findsOneWidget);
        await tester.tap(find.text('Edit project'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('project-name')),
          'Renamed bridge',
        );
        await tester.tap(find.text('Save project'));
        await tester.pumpAndSettle();
        expect(find.text('Renamed bridge'), findsWidgets);
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Renamed bridge'), findsOneWidget);
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        expect(find.text('Renamed bridge'), findsOneWidget);
        await tester.tap(find.text('Edit entry'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilterChip>(find.byKey(ValueKey('pick-location-$l')))
              .selected,
          isTrue,
        );
        await tester.ensureVisible(find.byKey(ValueKey('pick-location-$l')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('pick-location-$l')));
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('tag-location-$l')), findsNothing);
        expect(find.byKey(ValueKey('tag-project-$p')), findsOneWidget);
        await tester.tap(find.text('Edit entry'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'Keep my edited title',
        );
        await projects.delete(worldId: world, id: p);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            'Could not save this entry. Your notes are still here; please try again.',
          ),
          findsOneWidget,
        );
        expect(find.text('Keep my edited title'), findsOneWidget);
        await tester.ensureVisible(
          find.widgetWithText(InputChip, 'Unavailable project'),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.widgetWithText(InputChip, 'Unavailable project'),
            matching: find.byTooltip('Delete'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('tag-project-$p')), findsNothing);
        expect(find.text('Journal notes'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
