import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../actions/gamepad_stick.dart';
import '../input_management.dart';

/// Short, brand-aware text label for a gamepad button — Unicode glyphs, not
/// bundled icon assets, consistent with every other input label in this
/// codebase already being plain text (`LogicalKeyboardKey.keyLabel` for keys,
/// a hardcoded 'LMB'/'RMB'/'MMB' switch for mouse buttons — see
/// `settings_view.dart`/the editor's Input Setup panel). Adding an icon
/// asset pipeline for this alone would be disproportionate: this project has
/// no icon assets at all today.
///
/// [type] chooses which face-button glyphs to use — Xbox/generic uses
/// circled letters, PlayStation uses its shape glyphs, and Nintendo's Switch
/// Pro controller gets its own mapping since its face buttons are physically
/// **mirrored** relative to Xbox (A/B swapped, X/Y swapped) — a real,
/// easy-to-get-wrong detail, not a copy-paste of the Xbox case.
/// [GamepadType.unknown]/[GamepadType.generic] both fall back to the
/// Xbox-style circled-letter glyphs as a reasonable default.
String gamepadButtonLabel(gp.GamepadType type, int button) {
  switch (button) {
    case gp.GamepadButton.a:
    case gp.GamepadButton.b:
    case gp.GamepadButton.x:
    case gp.GamepadButton.y:
      return _faceButtonLabel(type, button);
    case gp.GamepadButton.leftBumper:
      return 'LB';
    case gp.GamepadButton.rightBumper:
      return 'RB';
    case gp.GamepadButton.leftTriggerButton:
      return 'LT';
    case gp.GamepadButton.rightTriggerButton:
      return 'RT';
    case gp.GamepadButton.back:
      return type == gp.GamepadType.playStation ? 'Share' : 'Back';
    case gp.GamepadButton.start:
      return type == gp.GamepadType.playStation ? 'Options' : 'Start';
    case gp.GamepadButton.leftStick:
      return 'L3';
    case gp.GamepadButton.rightStick:
      return 'R3';
    case gp.GamepadButton.dpadUp:
      return 'D-Up';
    case gp.GamepadButton.dpadDown:
      return 'D-Down';
    case gp.GamepadButton.dpadLeft:
      return 'D-Left';
    case gp.GamepadButton.dpadRight:
      return 'D-Right';
    default:
      return 'Btn $button';
  }
}

String _faceButtonLabel(gp.GamepadType type, int button) {
  switch (type) {
    case gp.GamepadType.playStation:
      // ✕ ○ □ △ — PlayStation's own face-button glyphs.
      return switch (button) {
        gp.GamepadButton.a => '✕',
        gp.GamepadButton.b => '○',
        gp.GamepadButton.x => '□',
        gp.GamepadButton.y => '△',
        _ => '?',
      };
    case gp.GamepadType.nintendoSwitchPro:
      // Physically mirrored vs. Xbox: A/B swapped, X/Y swapped.
      return switch (button) {
        gp.GamepadButton.a => 'Ⓑ',
        gp.GamepadButton.b => 'Ⓐ',
        gp.GamepadButton.x => 'Ⓨ',
        gp.GamepadButton.y => 'Ⓧ',
        _ => '?',
      };
    case gp.GamepadType.xbox:
    case gp.GamepadType.generic:
    case gp.GamepadType.unknown:
      return switch (button) {
        gp.GamepadButton.a => 'Ⓐ',
        gp.GamepadButton.b => 'Ⓑ',
        gp.GamepadButton.x => 'Ⓧ',
        gp.GamepadButton.y => 'Ⓨ',
        _ => '?',
      };
  }
}

/// Short label for a [GamepadStick] — used by the editor's Input Setup panel
/// and anywhere a Vector2 action's stick binding needs description.
String gamepadStickLabel(GamepadStick stick) =>
    stick == GamepadStick.left ? 'Left Stick' : 'Right Stick';

/// Convenience wrapper so callers that only have a [ControllerInput] (e.g.
/// the level editor's Input Setup panel, or the in-game Controls screen)
/// don't need their own dependency on `just_gamepads` just to write a
/// [gp.GamepadType] fallback literal — falls back to the Xbox-style glyphs
/// (matching [gamepadButtonLabel]'s own default for
/// [gp.GamepadType.generic]/[gp.GamepadType.unknown]) when no controller has
/// produced input yet, so bindings still describe correctly even with no
/// hardware currently connected.
String gamepadButtonLabelForController(ControllerInput controller, int button) =>
    gamepadButtonLabel(controller.activeGamepadType ?? gp.GamepadType.xbox, button);
