import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Something the platform reports while a lock is wanted.
sealed class PointerLockEvent {
  const PointerLockEvent();
}

/// The mouse moved: raw movement since the last one, in device counts, x
/// right and y down.
final class PointerLockMotion extends PointerLockEvent {
  const PointerLockMotion(this.delta);

  final Offset delta;

  @override
  String toString() => 'PointerLockMotion($delta)';
}

/// The lock took hold or let go: the game asked, or the window came to the
/// front or went behind.
final class PointerLockChanged extends PointerLockEvent {
  const PointerLockChanged(this.locked);

  final bool locked;

  @override
  String toString() => 'PointerLockChanged($locked)';
}

/// Where a `PointerLock` does its work: the plugin on Windows, nothing
/// elsewhere. A test gives its own.
abstract interface class PointerLockPlatform {
  /// The one for the platform the app runs on: [MethodChannelPointerLock] on
  /// Windows, [UnsupportedPointerLock] everywhere else, the web included.
  static PointerLockPlatform forCurrentPlatform() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows
      ? MethodChannelPointerLock()
      : const UnsupportedPointerLock();

  /// Whether this platform can lock the pointer at all.
  bool get isSupported;

  /// What the platform reports. Listening starts the platform's side; a new
  /// listener (a hot restart's) finds any lock left over let go.
  Stream<PointerLockEvent> get events;

  /// Asks for the lock. True when it took hold now; false when the window is
  /// behind another (it takes hold when the window comes forward) or there
  /// is no window.
  Future<bool> lock({required bool pinToCentre});

  /// Lets the lock go and stops asking for it.
  Future<void> unlock();
}

/// The Windows plugin, over a method channel and an event channel.
///
/// Messages on [eventChannel]: a two-element `Float64List`, `[dx, dy]`, for
/// movement; a `bool` when the lock takes hold or lets go.
final class MethodChannelPointerLock implements PointerLockPlatform {
  static const MethodChannel methodChannel = MethodChannel('just_inputs/pointer_lock');
  static const EventChannel eventChannel = EventChannel(
    'just_inputs/pointer_lock/events',
  );

  // One stream for the whole app: a second `receiveBroadcastStream` would
  // take the channel's handler from the first.
  static final Stream<PointerLockEvent> _events = eventChannel
      .receiveBroadcastStream()
      .expand((message) => [?decode(message)]);

  /// One message from the plugin as an event, or null when it is neither.
  static PointerLockEvent? decode(Object? message) => switch (message) {
    final bool locked => PointerLockChanged(locked),
    final Float64List v when v.length == 2 => PointerLockMotion(
      Offset(v[0], v[1]),
    ),
    [final num dx, final num dy] => PointerLockMotion(
      Offset(dx.toDouble(), dy.toDouble()),
    ),
    _ => null,
  };

  @override
  bool get isSupported => true;

  @override
  Stream<PointerLockEvent> get events => _events;

  @override
  Future<bool> lock({required bool pinToCentre}) async =>
      await methodChannel.invokeMethod<bool>('lock', {
        'pinToCentre': pinToCentre,
      }) ??
      false;

  @override
  Future<void> unlock() => methodChannel.invokeMethod<void>('unlock');
}

/// A platform with no pointer lock: nothing happens, and nothing moves.
final class UnsupportedPointerLock implements PointerLockPlatform {
  const UnsupportedPointerLock();

  @override
  bool get isSupported => false;

  @override
  Stream<PointerLockEvent> get events => const Stream.empty();

  @override
  Future<bool> lock({required bool pinToCentre}) async => false;

  @override
  Future<void> unlock() async {}
}
