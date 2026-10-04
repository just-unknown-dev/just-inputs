import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/testing.dart';
import 'package:just_inputs/just_inputs.dart';

import 'sample_asset.dart';

typedef K = PhysicalKeyboardKey;

/// A service running [asset] (the sample by default) and a tester for it.
(InputService, InputTester) run([InputActionAsset? asset]) {
  final service = InputService()..loadAsset(asset ?? sampleAsset());
  addTearDown(service.dispose);
  return (service, InputTester(service));
}

/// Records every phase change of [action] as `started`, `performed`,
/// `canceled`.
List<String> record(InputAction action) {
  final log = <String>[];
  action
    ..onStarted((_) => log.add('started'))
    ..onPerformed((_) => log.add('performed'))
    ..onCanceled((_) => log.add('canceled'));
  return log;
}

void main() {
  group('a button action', () {
    test('press: started and performed; release: canceled', () {
      final (service, t) = run();
      final jump = service.actions.action('player/jump');
      final log = record(jump);

      t.keyDown(K.space);
      expect(
        jump.isPressed(),
        isFalse,
        reason: 'nothing moves before the update',
      );
      t.step();
      expect(log, ['started', 'performed']);
      expect(jump.isPressed(), isTrue);
      expect(jump.wasPressedThisFrame(), isTrue);
      expect(jump.phase, InputActionPhase.performed);

      t.step();
      expect(jump.wasPressedThisFrame(), isFalse, reason: 'one update only');
      expect(jump.isPressed(), isTrue);

      t.keyUp(K.space);
      t.step();
      expect(log, ['started', 'performed', 'canceled']);
      expect(jump.wasReleasedThisFrame(), isTrue);
      expect(jump.phase, InputActionPhase.waiting);
    });

    test('a press and release between two updates is still a press', () {
      final (service, t) = run();
      final jump = service.actions.action('jump');
      final log = record(jump);

      t.keyDown(K.space);
      t.keyUp(K.space);
      t.step();

      expect(log, ['started', 'performed', 'canceled']);
      expect(jump.wasPressedThisFrame(), isTrue);
      expect(jump.wasReleasedThisFrame(), isTrue);
      expect(jump.isPressed(), isFalse);
    });

    test('key repeats are not presses', () {
      final (service, t) = run();
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step();
      service.handleKeyEvent(
        const KeyRepeatEvent(
          physicalKey: K.space,
          logicalKey: LogicalKeyboardKey.space,
          timeStamp: Duration.zero,
        ),
      );
      t.step();
      expect(log, ['started', 'performed']);
    });

    test('two bindings held: letting one go keeps it pressed', () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            ...a.bindings,
            const ControlBindingDef(id: 'b30', path: '<Keyboard>/z'),
          ],
        ),
      );
      final (service, t) = run(asset);
      final jump = service.actions.action('jump');
      final log = record(jump);

      t.keyDown(K.space);
      t.step();
      t.keyDown(K.keyZ);
      t.step();
      t.keyUp(K.space);
      t.step();
      expect(jump.isPressed(), isTrue);
      expect(log, ['started', 'performed']);

      t.keyUp(K.keyZ);
      t.step();
      expect(log.last, 'canceled');
    });

    test(
      'a trigger presses it past the press point, and lets go below the release point',
      () {
        final asset = withJump(
          sampleAsset(),
          (a) => a.copyWith(
            bindings: [
              const ControlBindingDef(
                id: 'b30',
                path: '<Gamepad>/rightTrigger',
              ),
            ],
          ),
        );
        final (service, t) = run(
          asset.copyWith(
            settings: const InputSettingsDef(
              axisDeadzoneMin: 0,
              axisDeadzoneMax: 1,
            ),
          ),
        );
        final pads = FakeGamepadSource();
        service.attachGamepads(pads);
        pads.connect('p1');
        final jump = service.actions.action('jump');

        void trigger(double v) {
          pads.send('p1', axes: {gp.GamepadAxis.rightTrigger: v});
          t.step();
        }

        trigger(0.4);
        expect(jump.isPressed(), isFalse);
        trigger(0.6);
        expect(jump.isPressed(), isTrue);
        expect(jump.magnitude, closeTo(0.6, 1e-9));
        trigger(0.45); // above 0.5 × 0.75
        expect(jump.isPressed(), isTrue);
        trigger(0.3);
        expect(jump.isPressed(), isFalse);
      },
    );
  });

  group('a vector action', () {
    test('WASD: one key is a direction, two a normalized diagonal', () {
      final (service, t) = run();
      final move = service.actions.action('player/move');
      final log = record(move);

      t.keyDown(K.keyD);
      t.step();
      expect(move.readVector2(), const Offset(1, 0));
      expect(log, ['started', 'performed']);

      t.keyDown(K.keyW);
      t.step();
      final v = move.readVector2();
      expect(v.dx, closeTo(0.7071, 1e-4));
      expect(v.dy, closeTo(-0.7071, 1e-4), reason: 'up is negative y');
      expect(log, ['started', 'performed', 'performed']);

      t.keyUp(K.keyD);
      t.keyUp(K.keyW);
      t.step();
      expect(move.readVector2(), Offset.zero);
      expect(log.last, 'canceled');
    });

    test('opposite keys cancel out', () {
      final (service, t) = run();
      final move = service.actions.action('move');
      t.keyDown(K.keyA);
      t.keyDown(K.keyD);
      t.step();
      expect(move.readVector2(), Offset.zero);
      expect(move.phase, InputActionPhase.waiting);
    });

    test('a stick, through its dead zone, and the stronger binding wins', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      pads.connect('p1');
      final move = service.actions.action('move');

      pads.leftStick('p1', const Offset(0.1, 0));
      t.step();
      expect(move.readVector2(), Offset.zero, reason: 'inside the dead zone');

      pads.leftStick('p1', const Offset(0, 1));
      t.step();
      expect(move.readVector2().dy, closeTo(1, 1e-9));

      // The binding's own dead zone is 0.2, on top of the pad's 0.125.
      pads.leftStick('p1', const Offset(0.3, 0));
      t.step();
      expect(move.readVector2().dx, greaterThan(0));
      expect(move.readVector2().dx, lessThan(0.3));

      t.keyDown(K.keyA);
      t.step();
      expect(
        move.readVector2(),
        const Offset(-1, 0),
        reason: 'full beats a little',
      );
    });

    test('an action processor applies to whatever drives it', () {
      final asset = sampleAsset();
      final move = asset.maps.first.actions.first;
      final inverted = asset.copyWith(
        maps: [
          asset.maps.first.copyWith(
            actions: [
              move.copyWith(
                processors: const [
                  ProcessorDef('invertVector2', {'invertY': false}),
                ],
              ),
              ...asset.maps.first.actions.skip(1),
            ],
          ),
          asset.maps[1],
        ],
      );
      final (service, t) = run(inverted);
      t.keyDown(K.keyD);
      t.step();
      expect(service.actions.action('move').readVector2(), const Offset(-1, 0));
    });
  });

  group('composites', () {
    InputActionAsset withAction(InputActionDef action) {
      final asset = sampleAsset();
      return asset.copyWith(
        maps: [
          asset.maps.first.copyWith(
            actions: [...asset.maps.first.actions, action],
          ),
          asset.maps[1],
        ],
      );
    }

    test('a 1D axis: Q is -1, E is +1, both is neither', () {
      final (service, t) = run(
        withAction(
          const InputActionDef(
            id: 'a30',
            name: 'turn',
            type: ActionValueType.axis,
            bindings: [
              CompositeBindingDef(
                id: 'b31',
                composite: CompositeKinds.axis1D,
                parts: [
                  CompositePartDef(
                    id: 'b32',
                    part: 'negative',
                    path: '<Keyboard>/q',
                  ),
                  CompositePartDef(
                    id: 'b33',
                    part: 'positive',
                    path: '<Keyboard>/e',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final turn = service.actions.action('turn');
      t.keyDown(K.keyQ);
      t.step();
      expect(turn.readAxis(), -1);
      t.keyDown(K.keyE);
      t.step();
      expect(turn.readAxis(), 0);
      t.keyUp(K.keyQ);
      t.step();
      expect(turn.readAxis(), 1);
    });

    test('Shift + E: counts when Shift came first, not when E did', () {
      final (service, t) = run(
        withAction(
          const InputActionDef(
            id: 'a30',
            name: 'dash',
            bindings: [
              CompositeBindingDef(
                id: 'b31',
                composite: CompositeKinds.oneModifier,
                parts: [
                  CompositePartDef(
                    id: 'b32',
                    part: 'modifier',
                    path: '<Keyboard>/shift',
                  ),
                  CompositePartDef(
                    id: 'b33',
                    part: 'binding',
                    path: '<Keyboard>/e',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      final dash = service.actions.action('dash');

      t.keyDown(K.shiftRight);
      t.keyDown(K.keyE);
      t.step();
      expect(dash.isPressed(), isTrue, reason: 'either Shift will do');
      t.keyUp(K.keyE);
      t.keyUp(K.shiftRight);
      t.step();
      expect(dash.isPressed(), isFalse);

      t.keyDown(K.keyE);
      t.step();
      t.keyDown(K.shiftLeft);
      t.step();
      expect(
        dash.isPressed(),
        isFalse,
        reason: 'E then Shift is not Shift + E',
      );
    });
  });

  group('maps', () {
    test('a disabled map does nothing; enabling ignores what is held', () {
      final (service, t) = run();
      final player = service.actions.map('player')!;
      final jump = service.actions.action('jump');

      player.disable();
      t.keyDown(K.space);
      t.step();
      expect(jump.isPressed(), isFalse);
      expect(jump.phase, InputActionPhase.disabled);

      player.enable();
      t.step();
      expect(jump.isPressed(), isFalse, reason: 'Space was held already');

      t.keyUp(K.space);
      t.step();
      t.keyDown(K.space);
      t.step();
      expect(jump.isPressed(), isTrue);
    });

    test('disabling a map cancels what is in progress', () {
      final (service, t) = run();
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step();
      service.actions.map('player')!.disable();
      expect(log, ['started', 'performed', 'canceled']);
    });

    test('a map the asset starts switched off is off', () {
      final asset = sampleAsset();
      final (service, _) = run(
        asset.copyWith(
          maps: [asset.maps.first, asset.maps[1].copyWith(enabled: false)],
        ),
      );
      expect(service.actions.map('ui')!.enabled, isFalse);
      expect(
        service.actions.action('ui/pause').phase,
        InputActionPhase.disabled,
      );
    });
  });

  group('loading an asset again', () {
    test('keeps actions and their callbacks; maps stay on or off', () {
      final (service, t) = run();
      final jump = service.actions.action('jump');
      final log = record(jump);
      service.actions.map('ui')!.disable();

      final rebound = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [const ControlBindingDef(id: 'b11', path: '<Keyboard>/k')],
        ),
      );
      service.loadAsset(rebound);

      expect(identical(service.actions.action('jump'), jump), isTrue);
      expect(service.actions.map('ui')!.enabled, isFalse);
      t.keyDown(K.space);
      t.step();
      expect(log, isEmpty, reason: 'Space is no longer jump');
      t.keyDown(K.keyK);
      t.step();
      expect(log, ['started', 'performed']);
    });

    test('a key held across the swap waits to be let go', () {
      final (service, t) = run();
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step();
      service.loadAsset(sampleAsset());
      t.step();
      expect(log, ['started', 'performed', 'canceled']);
      expect(service.actions.action('jump').isPressed(), isFalse);
    });

    test('an action the new asset lacks is gone', () {
      final (service, _) = run();
      final asset = sampleAsset();
      service.loadAsset(asset.copyWith(maps: [asset.maps.first]));
      expect(service.actions.tryAction('ui/pause'), isNull);
      expect(() => service.actions.action('ui/pause'), throwsArgumentError);
    });
  });

  group('devices', () {
    test('two pads are two devices: each read apart', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      pads.connect('p1');
      pads.connect('p2');
      expect(service.gamepads, hasLength(2));

      final one = service.createActions(
        devices: DeviceList([service.gamepads[0]]),
      );
      final two = service.createActions(
        devices: DeviceList([service.gamepads[1]]),
      );

      pads.press('p2', gp.GamepadButton.a);
      t.step();
      expect(one.action('jump').isPressed(), isFalse);
      expect(two.action('jump').isPressed(), isTrue);
      expect(two.action('jump').activeDevice, service.gamepads[1]);
      expect(
        service.actions.action('jump').isPressed(),
        isTrue,
        reason: 'the shared copy reads every pad',
      );
    });

    test('a pad pulled out while held lets go', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      pads.connect('p1');
      final changes = <String>[];
      service.listenDevices((d, c) => changes.add('${d.layout} ${c.name}'));
      final log = record(service.actions.action('jump'));

      pads.press('p1', gp.GamepadButton.a);
      t.step();
      pads.disconnect('p1');
      t.step();
      expect(log, ['started', 'performed', 'canceled']);
      expect(service.gamepads, isEmpty);
      expect(changes, ['Gamepad removed']);
    });

    test('plugging a pad in does not disturb a key held on the keyboard', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step();
      pads.connect('p1');
      t.step();
      expect(log, ['started', 'performed']);
      expect(service.actions.action('jump').isPressed(), isTrue);
    });

    test('the mouse: movement and the wheel last one update', () {
      final (service, t) = run();
      service.handlePointerEvent(
        const PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: Offset(10, 10),
          delta: Offset(4, 3),
        ),
      );
      service.handlePointerEvent(
        const PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: Offset(10, 10),
          scrollDelta: Offset(0, -100),
        ),
      );
      t.step();
      expect(service.mouse.control('delta')!.read(), const Offset(4, 3));
      expect(service.mouse.control('scroll/up')!.read().dx, 100);
      expect(service.mouse.control('position')!.read(), const Offset(10, 10));
      t.step();
      expect(service.mouse.control('delta')!.read(), Offset.zero);
      expect(service.mouse.control('scroll')!.read(), Offset.zero);
      expect(service.mouse.control('position')!.read(), const Offset(10, 10));
    });

    test('losing focus lets every key go', () {
      final (service, t) = run();
      final jump = service.actions.action('jump');
      t.keyDown(K.space);
      t.step();
      service.releaseKeyboard();
      t.step();
      expect(jump.isPressed(), isFalse);
    });

    test('the last device used is the one pressed, not the mouse moved', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      pads.connect('p1');
      expect(service.lastUsedDevice.value, isNull);
      pads.press('p1', gp.GamepadButton.x);
      expect(service.lastUsedDevice.value, service.gamepads.single);
      service.handlePointerEvent(
        const PointerHoverEvent(
          kind: PointerDeviceKind.mouse,
          position: Offset(50, 50),
          delta: Offset(40, 0),
        ),
      );
      expect(service.lastUsedDevice.value, service.gamepads.single);
      t.keyDown(K.keyQ);
      expect(service.lastUsedDevice.value, service.keyboard);
    });

    test(
      'raw listening hears a key the moment it is pressed, before any update',
      () {
        final (service, t) = run();
        final heard = <String>[];
        service.listenRaw((c, m) {
          if (!c.synthetic) heard.add('${c.path}=$m');
        });
        t.keyDown(K.keyW);
        expect(heard, ['<Keyboard>/w=1.0']);
      },
    );

    test('on-screen controls are read like any other', () {
      final (service, t) = run();
      service.onScreen.setButton('jump', true);
      service.onScreen.setStick('moveStick', const Offset(2, 0));
      t.step();
      expect(service.actions.action('jump').isPressed(), isTrue);
      expect(
        service.actions.action('move').readVector2(),
        const Offset(1, 0),
        reason: 'clamped to the unit circle',
      );
    });
  });

  group('suspending', () {
    test('while suspended nothing fires; after, what is held waits', () {
      final (service, t) = run();
      final log = record(service.actions.action('jump'));
      service.suspendActions();
      t.keyDown(K.space);
      t.step();
      expect(log, isEmpty);
      service.resumeActions();
      t.step();
      expect(log, isEmpty);
      t.keyUp(K.space);
      t.step();
      t.keyDown(K.space);
      t.step();
      expect(log, ['started', 'performed']);
    });
  });

  group('schemes', () {
    test('a group reads only its own bindings', () {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      service.attachGamepads(pads);
      pads.connect('p1');
      final keyboardOnly = service.createActions(group: 'KeyboardMouse');
      pads.press('p1', gp.GamepadButton.a);
      t.step();
      expect(keyboardOnly.action('jump').isPressed(), isFalse);
      t.keyDown(K.space);
      t.step();
      expect(keyboardOnly.action('jump').isPressed(), isTrue);
    });
  });
}
