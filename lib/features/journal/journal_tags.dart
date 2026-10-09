import 'package:drift/drift.dart' hide Column;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../core/database/app_database.dart';
import 'journal_repository.dart';
import 'mention_controller.dart';
import '../locations/location_repository.dart';
import '../locations/locations_screen.dart';
import '../projects/project_repository.dart';
import '../projects/projects_screen.dart';

final entryLocationTagsProvider =
    StreamProvider.family<Set<String>, (String, String)>((ref, key) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.journalLocationTags).join([
            innerJoin(
              db.journalEntries,
              db.journalEntries.id.equalsExp(db.journalLocationTags.entryId),
            ),
          ])..where(
            db.journalEntries.worldId.equals(key.$1) &
                db.journalEntries.id.equals(key.$2),
          ))
          .watch()
          .map(
            (rows) => rows
                .map((r) => r.readTable(db.journalLocationTags).locationId)
                .toSet(),
          );
    });
final entryProjectTagsProvider =
    StreamProvider.family<Set<String>, (String, String)>((ref, key) {
      final db = ref.watch(databaseProvider);
      return (db.select(db.journalProjectTags).join([
            innerJoin(
              db.journalEntries,
              db.journalEntries.id.equalsExp(db.journalProjectTags.entryId),
            ),
          ])..where(
            db.journalEntries.worldId.equals(key.$1) &
                db.journalEntries.id.equals(key.$2),
          ))
          .watch()
          .map(
            (rows) => rows
                .map((r) => r.readTable(db.journalProjectTags).projectId)
                .toSet(),
          );
    });

class RecordPreview extends StatelessWidget {
  const RecordPreview({
    super.key,
    required this.name,
    required this.kind,
    required this.summary,
    required this.notes,
    required this.child,
  });
  final String name, kind, summary, notes;
  final Widget child;
  @override
  Widget build(BuildContext context) => Tooltip(
    waitDuration: const Duration(milliseconds: 350),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    textStyle: Theme.of(context).textTheme.bodyMedium,

    richMessage: WidgetSpan(
      child: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kind, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(summary),
            if (notes.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(notes, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    ),
    child: child,
  );
}

class RecordTag extends StatelessWidget {
  const RecordTag({
    super.key,
    required this.name,
    required this.kind,
    required this.summary,
    required this.notes,
    required this.onPressed,
  });
  final String name, kind, summary, notes;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => RecordPreview(
    name: name,
    kind: kind,
    summary: summary,
    notes: notes,
    child: ActionChip(
      avatar: Icon(
        kind == 'Location' ? CupertinoIcons.map_pin : CupertinoIcons.hammer,
        size: 14,
      ),
      label: Text(name),
      onPressed: onPressed,
    ),
  );
}

String projectSummary(Project project, List<Location> locations) {
  final linked = locations.where((l) => l.id == project.locationId);
  if (linked.isEmpty) return project.status;
  final location = linked.first;
  return '${project.status}\n${location.name} · ${location.dimension}\n${coordinateText(location)}';
}

class JournalTags extends ConsumerWidget {
  const JournalTags({super.key, required this.worldId, required this.entryId});
  final String worldId, entryId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationIds = ref.watch(
      entryLocationTagsProvider((worldId, entryId)),
    );
    final projectIds = ref.watch(entryProjectTagsProvider((worldId, entryId)));
    final locations = ref.watch(locationsProvider(worldId));
    final projects = ref.watch(projectsProvider(worldId));
    if ([locationIds, projectIds, locations, projects].any((v) => v.hasError)) {
      return TextButton(
        onPressed: () {
          ref.invalidate(entryLocationTagsProvider((worldId, entryId)));
          ref.invalidate(entryProjectTagsProvider((worldId, entryId)));
          ref.invalidate(locationsProvider(worldId));
          ref.invalidate(projectsProvider(worldId));
        },
        child: const Text('Retry loading tags'),
      );
    }
    if ([
      locationIds,
      projectIds,
      locations,
      projects,
    ].any((v) => v.isLoading)) {
      return const CupertinoActivityIndicator();
    }
    final entries =
        ref.watch(journalProvider(worldId)).asData?.value ?? <JournalEntry>[];
    final body =
        entries.where((e) => e.id == entryId).map((e) => e.body).firstOrNull ??
        '';
    final controller = MentionController(body);
    final inlineLocations = controller.ids('location'),
        inlineProjects = controller.ids('project');
    controller.dispose();
    final linkedLocations = locations.requireValue.where(
      (l) =>
          locationIds.requireValue.contains(l.id) &&
          !inlineLocations.contains(l.id),
    );
    final linkedProjects = projects.requireValue.where(
      (p) =>
          projectIds.requireValue.contains(p.id) &&
          !inlineProjects.contains(p.id),
    );
    if (linkedLocations.isEmpty && linkedProjects.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tagged locations & projects',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in linkedLocations)
                RecordTag(
                  key: ValueKey('tag-location-${l.id}'),
                  name: l.name,
                  kind: 'Location',
                  summary: '${l.dimension} · ${coordinateText(l)}',
                  notes: l.notes,
                  onPressed: () => showLocationDetails(context, l),
                ),
              for (final p in linkedProjects)
                RecordTag(
                  key: ValueKey('tag-project-${p.id}'),
                  name: p.name,
                  kind: 'Project',
                  summary: projectSummary(p, locations.requireValue),
                  notes: p.notes,
                  onPressed: () =>
                      showProjectDetails(context, worldId: worldId, id: p.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
