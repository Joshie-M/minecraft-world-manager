import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_shell.dart';
import '../../core/database/app_database.dart';
import '../../main.dart';

class WorldScreen extends ConsumerWidget {
  const WorldScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth < 600 ? 20.0 : 40.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(inset, 32, inset, 28),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR PERSONAL ATLAS',
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          Text(
                            'Your worlds',
                            style: theme.textTheme.headlineLarge,
                          ),
                          FilledButton.icon(
                            onPressed: () => showWorldEditor(context, ref),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('New world'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Keep the places you explore and the stories you make.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              ref
                  .watch(worldsProvider)
                  .when(
                    loading: () => const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => SliverFillRemaining(
                      child: Center(
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
                    ),
                    data: (worlds) => worlds.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(inset),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 460,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: .07),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.explore_outlined,
                                          size: 42,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'An adventure worth keeping',
                                        style: theme.textTheme.headlineSmall,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Start with a world. Give it a name, a little context, and a place in your collection.',
                                        style: theme.textTheme.bodyLarge,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
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
                        : SliverPadding(
                            padding: EdgeInsets.fromLTRB(inset, 0, inset, 32),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: constraints.maxWidth < 650
                                        ? 1
                                        : constraints.maxWidth < 1100
                                        ? 2
                                        : 3,
                                    mainAxisExtent: 300,
                                    crossAxisSpacing: 20,
                                    mainAxisSpacing: 20,
                                  ),
                              itemCount: worlds.length,
                              itemBuilder: (context, index) =>
                                  _WorldCard(world: worlds[index]),
                            ),
                          ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  const _WorldCard({required this.world});
  final World world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => WorldOverview(id: world.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorldLandscape(edition: world.edition, height: 132),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        world.description.isEmpty
                            ? 'A new story starts here.'
                            : world.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${world.edition} edition',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Decorative illustration, not a screenshot of the player's world.
class WorldLandscape extends StatelessWidget {
  const WorldLandscape({
    super.key,
    required this.edition,
    required this.height,
  });
  final String edition;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LandscapePainter(
          Theme.of(context).brightness == Brightness.dark,
          edition == 'Bedrock',
        ),
      ),
    ),
  );
}

class _LandscapePainter extends CustomPainter {
  _LandscapePainter(this.dark, this.bedrock);
  final bool dark;
  final bool bedrock;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..color = Color(
          dark
              ? 0xff293b33
              : bedrock
              ? 0xffe4e7db
              : 0xffe0ebe4,
        ),
    );
    canvas.drawCircle(
      Offset(size.width * .8, size.height * .28),
      size.height * .15,
      Paint()..color = Color(dark ? 0xff81937a : 0xfff6f4dc),
    );
    for (var layer = 0; layer < 3; layer++) {
      final baseline = size.height * (.49 + layer * .18);
      final path = Path()..moveTo(0, baseline);
      path.cubicTo(
        size.width * .22,
        baseline - size.height * .3,
        size.width * .36,
        baseline + size.height * .25,
        size.width * .55,
        baseline,
      );
      path.cubicTo(
        size.width * .76,
        baseline - size.height * .28,
        size.width * .88,
        baseline - size.height * .06,
        size.width,
        baseline + size.height * .05,
      );
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = [
            const Color(0xffafc6b2),
            const Color(0xff7f9c85),
            const Color(0xff496f58),
          ][layer].withValues(alpha: dark ? .65 : 1),
      );
    }
  }

  @override
  bool shouldRepaint(_LandscapePainter oldDelegate) =>
      dark != oldDelegate.dark || bedrock != oldDelegate.bedrock;
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
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('All worlds'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WorldLandscape(
                        edition: current.edition,
                        height: 180,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete world'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
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
