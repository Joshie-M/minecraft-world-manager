import 'dart:async';
import 'dart:typed_data';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/backup/backup_files.dart';
import 'package:minecraft_world_manager/features/backup/backup_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';

class FakeFiles implements BackupFiles {
  Uint8List? input, output;
  bool saveResult = true;
  bool throwSave = false;
  Completer<bool>? saving;
  @override
  Future<Uint8List?> pick() async => input;
  @override
  Future<bool> save(Uint8List bytes) async {
    output = bytes;
    if (throwSave) throw StateError('Write failure');
    return saving == null ? saveResult : saving!.future;
  }
}

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('backup save, cancel, validate and restore at $width', (
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
      final id = await WorldRepository(
        db,
      ).save(name: 'My world', edition: 'Java');
      await ProjectRepository(
        db,
      ).save(worldId: id, name: 'Bridge', initialTasks: ['Gather wood']);
      final files = FakeFiles();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            backupFilesProvider.overrideWithValue(files),
          ],
          child: const WorldManagerApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Backup & restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save backup'));
      await tester.pumpAndSettle();
      expect(find.text('Backup saved.'), findsOneWidget);
      expect(
        WorldBackup.parse(files.output!).tasks.single.title,
        'Gather wood',
      );
      files.saveResult = false;
      await tester.tap(find.text('Save backup'));
      await tester.pumpAndSettle();
      expect(find.text('Backup saved.'), findsNothing);
      files.throwSave = true;
      await tester.tap(find.text('Save backup'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not complete this operation.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Choose backup'));
      await tester.pumpAndSettle();
      expect(find.text('Restore as new worlds?'), findsNothing);
      files.input = Uint8List.fromList([1, 2, 3]);
      await tester.tap(find.text('Choose backup'));
      await tester.pumpAndSettle();
      expect(find.text('Restore as new worlds?'), findsNothing);
      expect((await db.select(db.worlds).get()).length, 1);
      files.input = files.output;
      await tester.tap(find.text('Choose backup'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Worlds: 1 · Journal entries: 0'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await db.select(db.worlds).get()).length, 1);
      // A late SQL failure produces an error and leaves the original records intact.
      await db.customStatement(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON project_tasks BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await tester.tap(find.text('Choose backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore copies'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Could not complete this operation.'),
        findsOneWidget,
      );
      expect((await db.select(db.worlds).get()).length, 1);
      await db.customStatement('DROP TRIGGER fail_restore');
      await tester.tap(find.text('Choose backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore copies'));
      await tester.pumpAndSettle();
      expect(
        find.text('Restored 1 world. Find the copies in Your worlds.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back to worlds'));
      await tester.pumpAndSettle();
      expect(find.text('My world'), findsOneWidget);
      expect(find.text('My world (restored)'), findsOneWidget);
      expect((await db.select(db.projectTasks).get()).length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('backup prevents duplicate operations and leaving while saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final files = FakeFiles()..saving = Completer<bool>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          backupFilesProvider.overrideWithValue(files),
        ],
        child: const WorldManagerApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Backup & restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save backup'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save backup'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Choose backup'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == 'Back to worlds',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Your worlds'))
          .onPressed,
      isNull,
    );
    files.saving!.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Backup saved.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
