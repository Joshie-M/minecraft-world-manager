import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import 'task_repository.dart';

class ProjectChecklist extends ConsumerStatefulWidget {
  const ProjectChecklist({
    super.key,
    required this.worldId,
    required this.projectId,
  });
  final String worldId, projectId;
  @override
  ConsumerState<ProjectChecklist> createState() => _ProjectChecklistState();
}

class _ProjectChecklistState extends ConsumerState<ProjectChecklist> {
  final pending = <String>{};
  String? error;
  Future<void> change(
    ProjectTask task,
    Future<void> Function() operation,
  ) async {
    if (pending.contains(task.id)) return;
    setState(() {
      pending.add(task.id);
      error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not update this task. Please try again.');
      }
    } finally {
      if (mounted) setState(() => pending.remove(task.id));
    }
  }

  Future<void> edit([ProjectTask? task]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => TaskEditor(
      worldId: widget.worldId,
      projectId: widget.projectId,
      task: task,
    ),
  );
  Future<void> delete(ProjectTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Permanently delete "${task.title}"?'),
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
    if (confirmed == true && mounted) {
      await change(
        task,
        () => ref
            .read(taskRepositoryProvider)
            .delete(
              worldId: widget.worldId,
              projectId: widget.projectId,
              id: task.id,
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Checklist', style: Theme.of(context).textTheme.titleMedium),
          TextButton.icon(
            onPressed: () => edit(),
            icon: const Icon(CupertinoIcons.plus, size: 14),
            label: const Text('Add task'),
          ),
        ],
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ref
          .watch(projectTasksProvider((widget.worldId, widget.projectId)))
          .when(
            loading: () => const CupertinoActivityIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(
                projectTasksProvider((widget.worldId, widget.projectId)),
              ),
              child: const Text('Retry loading tasks'),
            ),
            data: (tasks) => tasks.isEmpty
                ? const Text('Break this project into a few small steps.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tasks.where((t) => t.completed).length} of ${tasks.length} complete',
                        key: const ValueKey('task-progress'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final task in tasks)
                        Row(
                          children: [
                            Checkbox(
                              key: ValueKey('complete-${task.id}'),
                              value: task.completed,
                              onChanged: pending.contains(task.id)
                                  ? null
                                  : (value) => change(
                                      task,
                                      () => ref
                                          .read(taskRepositoryProvider)
                                          .setCompleted(
                                            worldId: widget.worldId,
                                            projectId: widget.projectId,
                                            id: task.id,
                                            completed: value!,
                                          ),
                                    ),
                            ),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.completed
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              key: ValueKey('task-actions-${task.id}'),
                              enabled: !pending.contains(task.id),
                              tooltip: 'Task actions',
                              icon: const Icon(
                                CupertinoIcons.ellipsis,
                                size: 16,
                              ),
                              onSelected: (value) =>
                                  value == 'edit' ? edit(task) : delete(task),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit task'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete task'),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
    ],
  );
}

class TaskEditor extends ConsumerStatefulWidget {
  const TaskEditor({
    super.key,
    required this.worldId,
    required this.projectId,
    this.task,
  });
  final String worldId, projectId;
  final ProjectTask? task;
  @override
  ConsumerState<TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<TaskEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.task?.title ?? '');
  bool saving = false, allowLeave = false;
  String? error;
  bool get dirty => title.text != (widget.task?.title ?? '');
  @override
  void initState() {
    super.initState();
    title.addListener(changed);
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> leave() async {
    setState(() => allowLeave = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
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
    await leave();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(taskRepositoryProvider)
          .save(
            worldId: widget.worldId,
            projectId: widget.projectId,
            id: widget.task?.id,
            title: title.text,
          );
      if (mounted) await leave();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this task. Your text is still here; please try again.';
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
        title: Text(widget.task == null ? 'New task' : 'Edit task'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: 'Task',
                    child: TextFormField(
                      key: const ValueKey('task-title'),
                      controller: title,
                      autofocus: true,
                      enabled: !saving,
                      maxLength: 200,
                      onFieldSubmitted: (_) => save(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this task a name.'
                          : null,
                    ),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
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
            child: Text(saving ? 'Saving…' : 'Save task'),
          ),
        ],
      ),
    ),
  );
}
