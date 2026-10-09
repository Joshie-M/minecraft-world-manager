import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import 'entry_editor.dart';
import 'journal_repository.dart';
import 'journal_screen.dart';

class EntryReader extends ConsumerWidget {
  const EntryReader({
    super.key,
    required this.worldId,
    required this.worldName,
    required this.entryId,
  });
  final String worldId;
  final String worldName;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppShell(
      child: ref
          .watch(journalProvider(worldId))
          .when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (_, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this entry.'),
                  TextButton(
                    onPressed: () => ref.invalidate(journalProvider(worldId)),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
            data: (entries) {
              final matches = entries.where((entry) => entry.id == entryId);
              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('This entry is no longer available.'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go back'),
                      ),
                    ],
                  ),
                );
              }
              final entry = matches.first;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to entries',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(CupertinoIcons.chevron_left),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            worldName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final saved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => EntryEditor(
                                      worldId: worldId,
                                      worldName: worldName,
                                      entry: entry,
                                    ),
                                  ),
                                );
                            if (saved == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Journal entry saved on this device.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(CupertinoIcons.pencil, size: 16),
                          label: const Text('Edit entry'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(
                              entry.title,
                              style: theme.textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              entryDate(entry.occurredAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 28),
                            if (entry.body.trim().isEmpty)
                              Text(
                                'No notes in this entry.',
                                style: theme.textTheme.bodyMedium,
                              )
                            else
                              MarkdownBody(
                                data: entry.body,
                                selectable: true,
                                imageBuilder: (_, _, _) => const Text(
                                  'Image attachments are coming in a later milestone.',
                                ),
                              ),
                          ],
                        ),
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

class WorldJournalSection extends ConsumerWidget {
  const WorldJournalSection({
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
      Text(
        'Recent journal entries',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      ref
          .watch(journalProvider(worldId))
          .when(
            loading: () => const CupertinoActivityIndicator(),
            error: (_, _) => TextButton(
              onPressed: () => ref.invalidate(journalProvider(worldId)),
              child: const Text('Retry loading journal entries'),
            ),
            data: (entries) => entries.isEmpty
                ? const Text(
                    'No entries yet. Open the journal to record your first adventure.',
                  )
                : Column(
                    children: entries
                        .take(3)
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              entry.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(entryDate(entry.occurredAt)),
                            trailing: const Icon(
                              CupertinoIcons.chevron_right,
                              size: 14,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => EntryReader(
                                  worldId: worldId,
                                  worldName: worldName,
                                  entryId: entry.id,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
    ],
  );
}
