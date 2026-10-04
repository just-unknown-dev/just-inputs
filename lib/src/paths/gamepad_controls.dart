import 'package:just_gamepads/just_gamepads.dart' as gp;

import 'control_info.dart';
import 'control_path.dart';

/// The controls of a standard gamepad, named by **position** — the button at
/// the bottom of the face is `buttonSouth` whether it says A or ✕ — and tied
/// to the W3C standard layout `just_gamepads` reports every pad in.
abstract final class GamepadControls {
  static const String buttonSouth = 'buttonSouth';
  static const String buttonEast = 'buttonEast';
  static const String buttonWest = 'buttonWest';
  static const String buttonNorth = 'buttonNorth';
  static const String leftShoulder = 'leftShoulder';
  static const String rightShoulder = 'rightShoulder';
  static const String leftTrigger = 'leftTrigger';
  static const String rightTrigger = 'rightTrigger';
  static const String select = 'select';
  static const String start = 'start';
  static const String leftStickPress = 'leftStickPress';
  static const String rightStickPress = 'rightStickPress';
  static const String dpad = 'dpad';
  static const String leftStick = 'leftStick';
  static const String rightStick = 'rightStick';

  /// The W3C button index behind each plain button, the d-pad's directions
  /// included.
  static const Map<String, int> buttonIndex = {
    buttonSouth: gp.GamepadButton.a,
    buttonEast: gp.GamepadButton.b,
    buttonWest: gp.GamepadButton.x,
    buttonNorth: gp.GamepadButton.y,
    leftShoulder: gp.GamepadButton.leftBumper,
    rightShoulder: gp.GamepadButton.rightBumper,
    select: gp.GamepadButton.back,
    start: gp.GamepadButton.start,
    leftStickPress: gp.GamepadButton.leftStick,
    rightStickPress: gp.GamepadButton.rightStick,
    '$dpad/up': gp.GamepadButton.dpadUp,
    '$dpad/down': gp.GamepadButton.dpadDown,
    '$dpad/left': gp.GamepadButton.dpadLeft,
    '$dpad/right': gp.GamepadButton.dpadRight,
  };

  /// The triggers are axes from 0 to 1; a pad that only reports them as
  /// buttons reads 0 or 1 through these indices.
  static const Map<String, int> triggerButtonIndex = {
    leftTrigger: gp.GamepadButton.leftTriggerButton,
    rightTrigger: gp.GamepadButton.rightTriggerButton,
  };

  static const Map<String, String> triggerAxis = {
    leftTrigger: gp.GamepadAxis.leftTrigger,
    rightTrigger: gp.GamepadAxis.rightTrigger,
  };

  /// Each stick's two `just_gamepads` axes, x then y.
  static const Map<String, (String, String)> stickAxes = {
    leftStick: (gp.GamepadAxis.leftStickX, gp.GamepadAxis.leftStickY),
    rightStick: (gp.GamepadAxis.rightStickX, gp.GamepadAxis.rightStickY),
  };

  static ControlPath _p(String control) =>
      ControlPath(InputLayouts.gamepad, control);

  static ControlInfo _button(String name, String label) =>
      ControlInfo(_p(name), label, ControlValueType.button);

  static ControlInfo _vector(String name, String label) => ControlInfo(
    _p(name),
    label,
    ControlValueType.vector2,
    children: vector2Children(_p(name), label),
  );

  static final List<ControlInfo> all = [
    _button(buttonSouth, 'Button South'),
    _button(buttonEast, 'Button East'),
    _button(buttonWest, 'Button West'),
    _button(buttonNorth, 'Button North'),
    _button(leftShoulder, 'Left Shoulder'),
    _button(rightShoulder, 'Right Shoulder'),
    ControlInfo(_p(leftTrigger), 'Left Trigger', ControlValueType.axis),
    ControlInfo(_p(rightTrigger), 'Right Trigger', ControlValueType.axis),
    _button(select, 'Select'),
    _button(start, 'Start'),
    _button(leftStickPress, 'Left Stick Press'),
    _button(rightStickPress, 'Right Stick Press'),
    ControlInfo(
      _p(dpad),
      'D-Pad',
      ControlValueType.vector2,
      // The d-pad's directions are buttons, not halves of an axis.
      children: [
        for (final d in const ['up', 'down', 'left', 'right'])
          ControlInfo(
            _p('$dpad/$d'),
            'D-Pad ${d[0].toUpperCase()}${d.substring(1)}',
            ControlValueType.button,
          ),
      ],
    ),
    _vector(leftStick, 'Left Stick'),
    _vector(rightStick, 'Right Stick'),
  ];
}
