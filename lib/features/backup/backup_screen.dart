import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/app_shell.dart';
import 'backup_files.dart';
import 'backup_repository.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool busy = false, confirming = false;
  String? message;
  bool failed = false;

  Future<void> run(Future<String?> Function() operation) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
      failed = false;
    });
    try {
      final result = await operation();
      if (mounted) setState(() => message = result);
    } catch (error) {
      if (mounted) {
        setState(() {
          failed = true;
          message = error is FormatException
              ? error.message
              : 'Could not complete this operation. Your saved data is unchanged; please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          confirming = false;
        });
      }
    }
  }

  Future<void> export() => run(() async {
    final bytes = await ref.read(backupRepositoryProvider).export();
    final saved = await ref.read(backupFilesProvider).save(bytes);
    return saved ? 'Backup saved.' : null;
  });
  Future<void> restore() => run(() async {
    final bytes = await ref.read(backupFilesProvider).pick();
    if (bytes == null || !mounted) return null;
    final backup = WorldBackup.parse(bytes);
    if (backup.worlds.isEmpty) return 'This backup has no worlds to restore.';
    setState(() => confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore as new worlds?'),
        content: SingleChildScrollView(
          child: Text(
            'Worlds: ${backup.worlds.length} · Journal entries: ${backup.entries.length}\n'
            '${backup.locations.length} locations · ${backup.projects.length} projects · ${backup.tasks.length} tasks · ${backup.materials.length} materials\n\n'
            'These will be added as separate worlds with “(restored)” in their names. '
            'Your current worlds will stay as they are. Restoring the same file again adds another copy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore copies'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => confirming = false);
    if (confirmed != true || !mounted) return null;
    await ref.read(backupRepositoryProvider).restore(backup);
    return 'Restored ${backup.worlds.length} ${backup.worlds.length == 1 ? 'world' : 'worlds'}. Find the copies in Your worlds.';
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AppShell(
      navigationEnabled: !busy,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to worlds',
                  onPressed: busy ? null : () => Navigator.pop(context),
                  icon: const Icon(CupertinoIcons.chevron_left),
                ),
                const SizedBox(width: 8),
                Text(
                  'Backup & restore',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Keep a copy of your worlds',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Save all worlds, journal entries, locations, projects, materials, and checklists in one backup file. Journal links and task completion are included.',
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : export,
                        icon: const Icon(
                          CupertinoIcons.arrow_down_doc,
                          size: 16,
                        ),
                        label: const Text('Save backup'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Restore from a backup',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose a World Manager backup to preview and restore as new worlds. Your current data stays intact.',
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : restore,
                        icon: const Icon(CupertinoIcons.arrow_up_doc, size: 16),
                        label: const Text('Choose backup'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (busy && !confirming)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: CupertinoActivityIndicator(),
                      ),
                    if (message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message!,
                          style: TextStyle(
                            color: failed
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Backups contain your saved text and coordinates. Store the file somewhere you trust. '
                      'This backs up your World Manager records; Minecraft game save files are managed separately.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
