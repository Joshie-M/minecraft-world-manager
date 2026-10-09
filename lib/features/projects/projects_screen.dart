import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import '../../core/database/app_database.dart';
import '../locations/location_repository.dart';
import '../locations/locations_screen.dart';
import 'project_repository.dart';
import 'project_editor.dart';

Future<void> showProjectDetails(
  BuildContext context, {
  required String worldId,
  required String id,
}) => showDialog<void>(
  context: context,
  builder: (_) => ProjectDetails(worldId: worldId, id: id),
);

class ProjectDetails extends ConsumerWidget {
  const ProjectDetails({super.key, required this.worldId, required this.id});
  final String worldId, id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider(worldId));
    Project? project;
    for (final p in projects.asData?.value ?? <Project>[]) {
      if (p.id == id) project = p;
    }
    final current = project;
    Location? location;
    for (final l
        in ref.watch(locationsProvider(worldId)).asData?.value ??
            <Location>[]) {
      if (l.id == current?.locationId) location = l;
    }
    final linked = location;
    return AlertDialog(
      title: Text(current?.name ?? 'Project'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: current == null
              ? Text(
                  projects.isLoading
                      ? 'Loading project…'
                      : projects.hasError
                      ? 'Could not load project.'
                      : 'This project is no longer available.',
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(current.status),
                    const SizedBox(height: 20),
                    SelectableText(
                      current.notes.isEmpty ? 'No notes yet.' : current.notes,
                    ),
                    if (linked != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Saved location',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(linked.name),
                      Text('${linked.dimension} · ${coordinateText(linked)}'),
                      TextButton.icon(
                        onPressed: () => copyCoordinates(context, linked),
                        icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                        label: const Text('Copy coordinates'),
                      ),
                    ],
                    if (current.locationId != null && linked == null)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'Linked location is currently unavailable.',
                        ),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (current != null)
          OutlinedButton.icon(
            onPressed: () =>
                showProjectEditor(context, worldId: worldId, project: current),
            icon: const Icon(CupertinoIcons.pencil, size: 16),
            label: const Text('Edit project'),
          ),
      ],
    );
  }
}

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId;
  final String worldName;
  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String query = '';
  String? status;
  Future<void> edit([Project? project]) async {
    final saved = await showProjectEditor(
      context,
      worldId: widget.worldId,
      project: project,
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project saved on this device.')),
      );
    }
  }

  Future<void> delete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'Permanently delete "${project.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(projectRepositoryProvider)
          .delete(worldId: widget.worldId, id: project.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete project. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppShell(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to world',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Projects', style: theme.textTheme.titleLarge),
                      Text(
                        widget.worldName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => edit(),
                  icon: const Icon(CupertinoIcons.plus, size: 16),
                  label: const Text('New project'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search projects',
                prefixIcon: Icon(CupertinoIcons.search, size: 16),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: ref
                .watch(projectsProvider(widget.worldId))
                .when(
                  loading: () =>
                      const Center(child: CupertinoActivityIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load projects.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(projectsProvider(widget.worldId)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (all) {
                    final needle = query.trim().toLowerCase();
                    final filtered = all
                        .where(
                          (p) =>
                              (status == null || p.status == status) &&
                              '${p.name} ${p.notes}'.toLowerCase().contains(
                                needle,
                              ),
                        )
                        .toList();
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(status),
                            initialValue: status ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Status filter',
                            ),
                            items: ['', ...projectStatuses]
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d.isEmpty ? 'All statuses' : d),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(
                              () => status = value == '' ? null : value,
                            ),
                          ),
                        ),
                        Expanded(
                          child: filtered.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      all.isEmpty
                                          ? 'Plan your next build or adventure.'
                                          : 'No matching projects.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final project = filtered[index];
                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                      title: Text(
                                        project.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(project.status),
                                      onTap: () => showProjectDetails(
                                        context,
                                        worldId: widget.worldId,
                                        id: project.id,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          PopupMenuButton<String>(
                                            tooltip: 'Project actions',
                                            icon: const Icon(
                                              CupertinoIcons.ellipsis,
                                            ),
                                            onSelected: (value) =>
                                                value == 'edit'
                                                ? edit(project)
                                                : delete(project),
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Edit project'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete project'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class WorldProjectsSection extends ConsumerWidget {
  const WorldProjectsSection({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId;
  final String worldName;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(),
      const SizedBox(height: 20),
      Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Projects', style: Theme.of(context).textTheme.titleLarge),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ProjectsScreen(worldId: worldId, worldName: worldName),
              ),
            ),
            child: const Text('Open projects'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      ref
          .watch(projectsProvider(worldId))
          .when(
            loading: () => const CupertinoActivityIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(projectsProvider(worldId)),
              child: const Text('Retry loading projects'),
            ),
            data: (projects) => projects.isEmpty
                ? const Text('No projects yet.')
                : Column(
                    children: projects
                        .take(3)
                        .map(
                          (project) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(project.name),
                            subtitle: Text(project.status),
                            onTap: () => showProjectDetails(
                              context,
                              worldId: worldId,
                              id: project.id,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
    ],
  );
}
