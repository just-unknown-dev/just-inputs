import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/just_inputs.dart';
import 'package:just_inputs/testing.dart';

import 'sample_asset.dart';

/// The sample asset with the ready-made look actions in its player map.
InputActionAsset lookAsset({bool touchDrag = false}) =>
    LookActions.addTo(sampleAsset(), touchDrag: touchDrag);

/// A service running [asset] (the look asset by default) and a tester.
(InputService, InputTester) run([InputActionAsset? asset]) {
  final service = InputService()..loadAsset(asset ?? lookAsset());
  addTearDown(service.dispose);
  return (service, InputTester(service));
}

/// The sample with the `look` action's mouse binding and the action itself
/// given [binding] and [action] processors.
InputActionAsset withLookProcessors(
  List<ProcessorDef> binding,
  List<ProcessorDef> action,
) {
  final asset = lookAsset();
  final map = asset.mapNamed('player')!;
  return asset.copyWith(
    maps: [
      for (final m in asset.maps)
        if (m != map)
          m
        else
          map.copyWith(
            actions: [
              for (final a in map.actions)
                if (a.name != LookActions.pointer)
                  a
                else
                  a.copyWith(
                    processors: action,
                    bindings: [
                      for (final b in a.bindings)
                        (b as ControlBindingDef).copyWith(processors: binding),
                    ],
                  ),
            ],
          ),
    ],
  );
}

void moveMouse(InputService service, Offset delta) =>
    service.handlePointerEvent(
      PointerHoverEvent(
        kind: PointerDeviceKind.mouse,
        position: const Offset(100, 100),
        delta: delta,
      ),
    );

void expectOffset(Offset actual, Offset expected) {
  expect(actual.dx, moreOrLessEquals(expected.dx, epsilon: 1e-9));
  expect(actual.dy, moreOrLessEquals(expected.dy, epsilon: 1e-9));
}

void main() {
  group('the mouse, moved from outside', () {
    test('injected movement is <Mouse>/delta at the next update only', () {
      final (service, t) = run();
      final look = service.actions.action('player/look');
      service.mouse
        ..injectDelta(const Offset(3, 4))
        ..injectDelta(const Offset(1, 0));
      expect(look.readVector2(), Offset.zero, reason: 'not before the update');
      t.step();
      expect(look.readVector2(), const Offset(4, 4));
      t.step();
      expect(look.readVector2(), Offset.zero);
    });

    test(
      'relative mode: the pointer moves nothing, its buttons still count',
      () {
        final (service, t) = run();
        final look = service.actions.action('player/look');
        service.mouse.relativeMode = true;
        moveMouse(service, const Offset(10, 0));
        service.mouse.injectDelta(const Offset(2, 0));
        service.handlePointerEvent(
          const PointerDownEvent(
            kind: PointerDeviceKind.mouse,
            position: Offset(100, 100),
            buttons: kPrimaryMouseButton,
          ),
        );
        t.step();
        expect(look.readVector2(), const Offset(2, 0));
        expect(service.mouse.control(MouseControls.leftButton)!.read().dx, 1);
      },
    );

    test('attachRawMouse follows a stream and a lock; cancel undoes both', () {
      final (service, t) = run();
      final look = service.actions.action('player/look');
      final deltas = StreamController<Offset>(sync: true);
      addTearDown(deltas.close);
      final locked = ValueNotifier(false);
      addTearDown(locked.dispose);

      final subscription = service.attachRawMouse(
        deltas.stream,
        relative: locked,
      );
      expect(service.mouse.relativeMode, isFalse);
      locked.value = true;
      expect(service.mouse.relativeMode, isTrue);
      deltas.add(const Offset(5, -1));
      t.step();
      expect(look.readVector2(), const Offset(5, -1));

      subscription.cancel();
      expect(service.mouse.relativeMode, isFalse);
      locked.value = true;
      expect(service.mouse.relativeMode, isFalse, reason: 'no longer follows');
      deltas.add(const Offset(5, 0));
      t.step();
      expect(look.readVector2(), Offset.zero);
    });
  });

  group('a frame at a time', () {
    test('everything since the last take, however many updates ran', () {
      final (service, t) = run();
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);

      moveMouse(service, const Offset(3, 0));
      t.step();
      t.step();
      moveMouse(service, const Offset(2, 1));
      expect(motion.take(), const Offset(5, 1), reason: 'two steps, and none');
      expect(motion.take(), Offset.zero);

      // Two frames inside one step: each its own share.
      moveMouse(service, const Offset(1, 0));
      expect(motion.take(), const Offset(1, 0));
      moveMouse(service, const Offset(0, 2));
      expect(motion.take(), const Offset(0, 2));
      t.step();
      expect(motion.take(), Offset.zero);
    });

    test('injected and pointer movement both count', () {
      final (service, _) = run();
      final motion = FrameMotion(service.actions, 'look');
      addTearDown(motion.dispose);
      moveMouse(service, const Offset(1, 1));
      service.mouse.injectDelta(const Offset(10, 0));
      expect(motion.take(), const Offset(11, 1));
    });

    test('nothing moved while its map was off counts, even unread', () {
      final (service, t) = run();
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);
      final map = service.actions.map('player')!;

      map.disable();
      moveMouse(service, const Offset(40, 0));
      t.step();
      map.enable();
      moveMouse(service, const Offset(1, 0));
      expect(motion.take(), const Offset(1, 0));

      map.disable();
      expect(motion.take(), Offset.zero);
    });

    test('nor while a rebind is listening', () {
      final (service, t) = run();
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);
      service.suspendActions();
      moveMouse(service, const Offset(7, 0));
      t.step();
      service.resumeActions();
      expect(motion.take(), Offset.zero);
    });

    test('the bindings\' processors, then the action\'s, on the sum', () {
      final (service, _) = run(
        withLookProcessors(
          [
            const ProcessorDef('scaleVector2', {'x': 2.0, 'y': 3.0}),
          ],
          [
            const ProcessorDef('invertVector2', {'invertX': false}),
          ],
        ),
      );
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);
      moveMouse(service, const Offset(1, 1));
      moveMouse(service, const Offset(2, 1));
      expect(motion.take(), const Offset(6, -6));
    });

    test('a player reads their own devices only', () {
      final (service, _) = run();
      final keyboardOnly = service.createActions(
        devices: DeviceList([service.keyboard]),
      );
      final withMouse = service.createActions(
        devices: DeviceList([service.keyboard, service.mouse]),
      );
      final a = FrameMotion(keyboardOnly, 'player/look');
      final b = FrameMotion(withMouse, 'player/look');
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      moveMouse(service, const Offset(4, 0));
      expect(a.take(), Offset.zero);
      expect(b.take(), const Offset(4, 0));
    });

    test('relativeMouseOnly: only the locked mouse turns', () {
      final (service, t) = run();
      final motion = FrameMotion(
        service.actions,
        'player/look',
        relativeMouseOnly: true,
      );
      addTearDown(motion.dispose);

      moveMouse(service, const Offset(9, 0));
      expect(motion.take(), Offset.zero, reason: 'not locked');
      service.mouse.relativeMode = true;
      service.mouse.injectDelta(const Offset(4, 0));
      expect(motion.take(), const Offset(4, 0));

      // Let go and taken back with nobody reading between: the cursor's
      // wandering in between is not look.
      service.mouse.relativeMode = false;
      moveMouse(service, const Offset(30, 0));
      t.step();
      service.mouse.relativeMode = true;
      expect(motion.take(), Offset.zero);
    });

    test('the wheel, for an axis action on <Mouse>/scroll/y', () {
      final asset = sampleAsset();
      final (zoomId, spent) = asset.takeId('a');
      final (bindingId, last) = spent.takeId('b');
      final (service, _) = run(
        last.copyWith(
          maps: [
            ...asset.maps,
            ActionMapDef(
              id: 'mz',
              name: 'camera',
              actions: [
                InputActionDef(
                  id: zoomId,
                  name: 'zoom',
                  type: ActionValueType.axis,
                  passThrough: true,
                  bindings: [
                    ControlBindingDef(id: bindingId, path: '<Mouse>/scroll/y'),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      final zoom = FrameMotion(service.actions, 'camera/zoom');
      addTearDown(zoom.dispose);
      for (final dy in [-120.0, -120.0, 40.0]) {
        service.handlePointerEvent(
          PointerScrollEvent(
            kind: PointerDeviceKind.mouse,
            position: const Offset(10, 10),
            scrollDelta: Offset(0, dy),
          ),
        );
      }
      expect(zoom.take(), const Offset(-200, 0));
    });

    test('a finger\'s drag, when bound', () {
      final (service, _) = run(lookAsset(touchDrag: true));
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);
      service
        ..handlePointerEvent(
          const PointerDownEvent(
            kind: PointerDeviceKind.touch,
            pointer: 7,
            position: Offset(50, 50),
          ),
        )
        ..handlePointerEvent(
          const PointerMoveEvent(
            kind: PointerDeviceKind.touch,
            pointer: 7,
            position: Offset(56, 48),
            delta: Offset(6, -2),
          ),
        );
      expect(motion.take(), const Offset(6, -2));
    });

    test('reset forgets; dispose stops', () {
      final (service, t) = run();
      final motion = FrameMotion(service.actions, 'player/look');
      moveMouse(service, const Offset(5, 0));
      motion.reset();
      expect(motion.take(), Offset.zero);

      motion.dispose();
      moveMouse(service, const Offset(5, 0));
      t.step();
      expect(motion.take(), Offset.zero);
    });

    test('an action the asset lacks reads as nothing', () {
      final (service, _) = run(sampleAsset());
      final motion = FrameMotion(service.actions, 'player/look');
      addTearDown(motion.dispose);
      moveMouse(service, const Offset(5, 0));
      expect(motion.take(), Offset.zero);
    });
  });

  group('look', () {
    test('the pointer: pixels times the sensitivity, any frame length', () {
      final (service, _) = run();
      final look = LookInput(
        service.actions,
        settings: const LookSettings(radiansPerPixel: 0.01),
      );
      addTearDown(look.dispose);
      service.mouse.injectDelta(const Offset(100, -40));
      expectOffset(look.read(1 / 240), const Offset(1, -0.4));
      expect(look.read(1 / 30), Offset.zero);
    });

    test(
      'the stick: deflection times degrees a second times the frame',
      () async {
        final (service, t) = run();
        final pads = FakeGamepadSource();
        addTearDown(pads.dispose);
        await service.attachGamepads(pads);
        pads
          ..connect('p1')
          ..send('p1', axes: {gp.GamepadAxis.rightStickX: 1.0});
        t.step();
        final look = LookInput(
          service.actions,
          settings: const LookSettings(yawDegreesPerSecond: 180),
        );
        addTearDown(look.dispose);

        expectOffset(look.read(0.5), const Offset(math.pi / 2, 0));
        // Four short frames turn as far as one long one.
        var sum = Offset.zero;
        for (var i = 0; i < 4; i++) {
          sum += look.read(0.125);
        }
        expectOffset(sum, const Offset(math.pi / 2, 0));
        expect(look.read(0), Offset.zero);
      },
    );

    test('both at once add up; invert flips both', () async {
      final (service, t) = run();
      final pads = FakeGamepadSource();
      addTearDown(pads.dispose);
      await service.attachGamepads(pads);
      pads
        ..connect('p1')
        ..send('p1', axes: {gp.GamepadAxis.rightStickY: 1.0});
      t.step();
      final look = LookInput(
        service.actions,
        settings: const LookSettings(
          radiansPerPixel: 0.01,
          pitchDegreesPerSecond: 90,
        ),
      );
      addTearDown(look.dispose);

      service.mouse.injectDelta(const Offset(0, 10));
      expectOffset(look.read(1), Offset(0, 0.1 + math.pi / 2));

      look.settings = look.settings.copyWith(invertX: true, invertY: true);
      service.mouse.injectDelta(const Offset(10, 0));
      expectOffset(look.read(1), Offset(-0.1, -math.pi / 2));
    });

    test('a pause menu turns off the map: nothing turns', () {
      final (service, t) = run();
      final look = LookInput(service.actions);
      addTearDown(look.dispose);
      service.actions.map('player')!.disable();
      service.mouse.injectDelta(const Offset(100, 0));
      t.step();
      service.actions.map('player')!.enable();
      expect(look.read(1 / 60), Offset.zero);
    });

    test('no stick action: the pointer alone', () {
      final (service, _) = run();
      final look = LookInput(service.actions, stick: 'player/nothing');
      addTearDown(look.dispose);
      service.mouse.injectDelta(const Offset(400, 0));
      expectOffset(look.read(1), const Offset(1, 0));
    });
  });

  group('the ready-made actions', () {
    test('two actions, ids from the counter, bindings in their schemes', () {
      final before = sampleAsset();
      final asset = lookAsset();
      final player = asset.mapNamed('player')!;
      final pointer = player.actionNamed(LookActions.pointer)!;
      final stick = player.actionNamed(LookActions.stick)!;

      expect(asset.nextId, before.nextId + 4);
      expect(pointer.type, ActionValueType.vector2);
      expect(pointer.passThrough, isTrue);
      expect(pointer.rebindable, isFalse);
      final mouse = pointer.bindings.single as ControlBindingDef;
      expect(mouse.path, '<Mouse>/delta');
      expect(mouse.groups, ['KeyboardMouse']);
      expect(stick.type, ActionValueType.vector2);
      final pad = stick.bindings.single as ControlBindingDef;
      expect(pad.path, '<Gamepad>/rightStick');
      expect(pad.groups, ['Gamepad']);

      final ids = {
        pointer.id,
        stick.id,
        mouse.id,
        pad.id,
        for (final r in before.actions) r.action.id,
      };
      expect(ids, hasLength(before.actions.length + 4), reason: 'all new');
      expect(validateAsset(asset).where((i) => i.isError), isEmpty);
      expect(
        jsonEncode(InputActionAsset.parse(asset.encode()).toJson()),
        jsonEncode(asset.toJson()),
      );
    });

    test('touch drag and an on-screen stick, when asked', () {
      final asset = LookActions.addTo(
        sampleAsset().copyWith(
          onScreen: [
            ...sampleAsset().onScreen,
            const OnScreenControlDef(id: 'lookPad', kind: OnScreenKind.stick),
          ],
        ),
        touchDrag: true,
        onScreenStick: 'lookPad',
      );
      final player = asset.mapNamed('player')!;
      final paths = [
        for (final a in [LookActions.pointer, LookActions.stick])
          for (final b in player.actionNamed(a)!.bindings)
            (b as ControlBindingDef).path,
      ];
      expect(paths, [
        '<Mouse>/delta',
        '<Touchscreen>/delta',
        '<Gamepad>/rightStick',
        '<OnScreen>/lookPad',
      ]);
      expect(validateAsset(asset).where((i) => i.isError), isEmpty);
    });

    test('twice is once; a map is made when there is none', () {
      final once = lookAsset();
      expect(identical(LookActions.addTo(once), once), isTrue);

      final asset = LookActions.addTo(sampleAsset(), map: 'camera');
      final camera = asset.mapNamed('camera')!;
      expect(camera.enabled, isTrue);
      expect(
        [for (final a in camera.actions) a.name],
        [LookActions.pointer, LookActions.stick],
      );
      expect(asset.nextId, sampleAsset().nextId + 5);
    });
  });
}
