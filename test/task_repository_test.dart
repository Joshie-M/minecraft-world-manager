import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:minecraft_world_manager/core/database/app_database.dart';
import 'package:minecraft_world_manager/features/projects/task_repository.dart';
import 'package:minecraft_world_manager/features/projects/project_repository.dart';
import 'package:minecraft_world_manager/features/worlds/world_repository.dart';
import 'package:minecraft_world_manager/features/journal/journal_repository.dart';

void main() {
  test(
    'schema 5 upgrade preserves journal links; checklist order and edits survive reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('project-tasks');
      final file = File('${dir.path}/db.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final w = await WorldRepository(db).save(name: 'Home', edition: 'Java');
        final p = await ProjectRepository(
          db,
        ).save(worldId: w, name: 'Bridge', notes: 'Keep notes');
        final j = await JournalRepository(db).save(
          worldId: w,
          title: 'Day one',
          body: 'Keep journal',
          occurredAt: DateTime(2026),
          projectIds: {p},
        );
        await db.close();
        // All other tables are identical to schema 5; removing the new table yields a real old-schema fixture.
        final old = sqlite3.open(file.path);
        old.execute('DROP TABLE project_tasks');
        old.execute('PRAGMA user_version=5');
        old.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        var repo = TaskRepository(db);
        expect(
          (await db.select(db.journalProjectTags).get()).single.entryId,
          j,
        );
        expect((await db.select(db.projects).get()).single.notes, 'Keep notes');
        final first = await repo.save(
          worldId: w,
          projectId: p,
          title: ' Gather wood ',
        );
        final second = await repo.save(
          worldId: w,
          projectId: p,
          title: 'Build supports',
        );
        await repo.setCompleted(
          worldId: w,
          projectId: p,
          id: first,
          completed: true,
        );
        await repo.save(
          worldId: w,
          projectId: p,
          id: first,
          title: 'Gather oak',
        );
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        repo = TaskRepository(db);
        var tasks = await repo.watch(w, p).first;
        expect(tasks.map((t) => t.id), [first, second]);
        expect(tasks.first.title, 'Gather oak');
        expect(tasks.first.completed, isTrue);
        expect((await db.select(db.projects).get()).single.status, 'Planned');
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          6,
        );
        await repo.setCompleted(
          worldId: w,
          projectId: p,
          id: first,
          completed: false,
        );
        expect((await repo.watch(w, p).first).first.completed, isFalse);
        await repo.delete(worldId: w, projectId: p, id: first);
        final third = await repo.save(
          worldId: w,
          projectId: p,
          title: 'Lighting',
        );
        tasks = await repo.watch(w, p).first;
        expect(tasks.map((t) => t.id), [second, third]);
        await ProjectRepository(db).delete(worldId: w, id: p);
        expect(await db.select(db.projectTasks).get(), isEmpty);
        expect(
          (await db.select(db.journalEntries).get()).single.body,
          'Keep journal',
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
  test(
    'rejects invalid tasks, stale IDs and cross-world/project writes',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final worlds = WorldRepository(db);
        final projects = ProjectRepository(db);
        final tasks = TaskRepository(db);
        final a = await worlds.save(name: 'A', edition: 'Java');
        final b = await worlds.save(name: 'B', edition: 'Java');
        final p = await projects.save(worldId: a, name: 'Bridge');
        final other = await projects.save(worldId: a, name: 'Tower');
        final foreign = await projects.save(worldId: b, name: 'Base');
        final id = await tasks.save(
          worldId: a,
          projectId: p,
          title: 'Gather wood',
        );
        await tasks.save(worldId: b, projectId: foreign, title: 'Other world');
        for (final title in [' ', 'x' * 201]) {
          await expectLater(
            tasks.save(worldId: a, projectId: p, title: title),
            throwsArgumentError,
          );
        }
        await expectLater(
          tasks.save(worldId: b, projectId: p, title: 'Wrong'),
          throwsStateError,
        );
        await expectLater(
          tasks.save(worldId: a, projectId: other, id: id, title: 'Wrong'),
          throwsStateError,
        );
        await expectLater(
          tasks.setCompleted(worldId: b, projectId: p, id: id, completed: true),
          throwsStateError,
        );
        await expectLater(
          tasks.delete(worldId: a, projectId: other, id: id),
          throwsStateError,
        );
        await expectLater(
          tasks.setCompleted(
            worldId: a,
            projectId: p,
            id: 'missing',
            completed: true,
          ),
          throwsStateError,
        );
        await expectLater(
          tasks.save(worldId: a, projectId: 'missing', title: 'Wrong'),
          throwsStateError,
        );
        expect(await tasks.watch(b, p).first, isEmpty);
        expect((await tasks.watch(a, p).first).single.completed, isFalse);
        await worlds.delete(a);
        expect(
          (await db.select(db.projectTasks).get()).single.title,
          'Other world',
        );
      } finally {
        await db.close();
      }
    },
  );
}
