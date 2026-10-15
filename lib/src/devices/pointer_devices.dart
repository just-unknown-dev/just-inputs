import 'package:flutter/gestures.dart';

import '../paths/control_path.dart';
import '../paths/pointer_controls.dart';
import 'input_device.dart';

final class MouseState extends DeviceState<MouseState> {
  MouseState({
    this.buttons = 0,
    this.position = Offset.zero,
    this.delta = Offset.zero,
    this.scroll = Offset.zero,
    this.travelled = Offset.zero,
    this.scrolled = Offset.zero,
  });

  int buttons;
  Offset position;
  Offset delta;
  Offset scroll;

  /// Every movement added up since the mouse was made — [delta] without the
  /// reset at each update — for reading a frame at a time.
  Offset travelled;

  /// The same for the wheel.
  Offset scrolled;

  @override
  MouseState copy() => MouseState(
    buttons: buttons,
    position: position,
    delta: delta,
    scroll: scroll,
    travelled: travelled,
    scrolled: scrolled,
  );
}

/// The mouse. [MouseControls.delta] and [MouseControls.scroll] add up what
/// happened since the last update and start again from zero at each; their
/// running totals ([InputControl.readTotal]) never start again, for reading
/// once per rendered frame instead.
///
/// Movement comes from Flutter's pointer events, or from outside them
/// through [injectDelta] — a locked pointer's raw movement. While
/// [relativeMode] is on, only the injected movement counts.
final class MouseDevice extends StatefulDevice<MouseState> {
  MouseDevice({required super.deviceId})
    : super(
        layout: InputLayouts.mouse,
        displayName: 'Mouse',
        initial: MouseState(),
      );

  late final List<InputControl> _controls = [
    for (final entry in MouseControls.buttonBits.entries)
      InputControl(
        this,
        ControlPath(layout, entry.key),
        ControlValueType.button,
        (s) => buttonValue((s as MouseState).buttons & entry.value != 0),
      ),
    ...vector2Controls(
      this,
      MouseControls.position,
      (s) => (s as MouseState).position,
      directions: false,
      continuous: true,
    ),
    ...vector2Controls(
      this,
      MouseControls.delta,
      (s) => (s as MouseState).delta,
      continuous: true,
      total: (s) => (s as MouseState).travelled,
    ),
    ...vector2Controls(
      this,
      MouseControls.scroll,
      (s) => (s as MouseState).scroll,
      continuous: true,
      total: (s) => (s as MouseState).scrolled,
    ),
  ];

  late final Map<String, InputControl> _byName = {
    for (final c in _controls) c.name: c,
  };

  @override
  List<InputControl> get controls => _controls;

  @override
  InputControl? control(String name) => _byName[name];

  /// Movement comes from [injectDelta] alone: the pointer is locked, its
  /// cursor hidden and held in place, and the pointer events' own movement
  /// (a hidden cursor nudged against its clip) would count it twice. Their
  /// buttons and position still count. Off by default.
  bool relativeMode = false;

  void handlePointerEvent(PointerEvent event) {
    if (event.kind != PointerDeviceKind.mouse) return;
    if (event is PointerScrollEvent) {
      // Flutter's wheel delta already points the world's way: rolling the
      // wheel away (up) is negative y.
      final d = event.scrollDelta;
      queue((s) {
        s.scroll += d;
        s.scrolled += d;
      });
      return;
    }
    // Flutter reports the buttons still held; a cancel means none are.
    final buttons = event is PointerCancelEvent ? 0 : event.buttons;
    final position = event.localPosition;
    final delta = relativeMode ? Offset.zero : event.localDelta;
    if (buttons == live.buttons &&
        position == live.position &&
        delta == Offset.zero) {
      return;
    }
    queue((s) {
      s.buttons = buttons;
      s.position = position;
      s.delta += delta;
      s.travelled += delta;
    });
  }

  /// Adds [delta] to the mouse's movement as though the pointer had moved:
  /// raw movement from outside Flutter's pointer events, such as a locked
  /// pointer's (`PointerLock`). `<Mouse>/delta` sees it at the next
  /// update, and a frame-at-a-time read (`FrameMotion`) at once.
  ///
  /// `InputService.attachRawMouse` does this for a stream of them.
  void injectDelta(Offset delta) {
    if (delta == Offset.zero) return;
    queue((s) {
      s.delta += delta;
      s.travelled += delta;
    });
  }

  @override
  bool beginUpdate() {
    if (applied.delta == Offset.zero && applied.scroll == Offset.zero) {
      return false;
    }
    // Straight to both: the reset belongs to this update, not to the queue.
    applied
      ..delta = Offset.zero
      ..scroll = Offset.zero;
    live
      ..delta = Offset.zero
      ..scroll = Offset.zero;
    return true;
  }

  void releaseAll() {
    if (live.buttons == 0) return;
    queue((s) => s.buttons = 0);
  }
}

final class TouchState extends DeviceState<TouchState> {
  TouchState({
    this.pointer,
    this.position = Offset.zero,
    this.delta = Offset.zero,
    this.travelled = Offset.zero,
    Map<int, Offset>? touches,
  }) : touches = touches ?? {};

  /// The first finger down, followed until it lifts.
  int? pointer;
  Offset position;
  Offset delta;

  /// Every movement of the first finger added up since the screen was made
  /// — [delta] without the reset at each update.
  Offset travelled;

  /// Every finger down, by pointer id.
  final Map<int, Offset> touches;

  @override
  TouchState copy() => TouchState(
    pointer: pointer,
    position: position,
    delta: delta,
    travelled: travelled,
    touches: {...touches},
  );
}

/// A touch screen: the first finger as [TouchscreenControls], and every
/// finger in [touches] for game code that wants them.
final class TouchscreenDevice extends StatefulDevice<TouchState> {
  TouchscreenDevice({required super.deviceId})
    : super(
        layout: InputLayouts.touchscreen,
        displayName: 'Touch screen',
        initial: TouchState(),
      );

  late final List<InputControl> _controls = [
    InputControl(
      this,
      ControlPath(layout, TouchscreenControls.press),
      ControlValueType.button,
      (s) => buttonValue((s as TouchState).pointer != null),
    ),
    ...vector2Controls(
      this,
      TouchscreenControls.position,
      (s) => (s as TouchState).position,
      directions: false,
      continuous: true,
    ),
    ...vector2Controls(
      this,
      TouchscreenControls.delta,
      (s) => (s as TouchState).delta,
      continuous: true,
      total: (s) => (s as TouchState).travelled,
    ),
  ];

  late final Map<String, InputControl> _byName = {
    for (final c in _controls) c.name: c,
  };

  @override
  List<InputControl> get controls => _controls;

  @override
  InputControl? control(String name) => _byName[name];

  /// Every finger down now, by pointer id.
  Map<int, Offset> get touches => Map.unmodifiable(applied.touches);

  void handlePointerEvent(PointerEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    final id = event.pointer;
    final at = event.localPosition;
    switch (event) {
      case PointerDownEvent():
        queue((s) {
          s.touches[id] = at;
          if (s.pointer == null) {
            s.pointer = id;
            s.position = at;
          }
        });
      case PointerMoveEvent():
        final d = event.localDelta;
        queue((s) {
          s.touches[id] = at;
          if (s.pointer == id) {
            s.position = at;
            s.delta += d;
            s.travelled += d;
          }
        });
      case PointerUpEvent() || PointerCancelEvent():
        queue((s) {
          s.touches.remove(id);
          if (s.pointer == id) s.pointer = null;
        });
      default:
        return;
    }
  }

  @override
  bool beginUpdate() {
    if (applied.delta == Offset.zero) return false;
    applied.delta = Offset.zero;
    live.delta = Offset.zero;
    return true;
  }
}
