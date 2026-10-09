import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart';
import '../../app/theme.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';
import '../journal/journal_screen.dart';
import '../journal/entry_reader.dart';
import '../projects/projects_screen.dart';
import '../locations/locations_screen.dart';
import '../search/world_search.dart';
import '../backup/backup_screen.dart';

class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            showWorldEditor(context, ref),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () =>
            showWorldEditor(context, ref),
      },
      child: Focus(
        autofocus: true,
        child: AppShell(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.contentInset,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your worlds',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Backup & restore',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const BackupScreen(),
                        ),
                      ),
                      icon: const Icon(CupertinoIcons.arrow_down_doc, size: 18),
                    ),
                    Tooltip(
                      message: 'New world (⌘N / Ctrl+N)',
                      child: OutlinedButton.icon(
                        onPressed: () => showWorldEditor(context, ref),
                        icon: const Icon(CupertinoIcons.plus, size: 16),
                        label: const Text('New world'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ref
                    .watch(worldsProvider)
                    .when(
                      loading: () =>
                          const Center(child: CupertinoActivityIndicator()),
                      error: (_, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Your worlds could not be loaded.'),
                            TextButton(
                              onPressed: () => ref.invalidate(worldsProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (worlds) => worlds.isEmpty
                          ? SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 64,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 360,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          CupertinoIcons.square_stack_3d_up,
                                          size: 32,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Your collection starts here',
                                          style: theme.textTheme.titleLarge,
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Add a world to keep its story in one place.',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                          onPressed: () =>
                                              showWorldEditor(context, ref),
                                          child: const Text('Create a world'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              itemCount: worlds.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) =>
                                  _WorldRow(world: worlds[index]),
                            ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorldRow extends ConsumerWidget {
  const _WorldRow({required this.world});
  final World world;
  void open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => WorldOverview(id: world.id)));
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(DesignTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radius),
        onTap: () => open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.cube, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      world.description.isEmpty
                          ? '${world.edition} edition'
                          : '${world.edition} · ${world.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'World actions',
                icon: const Icon(CupertinoIcons.ellipsis, size: 18),
                onSelected: (value) {
                  if (value == 'open') {
                    open(context);
                  } else {
                    showWorldEditor(context, ref, world: world);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'open', child: Text('Open world')),
                  PopupMenuItem(value: 'edit', child: Text('Edit world')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WorldOverview extends ConsumerWidget {
  const WorldOverview({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds = ref.watch(worldsProvider);
    World? world;
    for (final candidate in worlds.asData?.value ?? <World>[]) {
      if (candidate.id == id) world = candidate;
    }
    final current = world;
    return AppShell(
      child: current == null
          ? const Center(
              child: Text('World unavailable. Return to your dashboard.'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                        label: const Text('All worlds'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'World overview',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      current.name,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    Text('${current.edition} edition'),
                    const SizedBox(height: 24),
                    Text(
                      current.description.isEmpty
                          ? 'No description yet. Add a few notes about this world.'
                          : current.description,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Added ${current.createdAt.toLocal().toString().split(' ').first}',
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JournalScreen(
                              worldId: current.id,
                              worldName: current.name,
                            ),
                          ),
                        ),
                        icon: const Icon(CupertinoIcons.book),
                        label: const Text('Open journal'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => WorldSearch(
                                worldId: current.id,
                                worldName: current.name,
                              ),
                            ),
                          ),
                          icon: const Icon(CupertinoIcons.search, size: 16),
                          label: const Text('Search world'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              showWorldEditor(context, ref, world: current),
                          icon: const Icon(CupertinoIcons.pencil),
                          label: const Text('Edit world'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete world?'),
                                content: Text(
                                  'Permanently delete "${current.name}" and its journal entries, saved locations, and projects? This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onError,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              await ref.read(repositoryProvider).delete(id);
                              if (context.mounted) Navigator.pop(context);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not delete this world. Please try again.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(CupertinoIcons.trash),
                          label: const Text('Delete world'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    WorldProjectsSection(
                      worldId: current.id,
                      worldName: current.name,
                    ),
                    const SizedBox(height: 24),
                    WorldLocationsSection(
                      worldId: current.id,
                      worldName: current.name,
                    ),
                    const SizedBox(height: 24),
                    WorldJournalSection(
                      worldId: current.id,
                      worldName: current.name,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

Future<void> showWorldEditor(
  BuildContext context,
  WidgetRef ref, {
  World? world,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => WorldEditor(world: world),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('World saved on this device.')),
    );
  }
}

class WorldEditor extends ConsumerStatefulWidget {
  const WorldEditor({super.key, this.world});
  final World? world;
  @override
  ConsumerState<WorldEditor> createState() => _WorldEditorState();
}

class _WorldEditorState extends ConsumerState<WorldEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.world?.name ?? '');
  late final description = TextEditingController(
    text: widget.world?.description ?? '',
  );
  late String edition = widget.world?.edition ?? 'Java';
  bool saving = false;
  String? error;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(repositoryProvider)
          .save(
            id: widget.world?.id,
            name: name.text,
            edition: edition,
            description: description.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save your world. Your text is still here; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): save,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
      },
      child: AlertDialog(
        title: Text(widget.world == null ? 'Create a world' : 'Edit world'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LabeledField(
                    label: 'World name',
                    child: TextFormField(
                      controller: name,
                      autofocus: true,
                      enabled: !saving,
                      maxLength: 100,
                      decoration: const InputDecoration(),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Give your world a name.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LabeledField(
                    label: 'Minecraft edition',
                    child: DropdownButtonFormField<String>(
                      initialValue: edition,
                      decoration: const InputDecoration(),
                      items: ['Java', 'Bedrock']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: saving
                          ? null
                          : (value) => setState(() => edition = value!),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LabeledField(
                    label: 'Description (optional)',
                    child: TextFormField(
                      controller: description,
                      enabled: !saving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
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
            onPressed: saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Saving…' : 'Save world'),
          ),
        ],
      ),
    ),
  );
}
