import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'pointer_lock_platform.dart';

/// Locks the mouse pointer to the game window, for mouse look.
///
/// While locked, the cursor is hidden and held in the window (at its
/// centre, unless asked otherwise), and [deltas] streams the mouse's raw
/// movement: counts straight from the device, never accelerated by the
/// pointer speed setting and never stopped by the edge of the screen.
///
/// The lock lets go by itself when the window goes behind another (Alt+Tab,
/// the Windows key, a click on another window) or is minimised, and takes
/// hold again when the window comes back, for as long as the game wants it
/// ([isRequested]). [locked] says which. Escape ([releaseKeys]) lets go and
/// stops asking, as a browser's pointer lock does, whatever widget has the
/// keyboard; a pause menu can call [unlock] too.
///
/// Windows only for now. Elsewhere [isSupported] is false, [lock] returns
/// false and nothing else happens: Android looks with on-screen controls,
/// and macOS and the web are still to come.
///
/// A game reaches it as `InputService.pointerLock`, whose mouse then moves
/// with the lock's raw movement; with `InputService.lockPointerOnClick` a
/// click on the game (or, in the editor, on the play-test) takes hold:
///
/// ```dart
/// engine.input.lockPointerOnClick = true;
/// ```
class PointerLock {
  PointerLock._(this._platform) {
    if (_platform.isSupported) {
      _events = _platform.events.listen(
        _onEvent,
        onError: (Object error) => debugPrint('Pointer lock: $error'),
      );
    }
  }

  /// A lock over [platform], for tests. A game uses [instance].
  @visibleForTesting
  factory PointerLock.withPlatform(PointerLockPlatform platform) =>
      PointerLock._(platform);

  /// The app's pointer lock, made on first use. There is one pointer.
  static PointerLock get instance =>
      _instance ??= PointerLock._(PointerLockPlatform.forCurrentPlatform());
  static PointerLock? _instance;

  final PointerLockPlatform _platform;
  StreamSubscription<PointerLockEvent>? _events;
  final StreamController<Offset> _deltas = StreamController.broadcast(
    sync: true,
  );
  final ValueNotifier<bool> _locked = ValueNotifier(false);
  bool _requested = false;
  bool _pinToCentre = true;
  bool _disposed = false;

  /// Keys that let go of the lock, and stop asking for it, while it is
  /// wanted: Escape. They are heard through [HardwareKeyboard], so a widget
  /// that keeps every key it is given (a game's own focus) cannot hold them
  /// back, and they still reach everything else: a game can pause on the
  /// same key. Empty: only [unlock] lets go.
  Set<LogicalKeyboardKey> releaseKeys = {LogicalKeyboardKey.escape};

  bool _listeningForRelease = false;

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        _requested &&
        releaseKeys.contains(event.logicalKey)) {
      unawaited(unlock());
    }
    return false;
  }

  void _listenForRelease(bool listen) {
    if (listen == _listeningForRelease) return;
    _listeningForRelease = listen;
    if (listen) {
      HardwareKeyboard.instance.addHandler(_onKey);
    } else {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
  }

  /// Whether this platform can lock the pointer. Windows, today.
  bool get isSupported => _platform.isSupported;

  /// Whether the game wants the lock: true from [lock] to [unlock], whether
  /// or not it holds right now.
  bool get isRequested => _requested;

  /// Whether the cursor is held at the window's centre (or anywhere in it),
  /// as last asked by [lock].
  bool get pinsToCentre => _pinToCentre;

  /// True while the lock holds: the cursor hidden and held, [deltas]
  /// flowing. Follows the window going behind and coming back.
  ValueListenable<bool> get locked => _locked;

  bool get isLocked => _locked.value;

  /// The mouse's raw movement while locked, in device counts (about one
  /// physical pixel each at Windows' default pointer speed): x right, y
  /// down. Each is the movement since the one before, so add them up.
  /// Nothing comes while unlocked.
  Stream<Offset> get deltas => _deltas.stream;

  /// Asks for the lock and keeps asking until [unlock]. Returns whether it
  /// took hold now; when the window is behind another it takes hold as the
  /// window comes forward.
  ///
  /// With [pinToCentre] (the default) the hidden cursor stays at the
  /// window's centre, so clicks land there and nothing under a wandering
  /// cursor reacts. Without it, the cursor is kept anywhere inside the
  /// window.
  Future<bool> lock({bool pinToCentre = true}) async {
    if (!isSupported || _disposed) return false;
    _requested = true;
    _listenForRelease(true);
    _pinToCentre = pinToCentre;
    try {
      final took = await _platform.lock(pinToCentre: pinToCentre);
      // An unlock while this was on its way wins.
      if (!_requested) return false;
      if (took) _locked.value = true;
      return took;
    } on PlatformException catch (e) {
      debugPrint('Pointer lock refused: ${e.message}');
    } on MissingPluginException {
      // A Windows app built without the plugin registered: a test, a
      // headless run.
      debugPrint('Pointer lock: the plugin is not registered.');
    }
    return false;
  }

  /// Lets the lock go — the cursor shows and moves freely again — and stops
  /// asking for it.
  Future<void> unlock() async {
    if (!isSupported || _disposed) return;
    _requested = false;
    _listenForRelease(false);
    _locked.value = false;
    try {
      await _platform.unlock();
    } on PlatformException catch (e) {
      debugPrint('Pointer unlock failed: ${e.message}');
    } on MissingPluginException {
      // Nothing was locked.
    }
  }

  void _onEvent(PointerLockEvent event) {
    switch (event) {
      case PointerLockMotion(:final delta):
        _deltas.add(delta);
      case PointerLockChanged(:final locked):
        // A hold reported after the game let go is old news.
        _locked.value = locked && _requested;
    }
  }

  /// Lets go, stops listening to the platform, and closes [deltas]. The
  /// next [instance] is a new one.
  Future<void> dispose() async {
    if (_disposed) return;
    if (_requested) await unlock();
    _disposed = true;
    if (identical(_instance, this)) _instance = null;
    await _events?.cancel();
    await _deltas.close();
    _locked.dispose();
  }
}
