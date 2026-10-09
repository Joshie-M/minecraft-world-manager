import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_screen.dart';

void main() {
  testWidgets('keyboard shortcuts create and save a world', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const WorldManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Keyboard world');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard world'), findsOneWidget);
    expect(find.text('World saved on this device.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  for (final width in [390.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('world dashboard at width $width in $brightness', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final database = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(database.close);
        await WorldRepository(database).save(
          name: 'A world with a longer name',
          edition: 'Java',
          description:
              'A peaceful place for building, exploring, and keeping memories.',
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              theme: appTheme(brightness),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const WorldScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('A world with a longer name'), findsOneWidget);
        expect(find.text('New world'), findsOneWidget);
        expect(
          find.text('World Manager'),
          width >= 900 ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets('create, edit, cancel deletion, then delete through the UI', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const WorldManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create a world'));
    await tester.tap(find.text('Create a world'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save world'));
    await tester.pumpAndSettle();
    expect(find.text('Give your world a name.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'My adventure');
    await tester.tap(find.text('Save world'));
    await tester.pumpAndSettle();
    expect(find.text('World saved on this device.'), findsOneWidget);
    await tester.tap(find.text('My adventure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit world'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Home base');
    await tester.tap(find.text('Save world'));
    await tester.pumpAndSettle();
    expect(find.text('Home base'), findsWidgets);
    await tester.ensureVisible(find.text('Delete world'));
    await tester.tap(find.text('Delete world'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      (await database.select(database.worlds).get()).single.name,
      'Home base',
    );
    await tester.tap(find.text('Delete world'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Create a world'), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Unsubscribe from Drift before the test binding checks pending timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
