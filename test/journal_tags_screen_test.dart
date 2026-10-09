import 'dart:ui' show PointerDeviceKind;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/journal/entry_reader.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';
import 'package:minecraft_world_manager/features/journal/mention_controller.dart';
import 'package:minecraft_world_manager/features/locations/location_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'inline suggestions, save, hover, navigation and removal at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        final foreign = await WorldRepository(
          db,
        ).save(name: 'Other', edition: 'Java');
        final l = await LocationRepository(db).save(
          worldId: world,
          name: 'River base',
          x: -125,
          y: 64,
          z: 402,
          dimension: 'Overworld',
          notes: 'Beside the willow.',
        );
        final projects = ProjectRepository(db);
        final p = await projects.save(
          worldId: world,
          name: 'River bridge',
          notes: 'Oak arches.',
          status: 'In progress',
          locationId: l,
        );
        await projects.save(
          worldId: world,
          name: 'Finished dock',
          status: 'Complete',
          locationId: l,
        );
        await projects.save(worldId: foreign, name: 'River foreign');
        final j = await JournalRepository(db).save(
          worldId: world,
          title: 'A day by the river',
          body: 'Original notes',
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
        final notes = find.byType(TextField).last;
        await tester.ensureVisible(notes);
        await tester.pumpAndSettle();
        await tester.enterText(notes, 'Email user@river');
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('suggest-location-$l')), findsNothing);
        await tester.enterText(notes, '`@riv');
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('suggest-location-$l')), findsNothing);
        await tester.enterText(notes, 'Worked near @unknown');
        await tester.pumpAndSettle();
        expect(find.text('No matching projects or locations.'), findsOneWidget);
        await tester.enterText(notes, 'Worked near @riv');
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('suggest-location-$l')), findsOneWidget);
        expect(find.byKey(ValueKey('suggest-project-$p')), findsOneWidget);
        expect(find.text('River foreign'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsNothing);
        expect(find.byKey(ValueKey('suggest-location-$l')), findsNothing);
        await tester.enterText(notes, 'Worked near @river b');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('suggest-location-$l')));
        await tester.pumpAndSettle();
        final c =
            tester.widget<TextField>(notes).controller! as MentionController;
        expect(c.text, 'Worked near @River base ');
        expect(c.ids('location'), {l});
        expect(find.byKey(ValueKey('suggest-location-$l')), findsNothing);
        await tester.enterText(notes, '${c.text}and built @river');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(c.ids('project'), {p});
        await tester.tap(find.byTooltip('Close editor'));
        await tester.pumpAndSettle();
        expect(find.text('Discard unsaved changes?'), findsOneWidget);
        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Preview notes'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('mention-project-$p')), findsOneWidget);
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('mention-location-$l')), findsOneWidget);
        expect(find.byKey(ValueKey('mention-project-$p')), findsOneWidget);
        expect(find.byType(ActionChip), findsNothing);
        expect(
          (await db.select(db.journalLocationTags).get()).single.locationId,
          l,
        );
        expect(
          (await db.select(db.journalProjectTags).get()).single.projectId,
          p,
        );
        if (width > 600) {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          await mouse.moveTo(
            tester.getCenter(find.byKey(ValueKey('mention-location-$l'))),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(find.text('Beside the willow.'), findsOneWidget);
          await mouse.moveTo(Offset.zero);
          await tester.pumpAndSettle();
          await mouse.moveTo(
            tester.getCenter(find.byKey(ValueKey('mention-project-$p'))),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pumpAndSettle();
          expect(find.text('Oak arches.'), findsOneWidget);
          await mouse.removePointer();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(ValueKey('mention-location-$l')));
        await tester.pumpAndSettle();
        expect(find.text('Projects at this location'), findsOneWidget);
        expect(find.text('Finished dock'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        await tester.tap(find.widgetWithText(ListTile, 'River bridge'));
        await tester.pumpAndSettle();
        expect(find.text('Oak arches.'), findsOneWidget);
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit entry'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextField).last);
        await tester.pumpAndSettle();
        final reopened =
            tester.widget<TextField>(find.byType(TextField).last).controller!
                as MentionController;
        expect(
          reopened.text,
          'Worked near @River base and built @River bridge ',
        );
        expect(reopened.ids('project'), {p});
        await tester.enterText(
          find.byType(TextField).last,
          reopened.text.replaceFirst('@River bridge', 'a bridge'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('mention-project-$p')), findsNothing);
        expect(await db.select(db.journalProjectTags).get(), isEmpty);
        await LocationRepository(db).delete(worldId: world, id: l);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('mention-location-$l')));
        await tester.pumpAndSettle();
        expect(
          find.text('Location is no longer available in this world.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit entry'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('mention-location-$l')), findsOneWidget);
        expect(await db.select(db.journalLocationTags).get(), isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
  testWidgets('legacy links survive edit/save as inline mentions', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final w = await WorldRepository(db).save(name: 'Home', edition: 'Java');
    final p = await ProjectRepository(db).save(worldId: w, name: 'Old project');
    final j = await JournalRepository(db).save(
      worldId: w,
      title: 'Old entry',
      body: 'Keep my history. A normal @ remains.',
      occurredAt: DateTime(2026),
      projectIds: {p},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: appTheme(Brightness.light),
          home: EntryReader(worldId: w, worldName: 'Home', entryId: j),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('tag-project-$p')), findsOneWidget);
    await tester.tap(find.text('Edit entry'));
    await tester.pumpAndSettle();
    final c =
        tester.widget<TextField>(find.byType(TextField).last).controller!
            as MentionController;
    expect(
      c.text,
      'Keep my history. A normal @ remains.\n\nRelated: @Old project',
    );
    expect(find.text('No unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('mention-project-$p')), findsOneWidget);
    expect(find.text('Old project'), findsOneWidget);
    expect(find.text('@Old project'), findsNothing);
    expect(
      find.textContaining('A normal @ remains.', findRichText: true),
      findsWidgets,
    );
    expect(find.byType(ActionChip), findsNothing);
    expect((await db.select(db.journalProjectTags).get()).single.projectId, p);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
