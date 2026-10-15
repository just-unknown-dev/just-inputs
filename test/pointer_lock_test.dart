import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

/// The Windows plugin, played by mocks: method calls are recorded, and
/// [sink] sends what the plugin would.
final class FakePlugin {
  FakePlugin({this.takesHold = true}) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MethodChannelPointerLock.methodChannel, (
      call,
    ) async {
      calls.add('${call.method} ${call.arguments ?? ''}'.trim());
      switch (call.method) {
        case 'lock':
          if (takesHold) sink?.success(true);
          return takesHold;
        case 'unlock':
          sink?.success(false);
          return null;
      }
      return null;
    });
    messenger.setMockStreamHandler(
      MethodChannelPointerLock.eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          listens++;
          sink = events;
        },
        onCancel: (_) => sink = null,
      ),
    );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(MethodChannelPointerLock.methodChannel, null)
        ..setMockStreamHandler(MethodChannelPointerLock.eventChannel, null);
    });
  }

  bool takesHold;
  final List<String> calls = [];
  MockStreamHandlerEventSink? sink;
  int listens = 0;

  void move(double dx, double dy) =>
      sink!.success(Float64List.fromList([dx, dy]));
}

/// A lock over the method channels, disposed at the end of the test.
PointerLock channelLock() {
  final lock = PointerLock.withPlatform(MethodChannelPointerLock());
  addTearDown(lock.dispose);
  return lock;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('on Windows', () {
    test('lock: asked with the pin, held, and the movement flows', () async {
      final plugin = FakePlugin();
      final lock = channelLock();
      final moved = <Offset>[];
      lock.deltas.listen(moved.add);
      await pumpEventQueue();
      expect(plugin.listens, 1, reason: 'listening from the start');

      expect(await lock.lock(), isTrue);
      expect(plugin.calls, ['lock {pinToCentre: true}']);
      expect(lock.isRequested, isTrue);
      expect(lock.isLocked, isTrue);
      expect(lock.pinsToCentre, isTrue);

      plugin
        ..move(3, -2)
        ..move(0.5, 4);
      await pumpEventQueue();
      expect(moved, const [Offset(3, -2), Offset(0.5, 4)]);
    });

    test('the window goes behind and comes back: still asked for', () async {
      final plugin = FakePlugin();
      final lock = channelLock();
      final seen = <bool>[];
      lock.locked.addListener(() => seen.add(lock.isLocked));
      await pumpEventQueue();

      await lock.lock(pinToCentre: false);
      expect(plugin.calls.single, 'lock {pinToCentre: false}');
      plugin.sink!.success(false);
      await pumpEventQueue();
      expect(lock.isLocked, isFalse);
      expect(lock.isRequested, isTrue);
      plugin.sink!.success(true);
      await pumpEventQueue();
      expect(lock.isLocked, isTrue);
      expect(seen, [true, false, true]);
    });

    test('behind another window: asked for, not held until it comes', () async {
      final plugin = FakePlugin(takesHold: false);
      final lock = channelLock();
      await pumpEventQueue();
      expect(await lock.lock(), isFalse);
      expect(lock.isRequested, isTrue);
      expect(lock.isLocked, isFalse);
      plugin.sink!.success(true);
      await pumpEventQueue();
      expect(lock.isLocked, isTrue);
    });

    test('unlock lets go and stops asking', () async {
      final plugin = FakePlugin();
      final lock = channelLock();
      await pumpEventQueue();
      await lock.lock();
      await lock.unlock();
      expect(plugin.calls, ['lock {pinToCentre: true}', 'unlock']);
      expect(lock.isLocked, isFalse);
      expect(lock.isRequested, isFalse);
    });

    test('dispose lets go and stops listening', () async {
      final plugin = FakePlugin();
      final lock = PointerLock.withPlatform(MethodChannelPointerLock());
      await pumpEventQueue();
      await lock.lock();
      await lock.dispose();
      expect(plugin.calls.last, 'unlock');
      expect(plugin.sink, isNull, reason: 'canceled');
      expect(await lock.lock(), isFalse, reason: 'disposed');
    });

    test('no plugin registered: a refusal, not a crash', () async {
      final lock = channelLock();
      expect(await lock.lock(), isFalse);
      await lock.unlock();
      expect(lock.isLocked, isFalse);
    });

    test('the plugin\'s messages, read', () {
      expect(
        MethodChannelPointerLock.decode(Float64List.fromList([1.5, -2])),
        isA<PointerLockMotion>().having(
          (m) => m.delta,
          'delta',
          const Offset(1.5, -2),
        ),
      );
      expect(
        MethodChannelPointerLock.decode([3, 4]),
        isA<PointerLockMotion>().having(
          (m) => m.delta,
          'delta',
          const Offset(3, 4),
        ),
      );
      expect(
        MethodChannelPointerLock.decode(true),
        isA<PointerLockChanged>().having((c) => c.locked, 'locked', isTrue),
      );
      expect(MethodChannelPointerLock.decode('hello'), isNull);
      expect(MethodChannelPointerLock.decode([1, 2, 3]), isNull);
    });
  });

  group('elsewhere', () {
    test('not supported: nothing is asked, nothing moves', () async {
      final plugin = FakePlugin();
      final lock = PointerLock.withPlatform(const UnsupportedPointerLock());
      addTearDown(lock.dispose);
      expect(lock.isSupported, isFalse);
      expect(await lock.lock(), isFalse);
      expect(lock.isRequested, isFalse);
      expect(lock.isLocked, isFalse);
      await lock.unlock();
      expect(plugin.calls, isEmpty);
      expect(plugin.listens, 0);
    });

    test('the platform is picked by where the app runs', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        expect(
          PointerLockPlatform.forCurrentPlatform().isSupported,
          platform == TargetPlatform.windows,
          reason: platform.name,
        );
      }
    });
  });
}
