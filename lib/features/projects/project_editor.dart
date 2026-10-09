import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import 'project_repository.dart';
import 'task_drag_list.dart';
import '../locations/location_repository.dart';

Future<bool?> showProjectEditor(
  BuildContext context, {
  required String worldId,
  Project? project,
}) => showDialog<bool>(
  context: context,
  barrierDismissible: false,
  builder: (_) => ProjectEditor(worldId: worldId, project: project),
);

class ProjectEditor extends ConsumerStatefulWidget {
  const ProjectEditor({super.key, required this.worldId, this.project});
  final String worldId;
  final Project? project;
  @override
  ConsumerState<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends ConsumerState<ProjectEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.project?.name ?? '');
  late final notes = TextEditingController(text: widget.project?.notes ?? '');
  late String status = widget.project?.status ?? 'Planned';
  late String? locationId = widget.project?.locationId;
  final tasks = <TextEditingController>[];
  bool saving = false, allowLeave = false;
  String? error;
  bool get dirty =>
      name.text != (widget.project?.name ?? '') ||
      notes.text != (widget.project?.notes ?? '') ||
      status != (widget.project?.status ?? 'Planned') ||
      locationId != widget.project?.locationId ||
      tasks.isNotEmpty;
  @override
  void initState() {
    super.initState();
    for (final c in [name, notes]) {
      c.addListener(changed);
    }
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    for (final c in [name, notes]) {
      c.dispose();
    }
    for (final task in tasks) {
      task.dispose();
    }
    super.dispose();
  }

  Future<void> leave(bool saved) async {
    setState(() => allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, saved);
  }

  Future<void> close() async {
    if (saving) return;
    if (dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard changes'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    await leave(false);
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(projectRepositoryProvider)
          .save(
            worldId: widget.worldId,
            id: widget.project?.id,
            name: name.text,
            status: status,
            locationId: locationId,
            notes: notes.text,
            initialTasks: tasks.map((task) => task.text).toList(),
          );
      if (mounted) await leave(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this project. Your changes are still here; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: allowLeave || (!dirty && !saving),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) close();
    },
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
      },
      child: AlertDialog(
        title: Text(widget.project == null ? 'New project' : 'Edit project'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabeledField(
                    label: 'Project name',
                    child: TextFormField(
                      key: const ValueKey('project-name'),
                      controller: name,
                      autofocus: true,
                      enabled: !saving,
                      maxLength: 100,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this project a name.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Status',
                    child: DropdownButtonFormField<String>(
                      key: const ValueKey('project-status'),
                      initialValue: status,
                      items: projectStatuses
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => status = value!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ref
                      .watch(locationsProvider(widget.worldId))
                      .when(
                        loading: () => const Text('Loading saved locations…'),
                        error: (_, _) => Row(
                          children: [
                            const Expanded(
                              child: Text('Could not load locations.'),
                            ),
                            TextButton(
                              onPressed: () => ref.invalidate(
                                locationsProvider(widget.worldId),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                        data: (locations) {
                          final available = locations.any(
                            (l) => l.id == locationId,
                          );
                          return LabeledField(
                            label: 'Saved location (optional)',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  key: ValueKey(
                                    'project-location-${available ? locationId : "none"}',
                                  ),
                                  initialValue: available ? locationId : '',
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem(
                                      value: '',
                                      child: Text('No location'),
                                    ),
                                    ...locations.map(
                                      (l) => DropdownMenuItem(
                                        value: l.id,
                                        child: Text(
                                          '${l.name} · ${l.dimension}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: saving
                                      ? null
                                      : (value) => setState(
                                          () => locationId = value == ''
                                              ? null
                                              : value,
                                        ),
                                ),
                                if (locationId != null && !available)
                                  TextButton(
                                    onPressed: saving
                                        ? null
                                        : () =>
                                              setState(() => locationId = null),
                                    child: const Text(
                                      'Location unavailable. Remove link',
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Notes (optional)',
                    child: TextFormField(
                      key: const ValueKey('project-notes'),
                      controller: notes,
                      enabled: !saving,
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ),
                  if (widget.project == null) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Text('Checklist (optional)')),
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                  final task = TextEditingController();
                                  task.addListener(changed);
                                  tasks.add(task);
                                }),
                          icon: const Icon(CupertinoIcons.plus, size: 16),
                          label: const Text('Add task'),
                        ),
                      ],
                    ),
                    TaskDragList(
                      onReorder: (oldIndex, newIndex) {
                        if (saving) return;
                        setState(
                          () =>
                              tasks.insert(newIndex, tasks.removeAt(oldIndex)),
                        );
                      },
                      children: [
                        for (final task in tasks)
                          Padding(
                            key: ObjectKey(task),
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TaskDragHandle(
                                  key: ObjectKey(task),
                                  index: tasks.indexOf(task),
                                  enabled: !saving,
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: task,
                                    enabled: !saving,
                                    maxLength: 200,
                                    decoration: const InputDecoration(
                                      hintText: 'Task name',
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Give this task a name.'
                                        : null,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Task order',
                                  enabled: !saving,
                                  icon: const Icon(
                                    CupertinoIcons.arrow_up_arrow_down,
                                    size: 18,
                                  ),
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'up',
                                      enabled: tasks.indexOf(task) > 0,
                                      child: const Text('Move up'),
                                    ),
                                    PopupMenuItem(
                                      value: 'down',
                                      enabled:
                                          tasks.indexOf(task) <
                                          tasks.length - 1,
                                      child: const Text('Move down'),
                                    ),
                                  ],
                                  onSelected: (value) => setState(() {
                                    final index = tasks.indexOf(task);
                                    final target =
                                        index + (value == 'up' ? -1 : 1);
                                    if (target >= 0 && target < tasks.length) {
                                      tasks.insert(
                                        target,
                                        tasks.removeAt(index),
                                      );
                                    }
                                  }),
                                ),
                                IconButton(
                                  tooltip: 'Remove task',
                                  onPressed: saving
                                      ? null
                                      : () {
                                          setState(() => tasks.remove(task));
                                          // Dispose after the field has detached its listeners.
                                          WidgetsBinding.instance
                                              .addPostFrameCallback(
                                                (_) => task.dispose(),
                                              );
                                        },
                                  icon: const Icon(
                                    CupertinoIcons.minus_circle,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : close,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save project'),
          ),
        ],
      ),
    ),
  );
}
