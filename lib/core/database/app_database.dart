import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Worlds extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get edition => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class JournalEntries extends Table {
  TextColumn get id => text()();
  TextColumn get worldId =>
      text().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get body => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Worlds, JournalEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(journalEntries);
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return NativeDatabase.createInBackground(
    File(p.join(directory.path, 'world_manager.sqlite')),
  );
});
