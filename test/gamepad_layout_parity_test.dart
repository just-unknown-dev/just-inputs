// `just_inputs`' ControllerInput deliberately doesn't import just_gamepads'
// GamepadAxis/GamepadButton models directly (kept dependency-free for
// testability — see controller_input.dart's doc comments), so the two
// packages' layout constants are defined twice. This test is the guard
// against them silently drifting apart.
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gamepads;
import 'package:just_inputs/just_inputs.dart';

void main() {
  test('GamepadButton constants match just_gamepads exactly', () {
    expect(GamepadButton.a, gamepads.GamepadButton.a);
    expect(GamepadButton.b, gamepads.GamepadButton.b);
    expect(GamepadButton.x, gamepads.GamepadButton.x);
    expect(GamepadButton.y, gamepads.GamepadButton.y);
    expect(GamepadButton.leftBumper, gamepads.GamepadButton.leftBumper);
    expect(GamepadButton.rightBumper, gamepads.GamepadButton.rightBumper);
    expect(
      GamepadButton.leftTriggerButton,
      gamepads.GamepadButton.leftTriggerButton,
    );
    expect(
      GamepadButton.rightTriggerButton,
      gamepads.GamepadButton.rightTriggerButton,
    );
    expect(GamepadButton.back, gamepads.GamepadButton.back);
    expect(GamepadButton.start, gamepads.GamepadButton.start);
    expect(GamepadButton.leftStick, gamepads.GamepadButton.leftStick);
    expect(GamepadButton.rightStick, gamepads.GamepadButton.rightStick);
    expect(GamepadButton.dpadUp, gamepads.GamepadButton.dpadUp);
    expect(GamepadButton.dpadDown, gamepads.GamepadButton.dpadDown);
    expect(GamepadButton.dpadLeft, gamepads.GamepadButton.dpadLeft);
    expect(GamepadButton.dpadRight, gamepads.GamepadButton.dpadRight);
  });

  test('GamepadAxis constants match just_gamepads exactly', () {
    expect(GamepadAxis.leftStickX, gamepads.GamepadAxis.leftStickX);
    expect(GamepadAxis.leftStickY, gamepads.GamepadAxis.leftStickY);
    expect(GamepadAxis.rightStickX, gamepads.GamepadAxis.rightStickX);
    expect(GamepadAxis.rightStickY, gamepads.GamepadAxis.rightStickY);
    expect(GamepadAxis.leftTrigger, gamepads.GamepadAxis.leftTrigger);
    expect(GamepadAxis.rightTrigger, gamepads.GamepadAxis.rightTrigger);
  });
}
