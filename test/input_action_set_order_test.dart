import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('allMapIds', () {
    test('includes explicitly-declared empty maps, in mapOrder order', () {
      final set = InputActionSet({}, ['ui', 'player']);
      expect(set.allMapIds, ['ui', 'player']);
    });

    test('includes map ids implied by actions even if not declared', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
      });
      expect(set.allMapIds, ['player']);
    });

    test('appends action-implied map ids after explicitly-ordered ones', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
      }, ['ui']);
      expect(set.allMapIds, ['ui', 'player']);
    });

    test('does not duplicate a map id declared in mapOrder and implied by an action', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
      }, ['player', 'ui']);
      expect(set.allMapIds, ['player', 'ui']);
    });
  });

  group('allActionKeys', () {
    test('reflects actionOrder for known keys', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
        'dash': const InputAction(mapId: 'player'),
      }, null, ['dash', 'move']);
      expect(set.allActionKeys, ['dash', 'move']);
    });

    test('appends defs keys missing from actionOrder at the end', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
        'dash': const InputAction(mapId: 'player'),
      }, null, ['dash']);
      expect(set.allActionKeys, ['dash', 'move']);
    });

    test('silently drops actionOrder entries no longer present in defs', () {
      final set = InputActionSet({
        'move': const InputAction(mapId: 'player'),
      }, null, ['dash', 'move']);
      expect(set.allActionKeys, ['move']);
    });
  });

  group('mergeFrom', () {
    test('unions mapOrder rather than replacing it', () {
      final base = InputActionSet({}, ['player']);
      final incoming = InputActionSet({}, ['ui']);
      base.mergeFrom(incoming);
      expect(base.mapOrder, ['player', 'ui']);
    });

    test('unions actionOrder rather than replacing it', () {
      final base = InputActionSet({}, null, ['move']);
      final incoming = InputActionSet({}, null, ['dash']);
      base.mergeFrom(incoming);
      expect(base.actionOrder, ['move', 'dash']);
    });

    test('does not duplicate an id already present in both', () {
      final base = InputActionSet({}, ['player']);
      final incoming = InputActionSet({}, ['player', 'ui']);
      base.mergeFrom(incoming);
      expect(base.mapOrder, ['player', 'ui']);
    });
  });

  group('toJson/fromJson round-trip', () {
    test('round-trips mapOrder and actionOrder', () {
      final set = InputActionSet({}, ['ui', 'player'], ['dash', 'move']);
      final restored = InputActionSet.fromJson(set.toJson());
      expect(restored.mapOrder, ['ui', 'player']);
      expect(restored.actionOrder, ['dash', 'move']);
    });

    test('defaults both to empty when absent (old save files)', () {
      final restored = InputActionSet.fromJson(const {
        'version': 2,
        'actions': <String, dynamic>{},
      });
      expect(restored.mapOrder, isEmpty);
      expect(restored.actionOrder, isEmpty);
    });

    test('falls back to the legacy "mapIds" key for mapOrder', () {
      final restored = InputActionSet.fromJson(const {
        'version': 2,
        'mapIds': ['ui', 'player'],
        'actions': <String, dynamic>{},
      });
      expect(restored.mapOrder, ['ui', 'player']);
      expect(restored.allMapIds, ['ui', 'player']);
    });

    test('prefers "mapOrder" over the legacy "mapIds" key when both are present', () {
      final restored = InputActionSet.fromJson(const {
        'version': 2,
        'mapIds': ['stale'],
        'mapOrder': ['ui', 'player'],
        'actions': <String, dynamic>{},
      });
      expect(restored.mapOrder, ['ui', 'player']);
    });
  });
}
