import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../devices/gamepad_device.dart';
import '../devices/input_device.dart';
import '../devices/keyboard_device.dart';
import '../devices/on_screen_device.dart';
import '../devices/pointer_devices.dart';
import '../model/input_action_asset.dart';
import '../players/player_input.dart';
import '../pointer/pointer_lock.dart';
import '../rebinding/binding_overrides.dart';
import 'input_action.dart';
import 'input_actions.dart';

/// Called for every control whose value changes, the moment it changes —
/// before any update, and while the game is paused.
typedef RawInputListener =
    void Function(InputControl control, double magnitude);

typedef DeviceListener = void Function(InputDevice device, DeviceChange change);

/// A game's input: its devices, the asset, and every live copy of the asset
/// (a shared one, and one per player).
///
/// Events arrive whenever Flutter or a gamepad sends them and are queued;
/// [update] replays them in order and moves every action along. The game
/// calls [update] once per fixed step with its own clock — nothing here
/// reads the wall clock.
class InputService {
  /// A service with its own devices. [pointerLock] is the one
  /// [InputService.pointerLock] hands out ([PointerLock.instance] when
  /// null); a test gives its own.
  InputService({PointerLock? pointerLock}) : _pointerLockGiven = pointerLock {
    keyboard = KeyboardDevice(deviceId: _nextId++);
    mouse = MouseDevice(deviceId: _nextId++);
    touchscreen = TouchscreenDevice(deviceId: _nextId++);
    onScreen = OnScreenDevice(deviceId: _nextId++);
    for (final d in [keyboard, mouse, touchscreen, onScreen]) {
      _adopt(d);
    }
    _shared = createActions();
  }

  int _nextId = 1;

  late final KeyboardDevice keyboard;
  late final MouseDevice mouse;
  late final TouchscreenDevice touchscreen;
  late final OnScreenDevice onScreen;

  final List<InputDevice> _devices = [];

  /// Every device there is now.
  List<InputDevice> get devices => List.unmodifiable(_devices);

  List<GamepadDevice> get gamepads => [
    for (final d in _devices)
      if (d is GamepadDevice) d,
  ];

  InputActionAsset _asset = InputActionAsset.empty;
  InputActionAsset get asset => _asset;

  late final InputActions _shared;

  /// The asset for every device at once — one player, or the menus before
  /// anyone has joined.
  InputActions get actions => _shared;

  final List<InputActions> _instances = [];

  /// Every live copy of the asset.
  List<InputActions> get instances => List.unmodifiable(_instances);

  /// Local multiplayer: off until `players.start()`.
  late final PlayerInputManager players = PlayerInputManager(this);

  /// Where players' own bindings are saved. In memory unless the game says
  /// otherwise — the engine gives it its cache.
  InputOverrideStore overrideStore = MemoryInputOverrideStore();

  /// Player [index]'s actions — or, while nobody has joined, the shared
  /// ones for player 1. Null for a player who is not playing.
  InputActions? actionsFor(int index) {
    final player = players[index];
    if (player != null) return player.actions;
    if (index == 0 && players.players.isEmpty) return _shared;
    return null;
  }

  /// A new live copy of the asset, reading only [devices]. With
  /// [ignoreHeld], whatever is held now waits to be let go.
  InputActions createActions({
    DeviceFilter devices = const AllDevices(),
    String? group,
    Map<String, String> overrides = const {},
    bool ignoreHeld = true,
  }) {
    final instance = InputActions(
      this,
      devices: devices,
      group: group,
      overrides: overrides,
    );
    _instances.add(instance);
    instance.load(_asset, ignoreHeld: ignoreHeld);
    return instance;
  }

  /// Called by [InputActions.dispose].
  void forget(InputActions instance) => _instances.remove(instance);

  /// Takes up a new asset — at boot, or when the Input Actions editor
  /// (`just_input_editor`) saves one. Every live copy keeps its actions (and
  /// their callbacks) where the names match, and its maps on or off as they
  /// were.
  void loadAsset(InputActionAsset asset) {
    _asset = asset;
    onScreen.configure(asset.onScreen);
    for (final i in [..._instances]) {
      i.load(asset);
    }
    players.assetLoaded();
  }

  // --- Events in -----------------------------------------------------------

  void handleKeyEvent(KeyEvent event) => keyboard.handleKeyEvent(event);

  void handlePointerEvent(PointerEvent event) {
    mouse.handlePointerEvent(event);
    touchscreen.handlePointerEvent(event);
  }

  /// The window lost the keyboard: every key held is let go.
  void releaseKeyboard() => keyboard.releaseAll();

  final List<InputSubscription> _rawMouse = [];

  /// Feeds raw mouse movement from outside Flutter's pointer events into
  /// [mouse] — what [pointerLock] does with a locked pointer's:
  ///
  /// ```dart
  /// input.attachRawMouse(lock.deltas, relative: lock.locked);
  /// ```
  ///
  /// Each of [deltas] goes to [MouseDevice.injectDelta]. While [relative]
  /// is true the mouse is in [MouseDevice.relativeMode], so the pointer
  /// events' own movement does not count twice. Cancel the subscription to
  /// stop; [dispose] does too.
  InputSubscription attachRawMouse(
    Stream<Offset> deltas, {
    ValueListenable<bool>? relative,
  }) {
    final motion = deltas.listen(mouse.injectDelta);
    void follow() => mouse.relativeMode = relative!.value;
    if (relative != null) {
      relative.addListener(follow);
      follow();
    }
    late final InputSubscription subscription;
    subscription = InputSubscription(() {
      motion.cancel();
      if (relative != null) {
        relative.removeListener(follow);
        mouse.relativeMode = false;
      }
      _rawMouse.remove(subscription);
    });
    _rawMouse.add(subscription);
    return subscription;
  }

  // --- Pointer lock --------------------------------------------------------

  /// Whether a press on the game takes hold of [pointerLock]: a game that
  /// looks with the mouse sets it. `GameWidget` takes hold on a press on
  /// the game, and the editor on a press on its play-test; Escape lets go.
  bool lockPointerOnClick = false;

  /// The app's pointer lock, its raw movement feeding [mouse] (in
  /// [MouseDevice.relativeMode] while it holds). Made on first use: a game
  /// that never asks for it never starts it.
  PointerLock get pointerLock {
    final made = _pointerLock;
    if (made != null) return made;
    final lock = _pointerLockGiven ?? PointerLock.instance;
    _pointerLock = lock;
    _pointerLockFeed = attachRawMouse(lock.deltas, relative: lock.locked);
    return lock;
  }

  final PointerLock? _pointerLockGiven;
  PointerLock? _pointerLock;
  InputSubscription? _pointerLockFeed;

  /// Takes hold of [pointerLock] for a press on the game, if
  /// [lockPointerOnClick] says so and it does not hold already. What
  /// `GameWidget` and the editor's play-test call.
  void lockPointerForClick() {
    if (!lockPointerOnClick) return;
    final lock = pointerLock;
    if (lock.isSupported && !lock.isRequested) unawaited(lock.lock());
  }

  /// Lets [pointerLock] go, if it was ever used: an editor's Stop or Pause.
  Future<void> releasePointer() async => _pointerLock?.unlock();

  // --- Gamepads ------------------------------------------------------------

  GamepadSource? _gamepadSource;
  final List<StreamSubscription<Object>> _gamepadSubscriptions = [];
  final Map<String, GamepadDevice> _padsById = {};

  /// Starts listening to gamepads. Opt-in, because it opens platform
  /// channels a test has no use for.
  Future<void> attachGamepads([GamepadSource? source]) async {
    if (_gamepadSource != null) return;
    final pads = _gamepadSource = source ?? JustGamepadsSource();
    _gamepadSubscriptions
      ..add(pads.connections.listen(_onPadConnection))
      ..add(pads.stateChanges.listen(_onPadState));
    try {
      await pads.start();
    } catch (e) {
      // No gamepad plugin here — a test, a headless run, a platform
      // without one. The game plays on without pads.
      debugPrint('Gamepads unavailable: $e');
      for (final s in _gamepadSubscriptions) {
        s.cancel();
      }
      _gamepadSubscriptions.clear();
      _gamepadSource = null;
      return;
    }
    for (final info in pads.connected) {
      _padConnected(info);
    }
  }

  void _onPadConnection(gp.GamepadConnectionEvent event) {
    if (event.connected) {
      _padConnected(event.info);
    } else {
      final pad = _padsById.remove(event.info.id);
      if (pad != null) _remove(pad);
    }
  }

  void _padConnected(gp.GamepadInfo info) {
    if (_padsById.containsKey(info.id)) return;
    final pad = GamepadDevice(deviceId: _nextId++, info: info);
    final state = _gamepadSource?.latestState(info.id);
    if (state != null) pad.live.pad = state;
    pad.settle();
    _padsById[info.id] = pad;
    _adopt(pad);
    _announce(pad, DeviceChange.added);
  }

  void _onPadState(gp.GamepadStateEvent event) =>
      _padsById[event.gamepadId]?.handleState(event.state);

  // --- Devices ---------------------------------------------------------------

  /// Adds a device of the game's own.
  void addDevice(InputDevice device) {
    _adopt(device);
    _announce(device, DeviceChange.added);
  }

  void removeDevice(InputDevice device) => _remove(device);

  void _adopt(InputDevice device) {
    device
      ..sink = _sink
      ..settings = (() => _asset.settings);
    _devices.add(device);
  }

  void _remove(InputDevice device) {
    if (!_devices.remove(device)) return;
    device.connected = false;
    device.sink = null;
    _queue.removeWhere((d) => identical(d, device));
    if (identical(lastUsedDevice.value, device)) lastUsedDevice.value = null;
    _announce(device, DeviceChange.removed);
  }

  final List<DeviceListener> _deviceListeners = [];

  InputSubscription listenDevices(DeviceListener listener) {
    _deviceListeners.add(listener);
    return InputSubscription(() => _deviceListeners.remove(listener));
  }

  void _announce(InputDevice device, DeviceChange change) {
    for (final i in [..._instances]) {
      i.refresh();
    }
    for (final l in [..._deviceListeners]) {
      l(device, change);
    }
  }

  // --- The queue -------------------------------------------------------------

  final List<InputDevice> _queue = [];
  final List<RawInputListener> _raw = [];

  /// The device used last — a key pressed, a button, a stick pushed. For
  /// showing the right button prompts before anyone has joined.
  final ValueNotifier<InputDevice?> lastUsedDevice = ValueNotifier(null);

  InputSubscription listenRaw(RawInputListener listener) {
    _raw.add(listener);
    return InputSubscription(() => _raw.remove(listener));
  }

  final List<void Function(double now)> _afterUpdate = [];

  /// Called at the end of every [update], with its time — for things that
  /// read actions once they have all moved, like a menu's focus.
  InputSubscription listenUpdates(void Function(double now) listener) {
    _afterUpdate.add(listener);
    return InputSubscription(() => _afterUpdate.remove(listener));
  }

  void _sink(InputDevice device, void Function() applyLive) {
    final controls = device.controls;
    final before = [for (final c in controls) c.magnitude(live: true)];
    applyLive();
    _queue.add(device);
    final press = _asset.settings.pressPoint;
    var used = false;
    final raw = [..._raw];
    for (var i = 0; i < controls.length; i++) {
      final c = controls[i];
      final after = c.magnitude(live: true);
      if (after == before[i]) continue;
      if (!c.continuous &&
          !c.synthetic &&
          after >= press &&
          before[i] < press) {
        used = true;
      }
      for (final l in raw) {
        l(c, after);
      }
    }
    if (used && !identical(lastUsedDevice.value, device)) {
      lastUsedDevice.value = device;
    }
  }

  double _time = 0;
  int _updates = 0;

  /// The clock, as of the last [update].
  double get time => _time;

  /// How many updates there have been. "This frame" means this update.
  int get updateCount => _updates;

  int _suspended = 0;

  /// While suspended, devices still change but no action does — a rebind
  /// is listening, and the key it hears must not also jump.
  bool get isSuspended => _suspended > 0;

  void suspendActions() => _suspended++;

  /// Actions move again; whatever is still held waits to be let go.
  void resumeActions() {
    if (_suspended == 0) return;
    _suspended--;
    if (_suspended > 0) return;
    for (final i in [..._instances]) {
      for (final a in i.allActions) {
        if (a.isEnabled) a.suppressHeld();
      }
    }
  }

  /// Replays what happened since the last update, in order, and moves every
  /// action along to [now] (seconds, from the game's clock).
  void update(double now) {
    _time = now;
    _updates++;
    for (final d in [..._devices]) {
      if (d.beginUpdate()) _dispatch(d);
    }
    // By index: a callback may queue more (an on-screen button set from
    // one), and those belong to this update too.
    for (var i = 0; i < _queue.length; i++) {
      final d = _queue[i];
      if (d is StatefulDevice) d.applyNext();
      _dispatch(d);
    }
    _queue.clear();
    if (_suspended == 0) {
      for (final i in [..._instances]) {
        i.tick(now);
      }
      players.afterUpdate();
    }
    for (final l in [..._afterUpdate]) {
      l(now);
    }
  }

  void _dispatch(InputDevice device) {
    if (_suspended > 0) return;
    for (final i in [..._instances]) {
      i.onDevice(device, _time);
    }
  }

  void dispose() {
    players.stop();
    // The lock is the app's: let go of it, but leave it for the next service.
    unawaited(releasePointer());
    _pointerLockFeed?.cancel();
    _pointerLockFeed = null;
    for (final s in [..._rawMouse]) {
      s.cancel();
    }
    for (final s in _gamepadSubscriptions) {
      s.cancel();
    }
    _gamepadSubscriptions.clear();
    _gamepadSource = null;
    for (final i in [..._instances]) {
      i.dispose();
    }
    lastUsedDevice.dispose();
  }
}
