import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('gamepadButtonLabel face buttons', () {
    test('Xbox and generic/unknown share circled-letter glyphs', () {
      for (final type in [gp.GamepadType.xbox, gp.GamepadType.generic, gp.GamepadType.unknown]) {
        expect(gamepadButtonLabel(type, GamepadButton.a), 'Ⓐ');
        expect(gamepadButtonLabel(type, GamepadButton.b), 'Ⓑ');
        expect(gamepadButtonLabel(type, GamepadButton.x), 'Ⓧ');
        expect(gamepadButtonLabel(type, GamepadButton.y), 'Ⓨ');
      }
    });

    test('PlayStation uses shape glyphs', () {
      expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.a), '✕');
      expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.b), '○');
      expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.x), '□');
      expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.y), '△');
    });

    test('Switch Pro is physically mirrored vs. Xbox: A/B and X/Y swapped', () {
      final xbox = gp.GamepadType.xbox;
      final switchPro = gp.GamepadType.nintendoSwitchPro;

      expect(
        gamepadButtonLabel(switchPro, GamepadButton.a),
        gamepadButtonLabel(xbox, GamepadButton.b),
      );
      expect(
        gamepadButtonLabel(switchPro, GamepadButton.b),
        gamepadButtonLabel(xbox, GamepadButton.a),
      );
      expect(
        gamepadButtonLabel(switchPro, GamepadButton.x),
        gamepadButtonLabel(xbox, GamepadButton.y),
      );
      expect(
        gamepadButtonLabel(switchPro, GamepadButton.y),
        gamepadButtonLabel(xbox, GamepadButton.x),
      );
    });
  });

  test('back/start relabel to Share/Options on PlayStation only', () {
    expect(gamepadButtonLabel(gp.GamepadType.xbox, GamepadButton.back), 'Back');
    expect(gamepadButtonLabel(gp.GamepadType.xbox, GamepadButton.start), 'Start');
    expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.back), 'Share');
    expect(gamepadButtonLabel(gp.GamepadType.playStation, GamepadButton.start), 'Options');
  });

  test('brand-agnostic buttons render identically regardless of type', () {
    for (final type in gp.GamepadType.values) {
      expect(gamepadButtonLabel(type, GamepadButton.leftBumper), 'LB');
      expect(gamepadButtonLabel(type, GamepadButton.dpadUp), 'D-Up');
    }
  });

  test('gamepadStickLabel', () {
    expect(gamepadStickLabel(GamepadStick.left), 'Left Stick');
    expect(gamepadStickLabel(GamepadStick.right), 'Right Stick');
  });
}
