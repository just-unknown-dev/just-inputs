import 'package:flutter/material.dart';

import '../display/binding_display.dart';
import '../model/binding_def.dart';
import '../model/action_def.dart';
import '../players/player_input.dart';
import '../rebinding/rebinding_operation.dart';
import '../runtime/input_actions.dart';

/// How [actions] does the action at [action], in words: `Space`, `Ⓐ`.
/// Follows the device its owner used last, so prompts change with the pad.
class BindingLabel extends StatelessWidget {
  const BindingLabel({
    super.key,
    required this.actions,
    required this.action,
    this.style,
  });

  final InputActions actions;
  final String action;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final service = actions.service;
    return ValueListenableBuilder(
      valueListenable: service.lastUsedDevice,
      builder: (context, device, _) {
        final display = BindingDisplay.forDevice(
          device,
          keyboard: service.keyboard,
          asset: service.asset,
        );
        return Text(display.action(actions, action), style: style);
      },
    );
  }
}

/// One binding of one player, and a way to change it: press, then press
/// the new control. Escape gives up.
class RebindButton extends StatefulWidget {
  const RebindButton({
    super.key,
    required this.player,
    required this.bindingId,
    this.onResult,
    this.style,
    this.listeningText = 'Press a key… (Esc cancels)',
    this.keyboardHook,
  });

  final PlayerInput player;

  /// A binding or composite part id.
  final String bindingId;

  final void Function(RebindResult result)? onResult;
  final TextStyle? style;
  final String listeningText;

  /// For tests; the real keyboard otherwise.
  final KeyboardCaptureHook? keyboardHook;

  @override
  State<RebindButton> createState() => _RebindButtonState();
}

class _RebindButtonState extends State<RebindButton> {
  RebindingOperation? _op;
  OverlayEntry? _catcher;

  bool get _listening => _op != null;

  Future<void> _start() async {
    if (_listening) return;
    final result = await rebindPlayer(
      widget.player,
      widget.bindingId,
      keyboardHook: widget.keyboardHook,
      onStart: (op) {
        setState(() => _op = op);
        _catchMouse(op);
      },
    );
    _catcher?.remove();
    _catcher = null;
    if (!mounted) return;
    setState(() => _op = null);
    widget.onResult?.call(result);
  }

  /// A mouse button is a control too: a sheet over everything hands clicks
  /// to the rebind instead of the buttons beneath.
  void _catchMouse(RebindingOperation op) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    _catcher = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: op.feedPointer,
          onPointerUp: op.feedPointer,
        ),
      ),
    );
    overlay.insert(_catcher!);
  }

  @override
  void dispose() {
    _op?.cancel();
    _catcher?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final service = player.manager.service;
    final display = BindingDisplay.forDevice(
      player.device,
      keyboard: service.keyboard,
      asset: service.asset,
    );
    final text = _listening
        ? widget.listeningText
        : display.control(effectivePath(player.actions, widget.bindingId));
    return OutlinedButton(
      onPressed: _start,
      child: Text(text.isEmpty ? '—' : text, style: widget.style),
    );
  }
}

/// Every binding a player may change, in their scheme: one row each, with a
/// way back to the default. The body of a Controls screen.
class RebindList extends StatefulWidget {
  const RebindList({
    super.key,
    required this.player,
    this.maps,
    this.labelStyle,
    this.buttonStyle,
    this.keyboardHook,
  });

  final PlayerInput player;

  /// Only these maps; every map by default.
  final List<String>? maps;

  final TextStyle? labelStyle;
  final TextStyle? buttonStyle;
  final KeyboardCaptureHook? keyboardHook;

  @override
  State<RebindList> createState() => _RebindListState();
}

/// One line of a [RebindList].
final class RebindRow {
  const RebindRow(this.label, this.bindingId);

  /// `Jump`, `Move Up`.
  final String label;
  final String bindingId;
}

/// The rows a [RebindList] shows for [player]: every rebindable action in
/// [maps], each binding in their scheme, a composite as its parts.
List<RebindRow> rebindRows(PlayerInput player, {List<String>? maps}) {
  final asset = player.manager.service.asset;
  final group = player.actions.group;
  return [
    for (final m in asset.maps)
      if (maps == null || maps.contains(m.name))
        for (final a in m.actions)
          if (a.rebindable)
            for (final b in a.bindings)
              if (b.inGroup(group))
                ...switch (b) {
                  ControlBindingDef() => [RebindRow(a.label, b.id)],
                  CompositeBindingDef() => [
                    for (final p in b.parts)
                      RebindRow(
                        a.type == ActionValueType.vector2 ||
                                b.composite == CompositeKinds.axis1D
                            ? '${a.label} ${prettifyName(p.part)}'
                            : a.label,
                        p.id,
                      ),
                  ],
                },
  ];
}

class _RebindListState extends State<RebindList> {
  @override
  Widget build(BuildContext context) {
    final rows = rebindRows(widget.player, maps: widget.maps);
    final overrides = widget.player.overrides;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(row.label, style: widget.labelStyle)),
                RebindButton(
                  player: widget.player,
                  bindingId: row.bindingId,
                  style: widget.buttonStyle,
                  keyboardHook: widget.keyboardHook,
                  onResult: (_) => setState(() {}),
                ),
                IconButton(
                  tooltip: 'Default',
                  icon: const Icon(Icons.undo, size: 18),
                  onPressed: overrides[row.bindingId] == null
                      ? null
                      : () async {
                          await widget.player.resetOverrides(
                            bindingId: row.bindingId,
                          );
                          if (mounted) setState(() {});
                        },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
