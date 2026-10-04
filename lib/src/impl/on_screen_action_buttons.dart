import 'package:flutter/material.dart';

import '../actions/input_action.dart';
import '../actions/input_binding.dart';
import '../actions/input_action_resolver.dart';

/// Renders one on-screen button per [ActionType.button] action whose
/// current binding has [InputBinding.touch] set to
/// [TouchBindingKind.onScreenButton], a non-null [InputBinding.touchPosition],
/// and whose map is currently active, wired directly into [resolver] via
/// [InputActionResolver.setTouchButtonDown].
///
/// Generic over action names — the caller supplies [labelFor] to render a
/// game-specific label/icon without this widget needing any game-specific
/// knowledge. Positions are freeform (set per-action, e.g. via the editor's
/// Input Setup panel), not fixed presets — this widget just draws each
/// button wherever its binding says to.
class OnScreenActionButtons extends StatelessWidget {
  const OnScreenActionButtons({
    super.key,
    required this.resolver,
    required this.labelFor,
  });

  final InputActionResolver resolver;
  final String Function(String action) labelFor;

  @override
  Widget build(BuildContext context) {
    final bound = resolver.actionSet.defs.entries.where(
      (entry) =>
          entry.value.type == ActionType.button &&
          entry.value.button.touch == TouchBindingKind.onScreenButton &&
          entry.value.button.touchPosition != null &&
          resolver.isMapActive(entry.key),
    );

    return Stack(
      children: [
        for (final entry in bound)
          Align(
            alignment: entry.value.button.touchPosition!,
            child: _ActionButton(
              label: labelFor(entry.key),
              onDown: () => resolver.setTouchButtonDown(entry.key, true),
              onUp: () => resolver.setTouchButtonDown(entry.key, false),
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.label,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    setState(() => _pressed = value);
    if (value) {
      widget.onDown();
    } else {
      widget.onUp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: _pressed ? 0.35 : 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Text(
          widget.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
