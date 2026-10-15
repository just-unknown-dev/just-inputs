import 'dart:ui' show Offset;

import '../model/settings_def.dart';
import '../paths/control_path.dart';

/// Whether a device came or went.
enum DeviceChange { added, removed }

/// Where a device's changes go: the service queues them and replays them,
/// in order, at its next update.
typedef DeviceSink = void Function(InputDevice device, void Function() apply);

/// One source of input — the keyboard, the mouse, a gamepad, the on-screen
/// controls.
///
/// A device keeps its state twice. The **live** state changes the moment an
/// event arrives; it is what rebinding reads, because a paused game still
/// has to hear the key the player presses. The **applied** state changes
/// when the service replays the queue at its update; it is what actions
/// read, so a press and a release that both land between two updates are
/// still seen as a press and then a release.
abstract class InputDevice {
  InputDevice({
    required this.deviceId,
    required this.layout,
    required this.displayName,
  });

  /// Unique for the session. A pad that is unplugged and plugged back in is
  /// a new device with a new id.
  final int deviceId;

  /// A layout name: `Keyboard`, `Gamepad`.
  final String layout;

  /// What a player sees: `Xbox Wireless Controller`.
  String displayName;

  /// False once it has gone. A player holding a device that went is waiting
  /// for it to come back.
  bool connected = true;

  /// Set by the service that owns this device.
  DeviceSink? sink;

  /// Asset settings the device reads — dead zones.
  InputSettingsDef Function() settings = () => const InputSettingsDef();

  /// Every control a binding can name on this device, children included.
  List<InputControl> get controls;

  /// The control called [name] — `space`, `leftStick/up` — or null.
  InputControl? control(String name);

  Object get liveState;
  Object get appliedState;

  /// Brings the applied state level with the live one without replaying —
  /// for a device that was just added, whose history nobody needs.
  void settle();

  /// Called at the start of every update, before the queue is replayed:
  /// clears what only lasts one update (mouse movement, wheel). True when
  /// something changed.
  bool beginUpdate() => false;

  @override
  String toString() => '$layout#$deviceId';
}

/// An [InputDevice] whose state is one object of type [S], mutated by
/// changes that are made to the live copy at once and to the applied copy
/// at the next update.
abstract class StatefulDevice<S extends DeviceState<S>> extends InputDevice {
  StatefulDevice({
    required super.deviceId,
    required super.layout,
    required super.displayName,
    required S initial,
  }) : live = initial,
       applied = initial.copy();

  S live;
  S applied;

  @override
  Object get liveState => live;

  @override
  Object get appliedState => applied;

  /// Makes [change] now to the live state, and queues it for the applied
  /// state. With no service yet, both change at once.
  void queue(void Function(S state) change) {
    final sink = this.sink;
    if (sink == null) {
      change(live);
      change(applied);
      return;
    }
    sink(this, () => change(live));
    // The live change is made by the sink, after it has looked at the state
    // before it; the applied one waits for the update.
    _pending.add(change);
  }

  final List<void Function(S)> _pending = [];

  /// Applies the oldest queued change to the applied state. The service
  /// calls this once per queued change, in order.
  void applyNext() {
    if (_pending.isEmpty) return;
    _pending.removeAt(0)(applied);
  }

  @override
  void settle() {
    _pending.clear();
    applied = live.copy();
  }
}

/// A device's whole state, copyable so live and applied can part.
abstract class DeviceState<S> {
  S copy();
}

/// One thing on a device a binding can name.
///
/// Every value is an [Offset]: a button or axis is its `dx`, a stick is both.
/// Values come already cleaned by the device — a stick's dead zone is part of
/// the stick.
final class InputControl {
  InputControl(
    this.device,
    this.path,
    this.type,
    this._read, {
    this.synthetic = false,
    this.continuous = false,
    this._total,
  });

  final InputDevice device;
  final ControlPath path;
  final ControlValueType type;
  final Offset Function(Object state) _read;
  final Offset Function(Object state)? _total;

  /// Stands for others rather than being a thing of its own: Any key, and
  /// Shift for either Shift key. Listening for a new binding passes these
  /// by in favour of the key actually pressed.
  final bool synthetic;

  /// Always moving — a pointer's position, its movement, the wheel. Moving
  /// the mouse does not count as using it, for switching devices or
  /// listening.
  final bool continuous;

  String get name => path.control;

  /// The value now. [live] reads the state as it is this instant rather than
  /// as of the last update.
  Offset read({bool live = false}) =>
      _read(live ? device.liveState : device.appliedState);

  /// How far it is pushed: a button's 0 or 1, an axis's size, a stick's
  /// length.
  double magnitude({bool live = false}) {
    final v = read(live: live);
    return type == ControlValueType.vector2 ? v.distance : v.dx.abs();
  }

  /// Whether it is movement that adds up — a pointer's delta, the wheel —
  /// so [readTotal] has something to read.
  bool get accumulates => _total != null;

  /// Everything it has moved since its device was made, added up and never
  /// reset by an update — the movement between two moments is the
  /// difference of two reads, however many updates ran between them (see
  /// `FrameMotion`). Null for a control that is not movement.
  ///
  /// Reads the live state by default: a rendered frame wants everything up
  /// to now.
  Offset? readTotal({bool live = true}) {
    final total = _total;
    if (total == null) return null;
    return total(live ? device.liveState : device.appliedState);
  }

  @override
  String toString() => '$path (${device.deviceId})';
}

/// Controls for a two-axis value and its parts: `x`, `y` and — unless it is
/// a position — the four directions, each from 0 to 1.
///
/// With [total] — movement that adds up, read by
/// [InputControl.readTotal] — the value and its `x` and `y` carry their
/// running totals too. The directions do not: what moved up over a frame is
/// not a part of where the total ended.
List<InputControl> vector2Controls(
  InputDevice device,
  String name,
  Offset Function(Object state) read, {
  bool directions = true,
  bool continuous = false,
  Offset Function(Object state)? total,
}) {
  ControlPath p(String control) => ControlPath(device.layout, control);
  InputControl axis(
    String part,
    double Function(Offset v) pick,
    ControlValueType type, {
    bool adds = false,
  }) => InputControl(
    device,
    p('$name/$part'),
    type,
    (s) => Offset(pick(read(s)), 0),
    continuous: continuous,
    total: adds && total != null ? (s) => Offset(pick(total(s)), 0) : null,
  );
  return [
    InputControl(
      device,
      p(name),
      ControlValueType.vector2,
      read,
      continuous: continuous,
      total: total,
    ),
    axis('x', (v) => v.dx, ControlValueType.axis, adds: true),
    axis('y', (v) => v.dy, ControlValueType.axis, adds: true),
    if (directions) ...[
      axis('up', (v) => v.dy < 0 ? -v.dy : 0, ControlValueType.button),
      axis('down', (v) => v.dy > 0 ? v.dy : 0, ControlValueType.button),
      axis('left', (v) => v.dx < 0 ? -v.dx : 0, ControlValueType.button),
      axis('right', (v) => v.dx > 0 ? v.dx : 0, ControlValueType.button),
    ],
  ];
}

/// A button's value.
Offset buttonValue(bool down) => down ? const Offset(1, 0) : Offset.zero;
