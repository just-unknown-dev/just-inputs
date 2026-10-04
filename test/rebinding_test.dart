import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;
import 'package:just_inputs/just_inputs.dart';

import 'players_test.dart' show holdStart, players;

typedef K = PhysicalKeyboardKey;

/// A keyboard hook a test presses keys through, as the real one would hand
/// them over from [HardwareKeyboard].
final class FakeHook implements KeyboardCaptureHook {
  bool Function(KeyEvent)? handler;
  final List<bool> swallowed = [];

  @override
  void install(bool Function(KeyEvent) onKey) => handler = onKey;

  @override
  void remove() => handler = null;

  void down(PhysicalKeyboardKey key) => swallowed.add(
    handler?.call(
          KeyDownEvent(
            physicalKey: key,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        ) ??
        false,
  );

  void up(PhysicalKeyboardKey key) => swallowed.add(
    handler?.call(
          KeyUpEvent(
            physicalKey: key,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        ) ??
        false,
  );
}

void main() {
  test(
    'hears the next key, swallows its down, and lets the up go by',
    () async {
      final (service, t, _) = players();
      t.tap(K.keyW);
      final p1 = service.players[0]!;
      final hook = FakeHook();
      final op = RebindingOperation(
        service: service,
        target: p1.actions,
        bindingId: 'b11',
        keyboardHook: hook,
      );
      final result = op.start();
      expect(op.state.value, RebindState.listening);

      hook.down(K.keyQ);
      final done = await result as RebindCompleted;
      expect(done.path, '<Keyboard>/q');
      expect(hook.swallowed, [true]);
      expect(op.state.value, RebindState.completed);
      expect(hook.handler, isNull, reason: 'the hook comes off');
    },
  );

  test('Escape gives up', () async {
    final (service, t, _) = players();
    t.tap(K.keyW);
    final hook = FakeHook();
    final op = RebindingOperation(
      service: service,
      target: service.players[0]!.actions,
      bindingId: 'b11',
      keyboardHook: hook,
    );
    final result = op.start();
    hook.down(K.escape);
    expect(await result, isA<RebindCanceled>());
  });

  test('what was held when it began is ignored until let go', () async {
    final (service, t, _) = players();
    t.keyDown(K.enter); // the key that opened the rebind
    t.step();
    final hook = FakeHook();
    final op = RebindingOperation(
      service: service,
      target: service.players[0]!.actions,
      bindingId: 'b11',
      keyboardHook: hook,
    );
    final result = op.start();
    t.keyUp(K.enter);
    hook.down(K.enter);
    expect(
      await result,
      isA<RebindCompleted>().having((r) => r.path, 'path', '<Keyboard>/enter'),
      reason: 'pressed again after letting go, it counts',
    );
  });

  test('nothing else happens to the press it hears', () async {
    final (service, t, _) = players();
    t.tap(K.keyW);
    final p1 = service.players[0]!;
    final jumped = <String>[];
    p1.action('jump').onPerformed((_) => jumped.add('jump'));
    final hook = FakeHook();
    final result = RebindingOperation(
      service: service,
      target: p1.actions,
      bindingId: 'b16',
      keyboardHook: hook,
    ).start();
    hook.down(K.space);
    await result;
    t.step();
    hook.up(K.space);
    service.handleKeyEvent(
      const KeyUpEvent(
        physicalKey: K.space,
        logicalKey: LogicalKeyboardKey.space,
        timeStamp: Duration.zero,
      ),
    );
    t.step();
    expect(jumped, isEmpty);
  });

  test(
    'a gamepad player listens to their pad only, and takes a button',
    () async {
      final (service, t, pads) = players();
      pads
        ..connect('p1')
        ..connect('p2');
      t.tap(K.keyW);
      holdStart(t, pads, 'p1');
      final p2 = service.players[1]!;
      final op = RebindingOperation(
        service: service,
        target: p2.actions,
        bindingId: 'b12',
        keyboardHook: FakeHook(),
      );
      final result = op.start();
      pads.press('p2', gp.GamepadButton.y); // someone else's pad
      t.keyDown(K.keyQ); // the keyboard is player 1's
      pads.press('p1', gp.GamepadButton.x);
      final done = await result as RebindCompleted;
      expect(done.path, '<Gamepad>/buttonWest');
    },
  );

  test(
    'a vector binding takes a whole stick; a part takes a direction',
    () async {
      final (service, t, pads) = players();
      pads.connect('p1');
      t.tap(K.keyW);
      holdStart(t, pads, 'p1');
      final p2 = service.players[1]!;

      final whole = RebindingOperation(
        service: service,
        target: p2.actions,
        bindingId: 'b8',
        keyboardHook: FakeHook(),
      ).start();
      pads.send('p1', axes: {gp.GamepadAxis.rightStickX: 1.0});
      expect((await whole as RebindCompleted).path, '<Gamepad>/rightStick');
      pads.release('p1');

      final part = RebindingOperation(
        service: service,
        target: p2.actions,
        bindingId: 'b4',
        layouts: {InputLayouts.gamepad},
        keyboardHook: FakeHook(),
      ).start();
      pads.send('p1', axes: {gp.GamepadAxis.leftStickY: -1.0});
      expect((await part as RebindCompleted).path, '<Gamepad>/leftStick/up');
    },
  );

  test('says which other action the control would also press', () async {
    final (service, t, _) = players();
    t.tap(K.keyW);
    final hook = FakeHook();
    final result = RebindingOperation(
      service: service,
      target: service.players[0]!.actions,
      bindingId: 'b11',
      keyboardHook: hook,
    ).start();
    hook.down(K.keyD); // D is move right
    final done = await result as RebindCompleted;
    expect(done.conflicts.single.bindingIds, containsAll(['b7', 'b11']));
  });

  test('rebindPlayer keeps it, saves it, and swaps a clash', () async {
    final (service, t, _) = players();
    t.tap(K.keyW);
    final p1 = service.players[0]!;
    final hook = FakeHook();
    final result = rebindPlayer(p1, 'b11', keyboardHook: hook);
    await pumpEventQueue();
    hook.down(K.keyD);
    await result;
    expect(p1.overrides.paths, {
      'b11': '<Keyboard>/d',
      'b7': '<Keyboard>/space',
    });
    final store = service.overrideStore as MemoryInputOverrideStore;
    expect(store.data, contains(service.players.overridesKey(0)));

    t.keyDown(K.space);
    t.step();
    expect(
      p1.action('move').readVector2(),
      const Offset(1, 0),
      reason: 'right moved to Space',
    );
  });

  test('effectivePath: the override, else the asset\'s', () {
    final (service, t, _) = players();
    t.tap(K.keyW);
    final p1 = service.players[0]!;
    expect(effectivePath(p1.actions, 'b11'), '<Keyboard>/space');
    p1.overrides = p1.overrides.withPath('b11', '<Keyboard>/j');
    expect(effectivePath(p1.actions, 'b11'), '<Keyboard>/j');
    expect(effectivePath(p1.actions, 'b4'), '<Keyboard>/w');
  });
}
