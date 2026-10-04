import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/testing.dart';
import 'package:just_inputs/just_inputs.dart';

import 'runtime_test.dart' show record, run;
import 'sample_asset.dart';

typedef K = PhysicalKeyboardKey;

/// The sample with jump given [interactions] on the action.
InputActionAsset jumpWith(List<InteractionDef> interactions) =>
    withJump(sampleAsset(), (a) => a.copyWith(interactions: interactions));

void main() {
  group('hold', () {
    test('performed once held long enough', () {
      final (service, t) = run(
        jumpWith(const [
          InteractionDef('hold', {'duration': 0.5}),
        ]),
      );
      final log = record(service.actions.action('jump'));

      t.keyDown(K.space);
      t.step(0.1);
      expect(log, ['started']);
      t.step(0.3);
      expect(log, ['started']);
      t.step(0.2);
      expect(log, ['started', 'performed']);
      t.keyUp(K.space);
      t.step();
      expect(log, ['started', 'performed', 'canceled']);
    });

    test('canceled if let go too soon', () {
      final (service, t) = run(
        jumpWith(const [
          InteractionDef('hold', {'duration': 0.5}),
        ]),
      );
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step(0.2);
      t.keyUp(K.space);
      t.step(0.1);
      t.step(1);
      expect(log, ['started', 'canceled']);
    });

    test('takes the asset\'s hold time when it names none', () {
      final asset = jumpWith(const [
        InteractionDef('hold'),
      ]).copyWith(settings: const InputSettingsDef(holdTime: 1));
      final (service, t) = run(asset);
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step(0.1); // the press is timed at the update that hears it
      t.step(0.9);
      expect(log, ['started']);
      t.step(0.2);
      expect(log.last, 'performed');
    });
  });

  group('tap', () {
    test('performed when let go quickly', () {
      final (service, t) = run(
        jumpWith(const [
          InteractionDef('tap', {'duration': 0.2}),
        ]),
      );
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step(0.05);
      t.keyUp(K.space);
      t.step(0.05);
      expect(log, ['started', 'performed']);
      expect(service.actions.action('jump').phase, InputActionPhase.waiting);
    });

    test('canceled when held too long', () {
      final (service, t) = run(
        jumpWith(const [
          InteractionDef('tap', {'duration': 0.2}),
        ]),
      );
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.step(0.1);
      t.step(0.25);
      expect(log, ['started', 'canceled']);
      t.keyUp(K.space);
      t.step();
      expect(log, ['started', 'canceled']);
    });
  });

  test('slow tap: performed on a late release, canceled on an early one', () {
    final (service, t) = run(
      jumpWith(const [
        InteractionDef('slowTap', {'duration': 0.5}),
      ]),
    );
    final log = record(service.actions.action('jump'));
    t.keyDown(K.space);
    t.step(0.2);
    t.keyUp(K.space);
    t.step(0.1);
    expect(log, ['started', 'canceled']);
    t.keyDown(K.space);
    t.step(0.01);
    t.step(0.6);
    t.keyUp(K.space);
    t.step(0.01);
    expect(log, ['started', 'canceled', 'started', 'performed']);
  });

  test('multi tap: two quick taps are a double tap; a slow second is not', () {
    final (service, t) = run(
      jumpWith(const [
        InteractionDef('multiTap', {
          'tapCount': 2,
          'tapTime': 0.2,
          'tapDelay': 0.3,
        }),
      ]),
    );
    final log = record(service.actions.action('jump'));

    t.tap(K.space);
    t.step(0.1);
    t.tap(K.space);
    expect(log, ['started', 'performed']);

    log.clear();
    t.tap(K.space);
    t.step(0.5);
    expect(log, ['started', 'canceled']);
  });

  test('press, release only: started on press, performed on release', () {
    final (service, t) = run(
      jumpWith(const [
        InteractionDef('press', {'behavior': 'releaseOnly'}),
      ]),
    );
    final log = record(service.actions.action('jump'));
    t.keyDown(K.space);
    t.step();
    expect(log, ['started']);
    t.keyUp(K.space);
    t.step();
    expect(log, ['started', 'performed']);
  });

  test('tap then hold on one action: quick is a tap, long becomes a hold', () {
    final (service, t) = run(
      jumpWith(const [
        InteractionDef('tap', {'duration': 0.2}),
        InteractionDef('hold', {'duration': 0.5}),
      ]),
    );
    final log = record(service.actions.action('jump'));

    t.keyDown(K.space);
    t.step(0.05);
    t.keyUp(K.space);
    t.step(0.05);
    expect(log, [
      'started',
      'performed',
    ], reason: 'a tap; the hold never speaks');

    log.clear();
    t.keyDown(K.space);
    t.step(0.05);
    t.step(0.3); // the tap gives up — the hold carries on, no cancel seen
    expect(log, ['started']);
    t.step(0.3);
    expect(log, ['started', 'performed']);
    t.keyUp(K.space);
    t.step();
    expect(log, ['started', 'performed', 'canceled']);
  });

  test(
    'binding interactions: each binding has its own, the first to start drives',
    () {
      final asset = withJump(
        sampleAsset(),
        (a) => a.copyWith(
          bindings: [
            const ControlBindingDef(
              id: 'b30',
              path: '<Keyboard>/space',
              interactions: [
                InteractionDef('hold', {'duration': 0.5}),
              ],
            ),
            const ControlBindingDef(id: 'b31', path: '<Keyboard>/z'),
          ],
        ),
      );
      final (service, t) = run(asset);
      final log = record(service.actions.action('jump'));

      t.keyDown(K.keyZ);
      t.step();
      expect(log, [
        'started',
        'performed',
      ], reason: 'Z has no hold: a plain press');
      t.keyUp(K.keyZ);
      t.step();
      log.clear();

      t.keyDown(K.space);
      t.step(0.2);
      expect(log, ['started']);
      t.step(0.6);
      expect(log, ['started', 'performed']);
    },
  );

  test('a hold ticks on the service\'s clock, never the wall clock', () {
    final (service, t) = run(
      jumpWith(const [
        InteractionDef('hold', {'duration': 0.5}),
      ]),
    );
    final log = record(service.actions.action('jump'));
    t.keyDown(K.space);
    service.update(10);
    service.update(10.2);
    expect(log, ['started']);
    service.update(10.5);
    expect(log, ['started', 'performed']);
  });

  test(
    'press-and-release in one update with a hold: canceled, never performed',
    () {
      final (service, t) = run(
        jumpWith(const [
          InteractionDef('hold', {'duration': 0.5}),
        ]),
      );
      final log = record(service.actions.action('jump'));
      t.keyDown(K.space);
      t.keyUp(K.space);
      t.step();
      expect(log, ['started', 'canceled']);
    },
  );

  test('InputTester is for tests only: its keys come in as real events', () {
    final service = InputService();
    addTearDown(service.dispose);
    final t = InputTester(service);
    t.keyDown(K.keyW);
    expect(service.keyboard.isDown(K.keyW, live: true), isTrue);
    expect(service.keyboard.isDown(K.keyW), isFalse);
    t.step();
    expect(service.keyboard.isDown(K.keyW), isTrue);
  });
}
