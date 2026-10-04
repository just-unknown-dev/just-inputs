import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

Iterable<String> codes(InputActionAsset asset) =>
    validateAsset(asset).map((i) => i.code);

void main() {
  group('validating an asset', () {
    test('the sample is clean', () {
      expect(validateAsset(sampleAsset()), isEmpty);
    });

    test('a path that is not one, or names nothing, is an error', () {
      final bad = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(id: 'b30', path: 'space'),
            const ControlBindingDef(id: 'b31', path: '<Gamepad>/buttonMiddle'),
            const ControlBindingDef(id: 'b32', path: '<OnScreen>/dash'),
          ],
        ),
      );
      final issues = validateAsset(bad);
      expect(
        issues.map((i) => i.code),
        containsAll(['badPath', 'unknownControl']),
      );
      expect(issues.where((i) => i.code == 'unknownControl'), hasLength(2));
      expect(issues.firstWhere((i) => i.code == 'badPath').bindingId, 'b30');
      expect(issues.every((i) => i.isError), isTrue);
    });

    test('an empty slot is only a warning', () {
      final unbound = withJump(
        sampleAsset(),
        (a) => a.copyWith(bindings: [const ControlBindingDef(id: 'b30')]),
      );
      final issue = validateAsset(unbound).single;
      expect(issue.code, 'unbound');
      expect(issue.severity, IssueSeverity.warning);
    });

    test('names: unique in their place, and nothing code cannot type', () {
      final asset = sampleAsset();
      final twoMaps = asset.copyWith(
        maps: [
          ...asset.maps,
          const ActionMapDef(id: 'm30', name: 'ui'),
          const ActionMapDef(id: 'm31', name: 'my map'),
        ],
      );
      expect(codes(twoMaps), containsAll(['duplicateMap', 'badName']));

      final twoJumps = withJump(asset, (a) => a.copyWith(name: 'move'));
      expect(codes(twoJumps), contains('duplicateAction'));

      final slash = withJump(asset, (a) => a.copyWith(name: 'jump/high'));
      expect(codes(slash), contains('badName'));
    });

    test('an id used twice, or ahead of the counter, is an error', () {
      final asset = sampleAsset();
      final twice = withJump(
        asset,
        (a) => a.copyWith(
          bindings: [
            ...a.bindings,
            const ControlBindingDef(id: 'b11', path: '<Keyboard>/z'),
          ],
        ),
      );
      expect(codes(twice), contains('duplicateId'));

      final ahead = withJump(
        asset,
        (a) => a.copyWith(
          bindings: [
            ...a.bindings,
            const ControlBindingDef(id: 'b99', path: '<Keyboard>/z'),
          ],
        ),
      );
      expect(codes(ahead), contains('idAhead'));
    });

    test('a composite: its parts must exist, and all should be there', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          type: ActionValueType.axis,
          bindings: [
            const CompositeBindingDef(
              id: 'b30',
              composite: CompositeKinds.axis1D,
              parts: [
                CompositePartDef(
                  id: 'b31',
                  part: 'negative',
                  path: '<Keyboard>/q',
                ),
                CompositePartDef(
                  id: 'b32',
                  part: 'sideways',
                  path: '<Keyboard>/e',
                ),
              ],
            ),
          ],
        ),
      );
      final issues = validateAsset(asset);
      expect(
        issues.firstWhere((i) => i.code == 'unknownPart').bindingId,
        'b32',
      );
      expect(
        issues.firstWhere((i) => i.code == 'missingPart').message,
        contains('positive'),
      );
    });

    test('a game composite the editor does not know is only a warning', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [const CompositeBindingDef(id: 'b30', composite: 'Swipe')],
        ),
      );
      final issue = validateAsset(asset).single;
      expect(issue.code, 'unknownComposite');
      expect(issue.isError, isFalse);
    });

    test('a single button cannot point a vector action', () {
      final asset = sampleAsset();
      final move = asset.maps.first.actions.first;
      final wrong = asset.copyWith(
        maps: [
          asset.maps.first.copyWith(
            actions: [
              move.copyWith(
                bindings: [
                  ...move.bindings,
                  const ControlBindingDef(id: 'b30', path: '<Keyboard>/space'),
                ],
              ),
              ...asset.maps.first.actions.skip(1),
            ],
          ),
          asset.maps[1],
        ],
      );
      final issue = validateAsset(wrong).single;
      expect(issue.code, 'typeMismatch');
      expect(issue.bindingId, 'b30');
    });

    test('a stick drives a button action — by how far it is pushed', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            ...a.bindings,
            const ControlBindingDef(id: 'b30', path: '<Gamepad>/rightStick'),
          ],
        ),
      );
      expect(validateAsset(asset), isEmpty);
    });

    test('a group no scheme has is a warning', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(
              id: 'b30',
              path: '<Keyboard>/z',
              groups: ['Arcade'],
            ),
          ],
        ),
      );
      expect(codes(asset).single, 'unknownGroup');
    });

    test('schemes: unique, and on devices that exist', () {
      final asset = sampleAsset();
      final bad = asset.copyWith(
        schemes: [
          ...asset.schemes,
          const ControlSchemeDef(name: 'Gamepad', group: 'Pad2'),
          const ControlSchemeDef(
            name: 'Wheel',
            group: 'Gamepad',
            devices: [DeviceRequirement('Wheel')],
          ),
        ],
      );
      expect(
        codes(bad),
        containsAll(['duplicateScheme', 'duplicateGroup', 'unknownLayout']),
      );
    });

    test('on-screen controls need usable, unique ids', () {
      final asset = sampleAsset();
      final bad = asset.copyWith(
        onScreen: [
          ...asset.onScreen,
          const OnScreenControlDef(id: 'jump'),
          const OnScreenControlDef(id: 'big button'),
        ],
      );
      expect(codes(bad), containsAll(['duplicateOnScreen', 'badOnScreenId']));
    });

    test('players: a join action must exist', () {
      final asset = sampleAsset();
      final bad = asset.copyWith(
        players: asset.players.copyWith(joinActions: ['ui/join', 'ui/start']),
      );
      expect(codes(bad).single, 'unknownJoinAction');

      final none = asset.copyWith(
        players: asset.players.copyWith(joinActions: []),
      );
      expect(codes(none).single, 'noJoinActions');

      final nobody = asset.copyWith(
        players: asset.players.copyWith(maxPlayers: 0),
      );
      expect(codes(nobody), contains('maxPlayers'));
    });
  });
}
