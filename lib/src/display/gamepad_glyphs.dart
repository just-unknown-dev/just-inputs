import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../paths/gamepad_controls.dart';

/// What a gamepad control is called on a given brand of pad — plain text,
/// Unicode glyphs where the brand has them.
///
/// Positions, not letters: `buttonSouth` is Ⓐ on an Xbox pad, ✕ on a
/// PlayStation one and Ⓑ on a Switch Pro, whose face buttons are mirrored.
abstract final class GamepadGlyphs {
  static String label(gp.GamepadType type, String control) {
    final slash = control.indexOf('/');
    final head = slash < 0 ? control : control.substring(0, slash);
    final child = slash < 0 ? null : control.substring(slash + 1);
    final ps = type == gp.GamepadType.playStation;
    final nx = type == gp.GamepadType.nintendoSwitchPro;
    switch (head) {
      case GamepadControls.buttonSouth:
      case GamepadControls.buttonEast:
      case GamepadControls.buttonWest:
      case GamepadControls.buttonNorth:
        return _face(type, head);
      case GamepadControls.leftShoulder:
        return ps ? 'L1' : (nx ? 'L' : 'LB');
      case GamepadControls.rightShoulder:
        return ps ? 'R1' : (nx ? 'R' : 'RB');
      case GamepadControls.leftTrigger:
        return ps ? 'L2' : (nx ? 'ZL' : 'LT');
      case GamepadControls.rightTrigger:
        return ps ? 'R2' : (nx ? 'ZR' : 'RT');
      case GamepadControls.select:
        return ps ? 'Share' : (nx ? '−' : 'Back');
      case GamepadControls.start:
        return ps ? 'Options' : (nx ? '+' : 'Start');
      case GamepadControls.leftStickPress:
        return nx ? 'LS' : 'L3';
      case GamepadControls.rightStickPress:
        return nx ? 'RS' : 'R3';
      case GamepadControls.dpad:
        return child == null ? 'D-Pad' : 'D-Pad ${_arrow(child)}';
      case GamepadControls.leftStick:
        return child == null ? 'Left Stick' : 'Left Stick ${_arrow(child)}';
      case GamepadControls.rightStick:
        return child == null ? 'Right Stick' : 'Right Stick ${_arrow(child)}';
    }
    return control;
  }

  static String _arrow(String child) => switch (child) {
    'up' => '↑',
    'down' => '↓',
    'left' => '←',
    'right' => '→',
    'x' => 'X',
    'y' => 'Y',
    _ => child,
  };

  static String _face(gp.GamepadType type, String control) => switch (type) {
    gp.GamepadType.playStation => switch (control) {
      GamepadControls.buttonSouth => '✕',
      GamepadControls.buttonEast => '○',
      GamepadControls.buttonWest => '□',
      _ => '△',
    },
    // Mirrored against Xbox: the bottom button says B.
    gp.GamepadType.nintendoSwitchPro => switch (control) {
      GamepadControls.buttonSouth => 'Ⓑ',
      GamepadControls.buttonEast => 'Ⓐ',
      GamepadControls.buttonWest => 'Ⓨ',
      _ => 'Ⓧ',
    },
    _ => switch (control) {
      GamepadControls.buttonSouth => 'Ⓐ',
      GamepadControls.buttonEast => 'Ⓑ',
      GamepadControls.buttonWest => 'Ⓧ',
      _ => 'Ⓨ',
    },
  };
}
