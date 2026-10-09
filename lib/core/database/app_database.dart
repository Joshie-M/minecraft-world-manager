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

class Locations extends Table {
  TextColumn get id => text()();
  TextColumn get worldId =>
      text().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get x => integer()();
  IntColumn get y => integer()();
  IntColumn get z => integer()();
  TextColumn get dimension => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get worldId =>
      text().references(Worlds, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get locationId => text().nullable().references(
    Locations,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class JournalLocationTags extends Table {
  TextColumn get entryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get locationId =>
      text().references(Locations, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {entryId, locationId};
}

class JournalProjectTags extends Table {
  TextColumn get entryId =>
      text().references(JournalEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {entryId, projectId};
}

class ProjectTasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

class ProjectMaterials extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get needed => integer()();
  IntColumn get gathered => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Worlds,
    JournalEntries,
    Locations,
    Projects,
    JournalLocationTags,
    JournalProjectTags,
    ProjectTasks,
    ProjectMaterials,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(journalEntries);
      if (from < 3) await m.createTable(locations);
      if (from < 4) await m.createTable(projects);
      if (from < 6) await m.createTable(projectTasks);
      if (from < 7) await m.createTable(projectMaterials);
      if (from < 5) {
        await m.createTable(journalLocationTags);
        await m.createTable(journalProjectTags);
      }
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
