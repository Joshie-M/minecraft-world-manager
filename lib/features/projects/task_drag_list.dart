import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TaskDragList extends StatelessWidget {
  const TaskDragList({
    super.key,
    required this.children,
    required this.onReorder,
  });
  final List<Widget> children;
  final void Function(int, int) onReorder;
  @override
  Widget build(BuildContext context) => ReorderableListView(
    shrinkWrap: true,
    primary: false,
    physics: const NeverScrollableScrollPhysics(),
    buildDefaultDragHandles: false,
    padding: EdgeInsets.zero,
    onReorderItem: onReorder,
    proxyDecorator: (child, _, animation) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: child,
    ),
    children: children,
  );
}

class TaskDragHandle extends StatelessWidget {
  const TaskDragHandle({super.key, required this.index, required this.enabled});
  final int index;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
    index: index,
    enabled: enabled,
    child: Tooltip(
      message: 'Drag to reorder',
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.grab : SystemMouseCursors.basic,
        child: SizedBox(
          width: 36,
          height: 44,
          child: Icon(
            CupertinoIcons.line_horizontal_3,
            size: 16,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: enabled ? 1 : .4),
          ),
        ),
      ),
    ),
  );
}
