import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import 'material_repository.dart';

class ProjectMaterialsSection extends ConsumerStatefulWidget {
  const ProjectMaterialsSection({
    super.key,
    required this.worldId,
    required this.projectId,
  });
  final String worldId, projectId;
  @override
  ConsumerState<ProjectMaterialsSection> createState() =>
      _ProjectMaterialsSectionState();
}

class _ProjectMaterialsSectionState
    extends ConsumerState<ProjectMaterialsSection> {
  bool busy = false;
  String? error;
  Future<void> edit([ProjectMaterial? material]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => MaterialEditor(
      worldId: widget.worldId,
      projectId: widget.projectId,
      material: material,
    ),
  );
  Future<void> change(Future<void> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not update this material. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete(ProjectMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete material?'),
        content: Text(
          'Permanently remove "${material.name}" from this project?',
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
    if (confirmed == true && mounted) {
      await change(
        () => ref
            .read(materialRepositoryProvider)
            .delete(
              worldId: widget.worldId,
              projectId: widget.projectId,
              id: material.id,
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
          Text('Materials', style: Theme.of(context).textTheme.titleMedium),
          TextButton.icon(
            onPressed: busy ? null : () => edit(),
            icon: const Icon(CupertinoIcons.plus, size: 14),
            label: const Text('Add material'),
          ),
        ],
      ),
      if (error != null)
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ref
          .watch(projectMaterialsProvider((widget.worldId, widget.projectId)))
          .when(
            loading: () => const CupertinoActivityIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(
                projectMaterialsProvider((widget.worldId, widget.projectId)),
              ),
              child: const Text('Retry loading materials'),
            ),
            data: (materials) => materials.isEmpty
                ? const Text('Keep track of supplies for this build.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${materials.where((m) => m.gathered >= m.needed).length} of ${materials.length} materials ready',
                        key: const ValueKey('material-progress'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      for (final material in materials)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(material.name),
                          subtitle: Text(
                            '${material.gathered} of ${material.needed} gathered',
                          ),
                          leading: Icon(
                            material.gathered >= material.needed
                                ? CupertinoIcons.checkmark_circle
                                : CupertinoIcons.cube,
                            size: 18,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          onTap: busy ? null : () => edit(material),
                          trailing: PopupMenuButton<String>(
                            key: ValueKey('material-actions-${material.id}'),
                            tooltip: 'Material actions',
                            enabled: !busy,
                            icon: const Icon(CupertinoIcons.ellipsis, size: 16),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit material'),
                              ),
                              PopupMenuItem(
                                value: 'gather',
                                enabled: material.gathered < material.needed,
                                child: const Text('Mark gathered'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete material'),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'edit') {
                                edit(material);
                              } else if (value == 'delete') {
                                delete(material);
                              } else {
                                change(
                                  () => ref
                                      .read(materialRepositoryProvider)
                                      .markGathered(
                                        worldId: widget.worldId,
                                        projectId: widget.projectId,
                                        id: material.id,
                                      ),
                                );
                              }
                            },
                          ),
                        ),
                    ],
                  ),
          ),
    ],
  );
}

class MaterialEditor extends ConsumerStatefulWidget {
  const MaterialEditor({
    super.key,
    required this.worldId,
    required this.projectId,
    this.material,
  });
  final String worldId, projectId;
  final ProjectMaterial? material;
  @override
  ConsumerState<MaterialEditor> createState() => _MaterialEditorState();
}

class _MaterialEditorState extends ConsumerState<MaterialEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.material?.name ?? '');
  late final needed = TextEditingController(
    text: '${widget.material?.needed ?? 1}',
  );
  late final gathered = TextEditingController(
    text: '${widget.material?.gathered ?? 0}',
  );
  bool saving = false, allowLeave = false;
  String? error;
  bool get dirty =>
      name.text != (widget.material?.name ?? '') ||
      needed.text != '${widget.material?.needed ?? 1}' ||
      gathered.text != '${widget.material?.gathered ?? 0}';
  @override
  void initState() {
    super.initState();
    name.addListener(changed);
    needed.addListener(changed);
    gathered.addListener(changed);
  }

  void changed() => setState(() {});
  @override
  void dispose() {
    name.dispose();
    needed.dispose();
    gathered.dispose();
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
          .read(materialRepositoryProvider)
          .save(
            worldId: widget.worldId,
            projectId: widget.projectId,
            id: widget.material?.id,
            name: name.text,
            needed: int.parse(needed.text.trim()),
            gathered: int.parse(gathered.text.trim()),
          );
      if (mounted) await leave();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this material. Your text is still here; please try again.';
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
        title: Text(widget.material == null ? 'New material' : 'Edit material'),
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
                    label: 'Material',
                    child: TextFormField(
                      key: const ValueKey('material-name'),
                      controller: name,
                      autofocus: true,
                      enabled: !saving,
                      maxLength: 100,
                      onFieldSubmitted: (_) => save(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give this material a name.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final field in [
                    (needed, 'Quantity needed', 'material-needed', 1),
                    (gathered, 'Quantity gathered', 'material-gathered', 0),
                  ]) ...[
                    LabeledField(
                      label: field.$2,
                      child: TextFormField(
                        key: ValueKey(field.$3),
                        controller: field.$1,
                        enabled: !saving,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final number = int.tryParse(value?.trim() ?? '');
                          return number == null ||
                                  number < field.$4 ||
                                  number > maxMaterialQuantity
                              ? 'Enter a whole number from ${field.$4} to $maxMaterialQuantity.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Quantities count individual items. You can record extra gathered items.',
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
            child: Text(saving ? 'Saving…' : 'Save material'),
          ),
        ],
      ),
    ),
  );
}
