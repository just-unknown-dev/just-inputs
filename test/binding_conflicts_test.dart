import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('findBindingConflicts', () {
    test('flags two button actions sharing a key in the same map', () {
      final set = InputActionSet({
        'reload': const InputAction(
          mapId: 'player',
          button: InputBinding(keys: [LogicalKeyboardKey.keyR]),
        ),
        'skillSpit': const InputAction(
          mapId: 'player',
          button: InputBinding(keys: [LogicalKeyboardKey.keyR]),
        ),
      });

      final conflicts = findBindingConflicts(set);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.source, ConflictSource.key);
      expect(conflicts.single.key, LogicalKeyboardKey.keyR);
      expect(
        conflicts.single.actionIds.toSet(),
        {'reload', 'skillSpit'},
      );
    });

    test('does not flag the same key bound in different maps', () {
      final set = InputActionSet({
        'pause': const InputAction(
          mapId: 'ui',
          button: InputBinding(keys: [LogicalKeyboardKey.escape]),
        ),
        'cancel': const InputAction(
          mapId: 'menu',
          button: InputBinding(keys: [LogicalKeyboardKey.escape]),
        ),
      });

      expect(findBindingConflicts(set), isEmpty);
    });

    test('flags shared mouse buttons', () {
      final set = InputActionSet({
        'fire': const InputAction(
          mapId: 'player',
          button: InputBinding(mouseButton: 0),
        ),
        'crouch': const InputAction(
          mapId: 'player',
          button: InputBinding(mouseButton: 0),
        ),
      });

      final conflicts = findBindingConflicts(set);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.source, ConflictSource.mouseButton);
      expect(conflicts.single.mouseButton, 0);
    });

    test('flags shared gamepad buttons', () {
      final set = InputActionSet({
        'fire': const InputAction(
          mapId: 'player',
          button: InputBinding(gamepadButton: GamepadButton.rightTriggerButton),
        ),
        'meleeAttack': const InputAction(
          mapId: 'player',
          button: InputBinding(gamepadButton: GamepadButton.rightTriggerButton),
        ),
      });

      final conflicts = findBindingConflicts(set);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.source, ConflictSource.gamepadButton);
      expect(conflicts.single.gamepadButton, GamepadButton.rightTriggerButton);
    });

    test('a vector2 action\'s directional keys colliding with a button action is flagged', () {
      final set = InputActionSet({
        'move': const InputAction(
          mapId: 'player',
          type: ActionType.vector2,
          vector2: Vector2Binding(up: [LogicalKeyboardKey.keyW]),
        ),
        'weaponWheel': const InputAction(
          mapId: 'player',
          button: InputBinding(keys: [LogicalKeyboardKey.keyW]),
        ),
      });

      final conflicts = findBindingConflicts(set);

      expect(conflicts, hasLength(1));
      expect(conflicts.single.actionIds.toSet(), {'move', 'weaponWheel'});
    });

    test('no conflicts across entirely distinct bindings', () {
      final set = InputActionSet({
        'fire': const InputAction(
          mapId: 'player',
          button: InputBinding(mouseButton: 0),
        ),
        'reload': const InputAction(
          mapId: 'player',
          button: InputBinding(keys: [LogicalKeyboardKey.keyR]),
        ),
      });

      expect(findBindingConflicts(set), isEmpty);
    });
  });

  group('findMissingActionIds', () {
    test('flags an expected id with no entry in the action set', () {
      final set = InputActionSet({
        'fire': const InputAction(mapId: 'player'),
      });

      expect(
        findMissingActionIds(set, ['fire', 'reload']),
        ['reload'],
      );
    });

    test('empty when every expected id is present', () {
      final set = InputActionSet({
        'fire': const InputAction(mapId: 'player'),
        'reload': const InputAction(mapId: 'player'),
      });

      expect(findMissingActionIds(set, ['fire', 'reload']), isEmpty);
    });

    test('collapses duplicate expected ids', () {
      final set = InputActionSet({});

      expect(findMissingActionIds(set, ['fire', 'fire']), ['fire']);
    });
  });
}
