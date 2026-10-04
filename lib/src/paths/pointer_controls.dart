import 'package:flutter/gestures.dart';

import 'control_info.dart';
import 'control_path.dart';

/// The mouse's controls.
abstract final class MouseControls {
  static const String leftButton = 'leftButton';
  static const String rightButton = 'rightButton';
  static const String middleButton = 'middleButton';
  static const String backButton = 'backButton';
  static const String forwardButton = 'forwardButton';

  /// Where the pointer is, in logical pixels of the game view.
  static const String position = 'position';

  /// How far it moved since the last update.
  static const String delta = 'delta';

  /// How far the wheel turned since the last update.
  static const String scroll = 'scroll';

  /// Flutter's button bit for each button.
  static const Map<String, int> buttonBits = {
    leftButton: kPrimaryMouseButton,
    rightButton: kSecondaryMouseButton,
    middleButton: kMiddleMouseButton,
    backButton: kBackMouseButton,
    forwardButton: kForwardMouseButton,
  };

  static ControlPath _p(String control) =>
      ControlPath(InputLayouts.mouse, control);

  static final List<ControlInfo> all = [
    ControlInfo(_p(leftButton), 'Left Button', ControlValueType.button),
    ControlInfo(_p(rightButton), 'Right Button', ControlValueType.button),
    ControlInfo(_p(middleButton), 'Middle Button', ControlValueType.button),
    ControlInfo(_p(backButton), 'Back Button', ControlValueType.button),
    ControlInfo(_p(forwardButton), 'Forward Button', ControlValueType.button),
    ControlInfo(
      _p(position),
      'Position',
      ControlValueType.vector2,
      children: vector2Children(_p(position), 'Position', directions: false),
    ),
    ControlInfo(
      _p(delta),
      'Delta',
      ControlValueType.vector2,
      children: vector2Children(_p(delta), 'Delta'),
    ),
    ControlInfo(
      _p(scroll),
      'Scroll',
      ControlValueType.vector2,
      children: vector2Children(_p(scroll), 'Scroll'),
    ),
  ];
}

/// The first finger on a touch screen. Several fingers at once are for the
/// on-screen controls, each of which follows its own.
abstract final class TouchscreenControls {
  static const String press = 'press';
  static const String position = 'position';
  static const String delta = 'delta';

  static ControlPath _p(String control) =>
      ControlPath(InputLayouts.touchscreen, control);

  static final List<ControlInfo> all = [
    ControlInfo(_p(press), 'Touch', ControlValueType.button),
    ControlInfo(
      _p(position),
      'Touch Position',
      ControlValueType.vector2,
      children: vector2Children(
        _p(position),
        'Touch Position',
        directions: false,
      ),
    ),
    ControlInfo(
      _p(delta),
      'Touch Delta',
      ControlValueType.vector2,
      children: vector2Children(_p(delta), 'Touch Delta'),
    ),
  ];
}
