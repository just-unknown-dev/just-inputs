// The input service's pointer lock: taken on a click when the game asks,
// its raw movement feeding the mouse, and let go by Escape whatever has the
// keyboard.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

final class FakeLockPlatform implements PointerLockPlatform {
  final StreamController<PointerLockEvent> sent = StreamController.broadcast(
    sync: true,
  );
  int locks = 0;
  int unlocks = 0;

  @override
  bool get isSupported => true;

  @override
  Stream<PointerLockEvent> get events => sent.stream;

  @override
  Future<bool> lock({required bool pinToCentre}) async {
    locks++;
    sent.add(const PointerLockChanged(true));
    return true;
  }

  @override
  Future<void> unlock() async {
    unlocks++;
    sent.add(const PointerLockChanged(false));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLockPlatform platform;
  late PointerLock lock;
  late InputService input;

  setUp(() {
    platform = FakeLockPlatform();
    lock = PointerLock.withPlatform(platform);
    input = InputService(pointerLock: lock);
  });

  tearDown(() async {
    input.dispose();
    await lock.dispose();
  });

  test('a click takes hold only when the game asks for it', () async {
    input.lockPointerForClick();
    await pumpEventQueue();
    expect(platform.locks, 0, reason: 'lockPointerOnClick is off');

    input.lockPointerOnClick = true;
    input.lockPointerForClick();
    await pumpEventQueue();
    expect(platform.locks, 1);
    expect(lock.isLocked, isTrue);

    input.lockPointerForClick();
    await pumpEventQueue();
    expect(platform.locks, 1, reason: 'already held');
  });

  test('while it holds, the mouse moves only with its raw movement', () async {
    expect(identical(input.pointerLock, lock), isTrue);
    expect(input.mouse.relativeMode, isFalse);
    await lock.lock();
    expect(input.mouse.relativeMode, isTrue);
    await input.releasePointer();
    expect(platform.unlocks, 1);
    expect(input.mouse.relativeMode, isFalse);
  });

  testWidgets('Escape lets go, and others still hear it', (tester) async {
    var heard = 0;
    bool listener(KeyEvent event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        heard++;
      }
      return false;
    }

    HardwareKeyboard.instance.addHandler(listener);
    addTearDown(() => HardwareKeyboard.instance.removeHandler(listener));

    await tester.runAsync(lock.lock);
    expect(lock.isRequested, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.runAsync(pumpEventQueue);
    expect(lock.isRequested, isFalse);
    expect(lock.isLocked, isFalse);
    expect(platform.unlocks, 1);
    expect(heard, 1, reason: 'a game can pause on the same key');

    // Not wanted any more: Escape is left alone.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.runAsync(pumpEventQueue);
    expect(platform.unlocks, 1);
  });
}
