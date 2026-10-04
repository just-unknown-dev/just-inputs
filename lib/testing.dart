/// Helpers for testing code that uses `just_inputs`: a gamepad source you
/// plug pads into by hand, and a way to press keys without a keyboard.
///
/// Never imported by a game.
library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;

import 'just_inputs.dart';

/// Pads that exist only in a test. Events arrive synchronously, so a test
/// can press and look straight after.
final class FakeGamepadSource implements GamepadSource {
  final _connections = StreamController<gp.GamepadConnectionEvent>.broadcast(
    sync: true,
  );
  final _states = StreamController<gp.GamepadStateEvent>.broadcast(sync: true);
  final Map<String, gp.GamepadInfo> _pads = {};
  final Map<String, gp.GamepadState> _latest = {};

  @override
  Future<void> start() async {}

  @override
  List<gp.GamepadInfo> get connected => List.unmodifiable(_pads.values);

  @override
  gp.GamepadState? latestState(String gamepadId) => _latest[gamepadId];

  @override
  Stream<gp.GamepadConnectionEvent> get connections => _connections.stream;

  @override
  Stream<gp.GamepadStateEvent> get stateChanges => _states.stream;

  /// Plugs a pad in.
  gp.GamepadInfo connect(
    String id, {
    String? name,
    gp.GamepadType type = gp.GamepadType.xbox,
    int? vendorId,
    int? productId,
  }) {
    final info = gp.GamepadInfo(
      id: id,
      name: name ?? 'Pad $id',
      type: type,
      vendorId: vendorId,
      productId: productId,
    );
    _pads[id] = info;
    _connections.add(gp.GamepadConnectionEvent(info: info, connected: true));
    return info;
  }

  void disconnect(String id) {
    final info = _pads.remove(id);
    if (info == null) return;
    _latest.remove(id);
    _connections.add(gp.GamepadConnectionEvent(info: info, connected: false));
  }

  /// Sends a whole snapshot: [buttons] held (W3C indices) and [axes].
  void send(
    String id, {
    Set<int> buttons = const {},
    Map<String, double> axes = const {},
  }) {
    final state = gp.GamepadState(buttonsDown: buttons, axes: axes);
    _latest[id] = state;
    _states.add(gp.GamepadStateEvent(gamepadId: id, state: state));
  }

  /// Holds [button] alone.
  void press(String id, int button) => send(id, buttons: {button});

  /// Lets go of everything.
  void release(String id) => send(id);

  /// Pushes the left stick to [value] (y down).
  void leftStick(String id, Offset value) => send(
    id,
    axes: {
      gp.GamepadAxis.leftStickX: value.dx,
      gp.GamepadAxis.leftStickY: value.dy,
    },
  );

  void dispose() {
    _connections.close();
    _states.close();
  }
}

/// Drives an [InputService] by hand: press keys, advance its clock.
final class InputTester {
  InputTester(this.service);

  final InputService service;
  double now = 0;

  void keyDown(PhysicalKeyboardKey key) => service.handleKeyEvent(
    KeyDownEvent(
      physicalKey: key,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    ),
  );

  void keyUp(PhysicalKeyboardKey key) => service.handleKeyEvent(
    KeyUpEvent(
      physicalKey: key,
      logicalKey: LogicalKeyboardKey.keyA,
      timeStamp: Duration.zero,
    ),
  );

  /// Advances the clock by [seconds] and updates.
  void step([double seconds = 1 / 60]) {
    now += seconds;
    service.update(now);
  }

  /// Presses [key], updates, lets go, updates.
  void tap(PhysicalKeyboardKey key) {
    keyDown(key);
    step();
    keyUp(key);
    step();
  }
}
