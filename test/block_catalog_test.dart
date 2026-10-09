import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minecraft_world_manager/app/theme.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/main.dart';
import 'package:minecraft_world_manager/features/projects/block_catalog.dart';
import 'package:minecraft_world_manager/features/projects/project_materials.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled catalog searches names and IDs with canonical stack sizes',
    () async {
      final catalog = await BlockCatalog.load();
      expect(catalog.blocks.length, 1326);
      expect(
        catalog.blocks.map((b) => b.name.toLowerCase()).toSet().length,
        catalog.blocks.length,
      );
      expect(
        catalog.blocks.every((b) => [1, 16, 64].contains(b.stackSize)),
        isTrue,
      );
      expect(catalog.match('oak_planks')!.stackSize, 64);
      expect(catalog.match('minecraft:oak_sign')!.stackSize, 16);
      expect(catalog.match('White Bed')!.stackSize, 1);
      expect(catalog.search('oak pla').first.name, 'Oak Planks');
      expect(
        catalog
            .search('stairs copper')
            .every((b) => b.name.toLowerCase().contains('copper')),
        isTrue,
      );
      expect(catalog.search('not_a_real_block'), isEmpty);
      expect(catalog.search(''), isEmpty);
      expect(catalog.match('Custom supply'), isNull);
    },
  );
  test(
    'stack breakdown covers remainders, exact stacks, zero and unstackable blocks',
    () {
      expect(stackQuantity(136, 64), '2 × stacks of 64 + 8 items');
      expect(stackQuantity(128, 64), '2 × stacks of 64');
      expect(stackQuantity(33, 16), '2 × stacks of 16 + 1 item');
      expect(stackQuantity(8, 64), '8 items');
      expect(stackQuantity(0, 64), '0 items');
      expect(stackQuantity(3, 1), '3 items (unstackable)');
      expect(() => stackQuantity(-1, 64), throwsArgumentError);
    },
  );
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'material autocomplete, keyboard, custom names and stacks at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final catalog = await tester.runAsync(BlockCatalog.load);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final world = await WorldRepository(
          db,
        ).save(name: 'Home', edition: 'Java');
        final project = await ProjectRepository(
          db,
        ).save(worldId: world, name: 'Bridge');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              blockCatalogProvider.overrideWith((ref) async => catalog!),
            ],
            child: MaterialApp(
              theme: appTheme(width < 600 ? Brightness.dark : Brightness.light),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          MaterialEditor(worldId: world, projectId: project),
                    ),
                    child: const Text('Add'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('Add'));
          await tester.pumpAndSettle();
        }

        await open();
        final name = find.byKey(const ValueKey('material-name'));
        final needed = find.byKey(const ValueKey('material-needed'));
        await tester.enterText(name, 'oak pla');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('block-option-oak_planks')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('block-option-oak_planks')));
        await tester.pumpAndSettle();
        await tester.enterText(needed, '136');
        await tester.pumpAndSettle();
        expect(find.text('Needed: 2 × stacks of 64 + 8 items'), findsOneWidget);
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(
          (await db.select(db.projectMaterials).get()).single.name,
          'Oak Planks',
        );
        await open();
        await tester.enterText(name, 'oak sign');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tester.widget<TextFormField>(name).controller!.text, 'Oak Sign');
        await tester.enterText(needed, '33');
        await tester.pumpAndSettle();
        expect(find.text('Needed: 2 × stacks of 16 + 1 item'), findsOneWidget);
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        await open();
        await tester.enterText(name, 'Custom supplies');
        await tester.pumpAndSettle();
        await tester.enterText(needed, '136');
        await tester.pumpAndSettle();
        expect(find.text('Needed: 2 × stacks of 64 + 8 items'), findsOneWidget);
        await tester.tap(find.text('Save material'));
        await tester.pumpAndSettle();
        expect(
          (await db.select(db.projectMaterials).get()).any(
            (m) => m.name == 'Custom supplies',
          ),
          isTrue,
        );
        // Read mode uses the same breakdown without editing saved quantities.
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              blockCatalogProvider.overrideWith((ref) async => catalog!),
            ],
            child: MaterialApp(
              theme: appTheme(Brightness.light),
              home: Scaffold(
                body: ProjectMaterialsSection(
                  worldId: world,
                  projectId: project,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Needed: 2 × stacks of 16 + 1 item'), findsOneWidget);
        expect(
          find.text('Needed: 2 × stacks of 64 + 8 items'),
          findsNWidgets(2),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
