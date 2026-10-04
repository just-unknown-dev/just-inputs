import 'dart:convert';

import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:flutter/painting.dart' show Offset;

import '../input_management.dart';
import 'gamepad_stick.dart';
import 'input_action.dart';
import 'input_action_set.dart';
import '_io_native.dart' if (dart.library.html) '_io_stub.dart';

/// Resolves named actions (e.g. `'dash'`, `'move'`) against an
/// [InputManager]'s live keyboard/mouse state plus generic on-screen
/// touch-button state, according to the currently-applied [actionSet] —
/// gated by [activeMapIds], so an action whose map isn't currently active
/// never resolves as triggered regardless of physical input state.
///
/// Games define their own action names, map ids, and defaults — this class
/// stays generic and knows nothing about any particular game's actions.
class InputActionResolver {
  InputActionResolver(this.inputManager, {InputActionSet? actionSet})
    : actionSet = actionSet ?? InputActionSet();

  final InputManager inputManager;
  InputActionSet actionSet;

  /// Action maps currently active. An action whose map isn't in this set
  /// never resolves as down/pressed/released/moved, regardless of physical
  /// input state — e.g. a "player" map disabled while a "ui" map stays
  /// active during a pause screen.
  Set<String> activeMapIds = {};

  final Map<String, bool> _touchDown = {};
  final Map<String, bool> _touchPrevDown = {};

  /// Replaces the current action definitions outright (e.g. after loading a
  /// saved config, or applying a live edit from the editor's Input Setup
  /// panel).
  void applyActions(InputActionSet next) => actionSet = next;

  /// Replaces the active map set outright.
  void setActiveMaps(Iterable<String> mapIds) => activeMapIds = Set.of(mapIds);

  /// Whether [action]'s map is currently active. An action with no
  /// definition is never active.
  bool isMapActive(String action) {
    final def = actionSet.defs[action];
    return def != null && activeMapIds.contains(def.mapId);
  }

  /// Every key currently bound to [action] (empty if undefined) — a raw
  /// lookup, deliberately **not** gated by [isMapActive]: callers that need
  /// map-awareness (e.g. a global hardware-key hook outside the normal ECS
  /// tick) check `isMapActive` explicitly alongside this.
  List<LogicalKeyboardKey> keysFor(String action) =>
      actionSet.defs[action]?.button.keys ?? const [];

  /// Called by an on-screen action button's press/release handler.
  void setTouchButtonDown(String action, bool down) =>
      _touchDown[action] = down;

  /// Ticked once per engine frame to snapshot previous touch-button state
  /// for edge detection — keyboard/mouse already do this internally inside
  /// [InputManager.update].
  void update() {
    _touchPrevDown.clear();
    _touchPrevDown.addAll(_touchDown);
  }

  bool isActionDown(String action) {
    if (!isMapActive(action)) return false;
    final def = actionSet.defs[action];
    if (def == null || def.type != ActionType.button) return false;
    final binding = def.button;
    if (inputManager.activeDevice == ActiveInputDevice.gamepad) {
      if (binding.gamepadButton != null &&
          inputManager.controller.isButtonDown(binding.gamepadButton!)) {
        return true;
      }
    } else {
      if (binding.keys.any(inputManager.keyboard.isKeyDown)) return true;
      if (binding.mouseButton != null &&
          inputManager.mouse.isButtonDown(binding.mouseButton!)) {
        return true;
      }
    }
    return _touchDown[action] ?? false;
  }

  bool isActionPressed(String action) {
    if (!isMapActive(action)) return false;
    final def = actionSet.defs[action];
    if (def == null || def.type != ActionType.button) return false;
    final binding = def.button;
    if (inputManager.activeDevice == ActiveInputDevice.gamepad) {
      if (binding.gamepadButton != null &&
          inputManager.controller.isButtonPressed(binding.gamepadButton!)) {
        return true;
      }
    } else {
      if (binding.keys.any(inputManager.keyboard.isKeyPressed)) return true;
      if (binding.mouseButton != null &&
          inputManager.mouse.isButtonPressed(binding.mouseButton!)) {
        return true;
      }
    }
    final down = _touchDown[action] ?? false;
    final wasDown = _touchPrevDown[action] ?? false;
    return down && !wasDown;
  }

  bool isActionReleased(String action) {
    if (!isMapActive(action)) return false;
    final def = actionSet.defs[action];
    if (def == null || def.type != ActionType.button) return false;
    final binding = def.button;
    if (inputManager.activeDevice == ActiveInputDevice.gamepad) {
      if (binding.gamepadButton != null &&
          inputManager.controller.isButtonReleased(binding.gamepadButton!)) {
        return true;
      }
    } else {
      if (binding.keys.any(inputManager.keyboard.isKeyReleased)) return true;
      if (binding.mouseButton != null &&
          inputManager.mouse.isButtonReleased(binding.mouseButton!)) {
        return true;
      }
    }
    final down = _touchDown[action] ?? false;
    final wasDown = _touchPrevDown[action] ?? false;
    return !down && wasDown;
  }

  /// Resolves a Vector2-type action's combined direction (each axis in
  /// -1..1) — e.g. `getVector2('move')`. Returns [Offset.zero] if [action]
  /// is undefined, isn't a vector2-type action, or its map isn't active.
  ///
  /// Reads from whichever device [InputManager.activeDevice] currently is:
  /// the four directional key-lists when keyboard/mouse owns input, or
  /// [Vector2Binding.gamepadStick] (if set) when the gamepad does — never
  /// both, so a stale key state and a live stick (or vice versa) can't fight
  /// over the result. Dead-zone is already applied inside
  /// `ControllerInput.setAxis`, so no dead-zone logic is needed here.
  Offset getVector2(String action) {
    if (!isMapActive(action)) return Offset.zero;
    final def = actionSet.defs[action];
    if (def == null || def.type != ActionType.vector2) return Offset.zero;
    final v = def.vector2;
    if (inputManager.activeDevice == ActiveInputDevice.gamepad) {
      if (v.gamepadStick == null) return Offset.zero;
      final stick = v.gamepadStick == GamepadStick.left
          ? inputManager.controller.leftStick
          : inputManager.controller.rightStick;
      return Offset(stick.dx, stick.dy);
    }
    final x =
        (_anyKeyDown(v.right) ? 1.0 : 0.0) - (_anyKeyDown(v.left) ? 1.0 : 0.0);
    final y =
        (_anyKeyDown(v.down) ? 1.0 : 0.0) - (_anyKeyDown(v.up) ? 1.0 : 0.0);
    return Offset(x, y);
  }

  bool _anyKeyDown(List<LogicalKeyboardKey> keys) =>
      keys.any(inputManager.keyboard.isKeyDown);

  /// Loads this project's canonical input bindings from [relativePath] and
  /// applies them outright — the project-relative JSON file is the *only*
  /// source of bindings (there's no separate code-defined default layer to
  /// merge onto), so this replaces whatever [actionSet] was previously.
  ///
  /// Tries a direct `dart:io` read of `${Directory.current.path}/$relativePath`
  /// first — this is what lets a live `flutter run` (JIT) session pick up
  /// the latest saved file on hot-restart with no asset-bundle rebuild
  /// needed — falling back to `rootBundle.loadString(relativePath)` (the
  /// path that actually works in release/mobile/web builds; requires
  /// [relativePath] to be declared under pubspec `flutter: assets:`).
  ///
  /// A tier being unavailable — `dart:io` unsupported on web, or the file
  /// not present relative to the current working directory — just means
  /// "try the next tier", the normal, expected case. Once content is
  /// actually read, though, a JSON parse failure is a real authoring
  /// mistake and is left to throw rather than being swallowed, so a bad
  /// edit is caught immediately instead of silently shipping a broken
  /// control scheme.
  Future<void> loadFromProjectFile(String relativePath) async {
    String? raw;
    try {
      raw = readFile(relativePath);
    } catch (_) {
      // Expected when dart:io is unavailable (web) or this isn't a desktop
      // dev run — fall through to the bundled-asset tier below.
    }
    raw ??= await rootBundle.loadString(relativePath);
    applyActions(InputActionSet.fromJson(jsonDecode(raw) as Map<String, dynamic>));
  }
}
