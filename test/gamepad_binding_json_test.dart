import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('InputBinding gamepad JSON round-trip', () {
    test('serializes and restores a bound gamepad button', () {
      const binding = InputBinding(gamepadButton: GamepadButton.a);
      final json = binding.toJson();
      expect(json['gamepadButton'], GamepadButton.a);

      final restored = InputBinding.fromJson(json);
      expect(restored.gamepadButton, GamepadButton.a);
    });

    test('defaults gamepadButton to null when absent from JSON', () {
      final restored = InputBinding.fromJson(const {
        'keys': <int>[],
        'touch': 'none',
      });
      expect(restored.gamepadButton, isNull);
    });

    test('an unset gamepadButton round-trips as null', () {
      const binding = InputBinding();
      final restored = InputBinding.fromJson(binding.toJson());
      expect(restored.gamepadButton, isNull);
    });
  });

  group('Vector2Binding gamepad JSON round-trip', () {
    test('serializes and restores a bound stick', () {
      const binding = Vector2Binding(gamepadStick: GamepadStick.right);
      final json = binding.toJson();
      expect(json['gamepadStick'], 'right');

      final restored = Vector2Binding.fromJson(json);
      expect(restored.gamepadStick, GamepadStick.right);
    });

    test('defaults gamepadStick to null when absent from JSON', () {
      final restored = Vector2Binding.fromJson(const {
        'up': <int>[],
        'down': <int>[],
        'left': <int>[],
        'right': <int>[],
      });
      expect(restored.gamepadStick, isNull);
    });

    test('an unset gamepadStick round-trips as null', () {
      const binding = Vector2Binding();
      final restored = Vector2Binding.fromJson(binding.toJson());
      expect(restored.gamepadStick, isNull);
    });
  });

  group('Vector2Binding useMouseAim JSON round-trip', () {
    test('serializes and restores true', () {
      const binding = Vector2Binding(useMouseAim: true);
      final json = binding.toJson();
      expect(json['useMouseAim'], isTrue);

      final restored = Vector2Binding.fromJson(json);
      expect(restored.useMouseAim, isTrue);
    });

    test('defaults to false when absent from JSON (old save files)', () {
      final restored = Vector2Binding.fromJson(const {
        'up': <int>[],
        'down': <int>[],
        'left': <int>[],
        'right': <int>[],
      });
      expect(restored.useMouseAim, isFalse);
    });

    test('defaults to false in the const constructor', () {
      const binding = Vector2Binding();
      expect(binding.useMouseAim, isFalse);
    });
  });
}
