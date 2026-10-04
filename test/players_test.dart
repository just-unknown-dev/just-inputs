import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/testing.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

typedef K = PhysicalKeyboardKey;

/// A service on the sample asset with players started and fake pads.
(InputService, InputTester, FakeGamepadSource) players([
  InputActionAsset? asset,
]) {
  final service = InputService()..loadAsset(asset ?? sampleAsset());
  final pads = FakeGamepadSource();
  service.attachGamepads(pads);
  service.players.start();
  addTearDown(() {
    service.dispose();
    pads.dispose();
  });
  return (service, InputTester(service), pads);
}

/// Holds Start on pad [id] long enough to join (the sample's hold is 0.6).
void holdStart(InputTester t, FakeGamepadSource pads, String id) {
  pads.press(id, gp.GamepadButton.start);
  t.step(0.05);
  t.step(0.6);
  pads.release(id);
  t.step();
}

void main() {
  group('joining', () {
    test('player 1 is whoever plays first, with what they touched', () {
      final (service, t, _) = players();
      final joined = <int>[];
      service.players.joined.listen((p) => joined.add(p.index));

      t.keyDown(K.keyD);
      final p1 = service.players[0]!;
      expect(joined, [0]);
      expect(p1.scheme!.group, 'KeyboardMouse');
      expect(p1.devices, containsAll([service.keyboard, service.mouse]));

      t.step();
      expect(
        p1.action('move').readVector2(),
        const Offset(1, 0),
        reason: 'the first press counts',
      );
    });

    test('holding Start on a free pad joins player 2', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      expect(service.players.players, hasLength(1));

      holdStart(t, pads, 'p1');
      final p2 = service.players[1]!;
      expect(p2.devices.single, service.gamepads.single);
      expect(p2.scheme!.group, 'Gamepad');
      expect(
        service.players[0]!.devices,
        contains(service.keyboard),
        reason: 'player 1 keeps the keyboard',
      );
    });

    test('the Start held to join does not also pause for the new player', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      pads.press('p1', gp.GamepadButton.start);
      t.step(0.05);
      t.step(0.6);
      final p2 = service.players[1]!;
      final paused = <String>[];
      p2.action('ui/pause').onPerformed((_) => paused.add('pause'));
      pads.release('p1');
      t.step();
      t.step();
      expect(paused, isEmpty);
      expect(p2.action('ui/pause').isPressed(), isFalse);
    });

    test('a quick press on a free pad, alone, moves player 1 onto it', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      final p1 = service.players[0]!;
      final switched = <String>[];
      service.players.schemeChanged.listen(
        (p) => switched.add(p.scheme!.group),
      );

      pads.press('p1', gp.GamepadButton.x);
      t.step();
      pads.release('p1');
      t.step();

      expect(service.players.players, hasLength(1));
      expect(p1.devices.single, service.gamepads.single);
      expect(switched, ['Gamepad']);
    });

    test(
      'a quick press of the join button, alone, switches rather than joins',
      () {
        final (service, t, pads) = players();
        pads.connect('p1');
        t.tap(K.space);

        pads.press('p1', gp.GamepadButton.start);
        t.step(0.05);
        t.step(0.1);
        expect(
          service.players[0]!.devices,
          contains(service.keyboard),
          reason: 'it might still be a join',
        );
        pads.release('p1');
        t.step();
        expect(service.players.players, hasLength(1));
        expect(service.players[0]!.devices.single, service.gamepads.single);
      },
    );

    test('with two playing, a free pad pressed quickly does nothing', () {
      final (service, t, pads) = players();
      pads
        ..connect('p1')
        ..connect('p2');
      t.tap(K.space);
      holdStart(t, pads, 'p1');
      pads.press('p2', gp.GamepadButton.x);
      t.step();
      pads.release('p2');
      t.step();
      expect(service.players.players, hasLength(2));
      expect(service.players.ownerOf(service.gamepads[1]), isNull);
    });

    test('the keyboard cannot join twice: no split keyboard', () {
      final (service, t, _) = players();
      t.tap(K.space);
      t.keyDown(K.enter); // Enter is a join key in the sample
      t.step(0.05);
      t.step(0.7);
      t.keyUp(K.enter);
      t.step();
      expect(service.players.players, hasLength(1));
    });

    test('players take the lowest free number; never more than the most', () {
      final (service, t, pads) = players(
        sampleAsset().copyWith(
          players: sampleAsset().players.copyWith(maxPlayers: 2),
        ),
      );
      pads
        ..connect('a')
        ..connect('b');
      t.tap(K.space);
      holdStart(t, pads, 'a');
      holdStart(t, pads, 'b');
      expect(service.players.players.map((p) => p.index), [
        0,
        1,
      ], reason: 'the most is 2');

      service.players.leave(service.players[0]!);
      holdStart(t, pads, 'b');
      expect(service.players[0]!.devices.single, service.gamepads[1]);
    });

    test('joining can be switched off by the game', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      service.players.joiningEnabled = false;
      holdStart(t, pads, 'p1');
      expect(service.players.players, hasLength(1));
    });

    test('each player reads only their own devices', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      holdStart(t, pads, 'p1');
      final p1 = service.players[0]!, p2 = service.players[1]!;

      pads.press('p1', gp.GamepadButton.a);
      t.step();
      expect(p2.action('jump').isPressed(), isTrue);
      expect(p1.action('jump').isPressed(), isFalse);

      t.keyDown(K.space);
      t.step();
      expect(p1.action('jump').isPressed(), isTrue);
    });

    test(
      'actionsFor: a player\'s, or the shared ones for 1 before anyone plays',
      () {
        final (service, t, _) = players();
        expect(service.actionsFor(0), same(service.actions));
        expect(service.actionsFor(1), isNull);
        t.tap(K.space);
        expect(service.actionsFor(0), same(service.players[0]!.actions));
      },
    );
  });

  group('losing a device', () {
    test(
      'a pulled pad makes its player lost; the same pad back finds them',
      () {
        final (service, t, pads) = players();
        pads.connect('p1', name: 'Xbox Pad', vendorId: 1, productId: 2);
        t.tap(K.space);
        holdStart(t, pads, 'p1');
        final p2 = service.players[1]!;
        final events = <String>[];
        service.players
          ..deviceLost.listen((p) => events.add('lost ${p.label}'))
          ..deviceRegained.listen((p) => events.add('back ${p.label}'));

        pads.disconnect('p1');
        expect(p2.isLost, isTrue);
        expect(p2.lostLayout, 'Gamepad');
        expect(p2.devices, isEmpty);

        pads.connect('p1-again', name: 'Xbox Pad', vendorId: 1, productId: 2);
        expect(p2.isLost, isFalse);
        expect(p2.devices.single.displayName, 'Xbox Pad');
        expect(events, ['lost P2', 'back P2']);
      },
    );

    test('another pad pressing a button stands in', () {
      final (service, t, pads) = players();
      pads.connect('p1', name: 'A');
      t.tap(K.space);
      holdStart(t, pads, 'p1');
      final p2 = service.players[1]!;
      pads.disconnect('p1');
      pads.connect('other', name: 'B');
      expect(
        p2.isLost,
        isTrue,
        reason: 'a different pad is not taken on its own',
      );
      pads.press('other', gp.GamepadButton.b);
      expect(p2.isLost, isFalse);
      expect(p2.devices.single.displayName, 'B');
    });

    test('a lost player can be dropped', () {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.space);
      holdStart(t, pads, 'p1');
      pads.disconnect('p1');
      final left = <String>[];
      service.players.left.listen((p) => left.add(p.label));
      service.players.dropLost(service.players[1]!);
      expect(left, ['P2']);
      expect(service.players.players, hasLength(1));
    });
  });

  group('overrides', () {
    test('saved per player slot, and a player who joins gets theirs', () async {
      final (service, t, pads) = players();
      final store = service.overrideStore as MemoryInputOverrideStore;
      store.data[service.players.overridesKey(0)] = const BindingOverrides({
        'b11': '<Keyboard>/k',
      }).toJson();
      await service.players.preloadOverrides();

      t.tap(K.keyW);
      final p1 = service.players[0]!;
      t.keyDown(K.keyK);
      t.step();
      expect(p1.action('jump').isPressed(), isTrue);
      t.keyUp(K.keyK);
      t.keyDown(K.space);
      t.step();
      expect(
        p1.action('jump').isPressed(),
        isFalse,
        reason: 'Space is not theirs any more',
      );

      p1.overrides = p1.overrides.withPath('b16', '<Keyboard>/p');
      await p1.saveOverrides();
      expect(
        BindingOverrides.fromJson(
          store.data[service.players.overridesKey(0)],
        ).paths,
        {'b11': '<Keyboard>/k', 'b16': '<Keyboard>/p'},
      );

      await p1.resetOverrides();
      expect(store.data.containsKey(service.players.overridesKey(0)), isFalse);
      expect(p1.overrides.isEmpty, isTrue);
    });

    test('an override for a binding the asset lost is dropped', () {
      const o = BindingOverrides({
        'b11': '<Keyboard>/k',
        'gone': '<Keyboard>/x',
      });
      expect(o.keptBy(sampleAsset()).paths.keys, ['b11']);
      expect(
        applyOverrides(sampleAsset(), o).findBinding('b11')!.path,
        '<Keyboard>/k',
      );
    });

    test('a key made from an asset name is one the engine cache accepts', () {
      final (service, _, _) = players(sampleAsset().copyWith(name: 'my game!'));
      expect(service.players.overridesKey(1), 'input.overrides.my_game_.p2');
    });
  });
}
