import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('InputActionResolver gamepad button resolution', () {
    late InputManager input;
    late InputActionResolver actions;

    setUp(() {
      input = InputManager()..initialize();
      actions = InputActionResolver(
        input,
        actionSet: InputActionSet({
          'fire': const InputAction(
            mapId: 'player',
            button: InputBinding(gamepadButton: GamepadButton.a),
          ),
        }),
      )..setActiveMaps({'player'});
    });

    test('isActionDown reflects a held gamepad button', () {
      expect(actions.isActionDown('fire'), isFalse);

      input.controller.setButton(GamepadButton.a, true);
      input.update();
      actions.update();

      expect(actions.isActionDown('fire'), isTrue);
    });

    test('isActionPressed/Released fire on the correct frame edges', () {
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      actions.update();
      expect(actions.isActionPressed('fire'), isTrue);
      expect(actions.isActionReleased('fire'), isFalse);

      // Held on a second frame: no longer a fresh press.
      input.update();
      actions.update();
      expect(actions.isActionPressed('fire'), isFalse);

      input.controller.setButton(GamepadButton.a, false);
      input.update();
      actions.update();
      expect(actions.isActionReleased('fire'), isTrue);
    });

    test('an inactive map never resolves the gamepad binding', () {
      actions.setActiveMaps({});
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      actions.update();

      expect(actions.isActionDown('fire'), isFalse);
    });
  });

  group('InputActionResolver gamepad stick fallback for Vector2 actions', () {
    late InputManager input;
    late InputActionResolver actions;

    setUp(() {
      input = InputManager()..initialize();
      actions = InputActionResolver(
        input,
        actionSet: InputActionSet({
          'move': const InputAction(
            mapId: 'player',
            type: ActionType.vector2,
            vector2: Vector2Binding(
              up: [LogicalKeyboardKey.keyW],
              down: [LogicalKeyboardKey.keyS],
              left: [LogicalKeyboardKey.keyA],
              right: [LogicalKeyboardKey.keyD],
              gamepadStick: GamepadStick.left,
            ),
          ),
        }),
      )..setActiveMaps({'player'});
    });

    test('falls back to the left stick when no key is held', () {
      input.controller.setAxis(GamepadAxis.leftStickX, 0.8);
      input.controller.setAxis(GamepadAxis.leftStickY, -0.6);
      input.update();
      actions.update();

      final move = actions.getVector2('move');
      expect(move.dx, closeTo(0.8, 1e-9));
      expect(move.dy, closeTo(-0.6, 1e-9));
    });

    test('keys take priority over the stick when both are active', () {
      input.controller.setAxis(GamepadAxis.leftStickX, 1.0);
      input.controller.setAxis(GamepadAxis.leftStickY, 1.0);
      input.keyboard.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyD,
          logicalKey: LogicalKeyboardKey.keyD,
          timeStamp: Duration.zero,
        ),
      );
      input.update();
      actions.update();

      final move = actions.getVector2('move');
      expect(move.dx, 1.0);
      expect(move.dy, 0.0);
    });

    test('dead zone on the stick still applies (via ControllerInput)', () {
      // Establish the gamepad as the active device first (a sub-threshold
      // reading alone wouldn't do that, since ControllerInput.setAxis zeroes
      // it before InputManager ever sees it as activity).
      input.controller.setButton(GamepadButton.a, true);
      input.update();
      input.controller.setButton(GamepadButton.a, false);

      input.controller.setAxis(GamepadAxis.leftStickX, 0.05);
      input.controller.setAxis(GamepadAxis.leftStickY, 0.05);
      input.update();
      actions.update();

      expect(actions.getVector2('move'), Offset.zero);
    });

    test('no fallback when gamepadStick is unset', () {
      actions.applyActions(
        InputActionSet({
          'move': const InputAction(
            mapId: 'player',
            type: ActionType.vector2,
            vector2: Vector2Binding(),
          ),
        }),
      );
      input.controller.setAxis(GamepadAxis.leftStickX, 1.0);
      input.update();
      actions.update();

      expect(actions.getVector2('move'), Offset.zero);
    });
  });
}
