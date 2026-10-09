import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('journal flow at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue = width < 600
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      await WorldRepository(database).save(name: 'My world', edition: 'Java');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const WorldManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My world'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Give this entry a title.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Cave expedition');
      await tester.enterText(
        find.byType(TextField).last,
        'Found **diamonds** under the mountain.',
      );
      await tester.ensureVisible(find.text('Preview notes'));
      await tester.tap(find.text('Preview notes'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(
        find.textContaining('Found diamonds', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Journal entry saved on this device.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'DIAMONDS');
      await tester.pumpAndSettle();
      expect(find.text('Cave expedition'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'village');
      await tester.pumpAndSettle();
      expect(find.text('No matching entries'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cave expedition'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.textContaining('Found diamonds', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.text('Edit entry'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Diamond expedition');
      await tester.tap(find.byTooltip('Close editor'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save entry'));
      await tester.pumpAndSettle();
      expect(find.text('Diamond expedition'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to entries'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back to world'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Diamond expedition'));
      await tester.tap(find.text('Diamond expedition'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(
        find.textContaining('Found diamonds', findRichText: true),
        findsWidgets,
      );
      await tester.tap(find.byTooltip('Back to entries'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open journal'));
      await tester.tap(find.text('Open journal'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Entry actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Diamond expedition'), findsOneWidget);
      await tester.tap(find.byTooltip('Entry actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Every world has a story'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
