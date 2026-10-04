import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;

import 'impl/gamepad_input_adapter.dart';

part 'impl/mouse_button.dart';
part 'impl/keyboard_input.dart';
part 'impl/mouse_input.dart';
part 'impl/touch_input.dart';
part 'impl/virtual_joystick.dart';
part 'controller_input.dart';

/// Which physical input device currently "owns" gameplay input —
/// keyboard/mouse and the gamepad are mutually exclusive rather than both
/// being read every frame, so e.g. a stale mouse position and a live gamepad
/// stick can't fight over aim direction at once. On-screen touch controls
/// (buttons, virtual joysticks) are deliberately **not** part of this: they
/// only ever appear on touch UIs, which aren't used alongside a mouse or a
/// physical gamepad in practice, so they stay independently always-on.
///
/// See [InputManager.activeDevice].
enum ActiveInputDevice { keyboardMouse, gamepad }

/// Main input manager class
class InputManager {
  /// Keyboard input handler
  final keyboard = KeyboardInput();

  /// Mouse input handler
  final mouse = MouseInput();

  /// Touch input handler
  final touch = TouchInput();

  /// Controller input handler
  final controller = ControllerInput();

  /// Which device ([keyboard]+[mouse] or [controller]) currently owns
  /// gameplay input resolution — see [ActiveInputDevice]. Starts as
  /// [ActiveInputDevice.keyboardMouse] and only ever changes when one side
  /// shows genuine activity (see [_updateActiveDevice]); a frame where
  /// neither device is active leaves it unchanged rather than resetting it,
  /// so e.g. releasing a held gamepad button doesn't itself flip control
  /// back to keyboard/mouse.
  ActiveInputDevice activeDevice = ActiveInputDevice.keyboardMouse;

  /// Mouse movement below this (in logical pixels, per frame) doesn't count
  /// as "using the mouse" — filters out OS/sensor jitter from a physically
  /// stationary mouse so it can't steal control back from an actively-used
  /// gamepad.
  static const double mouseMoveActivationThreshold = 2.0;

  /// Callbacks for external handling
  final List<void Function(KeyEvent)> _keyCallbacks = [];
  final List<void Function(PointerEvent)> _pointerCallbacks = [];

  GamepadInputAdapter? _gamepadAdapter;

  /// Starts feeding real gamepad hardware into [controller]. Deliberately
  /// **not** called automatically from [initialize] — this is the only
  /// method on [InputManager] with a platform-channel side effect (via
  /// `just_gamepads`), and keeping the rest of this class free of that
  /// matters for future headless/unit-testability (every existing
  /// `InputManager()` construction in this package's own tests works with no
  /// platform bindings at all). Callers that want gamepad support (i.e. the
  /// app, once per `Engine`) opt in explicitly by calling this once.
  void attachGamepads({gp.GamepadManager? manager}) {
    _gamepadAdapter?.dispose();
    _gamepadAdapter = GamepadInputAdapter(controller, manager: manager)
      ..start();
  }

  /// Initialize input system
  void initialize() {
    keyboard.initialize();
    mouse.initialize();
    touch.initialize();
    controller.initialize();
  }

  /// Update input state (call each frame)
  void update() {
    keyboard.update();
    mouse.update();
    touch.update();
    controller.update();
    _updateActiveDevice();
  }

  /// Decides which device owns [activeDevice] this frame. Keyboard/mouse
  /// activity takes priority over an already-active gamepad on a frame where
  /// both are active — an explicit key press, click, or real mouse move is
  /// treated as the player deliberately reclaiming control, matching
  /// [ActiveInputDevice]'s doc.
  void _updateActiveDevice() {
    final keyboardMouseActive =
        keyboard.anyKeyDown ||
        mouse.anyButtonDown ||
        mouse.delta.distance > mouseMoveActivationThreshold;
    if (keyboardMouseActive) {
      activeDevice = ActiveInputDevice.keyboardMouse;
    } else if (controller.hasActivity) {
      activeDevice = ActiveInputDevice.gamepad;
    }
  }

  /// Handle key event (call from widget)
  void handleKeyEvent(KeyEvent event) {
    keyboard.handleKeyEvent(event);
    for (final callback in _keyCallbacks) {
      callback(event);
    }
  }

  /// Handle pointer event (call from widget)
  void handlePointerEvent(PointerEvent event) {
    mouse.handlePointerEvent(event);
    touch.handlePointerEvent(event);
    for (final callback in _pointerCallbacks) {
      callback(event);
    }
  }

  /// Register callback for key events
  void onKeyEvent(void Function(KeyEvent) callback) {
    _keyCallbacks.add(callback);
  }

  /// Register callback for pointer events
  void onPointerEvent(void Function(PointerEvent) callback) {
    _pointerCallbacks.add(callback);
  }

  /// Clear all input states
  void clear() {
    keyboard.clear();
    mouse.clear();
    touch.clear();
    controller.clear();
  }

  /// Clean up input resources
  void dispose() {
    keyboard.dispose();
    mouse.dispose();
    touch.dispose();
    controller.dispose();
    _gamepadAdapter?.dispose();
    _gamepadAdapter = null;
    _keyCallbacks.clear();
    _pointerCallbacks.clear();
  }
}
