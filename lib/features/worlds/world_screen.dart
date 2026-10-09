import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../main.dart';

class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your worlds')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => showWorldEditor(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('New world'),
    ),
    body: ref
        .watch(worldsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.landscape_outlined, size: 72),
                        const SizedBox(height: 16),
                        Text(
                          'Every adventure starts with a world',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add your first world to start keeping its story.',
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => showWorldEditor(context, ref),
                          child: const Text('Create a world'),
                        ),
                      ],
                    ),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) => GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth < 650
                          ? 1
                          : constraints.maxWidth < 1050
                          ? 2
                          : 3,
                      mainAxisExtent: 200,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: worlds.length,
                    itemBuilder: (context, index) {
                      final world = worlds[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WorldOverview(id: world.id),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.landscape, size: 32),
                                const Spacer(),
                                Text(
                                  world.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                Text('${world.edition} edition'),
                                if (world.description.isNotEmpty)
                                  Text(
                                    world.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
  );
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
    return Scaffold(
      appBar: AppBar(title: Text(current?.name ?? 'World overview')),
      body: current == null
          ? const Center(
              child: Text('World unavailable. Return to your dashboard.'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Icon(Icons.landscape_outlined, size: 96),
                    const SizedBox(height: 24),
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () =>
                              showWorldEditor(context, ref, world: current),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit world'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete world?'),
                                content: Text(
                                  'Permanently delete "${current.name}"? This cannot be undone.',
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
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete world'),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
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
                TextFormField(
                  controller: name,
                  autofocus: true,
                  enabled: !saving,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'World name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Give your world a name.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: edition,
                  decoration: const InputDecoration(
                    labelText: 'Minecraft edition',
                  ),
                  items: ['Java', 'Bedrock']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) => setState(() => edition = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: description,
                  enabled: !saving,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true,
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
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
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
                    if (context.mounted) Navigator.pop(context, true);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        saving = false;
                        error =
                            'Could not save your world. Your text is still here; please try again.';
                      });
                    }
                  }
                },
          child: Text(saving ? 'Saving…' : 'Save world'),
        ),
      ],
    ),
  );
}
