import 'dart:async';

import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../input_management.dart';

/// Bridges `just_gamepads` into a single [ControllerInput] — subscribes to a
/// [gp.GamepadManager]'s connect/disconnect and state streams and forwards
/// whichever controller is currently
/// [gp.GamepadManager.mostRecentlyActiveId] into [ControllerInput.setAxis]/
/// [ControllerInput.setButton], since this game is single-player and only
/// ever wants one surfaced controller regardless of how many are physically
/// connected.
///
/// Constructed and started once by [InputManager.attachGamepads] — not
/// meant to be used directly by app code.
class GamepadInputAdapter {
  GamepadInputAdapter(this._controller, {gp.GamepadManager? manager})
    : _manager = manager ?? gp.GamepadManager.instance;

  final ControllerInput _controller;
  final gp.GamepadManager _manager;

  StreamSubscription<gp.GamepadConnectionEvent>? _connectionsSubscription;
  StreamSubscription<gp.GamepadStateEvent>? _stateSubscription;

  /// Which gamepad id's state is currently reflected in [_controller] — used
  /// to detect an active-controller switch (or a same-id-but-clean restart)
  /// so stale button/axis state from a previously-active controller doesn't
  /// stick around forever once it stops sending events (e.g. on disconnect).
  String? _forwardingId;

  void start() {
    unawaited(_manager.start());
    _connectionsSubscription = _manager.connections.listen(_onConnection);
    _stateSubscription = _manager.stateChanges.listen(_onState);
  }

  void _onConnection(gp.GamepadConnectionEvent event) {
    if (!event.connected && event.info.id == _forwardingId) {
      _controller.clear();
      _forwardingId = null;
    }
    _refreshActiveMeta();
  }

  void _onState(gp.GamepadStateEvent event) {
    if (event.gamepadId != _manager.mostRecentlyActiveId) return;

    // Switching which controller is active (or its first-ever snapshot):
    // reset edge-detection/axis state first so nothing from a previous
    // controller (or a stale pre-connection default) lingers.
    if (_forwardingId != event.gamepadId) {
      _controller.clear();
      _forwardingId = event.gamepadId;
    }

    final axes = event.state.axes;
    _controller.setAxis(GamepadAxis.leftStickX, axes[gp.GamepadAxis.leftStickX] ?? 0.0);
    _controller.setAxis(GamepadAxis.leftStickY, axes[gp.GamepadAxis.leftStickY] ?? 0.0);
    _controller.setAxis(GamepadAxis.rightStickX, axes[gp.GamepadAxis.rightStickX] ?? 0.0);
    _controller.setAxis(GamepadAxis.rightStickY, axes[gp.GamepadAxis.rightStickY] ?? 0.0);
    _controller.setAxis(GamepadAxis.leftTrigger, axes[gp.GamepadAxis.leftTrigger] ?? 0.0);
    _controller.setAxis(GamepadAxis.rightTrigger, axes[gp.GamepadAxis.rightTrigger] ?? 0.0);

    for (var button = GamepadButton.a; button <= GamepadButton.dpadRight; button++) {
      _controller.setButton(button, event.state.buttonsDown.contains(button));
    }

    _refreshActiveMeta();
  }

  void _refreshActiveMeta() {
    final activeId = _manager.mostRecentlyActiveId;
    gp.GamepadInfo? info;
    if (activeId != null) {
      for (final candidate in _manager.connected) {
        if (candidate.id == activeId) {
          info = candidate;
          break;
        }
      }
    }
    _controller.activeGamepadType = info?.type;
    _controller.activeGamepadName = info?.name;
  }

  void dispose() {
    _connectionsSubscription?.cancel();
    _stateSubscription?.cancel();
    _connectionsSubscription = null;
    _stateSubscription = null;
  }
}
