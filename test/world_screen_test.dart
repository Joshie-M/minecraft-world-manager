import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';

void main() {
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
    expect(find.text('Home base'), findsWidgets);
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
