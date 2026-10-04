import '../devices/gamepad_device.dart';
import '../devices/input_device.dart';
import '../model/scheme_def.dart';
import '../model/settings_def.dart';
import '../rebinding/binding_overrides.dart';
import '../runtime/input_action.dart';
import '../runtime/input_actions.dart';
import '../runtime/input_service.dart';
import 'scheme_matching.dart';

/// Something that happens to players — one joined, one's pad went — that
/// any number of listeners hear.
final class InputEvent<T> {
  final List<void Function(T)> _listeners = [];

  InputSubscription listen(void Function(T value) listener) {
    _listeners.add(listener);
    return InputSubscription(() => _listeners.remove(listener));
  }

  void emit(T value) {
    for (final l in [..._listeners]) {
      l(value);
    }
  }
}

/// What is remembered of a device a player lost, to know it when it comes
/// back.
final class _LostDevice {
  _LostDevice(InputDevice device)
    : layout = device.layout,
      name = device.displayName,
      vendorId = device is GamepadDevice ? device.info.vendorId : null,
      productId = device is GamepadDevice ? device.info.productId : null;

  final String layout;
  final String name;
  final int? vendorId;
  final int? productId;

  /// The same model of pad: same name, and the same vendor and product
  /// where the platform says.
  bool matches(InputDevice device) {
    if (device.layout != layout || device.displayName != name) return false;
    if (device is! GamepadDevice) return true;
    return device.info.vendorId == vendorId &&
        device.info.productId == productId;
  }
}

/// One player: their devices, their scheme, and their own live copy of the
/// asset, reading only their devices.
final class PlayerInput {
  PlayerInput._(
    this.manager,
    this.index,
    this.actions,
    this._devices,
    this._scheme,
  );

  final PlayerInputManager manager;

  /// 0 for player 1. The lowest free one when they joined.
  final int index;

  /// Their actions: `player.actions.action('player/jump')`.
  final InputActions actions;

  List<InputDevice> _devices;
  ControlSchemeDef? _scheme;
  final List<_LostDevice> _lost = [];

  List<InputDevice> get devices => List.unmodifiable(_devices);

  /// The scheme they play, or null when the asset has none.
  ControlSchemeDef? get scheme => _scheme;

  /// A device of theirs is gone and they are waiting for it.
  bool get isLost => _lost.isNotEmpty;

  /// The layout of the device they lost (`Gamepad`), or null.
  String? get lostLayout => _lost.isEmpty ? null : _lost.first.layout;

  /// Their main device: the one they joined with.
  InputDevice? get device => _devices.isEmpty ? null : _devices.first;

  InputAction action(String path) => actions.action(path);

  InputAction? tryAction(String path) => actions.tryAction(path);

  /// "P1", "P2".
  String get label => 'P${index + 1}';

  BindingOverrides get overrides => BindingOverrides(actions.overrides);

  /// Changes their bindings now. [saveOverrides] keeps them.
  set overrides(BindingOverrides value) {
    actions.overrides = value.paths;
    manager._cached[index] = value;
  }

  Future<void> saveOverrides() => manager._save(this);

  /// Back to the asset's binding for [bindingId], or for everything.
  Future<void> resetOverrides({String? bindingId}) async {
    overrides = bindingId == null
        ? const BindingOverrides()
        : overrides.without(bindingId);
    await saveOverrides();
  }

  void _setDevices(List<InputDevice> devices, ControlSchemeDef? scheme) {
    _devices = devices;
    _scheme = scheme;
    actions
      ..group = scheme?.group
      ..devices = DeviceList(devices);
  }

  @override
  String toString() => 'PlayerInput($label, ${_devices.join(', ')})';
}

/// Local multiplayer: who is playing, with what, and who joins next.
///
/// Off until [start]. Then, as the asset's `players` settings say:
/// - player 1 is whoever plays first, with whatever they touch;
/// - a device nobody has joins as the next player when a join action is
///   performed on it (give the join action a hold, and a quick press means
///   something else);
/// - while there is only one player, a quick press on a device nobody has
///   moves player 1 onto it, scheme and all;
/// - a player whose pad goes is lost until it — or another pad — comes back.
final class PlayerInputManager {
  PlayerInputManager(this.service);

  final InputService service;

  PlayerSettingsDef get settings => service.asset.players;

  final Map<int, PlayerInput> _players = {};

  /// The players, player 1 first.
  List<PlayerInput> get players => [
    for (final i in (_players.keys.toList()..sort())) _players[i]!,
  ];

  PlayerInput? operator [](int index) => _players[index];

  PlayerInput? ownerOf(InputDevice device) {
    for (final p in _players.values) {
      if (p._devices.contains(device)) return p;
    }
    return null;
  }

  /// Heard when a player joins, leaves, loses a device, gets one back, or
  /// switches devices.
  final InputEvent<PlayerInput> joined = InputEvent();
  final InputEvent<PlayerInput> left = InputEvent();
  final InputEvent<PlayerInput> deviceLost = InputEvent();
  final InputEvent<PlayerInput> deviceRegained = InputEvent();
  final InputEvent<PlayerInput> schemeChanged = InputEvent();

  /// The game's own gate: off while paused, or once the level is won.
  bool joiningEnabled = true;

  bool get canJoin =>
      joiningEnabled &&
      settings.joining == JoinBehavior.onJoinAction &&
      _players.length < settings.maxPlayers;

  bool _started = false;
  bool get isStarted => _started;

  InputActions? _unpaired;
  final List<InputSubscription> _subscriptions = [];
  final List<InputSubscription> _joinSubscriptions = [];
  InputDevice? _pendingSwitch;

  /// Starts managing players. A game that has one player and no joining
  /// may leave it off and read `service.actions`.
  void start() {
    if (_started) return;
    _started = true;
    _unpaired = service.createActions(
      devices: DeviceWhere((d) => d.connected && ownerOf(d) == null),
    );
    service.lastUsedDevice.addListener(_onUsed);
    _subscriptions.add(service.listenDevices(_onDeviceChange));
    _hookJoinActions();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    service.lastUsedDevice.removeListener(_onUsed);
    for (final s in [..._subscriptions, ..._joinSubscriptions]) {
      s.cancel();
    }
    _subscriptions.clear();
    _joinSubscriptions.clear();
    _unpaired?.dispose();
    _unpaired = null;
    for (final p in players) {
      leave(p);
    }
  }

  /// The service loaded a new asset.
  void assetLoaded() {
    if (!_started) return;
    _hookJoinActions();
  }

  void _hookJoinActions() {
    for (final s in _joinSubscriptions) {
      s.cancel();
    }
    _joinSubscriptions.clear();
    for (final path in settings.joinActions) {
      final action = _unpaired?.tryAction(path);
      if (action == null) continue;
      _joinSubscriptions.add(action.onPerformed(_onJoinPerformed));
    }
  }

  List<InputAction> get _joinActions => [
    for (final path in settings.joinActions) ?_unpaired?.tryAction(path),
  ];

  /// Makes a player of [devices] (their scheme found from the first) —
  /// what joining does, for a game that picks players itself.
  ///
  /// With [ignoreHeld] (the default), what is held as they join waits to be
  /// let go — the Start held to join does not also pause. Player 1, who
  /// joins by simply playing, keeps that first press.
  PlayerInput join(
    Iterable<InputDevice> devices, {
    int? index,
    ControlSchemeDef? scheme,
    bool ignoreHeld = true,
  }) {
    final list = [...devices];
    final slot = index ?? _freeIndex();
    if (_players.containsKey(slot)) {
      throw StateError('Player ${slot + 1} is already playing.');
    }
    final match = scheme != null || list.isEmpty
        ? SchemeMatch(scheme, list)
        : matchScheme(service.asset, list.first, [...list.skip(1), ..._free()]);
    final overrides = (_cached[slot] ?? const BindingOverrides()).keptBy(
      service.asset,
    );
    final actions = service.createActions(
      devices: DeviceList(match.devices),
      group: match.scheme?.group,
      overrides: overrides.paths,
      ignoreHeld: ignoreHeld,
    );
    final player = PlayerInput._(
      this,
      slot,
      actions,
      match.devices,
      match.scheme,
    );
    _players[slot] = player;
    _unpaired?.refresh();
    joined.emit(player);
    return player;
  }

  /// Takes [player] out; their devices are free again.
  void leave(PlayerInput player) {
    if (!identical(_players[player.index], player)) return;
    _players.remove(player.index);
    player.actions.dispose();
    _unpaired?.refresh();
    left.emit(player);
  }

  int _freeIndex() {
    var i = 0;
    while (_players.containsKey(i)) {
      i++;
    }
    return i;
  }

  Iterable<InputDevice> _free() =>
      service.devices.where((d) => d.connected && ownerOf(d) == null);

  void _onJoinPerformed(InputAction action) {
    final device = action.activeDevice;
    if (device == null || ownerOf(device) != null || !canJoin) return;
    // The first player joins on any press; a join action is for the rest.
    if (_players.isEmpty && !settings.autoJoinFirst) return;
    if (identical(_pendingSwitch, device)) _pendingSwitch = null;
    join([device]);
  }

  void _onUsed() {
    final device = service.lastUsedDevice.value;
    if (!_started || device == null || ownerOf(device) != null) return;

    if (_players.isEmpty) {
      if (settings.autoJoinFirst) join([device], ignoreHeld: false);
      return;
    }
    // A lost player takes the first device of their kind that is used.
    for (final p in players) {
      if (p.isLost && p.lostLayout == device.layout) {
        _regain(p, device);
        return;
      }
    }
    if (_players.length == 1 && settings.autoSwitch) {
      _pendingSwitch = device;
    }
  }

  /// Called by the service after every update: a press on a free device
  /// becomes a switch once it is clear it was not the start of a join.
  void afterUpdate() {
    final device = _pendingSwitch;
    if (device == null) return;
    if (ownerOf(device) != null || !device.connected || _players.length != 1) {
      _pendingSwitch = null;
      return;
    }
    final joining = _joinActions.any(
      (a) => a.isInProgress() && identical(a.activeDevice, device),
    );
    if (joining && canJoin) return;
    _pendingSwitch = null;
    switchDevice(players.single, device);
  }

  /// Moves [player] onto [device] and whatever its scheme brings.
  void switchDevice(PlayerInput player, InputDevice device) {
    final match = matchScheme(service.asset, device, [
      ..._free(),
      ...player._devices,
    ]);
    player._setDevices(match.devices, match.scheme);
    player._lost.clear();
    _unpaired?.refresh();
    schemeChanged.emit(player);
  }

  void _onDeviceChange(InputDevice device, DeviceChange change) {
    switch (change) {
      case DeviceChange.removed:
        final owner = ownerOf(device);
        if (owner == null) return;
        owner._lost.add(_LostDevice(device));
        owner._setDevices([...owner._devices]..remove(device), owner._scheme);
        deviceLost.emit(owner);
      case DeviceChange.added:
        for (final p in players) {
          if (p._lost.any((l) => l.matches(device))) {
            _regain(p, device);
            return;
          }
        }
    }
  }

  void _regain(PlayerInput player, InputDevice device) {
    player._lost.removeWhere((l) => l.layout == device.layout);
    player._setDevices([device, ...player._devices], player._scheme);
    _unpaired?.refresh();
    deviceRegained.emit(player);
  }

  /// A lost player is given up on: they leave.
  void dropLost(PlayerInput player) => leave(player);

  // --- Overrides ----------------------------------------------------------

  final Map<int, BindingOverrides> _cached = {};

  String overridesKey(int index) {
    final name = service.asset.name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return 'input.overrides.${name.isEmpty ? 'game' : name}.p${index + 1}';
  }

  /// Reads every player slot's saved bindings, so a player who joins gets
  /// theirs at once.
  Future<void> preloadOverrides() async {
    for (var i = 0; i < settings.maxPlayers; i++) {
      final json = await service.overrideStore.load(overridesKey(i));
      _cached[i] = BindingOverrides.fromJson(json);
      final player = _players[i];
      if (player != null) {
        player.actions.overrides = _cached[i]!.keptBy(service.asset).paths;
      }
    }
  }

  Future<void> _save(PlayerInput player) async {
    final overrides = player.overrides;
    _cached[player.index] = overrides;
    final key = overridesKey(player.index);
    if (overrides.isEmpty) {
      await service.overrideStore.clear(key);
    } else {
      await service.overrideStore.save(key, overrides.toJson());
    }
  }
}
