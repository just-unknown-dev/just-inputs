import 'dart:ui' show Offset;

import '../devices/input_device.dart';
import '../devices/pointer_devices.dart';
import '../model/action_def.dart';
import '../paths/control_path.dart';
import 'input_action.dart';
import 'input_actions.dart';
import 'processors.dart';

/// The movement an action's bindings read — the mouse's delta or wheel, a
/// finger's drag — taken once per rendered frame instead of once per update.
///
/// An action reads `<Mouse>/delta` once per update: whatever moved since
/// the last fixed step. When frames come faster than steps, some frames see
/// no movement and the next sees two frames' worth; when they come slower,
/// a frame's first step takes everything and the rest see nothing. A camera
/// turned by that judders. [take] instead returns everything the action's
/// movement controls moved since the last [take], up to now (events not yet
/// replayed included), however many updates ran in between. A camera turned
/// by it once per frame turns smoothly at any frame rate.
///
/// What counts follows the action: its bindings as resolved for its
/// [actions] (a player's devices, the scheme's group, their rebinding), each
/// binding's processors, then the action's own. Keep those linear —
/// `scaleVector2`, `invertVector2` — since they apply to a frame's sum; a
/// dead zone or a normalize makes no sense on movement. Bindings to controls
/// that are not movement (a stick, a key, a composite) are passed over: a
/// stick's look is a rate, read by `LookInput`.
///
/// Movement made while the action is off, or while the service is
/// suspended for a rebind, never counts: every update in that state starts
/// the reader again from where the controls are. A game that stops reading
/// for a while with the action still on (a cutscene's camera) calls [reset]
/// before it reads again.
final class FrameMotion {
  /// Counts from now: the first [take] returns what moved since this.
  FrameMotion(this.actions, this.action, {this.relativeMouseOnly = false}) {
    _updates = actions.service.listenUpdates(_onUpdate);
    reset();
  }

  /// The actions read: a player's own, or the service's shared ones.
  final InputActions actions;

  /// The action's path, `player/look` or a bare `look`. One the asset does
  /// not have reads as no movement until an asset that has it is loaded.
  final String action;

  /// Counts the mouse only while it is in [MouseDevice.relativeMode] (the
  /// pointer locked), so a cursor crossing the window while the lock is let
  /// go (the window in the background, a menu open) turns nothing.
  bool relativeMouseOnly;

  late final InputSubscription _updates;

  /// Each movement control's total at the last take, by control.
  final Map<InputControl, Offset> _seen = {};

  bool _disposed = false;

  /// Everything the action's movement controls moved since the last [take]
  /// (or [reset]), through the bindings' processors and the action's: a
  /// vector for a vector action, `(value, 0)` otherwise. Zero while the
  /// action is off and after [dispose]. A control that only just appeared
  /// (a device plugged in) counts from its first take.
  Offset take() {
    if (_disposed) return Offset.zero;
    final a = actions.tryAction(action);
    if (a == null || !_counts(a)) {
      _rebase(a);
      return Offset.zero;
    }
    final settings = actions.service.asset.settings;
    final vector = a.type == ActionValueType.vector2;
    final next = <InputControl, Offset>{};
    var sum = Offset.zero;
    for (final (controls, processors) in ActionBuilder.controlBindings(a)) {
      var moved = Offset.zero;
      for (final c in controls) {
        // A control two bindings both read counts once.
        if (next.containsKey(c)) continue;
        final total = c.readTotal();
        if (total == null) continue;
        next[c] = total;
        final before = _seen[c];
        if (before != null && _counted(c)) moved += total - before;
      }
      if (moved == Offset.zero) continue;
      var v = InputProcessors.apply(processors, moved, settings);
      // As the action reads its controls: two numbers where it wants one
      // read as their length.
      if (!vector && controls.first.type == ControlValueType.vector2) {
        v = Offset(v.distance, 0);
      }
      sum += v;
    }
    _seen
      ..clear()
      ..addAll(next);
    if (sum == Offset.zero || a.def.processors.isEmpty) return sum;
    return InputProcessors.apply(a.def.processors, sum, settings);
  }

  /// Forgets what moved since the last [take]: the next one counts from
  /// now.
  void reset() => _rebase(actions.tryAction(action));

  /// Stops listening to the service. [take] reads nothing after.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _updates.cancel();
    _seen.clear();
  }

  bool _counts(InputAction a) =>
      a.isEnabled && !actions.service.isSuspended && !actions.isDisposed;

  bool _counted(InputControl c) {
    if (!relativeMouseOnly) return true;
    final device = c.device;
    return device is! MouseDevice || device.relativeMode;
  }

  /// Every movement control of [a] starts again from where it is now.
  void _rebase(InputAction? a) {
    _seen.clear();
    if (a == null) return;
    for (final c in a.controls) {
      final total = c.readTotal();
      if (total != null) _seen[c] = total;
    }
  }

  void _onUpdate(double now) {
    if (_disposed) return;
    final a = actions.tryAction(action);
    if (a == null || !_counts(a)) {
      _rebase(a);
      return;
    }
    if (!relativeMouseOnly) return;
    // The unlocked mouse's movement is never this reader's, even if nobody
    // takes before the lock comes back.
    for (final c in a.controls) {
      if (_counted(c) || !_seen.containsKey(c)) continue;
      final total = c.readTotal();
      if (total != null) _seen[c] = total;
    }
  }
}
