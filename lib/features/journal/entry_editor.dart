import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/labeled_field.dart';
import '../../core/database/app_database.dart';
import 'journal_repository.dart';
import 'journal_screen.dart';

class EntryEditor extends ConsumerStatefulWidget {
  const EntryEditor({
    super.key,
    required this.worldId,
    required this.worldName,
    this.entry,
  });
  final String worldId;
  final String worldName;
  final JournalEntry? entry;
  @override
  ConsumerState<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends ConsumerState<EntryEditor> {
  final form = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title ?? '');
  late final notes = TextEditingController(text: widget.entry?.body ?? '');
  final notesFocus = FocusNode();
  late DateTime occurredAt =
      widget.entry?.occurredAt.toLocal() ?? DateTime.now();
  late final initialDate = occurredAt;
  bool saving = false, preview = false, allowLeave = false;
  String? error;
  bool get dirty =>
      title.text != (widget.entry?.title ?? '') ||
      notes.text != (widget.entry?.body ?? '') ||
      occurredAt != initialDate;
  @override
  void initState() {
    super.initState();
    title.addListener(changed);
    notes.addListener(changed);
  }

  void changed() {
    setState(() {});
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    notesFocus.dispose();
    super.dispose();
  }

  Future<void> leave({bool saved = false}) async {
    if (!mounted) return;
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
          content: const Text(
            'Your changes have not been saved to this journal.',
          ),
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
      if (discard != true) return;
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
          .read(journalRepositoryProvider)
          .save(
            worldId: widget.worldId,
            id: widget.entry?.id,
            title: title.text,
            body: notes.text,
            occurredAt: occurredAt,
          );
      await leave(saved: true);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save this entry. Your notes are still here; please try again.';
        });
      }
    }
  }

  void format(String prefix, String suffix) {
    final selection = notes.selection;
    final start = selection.isValid ? selection.start : notes.text.length;
    final end = selection.isValid ? selection.end : start;
    final selected = notes.text.substring(start, end);
    notes.value = TextEditingValue(
      text: notes.text.replaceRange(start, end, '$prefix$selected$suffix'),
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selected.length,
      ),
    );
    notesFocus.requestFocus();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: occurredAt,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(occurredAt),
    );
    if (time != null && mounted) {
      setState(
        () => occurredAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: allowLeave || (!dirty && !saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) close();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): save,
          const SingleActivator(LogicalKeyboardKey.enter, control: true): save,
          const SingleActivator(LogicalKeyboardKey.escape): close,
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close editor',
                        onPressed: saving ? null : close,
                        icon: const Icon(CupertinoIcons.chevron_left),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.entry == null
                              ? 'New journal entry'
                              : 'Edit journal entry',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      FilledButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? 'Saving…' : 'Save entry'),
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
                            widget.worldName,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          Form(
                            key: form,
                            child: LabeledField(
                              label: 'Entry title',
                              child: TextFormField(
                                controller: title,
                                autofocus: true,
                                enabled: !saving,
                                maxLength: 200,
                                validator: (text) =>
                                    text == null || text.trim().isEmpty
                                    ? 'Give this entry a title.'
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: saving ? null : pickDate,
                                icon: const Icon(
                                  CupertinoIcons.calendar,
                                  size: 16,
                                ),
                                label: Text(entryDate(occurredAt)),
                              ),
                              Text(
                                dirty
                                    ? 'Unsaved changes'
                                    : 'No unsaved changes',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => preview = !preview),
                                child: Text(
                                  preview ? 'Edit notes' : 'Preview notes',
                                ),
                              ),
                              if (!preview) ...[
                                IconButton(
                                  tooltip: 'Bold',
                                  onPressed: saving
                                      ? null
                                      : () => format('**', '**'),
                                  icon: const Icon(CupertinoIcons.bold),
                                ),
                                IconButton(
                                  tooltip: 'Italic',
                                  onPressed: saving
                                      ? null
                                      : () => format('*', '*'),
                                  icon: const Icon(CupertinoIcons.italic),
                                ),
                                IconButton(
                                  tooltip: 'List',
                                  onPressed: saving
                                      ? null
                                      : () => format('\n- ', ''),
                                  icon: const Icon(CupertinoIcons.list_bullet),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (preview)
                            MarkdownBody(
                              data: notes.text.isEmpty
                                  ? '_No notes yet._'
                                  : notes.text,
                              selectable: true,
                              imageBuilder: (_, _, _) => const Text(
                                'Image attachments are coming in a later milestone.',
                              ),
                            )
                          else
                            LabeledField(
                              label: 'Notes',
                              child: TextField(
                                controller: notes,
                                focusNode: notesFocus,
                                enabled: !saving,
                                minLines: 12,
                                maxLines: null,
                                decoration: const InputDecoration(
                                  hintText: 'What happened in this world?',
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'Markdown: **bold**, *italic*, # heading, and - lists. Save before closing the app.',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
