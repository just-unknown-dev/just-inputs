import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../devices/input_device.dart';
import '../model/action_def.dart';
import '../model/binding_conflicts.dart';
import '../model/binding_def.dart';
import '../paths/control_path.dart';
import '../players/player_input.dart';
import '../runtime/input_action.dart';
import '../runtime/input_actions.dart';
import '../runtime/input_service.dart';
import 'binding_overrides.dart';

/// Takes keys before anything focused sees them, while a rebind listens —
/// so Escape, Enter and the arrows are heard as keys to bind rather than
/// closing the menu or moving its focus.
abstract interface class KeyboardCaptureHook {
  /// Starts sending every key event to [onKey]; true from it keeps the
  /// event from going further.
  void install(bool Function(KeyEvent event) onKey);

  void remove();
}

/// The real one, through [HardwareKeyboard] — which runs before focus.
final class HardwareKeyboardCaptureHook implements KeyboardCaptureHook {
  bool Function(KeyEvent)? _handler;

  @override
  void install(bool Function(KeyEvent event) onKey) {
    remove();
    _handler = onKey;
    HardwareKeyboard.instance.addHandler(onKey);
  }

  @override
  void remove() {
    final h = _handler;
    if (h == null) return;
    HardwareKeyboard.instance.removeHandler(h);
    _handler = null;
  }
}

enum RebindState { idle, listening, completed, canceled }

/// How a rebind ended.
sealed class RebindResult {
  const RebindResult();
}

final class RebindCompleted extends RebindResult {
  const RebindCompleted(this.path, {this.conflicts = const []});

  /// The control heard: `<Keyboard>/q`.
  final String path;

  /// Other actions in the same map the new control also presses.
  final List<BindingConflict> conflicts;
}

final class RebindCanceled extends RebindResult {
  const RebindCanceled();
}

/// Listens for the next control pressed, to bind it.
///
/// Works while the game is paused: it hears controls the moment they
/// change, not at the service's update. While it listens, actions are
/// suspended so the press it hears does nothing else, and whatever was
/// already held — the button that started the rebind — is ignored until
/// let go.
final class RebindingOperation {
  RebindingOperation({
    required this.service,
    required this.target,
    required this.bindingId,
    Iterable<InputDevice>? devices,
    this._layouts,
    this.excluding = const {
      '<Mouse>/position',
      '<Mouse>/delta',
      '<Mouse>/scroll',
      '<Touchscreen>/position',
      '<Touchscreen>/delta',
    },
    this.cancelWith = const {'<Keyboard>/escape'},
    this.threshold = 0.5,
    KeyboardCaptureHook? keyboardHook,
  }) : _devices = devices?.toSet(),
       keyboardHook = keyboardHook ?? HardwareKeyboardCaptureHook();

  final InputService service;

  /// The live actions the binding belongs to — a player's, or the shared
  /// ones. Its scheme and devices narrow what is heard.
  final InputActions target;

  /// The binding or composite part being rebound.
  final String bindingId;

  final Set<InputDevice>? _devices;
  final Set<String>? _layouts;

  /// Paths never taken, and everything under them.
  final Set<String> excluding;

  /// Paths that give up instead of binding.
  final Set<String> cancelWith;

  final double threshold;
  final KeyboardCaptureHook keyboardHook;

  final ValueNotifier<RebindState> state = ValueNotifier(RebindState.idle);

  final Set<InputControl> _held = {};
  final Completer<RebindResult> _done = Completer();
  InputSubscription? _raw;

  /// The devices listened to: those given, else the target's own, else all.
  Set<InputDevice> get devices {
    final given = _devices;
    if (given != null) return given;
    final filter = target.devices;
    return service.devices.where(filter.includes).toSet();
  }

  /// The layouts listened to: those given, else the target's scheme's, else
  /// all.
  Set<String> get layouts {
    final given = _layouts;
    if (given != null) return given;
    final group = target.group;
    final scheme = group == null ? null : service.asset.schemeWithGroup(group);
    return scheme == null ? InputLayouts.all.toSet() : scheme.layouts.toSet();
  }

  /// What kind of control the binding wants.
  Set<ControlValueType> get _wanted {
    final ref = service.asset.findBinding(bindingId);
    if (ref == null || ref.part != null) {
      return {ControlValueType.button, ControlValueType.axis};
    }
    return switch (ref.action.type) {
      ActionValueType.vector2 => {ControlValueType.vector2},
      _ => {ControlValueType.button, ControlValueType.axis},
    };
  }

  /// Starts listening. Completes with the control heard, or canceled.
  Future<RebindResult> start() {
    if (state.value != RebindState.idle) return _done.future;
    state.value = RebindState.listening;
    service.suspendActions();
    final devices = this.devices;
    for (final d in devices) {
      for (final c in d.controls) {
        if (c.magnitude(live: true) >= threshold) _held.add(c);
      }
    }
    _raw = service.listenRaw(_onRaw);
    keyboardHook.install(_onKey);
    return _done.future;
  }

  bool _onKey(KeyEvent event) {
    if (state.value != RebindState.listening) return false;
    service.handleKeyEvent(event);
    // Downs are ours; ups go on, so whatever saw the down sees it end.
    return event is! KeyUpEvent;
  }

  /// A pointer event from an overlay that keeps it from the widgets below —
  /// how a mouse button is heard.
  void feedPointer(PointerEvent event) {
    if (state.value != RebindState.listening) return;
    service.handlePointerEvent(event);
  }

  void _onRaw(InputControl control, double magnitude) {
    if (state.value != RebindState.listening) return;
    if (!devices.contains(control.device)) return;
    if (!layouts.contains(control.device.layout)) return;
    if (control.synthetic || control.continuous) return;
    final path = control.path.toString();
    if (excluding.any((e) => path == e || path.startsWith('$e/'))) return;
    if (_held.contains(control)) {
      if (magnitude < threshold * 0.75) _held.remove(control);
      return;
    }
    if (magnitude < threshold) return;
    if (cancelWith.contains(path)) {
      cancel();
      return;
    }
    final wanted = _wanted;
    if (!wanted.contains(control.type)) return;
    // A button slot takes a stick's direction, not half an axis.
    if (control.type == ControlValueType.axis &&
        control.path.child != null &&
        wanted.contains(ControlValueType.button)) {
      return;
    }
    _finish(
      RebindState.completed,
      RebindCompleted(path, conflicts: conflictsFor(path)),
    );
  }

  /// Other actions [path] would also press, were it bound here.
  List<BindingConflict> conflictsFor(String path) {
    final overrides = BindingOverrides(
      target.overrides,
    ).withPath(bindingId, path);
    final asset = applyOverrides(service.asset, overrides);
    return [
      for (final c in findBindingConflicts(asset, group: target.group))
        if (c.bindingIds.contains(bindingId)) c,
    ];
  }

  void cancel() {
    if (state.value != RebindState.listening) return;
    _finish(RebindState.canceled, const RebindCanceled());
  }

  void _finish(RebindState end, RebindResult result) {
    _raw?.cancel();
    keyboardHook.remove();
    state.value = end;
    service.resumeActions();
    if (!_done.isCompleted) _done.complete(result);
  }
}

/// Rebinds one of [player]'s bindings: listens, keeps the result, saves.
///
/// With [swap], a control another action already had goes to that action's
/// old binding in exchange — nothing is left doubled up.
Future<RebindResult> rebindPlayer(
  PlayerInput player,
  String bindingId, {
  bool swap = true,
  KeyboardCaptureHook? keyboardHook,
  void Function(RebindingOperation operation)? onStart,
}) async {
  final service = player.manager.service;
  final op = RebindingOperation(
    service: service,
    target: player.actions,
    bindingId: bindingId,
    keyboardHook: keyboardHook,
  );
  onStart?.call(op);
  final result = await op.start();
  if (result is! RebindCompleted) return result;

  final current = applyOverrides(service.asset, player.overrides);
  final oldPath = current.findBinding(bindingId)?.path ?? '';
  var overrides = player.overrides.withPath(bindingId, result.path);
  if (swap && oldPath.isNotEmpty) {
    for (final c in result.conflicts) {
      final other = c.first.bindingId == bindingId ? c.second : c.first;
      // Only single controls swap; a chord stays as it is.
      if (ControlPath.tryParse(other.path) == null) continue;
      overrides = overrides.withPath(other.bindingId, oldPath);
    }
  }
  player.overrides = overrides;
  await player.saveOverrides();
  return result;
}

/// The path a binding reads for [actions] — its override if it has one.
String effectivePath(InputActions actions, String bindingId) {
  final override = actions.overrides[bindingId];
  if (override != null) return override;
  final ref = actions.service.asset.findBinding(bindingId);
  if (ref == null) return '';
  return switch ((ref.part, ref.binding)) {
    (final CompositePartDef p, _) => p.path,
    (_, final ControlBindingDef b) => b.path,
    _ => '',
  };
}
