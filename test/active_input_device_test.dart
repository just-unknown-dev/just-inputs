import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/gestures.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('InputManager.activeDevice', () {
    late InputManager input;

    setUp(() {
      input = InputManager()..initialize();
    });

    test('starts as keyboardMouse before any input', () {
      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('switches to gamepad when a button is pressed', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();

      expect(input.activeDevice, ActiveInputDevice.gamepad);
    });

    test('switches to gamepad when a stick clears the dead zone', () {
      input.controller.setAxis(GamepadAxis.leftStickX, 0.8);
      input.update();

      expect(input.activeDevice, ActiveInputDevice.gamepad);
    });

    test('a sub-dead-zone stick reading does not switch to gamepad', () {
      input.controller.setAxis(GamepadAxis.leftStickX, 0.05);
      input.update();

      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('a key press reclaims control from an active gamepad', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      expect(input.activeDevice, ActiveInputDevice.gamepad);

      input.keyboard.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
      );
      input.update();

      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('a mouse click reclaims control from an active gamepad', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      expect(input.activeDevice, ActiveInputDevice.gamepad);

      input.handlePointerEvent(
        PointerDownEvent(position: const Offset(10, 10), buttons: 1),
      );
      input.update();

      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('mouse movement past the threshold reclaims control from the gamepad', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      expect(input.activeDevice, ActiveInputDevice.gamepad);

      input.handlePointerEvent(
        PointerHoverEvent(position: const Offset(0, 0)),
      );
      input.update();
      input.handlePointerEvent(
        PointerHoverEvent(position: const Offset(50, 0)),
      );
      input.update();

      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('tiny mouse jitter below the threshold does not reclaim control', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      expect(input.activeDevice, ActiveInputDevice.gamepad);

      input.handlePointerEvent(
        PointerHoverEvent(position: const Offset(0, 0)),
      );
      input.update();
      input.handlePointerEvent(
        PointerHoverEvent(position: const Offset(0.5, 0)),
      );
      input.update();

      expect(input.activeDevice, ActiveInputDevice.gamepad);
    });

    test('when both devices are active in the same frame, keyboard/mouse wins', () {
      input.controller.setAxis(GamepadAxis.leftStickX, 0.8);
      input.keyboard.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyW,
          logicalKey: LogicalKeyboardKey.keyW,
          timeStamp: Duration.zero,
        ),
      );
      input.update();

      expect(input.activeDevice, ActiveInputDevice.keyboardMouse);
    });

    test('releasing the gamepad with nothing else active leaves the device unchanged', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      expect(input.activeDevice, ActiveInputDevice.gamepad);

      input.controller.setButton(GamepadButton.a, false);
      input.update();

      expect(input.activeDevice, ActiveInputDevice.gamepad);
    });
  });
}
