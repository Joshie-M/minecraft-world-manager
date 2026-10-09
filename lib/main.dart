import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/app_database.dart';
import 'features/worlds/world_repository.dart';
import 'features/worlds/world_screen.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});
final repositoryProvider = Provider(
  (ref) => WorldRepository(ref.watch(databaseProvider)),
);
final worldsProvider = StreamProvider(
  (ref) => ref.watch(repositoryProvider).watchAll(),
);

void main() => runApp(const ProviderScope(child: WorldManagerApp()));

class WorldManagerApp extends StatelessWidget {
  const WorldManagerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Minecraft World Manager',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff397451)),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff397451),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const WorldScreen(),
  );
}
