import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

void main() {
  group('an input asset on disk', () {
    test('reads back exactly what it wrote', () {
      final asset = sampleAsset();
      final text = asset.encode();
      final again = InputActionAsset.parse(text);

      expect(again.encode(), text);
      expect(again.name, 'sample');
      expect(again.nextId, 40);
      expect(again.maps.map((m) => m.name), ['player', 'ui']);
      expect(again.players.maxPlayers, 4);
      expect(again.players.joinActions, ['ui/join']);
      expect(again.schemes.map((s) => s.group), [
        'KeyboardMouse',
        'Gamepad',
        'Touch',
      ]);
      expect(again.schemes.first.devices.last.optional, isTrue);
    });

    test('keeps composites, parts, processors and interactions', () {
      final again = InputActionAsset.parse(sampleAsset().encode());
      final move = again.findAction('player/move')!.action;
      final wasd = move.bindings.first as CompositeBindingDef;

      expect(move.type, ActionValueType.vector2);
      expect(wasd.composite, CompositeKinds.vector2);
      expect(wasd.name, 'WASD');
      expect(wasd.params['mode'], 'digitalNormalized');
      expect(wasd.parts.map((p) => '${p.part}=${p.path}'), [
        'up=<Keyboard>/w',
        'down=<Keyboard>/s',
        'left=<Keyboard>/a',
        'right=<Keyboard>/d',
      ]);
      final stick = move.bindings[1] as ControlBindingDef;
      expect(stick.processors.single.type, 'stickDeadzone');
      expect(stick.processors.single.number('min'), 0.2);

      final join = again.findAction('ui/join')!.action;
      expect(join.rebindable, isFalse);
      expect(join.interactions.single.type, 'hold');
      expect(join.interactions.single.number('duration'), 0.6);
    });

    test('keeps on-screen controls, a floating stick with its region', () {
      final again = InputActionAsset.parse(sampleAsset().encode());
      final stick = again.onScreenControl('moveStick')!;

      expect(stick.kind, OnScreenKind.stick);
      expect(stick.stickMode, StickMode.floating);
      expect(stick.stickAxis, StickAxis.horizontal);
      expect(stick.region, [0, 0.3, 0.5, 1]);
      expect(again.onScreenControl('jump')!.label, 'JUMP');
    });

    test('writes the same bytes every time, ending in a newline', () {
      final a = sampleAsset().encode();
      final b = sampleAsset().encode();
      expect(a, b);
      expect(a.endsWith('}\n'), isTrue);
      final json = jsonDecode(a) as Map<String, dynamic>;
      expect(json.keys.take(2), ['format', 'version']);
      expect(json['format'], 'just_inputs');
      expect(json['version'], 3);
    });

    test('leaves out what is at its default', () {
      final json = jsonDecode(sampleAsset().encode()) as Map<String, dynamic>;
      final jump = ((json['maps'] as List).first['actions'] as List)[1] as Map;

      expect(jump.containsKey('passThrough'), isFalse);
      expect(jump.containsKey('interactions'), isFalse);
      expect(jump.containsKey('rebindable'), isFalse);
    });

    test('refuses the old version-2 file', () {
      const v2 =
          '{"version":2,"mapOrder":["player"],"actionOrder":["jump"],'
          '"actions":{"jump":{"mapId":"player","type":"button"}}}';
      expect(() => InputActionAsset.parse(v2), throwsFormatException);
    });

    test('refuses another version of its own format, saying which', () {
      final json = sampleAsset().toJson()..['version'] = 4;
      expect(
        () => InputActionAsset.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('version 4'),
          ),
        ),
      );
    });

    test('refuses an action without a name, a binding without an id', () {
      final noName = sampleAsset().toJson();
      ((noName['maps'] as List).first['actions'] as List).first.remove('name');
      expect(() => InputActionAsset.fromJson(noName), throwsFormatException);

      final noId = sampleAsset().toJson();
      final bindings =
          ((noId['maps'] as List).first['actions'] as List)[1]['bindings']
              as List;
      (bindings.first as Map).remove('id');
      expect(() => InputActionAsset.fromJson(noId), throwsFormatException);
    });

    test('an empty file of the right format is an empty asset', () {
      final asset = InputActionAsset.parse(
        '{"format":"just_inputs","version":3}',
      );
      expect(asset.maps, isEmpty);
      expect(asset.nextId, 1);
      expect(asset.settings.holdTime, 0.4);
      expect(asset.players.maxPlayers, 1);
      expect(asset.players.joining, JoinBehavior.disabled);
    });
  });

  group('finding things in an asset', () {
    test('an action by map/action, or by a name only one map has', () {
      final asset = sampleAsset();
      expect(asset.findAction('player/jump')!.action.id, 'a10');
      expect(asset.findAction('jump')!.path, 'player/jump');
      expect(asset.findAction('ui/jump'), isNull);
      expect(asset.findAction('nothing'), isNull);
    });

    test('a bare name two maps share is ambiguous, so not found', () {
      final asset = sampleAsset();
      final ui = asset.maps[1];
      final twice = asset.copyWith(
        maps: [
          asset.maps[0],
          ui.copyWith(
            actions: [
              ...ui.actions,
              const InputActionDef(id: 'a30', name: 'jump'),
            ],
          ),
        ],
      );
      expect(twice.findAction('jump'), isNull);
      expect(twice.findAction('ui/jump')!.action.id, 'a30');
    });

    test('a binding or a composite part by id', () {
      final asset = sampleAsset();
      final part = asset.findBinding('b6')!;
      expect(part.action.name, 'move');
      expect(part.part!.part, 'left');
      expect(part.path, '<Keyboard>/a');
      expect(part.binding.id, 'b3');

      final single = asset.findBinding('b12')!;
      expect(single.part, isNull);
      expect(single.path, '<Gamepad>/buttonSouth');
      expect(asset.findBinding('b3')!.path, '');
      expect(asset.findBinding('zzz'), isNull);
    });

    test('ids come from the counter and are never handed out twice', () {
      final asset = sampleAsset();
      final (id, next) = asset.takeId('b');
      final (id2, _) = next.takeId('a');
      expect(id, 'b40');
      expect(id2, 'a41');
      expect(asset.nextId, 40, reason: 'the original is untouched');
    });

    test('a label is the display name, or the name tidied', () {
      expect(prettifyName('moveLeft'), 'Move Left');
      expect(prettifyName('jump_high'), 'Jump High');
      expect(prettifyName('ui2D'), 'Ui2 D');
      expect(
        const InputActionDef(id: 'a', name: 'jump', displayName: 'Hop').label,
        'Hop',
      );
    });
  });
}
