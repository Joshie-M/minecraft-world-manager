import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import '../../core/database/app_database.dart';
import 'journal_repository.dart';
import 'entry_editor.dart';

String entryDate(DateTime date) {
  final d = date.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({
    super.key,
    required this.worldId,
    required this.worldName,
  });
  final String worldId;
  final String worldName;
  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  String query = '';
  Future<void> edit([JournalEntry? entry]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EntryEditor(
          worldId: widget.worldId,
          worldName: widget.worldName,
          entry: entry,
        ),
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry saved on this device.')),
      );
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
                      Text('Journal', style: theme.textTheme.titleLarge),
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
                  label: const Text('New entry'),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search journal',
                prefixIcon: Icon(CupertinoIcons.search, size: 16),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
          ),
          Expanded(
            child: ref
                .watch(journalProvider(widget.worldId))
                .when(
                  loading: () =>
                      const Center(child: CupertinoActivityIndicator()),
                  error: (_, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load journal entries.'),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(journalProvider(widget.worldId)),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (all) {
                    final needle = query.trim().toLowerCase();
                    final entries = all
                        .where(
                          (e) =>
                              e.title.toLowerCase().contains(needle) ||
                              e.body.toLowerCase().contains(needle),
                        )
                        .toList();
                    if (entries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                all.isEmpty
                                    ? 'Every world has a story'
                                    : 'No matching entries',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                all.isEmpty
                                    ? 'Record your first adventure in ${widget.worldName}.'
                                    : 'Try another title or phrase.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          title: Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(entryDate(entry.occurredAt)),
                          onTap: () => edit(entry),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Entry actions',
                            icon: const Icon(CupertinoIcons.ellipsis),
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await edit(entry);
                                return;
                              }
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete entry?'),
                                  content: Text(
                                    'Permanently delete "${entry.title}"? This cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.error,
                                        foregroundColor:
                                            theme.colorScheme.onError,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              try {
                                await ref
                                    .read(journalRepositoryProvider)
                                    .delete(
                                      worldId: widget.worldId,
                                      id: entry.id,
                                    );
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not delete entry. Please try again.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit entry'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete entry'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
