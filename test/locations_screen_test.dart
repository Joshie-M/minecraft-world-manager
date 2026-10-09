import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('location CRUD, clipboard and filters at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.platformBrightnessTestValue = width < 600
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
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
      await tester.ensureVisible(find.text('Open locations'));
      await tester.tap(find.text('Open locations'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save location'));
      await tester.pumpAndSettle();
      expect(find.text('Give this location a name.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('location-name')),
        'River base',
      );
      for (final entry in {'X': '-125', 'Y': '64', 'Z': '402'}.entries) {
        await tester.ensureVisible(
          find.byKey(ValueKey('coordinate-${entry.key}')),
        );
        await tester.enterText(
          find.byKey(ValueKey('coordinate-${entry.key}')),
          entry.value,
        );
      }
      await tester.enterText(find.byKey(const ValueKey('coordinate-X')), '1.5');
      await tester.tap(find.text('Save location'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a 32-bit whole number.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('coordinate-X')),
        '-125',
      );
      await tester.tap(find.text('Save location'));
      await tester.pumpAndSettle();
      expect(find.text('Location saved on this device.'), findsOneWidget);
      expect(find.text('-125 64 402'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy coordinates'));
      await tester.pumpAndSettle();
      expect(clipboard, '-125 64 402');
      await tester.enterText(find.byType(TextField), 'river');
      await tester.pumpAndSettle();
      expect(find.text('River base'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'village');
      await tester.pumpAndSettle();
      expect(find.text('No matching locations.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('All dimensions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nether').last);
      await tester.pumpAndSettle();
      expect(find.text('No matching locations.'), findsOneWidget);
      await tester.tap(find.text('Nether'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All dimensions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('River base'));
      await tester.pumpAndSettle();
      expect(
        find.byType(TextFormField),
        findsNothing,
      ); // Reading view has no editor fields.
      expect(find.text('X / Y / Z'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Location actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit location'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('location-name')),
        'Hill base',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard unsaved changes?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<String>).last,
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('custom-dimension')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('custom-dimension')),
        'Skylands',
      );
      await tester.tap(find.text('Save location'));
      await tester.pumpAndSettle();
      expect(find.text('Hill base'), findsOneWidget);
      await tester.tap(find.byTooltip('Location actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Hill base'), findsOneWidget);
      await tester.tap(find.byTooltip('Location actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Save a place worth returning to.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
