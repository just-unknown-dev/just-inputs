import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

void main() {
  group('binding conflicts', () {
    test('the sample has none', () {
      expect(findBindingConflicts(sampleAsset()), isEmpty);
    });

    test('two actions on one key clash', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(
              id: 'b30',
              path: '<Keyboard>/w',
              groups: ['KeyboardMouse'],
            ),
          ],
        ),
      );
      final conflict = findBindingConflicts(asset).single;
      expect(conflict.mapId, 'm1');
      expect(conflict.bindingIds, containsAll(['b4', 'b30']));
      expect(conflict.actionIds, containsAll(['a2', 'a10']));
    });

    test('the whole stick clashes with one of its directions', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(
              id: 'b30',
              path: '<Gamepad>/leftStick/up',
              groups: ['Gamepad'],
            ),
          ],
        ),
      );
      expect(
        findBindingConflicts(asset).single.bindingIds,
        containsAll(['b8', 'b30']),
      );
    });

    test('a keyboard binding never clashes with a gamepad one', () {
      // Same map, and "W" would be taken — but the jump binding is only in
      // the Gamepad scheme, where W is not pressed.
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(
              id: 'b30',
              path: '<Keyboard>/w',
              groups: ['Gamepad'],
            ),
          ],
        ),
      );
      expect(findBindingConflicts(asset), isEmpty);
    });

    test('a binding in every scheme clashes with any', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [const ControlBindingDef(id: 'b30', path: '<Keyboard>/w')],
        ),
      );
      expect(findBindingConflicts(asset), hasLength(1));
    });

    test('asked about one scheme, only that scheme counts', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [const ControlBindingDef(id: 'b30', path: '<Keyboard>/w')],
        ),
      );
      expect(findBindingConflicts(asset, group: 'KeyboardMouse'), hasLength(1));
      expect(findBindingConflicts(asset, group: 'Gamepad'), isEmpty);
    });

    test('the same key in two maps is not a clash', () {
      // Space jumps in "player" and submits in "ui"; only one map is on
      // at a time where it matters, so the two never meet.
      final asset = sampleAsset();
      final ui = asset.maps[1];
      final spaced = asset.copyWith(
        maps: [
          asset.maps.first,
          ui.copyWith(
            actions: [
              ...ui.actions,
              const InputActionDef(
                id: 'a30',
                name: 'submit',
                bindings: [
                  ControlBindingDef(id: 'b31', path: '<Keyboard>/space'),
                ],
              ),
            ],
          ),
        ],
      );
      expect(findBindingConflicts(spaced), isEmpty);
    });

    test(
      'pause and join may share Start: they listen to different devices',
      () {
        final asset = sampleAsset();
        expect(
          asset.findAction('ui/join')!.action.bindings.first.paths.single,
          asset.findAction('ui/pause')!.action.bindings[1].paths.single,
        );
        expect(findBindingConflicts(asset), isEmpty);

        // With joining off, join is an ordinary action, and Start is taken.
        final alone = asset.copyWith(
          players: asset.players.copyWith(joining: JoinBehavior.disabled),
        );
        expect(
          findBindingConflicts(alone).single.first.path,
          '<Gamepad>/start',
        );
      },
    );

    test(
      'Shift + E is its own chord: not a clash with E, a clash with itself',
      () {
        CompositeBindingDef chord(String id, int part) => CompositeBindingDef(
          id: id,
          composite: CompositeKinds.oneModifier,
          parts: [
            CompositePartDef(
              id: 'b${part + 1}',
              part: 'modifier',
              path: '<Keyboard>/shift',
            ),
            CompositePartDef(
              id: 'b${part + 2}',
              part: 'binding',
              path: '<Keyboard>/e',
            ),
          ],
        );
        final asset = sampleAsset();
        final player = asset.maps.first;
        InputActionAsset add(List<InputActionDef> extra) => asset.copyWith(
          maps: [
            player.copyWith(actions: [...player.actions, ...extra]),
            asset.maps[1],
          ],
        );

        final shiftAndPlain = add([
          InputActionDef(id: 'a20', name: 'dash', bindings: [chord('b21', 21)]),
          const InputActionDef(
            id: 'a25',
            name: 'use',
            bindings: [ControlBindingDef(id: 'b26', path: '<Keyboard>/e')],
          ),
        ]);
        expect(findBindingConflicts(shiftAndPlain), isEmpty);

        final twice = add([
          InputActionDef(id: 'a20', name: 'dash', bindings: [chord('b21', 21)]),
          InputActionDef(id: 'a25', name: 'use', bindings: [chord('b26', 26)]),
        ]);
        final conflict = findBindingConflicts(twice).single;
        expect(conflict.first.path, '<Keyboard>/shift + <Keyboard>/e');
      },
    );

    test('an action does not clash with itself', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            ...a.bindings,
            const ControlBindingDef(id: 'b30', path: '<Keyboard>/space'),
          ],
        ),
      );
      expect(findBindingConflicts(asset), isEmpty);
    });
  });
}
