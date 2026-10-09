import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../locations/location_repository.dart';
import '../projects/project_repository.dart';
import 'mention_controller.dart';

class MentionChoice {
  const MentionChoice(this.id, this.name, this.kind, this.detail);
  final String id, name, kind, detail;
}

class MentionField extends ConsumerStatefulWidget {
  const MentionField({
    super.key,
    required this.worldId,
    required this.controller,
    required this.focusNode,
    required this.enabled,
  });
  final String worldId;
  final MentionController controller;
  final FocusNode focusNode;
  final bool enabled;
  @override
  ConsumerState<MentionField> createState() => _MentionFieldState();
}

class _MentionFieldState extends ConsumerState<MentionField> {
  final portal = OverlayPortalController();
  final fieldKey = GlobalKey();
  final suggestionScroll = ScrollController();
  int selected = 0;
  String? dismissed;
  ({int start, int end, String query})? get active {
    final c = widget.controller;
    if (!widget.enabled ||
        !widget.focusNode.hasFocus ||
        !c.selection.isValid ||
        !c.selection.isCollapsed ||
        !c.value.composing.isCollapsed) {
      return null;
    }
    final end = c.selection.extentOffset;
    if (end > c.text.length ||
        c.mentions.any((m) => m.start < end && end <= m.end) ||
        inCode(c.text, end)) {
      return null;
    }
    final match = RegExp(
      r'(?:^|[\s(\[{])@([^\n@]{0,80})$',
    ).firstMatch(c.text.substring(0, end));
    if (match == null) return null;
    final query = match[1]!;
    final start = end - query.length - 1;
    if (c.mentions.any((m) => m.start == start)) return null;
    if ('$start:$end:$query' == dismissed) return null;
    return (start: start, end: end, query: query.trim().toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changed);
    widget.focusNode.addListener(changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(changed);
    widget.focusNode.removeListener(changed);
    suggestionScroll.dispose();
    super.dispose();
  }

  void changed() {
    selected = 0;
    if (mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (active == null) {
        portal.hide();
      } else {
        portal.show();
      }
    });
  }

  List<MentionChoice> choices() {
    final query = active?.query ?? '';
    final list = [
      for (final l
          in ref.read(locationsProvider(widget.worldId)).asData?.value ?? [])
        MentionChoice(
          l.id,
          l.name,
          'location',
          '${l.dimension} · ${coordinateText(l)}',
        ),
      for (final p
          in ref.read(projectsProvider(widget.worldId)).asData?.value ?? [])
        MentionChoice(p.id, p.name, 'project', p.status),
    ].where((r) => r.name.toLowerCase().contains(query)).toList();
    list.sort((a, b) {
      final name = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return name == 0 ? a.kind.compareTo(b.kind) : name;
    });
    return list;
  }

  void choose(MentionChoice choice) {
    final match = active;
    if (match == null) return;
    widget.controller.insertMention(
      match.start,
      match.end,
      choice.name,
      choice.kind,
      choice.id,
    );
    portal.hide();
    widget.focusNode.requestFocus();
  }

  KeyEventResult onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        active == null ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    final list = choices();
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final m = active!;
      dismissed =
          '${m.start}:${m.end}:${widget.controller.text.substring(m.start + 1, m.end)}';
      portal.hide();
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && suggestionScroll.hasClients) {
          suggestionScroll.animateTo(
            (selected * 56.0).clamp(
              0.0,
              suggestionScroll.position.maxScrollExtent,
            ),
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
      return KeyEventResult.handled;
    }
    if (list.isNotEmpty &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown ||
            event.logicalKey == LogicalKeyboardKey.arrowUp)) {
      setState(
        () => selected =
            (selected +
                (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1)) %
            list.length,
      );
      return KeyEventResult.handled;
    }
    if (list.isNotEmpty &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.tab)) {
      choose(list[selected.clamp(0, list.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final list = choices();
    final loading =
        ref.watch(locationsProvider(widget.worldId)).isLoading ||
        ref.watch(projectsProvider(widget.worldId)).isLoading;
    final error =
        ref.watch(locationsProvider(widget.worldId)).hasError ||
        ref.watch(projectsProvider(widget.worldId)).hasError;
    return Focus(
      onKeyEvent: onKey,
      child: OverlayPortal(
        controller: portal,
        overlayChildBuilder: (context) {
          final editable = fieldKey.currentContext
              ?.findAncestorRenderObjectOfType<RenderEditable>();
          RenderEditable? render = editable;
          void find(RenderObject object) {
            if (object is RenderEditable) {
              render = object;
            } else {
              object.visitChildren(find);
            }
          }

          final root = fieldKey.currentContext?.findRenderObject();
          if (root != null) find(root);
          final caret = render?.getLocalRectForCaret(
            widget.controller.selection.extent,
          );
          final position = render != null && caret != null
              ? render!.localToGlobal(caret.bottomLeft)
              : const Offset(24, 200);
          final size = MediaQuery.sizeOf(context);
          final bottom = size.height - MediaQuery.viewInsetsOf(context).bottom;
          final height = math.min(220.0, math.max(80.0, bottom - 24));
          final top = position.dy + height + 8 < bottom
              ? position.dy + 8
              : math.max(8.0, position.dy - height - 24);
          final width = math.min(340.0, size.width - 32);
          return Positioned(
            left: position.dx.clamp(
              16.0,
              math.max(16.0, size.width - width - 16),
            ),
            top: top,
            width: width,
            child: TextFieldTapRegion(
              child: Material(
                elevation: 4,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: height),
                  child: list.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: error
                              ? TextButton(
                                  onPressed: () {
                                    ref.invalidate(
                                      locationsProvider(widget.worldId),
                                    );
                                    ref.invalidate(
                                      projectsProvider(widget.worldId),
                                    );
                                  },
                                  child: const Text(
                                    'Retry loading suggestions',
                                  ),
                                )
                              : Text(
                                  loading
                                      ? 'Loading suggestions…'
                                      : 'No matching projects or locations.',
                                ),
                        )
                      : ListView.builder(
                          controller: suggestionScroll,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (_, index) {
                            final r = list[index];
                            return ListTile(
                              key: ValueKey('suggest-${r.kind}-${r.id}'),
                              dense: true,
                              selected: index == selected,
                              leading: Icon(
                                r.kind == 'location'
                                    ? CupertinoIcons.map_pin
                                    : CupertinoIcons.hammer,
                                size: 16,
                              ),
                              title: Text(
                                r.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${r.kind == 'location' ? 'Location' : 'Project'} · ${r.detail}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => choose(r),
                            );
                          },
                        ),
                ),
              ),
            ),
          );
        },
        child: TextField(
          key: fieldKey,
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          minLines: 12,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'What happened? Type @ to mention a project or location.',
          ),
        ),
      ),
    );
  }
}
