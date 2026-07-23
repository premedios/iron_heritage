import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

final class AccessibleReorderHandle extends StatelessWidget {
  const AccessibleReorderHandle({
    required this.index,
    required this.label,
    this.enabled = true,
    this.onMoveUp,
    this.onMoveDown,
    super.key,
  });

  final int index;
  final String label;
  final bool enabled;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final actions = <CustomSemanticsAction, VoidCallback>{};
    if (enabled && onMoveUp != null) {
      actions[CustomSemanticsAction(label: 'Move $label up')] = onMoveUp!;
    }
    if (enabled && onMoveDown != null) {
      actions[CustomSemanticsAction(label: 'Move $label down')] = onMoveDown!;
    }

    final handle = Tooltip(
      message: 'Reorder $label',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: const Icon(Icons.drag_handle),
      ),
    );
    return Semantics(
      label: 'Reorder $label',
      customSemanticsActions: actions,
      enabled: enabled,
      child: enabled
          ? ReorderableDragStartListener(index: index, child: handle)
          : handle,
    );
  }
}
