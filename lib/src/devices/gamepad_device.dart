import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../paths/control_path.dart';
import '../paths/gamepad_controls.dart';
import 'input_device.dart';

/// Where gamepads come from. [JustGamepadsSource] in a game; a fake in tests.
abstract interface class GamepadSource {
  Future<void> start();

  /// The pads connected now.
  List<gp.GamepadInfo> get connected;

  gp.GamepadState? latestState(String gamepadId);

  Stream<gp.GamepadConnectionEvent> get connections;
  Stream<gp.GamepadStateEvent> get stateChanges;
}

/// The real pads, through `just_gamepads`. Shares the manager with anything
/// else that uses it, and never disposes it.
final class JustGamepadsSource implements GamepadSource {
  JustGamepadsSource([gp.GamepadManager? manager])
    : manager = manager ?? gp.GamepadManager.instance;

  final gp.GamepadManager manager;

  @override
  Future<void> start() => manager.start();

  @override
  List<gp.GamepadInfo> get connected => manager.connected;

  @override
  gp.GamepadState? latestState(String gamepadId) =>
      manager.latestState(gamepadId);

  @override
  Stream<gp.GamepadConnectionEvent> get connections => manager.connections;

  @override
  Stream<gp.GamepadStateEvent> get stateChanges => manager.stateChanges;
}

final class GamepadDeviceState extends DeviceState<GamepadDeviceState> {
  GamepadDeviceState([gp.GamepadState? pad])
    : pad = pad ?? gp.GamepadState.empty;

  gp.GamepadState pad;

  @override
  GamepadDeviceState copy() => GamepadDeviceState(pad);
}

/// One pad. Two pads are two devices — which is what lets two players
/// each have their own.
final class GamepadDevice extends StatefulDevice<GamepadDeviceState> {
  GamepadDevice({required super.deviceId, required this.info})
    : super(
        layout: InputLayouts.gamepad,
        displayName: info.name,
        initial: GamepadDeviceState(),
      );

  /// What `just_gamepads` knows of the pad: its id, name, brand.
  final gp.GamepadInfo info;

  gp.GamepadType get type => info.type;

  late final List<InputControl> _controls = [
    for (final entry in GamepadControls.buttonIndex.entries)
      InputControl(
        this,
        ControlPath(layout, entry.key),
        ControlValueType.button,
        (s) => buttonValue(_pad(s).buttonsDown.contains(entry.value)),
      ),
    for (final trigger in GamepadControls.triggerAxis.keys)
      InputControl(
        this,
        ControlPath(layout, trigger),
        ControlValueType.axis,
        (s) => Offset(_trigger(_pad(s), trigger), 0),
      ),
    InputControl(
      this,
      ControlPath(layout, GamepadControls.dpad),
      ControlValueType.vector2,
      (s) => _dpad(_pad(s)),
    ),
    for (final stick in GamepadControls.stickAxes.keys)
      ...vector2Controls(this, stick, (s) => _stick(_pad(s), stick)),
  ];

  late final Map<String, InputControl> _byName = {
    for (final c in _controls) c.name: c,
  };

  @override
  List<InputControl> get controls => _controls;

  @override
  InputControl? control(String name) => _byName[name];

  static gp.GamepadState _pad(Object s) => (s as GamepadDeviceState).pad;

  /// Takes a snapshot from the pad. One that changes nothing is dropped —
  /// some platforms send the same state every tick.
  void handleState(gp.GamepadState next) {
    if (_same(live.pad, next)) return;
    queue((s) => s.pad = next);
  }

  void releaseAll() {
    if (_same(live.pad, gp.GamepadState.empty)) return;
    queue((s) => s.pad = gp.GamepadState.empty);
  }

  static bool _same(gp.GamepadState a, gp.GamepadState b) {
    if (a.buttonsDown.length != b.buttonsDown.length ||
        !a.buttonsDown.containsAll(b.buttonsDown)) {
      return false;
    }
    final keys = {...a.axes.keys, ...b.axes.keys};
    return keys.every((k) => (a.axes[k] ?? 0) == (b.axes[k] ?? 0));
  }

  double _trigger(gp.GamepadState pad, String trigger) {
    final axis = pad.axes[GamepadControls.triggerAxis[trigger]!];
    final raw =
        axis ??
        (pad.buttonsDown.contains(GamepadControls.triggerButtonIndex[trigger]!)
            ? 1.0
            : 0.0);
    final s = settings();
    return _deadzone(raw.clamp(0.0, 1.0), s.axisDeadzoneMin, s.axisDeadzoneMax);
  }

  Offset _stick(gp.GamepadState pad, String stick) {
    final (x, y) = GamepadControls.stickAxes[stick]!;
    final raw = Offset(pad.axes[x] ?? 0, pad.axes[y] ?? 0);
    final s = settings();
    return stickDeadzone(raw, s.stickDeadzoneMin, s.stickDeadzoneMax);
  }

  static Offset _dpad(gp.GamepadState pad) {
    double on(String name) =>
        pad.buttonsDown.contains(GamepadControls.buttonIndex['dpad/$name']!)
        ? 1
        : 0;
    return Offset(on('right') - on('left'), on('down') - on('up'));
  }
}

/// A single axis's dead zone: nothing below [min], full past [max], and a
/// straight line between — so the value leaves zero smoothly rather than
/// jumping to [min].
double _deadzone(double v, double min, double max) {
  final a = v.abs();
  if (a <= min) return 0;
  if (a >= max) return v.sign;
  return v.sign * (a - min) / (max - min);
}

/// A stick's dead zone, measured on the stick's length so a diagonal is not
/// clipped to a square: centred inside [min], full past [max], direction
/// kept.
Offset stickDeadzone(Offset v, double min, double max) {
  final length = v.distance;
  if (length <= min) return Offset.zero;
  final scaled = math.min(1.0, (length - min) / (max - min));
  return v / length * scaled;
}

/// A single axis's dead zone; see [stickDeadzone].
double axisDeadzone(double v, double min, double max) => _deadzone(v, min, max);
