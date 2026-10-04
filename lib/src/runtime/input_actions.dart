import '../devices/input_device.dart';
import '../model/input_action_asset.dart';
import 'input_action.dart';
import 'input_service.dart';

/// Which devices an [InputActions] reads.
abstract interface class DeviceFilter {
  bool includes(InputDevice device);
}

/// Every device — one player playing with whatever they touch.
final class AllDevices implements DeviceFilter {
  const AllDevices();

  @override
  bool includes(InputDevice device) => true;
}

/// Only the devices in [devices] — a player's own.
final class DeviceList implements DeviceFilter {
  DeviceList([Iterable<InputDevice> devices = const []])
    : devices = {...devices};

  final Set<InputDevice> devices;

  @override
  bool includes(InputDevice device) => devices.contains(device);
}

/// Whatever [test] lets through.
final class DeviceWhere implements DeviceFilter {
  const DeviceWhere(this.test);

  final bool Function(InputDevice device) test;

  @override
  bool includes(InputDevice device) => test(device);
}

/// The asset, live, for one set of devices: its maps and actions, read from
/// those devices only. The service has a shared one for all devices; each
/// player has their own.
final class InputActions {
  InputActions(
    this.service, {
    this._devices = const AllDevices(),
    this._group,
    this._overrides = const {},
  });

  final InputService service;

  final Map<String, InputActionMap> _maps = {};
  DeviceFilter _devices;
  String? _group;
  Map<String, String> _overrides;
  bool _disposed = false;

  /// The maps, in the asset's order.
  Iterable<InputActionMap> get maps => _maps.values;

  InputActionMap? map(String name) => _maps[name];

  /// Every action of every map.
  Iterable<InputAction> get allActions => _maps.values.expand((m) => m.actions);

  /// The action at `map/action`, or the first action called [path] in any
  /// map. Null when there is none.
  InputAction? tryAction(String path) {
    final slash = path.indexOf('/');
    if (slash >= 0) {
      return _maps[path.substring(0, slash)]?.action(path.substring(slash + 1));
    }
    for (final m in _maps.values) {
      final a = m.action(path);
      if (a != null) return a;
    }
    return null;
  }

  /// The action at [path]; see [tryAction]. Throws when there is none, which
  /// is a spelling mistake in the game.
  InputAction action(String path) =>
      tryAction(path) ??
      (throw ArgumentError.value(path, 'path', 'No such input action'));

  DeviceFilter get devices => _devices;

  set devices(DeviceFilter value) {
    _devices = value;
    refresh();
  }

  /// The control scheme's binding group in use; null reads every binding.
  String? get group => _group;

  set group(String? value) {
    if (value == _group) return;
    _group = value;
    refresh();
  }

  /// A player's own bindings: binding id → control path.
  Map<String, String> get overrides => _overrides;

  set overrides(Map<String, String> value) {
    _overrides = Map.unmodifiable(value);
    refresh();
  }

  /// Takes up [asset]: maps and actions it has keep their objects — and so
  /// every callback on them — new ones appear, missing ones go. A map keeps
  /// whether it was on; a new one starts as the asset says.
  ///
  /// With [ignoreHeld], what is held now waits to be let go.
  void load(InputActionAsset asset, {bool ignoreHeld = true}) {
    final nextMaps = <String, InputActionMap>{};
    for (final m in asset.maps) {
      final map =
          _maps.remove(m.name) ?? ActionBuilder.map(this, m.name, m.enabled);
      final previous = {for (final a in map.actions) a.name: a};
      final actions = <String, InputAction>{};
      for (final def in m.actions) {
        final existing = previous.remove(def.name);
        if (existing != null) {
          ActionBuilder.retire(existing);
          existing.def = def;
          actions[def.name] = existing;
        } else {
          actions[def.name] = ActionBuilder.action(map, def);
        }
      }
      for (final gone in previous.values) {
        ActionBuilder.retire(gone);
      }
      ActionBuilder.setActions(map, actions);
      nextMaps[m.name] = map;
    }
    for (final gone in _maps.values) {
      for (final a in gone.actions) {
        ActionBuilder.retire(a);
      }
    }
    _maps
      ..clear()
      ..addAll(nextMaps);
    // A new asset starts every action over; what is held waits to be let
    // go, so nothing fires on the swap.
    final devices = service.devices.where(_devices.includes).toList();
    for (final a in allActions) {
      ActionBuilder.resolve(a, devices, _group, _overrides, keepState: false);
      if (a.isEnabled && ignoreHeld) a.suppressHeld();
    }
  }

  /// Resolves every binding again — the devices, the scheme or the
  /// overrides changed. Bindings that stay keep their state; one that went
  /// lets go.
  void refresh() {
    if (_disposed) return;
    final devices = service.devices.where(_devices.includes).toList();
    for (final a in allActions) {
      ActionBuilder.resolve(a, devices, _group, _overrides, keepState: true);
      if (a.isEnabled) a.evaluate(service.time);
    }
  }

  /// [device] changed: every action reading it looks again.
  void onDevice(InputDevice device, double now) {
    if (_disposed || !_devices.includes(device)) return;
    for (final a in allActions.toList()) {
      if (a.isEnabled && a.reads(device)) a.evaluate(now);
    }
  }

  /// Wakes interactions whose time has come.
  void tick(double now) {
    if (_disposed) return;
    for (final a in allActions.toList()) {
      a.tick(now);
    }
  }

  /// Switches every map on or off.
  void enableAll({bool ignoreHeld = true}) {
    for (final m in maps) {
      m.enable(ignoreHeld: ignoreHeld);
    }
  }

  void disableAll() {
    for (final m in maps) {
      m.disable();
    }
  }

  bool get isDisposed => _disposed;

  /// Stops it for good; the service forgets it.
  void dispose() {
    if (_disposed) return;
    for (final a in allActions) {
      ActionBuilder.retire(a);
    }
    _disposed = true;
    service.forget(this);
  }
}
