import 'dart:ui' show Offset;

import '../devices/input_device.dart';
import '../model/action_def.dart';
import '../model/binding_def.dart';
import '../model/param_def.dart';
import '../model/settings_def.dart';
import '../paths/control_path.dart';
import 'composites.dart';
import 'input_actions.dart';
import 'interactions.dart';
import 'processors.dart';

/// A way to stop listening.
final class InputSubscription {
  InputSubscription(this._cancel);

  final void Function() _cancel;
  bool _done = false;

  void cancel() {
    if (_done) return;
    _done = true;
    _cancel();
  }
}

typedef InputActionCallback = void Function(InputAction action);

/// A group of actions switched on and off together.
final class InputActionMap {
  InputActionMap._(this.owner, this.name, this.enabled);

  final InputActions owner;
  final String name;
  bool enabled;

  final Map<String, InputAction> _actions = {};

  Iterable<InputAction> get actions => _actions.values;

  InputAction? action(String name) => _actions[name];

  /// Switches the map on. With [ignoreHeld], a control already held counts
  /// only once it has been let go — the button that closed the menu does
  /// not also jump.
  void enable({bool ignoreHeld = true}) {
    if (enabled) return;
    enabled = true;
    for (final a in _actions.values) {
      a._enable(ignoreHeld: ignoreHeld);
    }
  }

  /// Switches the map off. Anything in progress is canceled.
  void disable() {
    if (!enabled) return;
    enabled = false;
    for (final a in _actions.values) {
      a._disable();
    }
  }
}

/// A live action: what its bindings say now, and what just happened.
///
/// "This frame" means since the service's last update — one fixed step
/// while a game runs.
final class InputAction implements InteractionHost {
  InputAction._(this.map, this.def);

  final InputActionMap map;
  InputActionDef def;

  String get name => def.name;
  String get path => '${map.name}/${def.name}';
  ActionValueType get type => def.type;
  InputActions get owner => map.owner;
  InputSettingsDef get _settings => owner.service.asset.settings;
  int get _frame => owner.service.updateCount;

  List<_Slot> _slots = const [];
  InteractionMachine? _machine;

  Offset _value = Offset.zero;
  double _actuation = 0;
  bool _pressed = false;
  _Slot? _driver;
  InputControl? _activeControl;

  int _pressedIn = -1, _releasedIn = -1;
  int _startedIn = -1, _performedIn = -1, _canceledIn = -1;

  InputActionPhase _phase = InputActionPhase.waiting;

  @override
  InputActionPhase get phase =>
      map.enabled ? _phase : InputActionPhase.disabled;

  bool get isEnabled => map.enabled;

  /// Held past the press point, and not yet let go below the release point.
  bool isPressed() => map.enabled && _pressed;

  bool wasPressedThisFrame() => _pressedIn == _frame;
  bool wasReleasedThisFrame() => _releasedIn == _frame;
  bool wasStartedThisFrame() => _startedIn == _frame;
  bool wasPerformedThisFrame() => _performedIn == _frame;
  bool wasCanceledThisFrame() => _canceledIn == _frame;

  /// Started or performed, and not over.
  bool isInProgress() =>
      phase == InputActionPhase.started || phase == InputActionPhase.performed;

  /// How far it is pushed: 0 to 1 for a button, the size of an axis, the
  /// length of a vector.
  double get magnitude => map.enabled ? _actuation : 0;

  /// A button's press (0 to 1) or an axis's value; a vector's length.
  double readAxis() {
    if (!map.enabled) return 0;
    return type == ActionValueType.vector2 ? _value.distance : _value.dx;
  }

  /// A vector's value, y down. An axis or button reads as `(value, 0)`.
  Offset readVector2() {
    if (!map.enabled) return Offset.zero;
    return type == ActionValueType.vector2 ? _value : Offset(_value.dx, 0);
  }

  bool readButton() => isPressed();

  /// The control driving it now, or last.
  InputControl? get activeControl => _activeControl;

  InputDevice? get activeDevice => _activeControl?.device;

  final List<InputActionCallback> _onStarted = [];
  final List<InputActionCallback> _onPerformed = [];
  final List<InputActionCallback> _onCanceled = [];

  InputSubscription onStarted(InputActionCallback callback) =>
      _listen(_onStarted, callback);
  InputSubscription onPerformed(InputActionCallback callback) =>
      _listen(_onPerformed, callback);
  InputSubscription onCanceled(InputActionCallback callback) =>
      _listen(_onCanceled, callback);

  InputSubscription _listen(
    List<InputActionCallback> list,
    InputActionCallback callback,
  ) {
    list.add(callback);
    return InputSubscription(() => list.remove(callback));
  }

  void _fire(List<InputActionCallback> list) {
    for (final cb in [...list]) {
      cb(this);
    }
  }

  // --- InteractionHost: what the driving machine reports -----------------

  @override
  void started() {
    _phase = InputActionPhase.started;
    _startedIn = _frame;
    _fire(_onStarted);
  }

  @override
  void performed() {
    _phase = InputActionPhase.performed;
    _performedIn = _frame;
    _fire(_onPerformed);
  }

  @override
  void canceled() {
    _phase = InputActionPhase.canceled;
    _canceledIn = _frame;
    _fire(_onCanceled);
    _phase = InputActionPhase.waiting;
  }

  @override
  void waiting() => _phase = InputActionPhase.waiting;

  // --- Building ------------------------------------------------------------

  /// Resolves the bindings against the devices this action may read.
  ///
  /// With [keepState] — the devices changed, not the asset — each binding
  /// keeps its interactions' state, so a key held while a pad is plugged in
  /// stays held rather than being pressed a second time.
  void _resolve(
    List<InputDevice> devices,
    String? group,
    Map<String, String> overrides, {
    required bool keepState,
  }) {
    final settings = _settings;
    final perSlot =
        def.bindings.any((b) => b.interactions.isNotEmpty) ||
        def.interactions.isNotEmpty;
    final old = keepState
        ? {for (final s in _slots) s.def.id: s}
        : const <String, _Slot>{};
    final driverId = _driver?.def.id;
    _slots = [
      for (final b in def.bindings)
        if (b.inGroup(group))
          _Slot.resolve(
            b,
            devices,
            overrides,
            settings,
            perSlot ? () => _machinesFor(b, settings) : null,
            reuse: old[b.id],
          ),
    ];
    _driver = null;
    for (final s in _slots) {
      if (s.def.id == driverId) _driver = s;
    }
    final keepMachine = keepState && !perSlot && _machine != null;
    if (!keepMachine) {
      _machine = perSlot
          ? null
          : def.passThrough
          ? PassThroughInteraction()
          : type == ActionValueType.button
          ? DefaultButtonInteraction(settings)
          : DefaultValueInteraction();
    }
  }

  List<InteractionMachine> _machinesFor(
    InputBindingDef b,
    InputSettingsDef settings,
  ) {
    final defs = b.interactions.isNotEmpty ? b.interactions : def.interactions;
    final machines = [
      for (final d in defs) ?InputInteractions.create(d, settings),
    ];
    if (machines.isNotEmpty) return machines;
    return [
      if (def.passThrough)
        PassThroughInteraction()
      else if (type == ActionValueType.button)
        DefaultButtonInteraction(settings)
      else
        DefaultValueInteraction(),
    ];
  }

  /// Whether a binding reads [device].
  bool reads(InputDevice device) => _slots.any((s) => s.reads(device));

  /// Every control the bindings read.
  Iterable<InputControl> get controls => _slots.expand((s) => s.controls);

  // --- Running -------------------------------------------------------------

  void _enable({required bool ignoreHeld}) {
    _phase = InputActionPhase.waiting;
    for (final s in _slots) {
      s.reset();
      if (ignoreHeld) s.suppressIfHeld(_settings);
    }
    _machine?.reset();
    _driver = null;
    _pressed = false;
    _value = Offset.zero;
    _actuation = 0;
    evaluate(owner.service.time);
  }

  void _disable() {
    if (_phase == InputActionPhase.started ||
        _phase == InputActionPhase.performed) {
      canceled();
    }
    if (_pressed) {
      _pressed = false;
      _releasedIn = _frame;
    }
    _phase = InputActionPhase.waiting;
    _value = Offset.zero;
    _actuation = 0;
    _driver = null;
    for (final s in _slots) {
      s.reset();
    }
    _machine?.reset();
  }

  /// Ignores what is held until it is let go — after a pause, a rebind.
  void suppressHeld() {
    for (final s in _slots) {
      s.suppressIfHeld(_settings);
    }
    evaluate(owner.service.time);
  }

  /// Reads the bindings and moves the phase along.
  void evaluate(double now) {
    if (!map.enabled) return;
    final settings = _settings;
    _Slot? changedLast;
    for (final s in _slots) {
      if (s.evaluate(settings, type)) changedLast = s;
    }

    // The strongest binding gives the value; a pass-through action takes
    // the one that moved last.
    _Slot? strongest;
    for (final s in _slots) {
      if (strongest == null || s.actuation > strongest.actuation) strongest = s;
    }
    final source = def.passThrough
        ? (changedLast ?? _driverOr(strongest))
        : _driverOr(strongest);
    final raw = source?.value ?? Offset.zero;
    final value = def.processors.isEmpty
        ? raw
        : InputProcessors.apply(def.processors, raw, settings);
    final changed = value != _value;
    _value = value;
    _actuation = def.processors.isEmpty
        ? (source?.actuation ?? 0)
        : _magnitudeOf(value);
    if (source?.activeControl != null) _activeControl = source!.activeControl;

    // Pressed and released, for polling, whatever the interactions say.
    final top = strongest?.actuation ?? 0;
    if (!_pressed && top >= settings.pressPoint) {
      _pressed = true;
      _pressedIn = _frame;
    } else if (_pressed && top < settings.releasePoint) {
      _pressed = false;
      _releasedIn = _frame;
    }

    final machine = _machine;
    if (machine != null) {
      machine.onInput(_actuation, changed, now, this);
    } else {
      _runSlots(now, (s, host) => s.feed(now, host));
    }
  }

  _Slot? _driverOr(_Slot? strongest) =>
      _machine == null ? (_driver ?? strongest) : strongest;

  double _magnitudeOf(Offset v) =>
      type == ActionValueType.vector2 ? v.distance : v.dx.abs();

  /// Runs each binding's own interactions. The first to start drives the
  /// action until it is over; the others are heard but not reported.
  void _runSlots(
    double now,
    void Function(_Slot slot, InteractionHost host) run,
  ) {
    for (final s in _slots) {
      final reporting = _driver == null || identical(_driver, s);
      final host = _SlotHost(this, s, reporting);
      run(s, host);
      if (reporting && _driver == null && s.phase != InputActionPhase.waiting) {
        _driver = s;
      }
      if (identical(_driver, s) && s.phase == InputActionPhase.waiting) {
        _driver = null;
      }
    }
  }

  /// The earliest time an interaction wants waking at, or null.
  double? get deadline {
    double? best;
    void consider(double? d) {
      if (d != null && (best == null || d < best!)) best = d;
    }

    consider(_machine?.deadline);
    for (final s in _slots) {
      for (final m in s.machines) {
        consider(m.deadline);
      }
    }
    return best;
  }

  void tick(double now) {
    if (!map.enabled) return;
    final d = deadline;
    if (d == null || d > now) return;
    final machine = _machine;
    if (machine != null) {
      machine.onTime(now, this);
    } else {
      _runSlots(now, (s, host) => s.tick(now, host));
    }
  }

  @override
  String toString() => 'InputAction($path, $phase)';
}

/// Passes a binding's interaction reports to the action — or keeps them to
/// the binding when another binding is driving.
final class _SlotHost implements InteractionHost {
  _SlotHost(this.action, this.slot, this.reporting);

  final InputAction action;
  final _Slot slot;
  final bool reporting;

  @override
  InputActionPhase get phase => slot.phase;

  @override
  void started() {
    slot.phase = InputActionPhase.started;
    if (reporting) action.started();
  }

  @override
  void performed() {
    slot.phase = InputActionPhase.performed;
    if (reporting) action.performed();
  }

  @override
  void canceled() {
    slot.phase = InputActionPhase.waiting;
    if (reporting) action.canceled();
  }

  @override
  void waiting() {
    slot.phase = InputActionPhase.waiting;
    if (reporting) action.waiting();
  }
}

/// One binding, resolved to the controls it reads.
final class _Slot {
  _Slot._(
    this.def,
    this.valueType,
    this.controls,
    this.parts,
    this.composite,
    this.machines,
  );

  factory _Slot.resolve(
    InputBindingDef def,
    List<InputDevice> devices,
    Map<String, String> overrides,
    InputSettingsDef settings,
    List<InteractionMachine> Function()? machines, {
    _Slot? reuse,
  }) {
    final slot = _Slot._fresh(
      def,
      devices,
      overrides,
      settings,
      machines,
      reuse,
    );
    if (reuse != null && identical(reuse.def, def)) slot._takeStateOf(reuse);
    return slot;
  }

  factory _Slot._fresh(
    InputBindingDef def,
    List<InputDevice> devices,
    Map<String, String> overrides,
    InputSettingsDef settings,
    List<InteractionMachine> Function()? machines,
    _Slot? reuse,
  ) {
    final same = reuse != null && identical(reuse.def, def);
    List<InteractionMachine> machinesNow() =>
        same ? reuse.machines : (machines?.call() ?? const []);
    List<InputControl> find(String id, String path) {
      final parsed = ControlPath.tryParse(overrides[id] ?? path);
      if (parsed == null) return const [];
      return [
        for (final d in devices)
          if (d.layout == parsed.layout && d.connected)
            ?d.control(parsed.control),
      ];
    }

    switch (def) {
      case ControlBindingDef():
        final controls = find(def.id, def.path);
        final type = controls.isEmpty
            ? ControlValueType.button
            : controls.first.type;
        return _Slot._(def, type, controls, const [], null, machinesNow());
      case CompositeBindingDef():
        final entry = InputComposites.entry(def.composite);
        final parts = [
          for (final p in def.parts)
            _Part(p.part, find(p.id, p.path), p.processors),
        ];
        return _Slot._(
          def,
          entry?.valueType ?? ControlValueType.button,
          [for (final p in parts) ...p.controls],
          parts,
          same ? reuse.composite : entry?.create(),
          machinesNow(),
        );
    }
  }

  final InputBindingDef def;
  final ControlValueType valueType;
  final List<InputControl> controls;
  final List<_Part> parts;
  final CompositeBehavior? composite;
  final List<InteractionMachine> machines;

  Offset value = Offset.zero;
  double actuation = 0;
  InputControl? activeControl;
  InputActionPhase phase = InputActionPhase.waiting;

  /// Held when its map came on; ignored until let go.
  bool suppressed = false;

  bool reads(InputDevice device) =>
      controls.any((c) => identical(c.device, device));

  /// The value before [suppressed] is taken into account.
  (Offset, double, InputControl?) _raw(InputSettingsDef settings) {
    if (composite == null && parts.isEmpty) {
      InputControl? best;
      var bestMagnitude = -1.0;
      for (final c in controls) {
        final m = c.magnitude();
        if (m > bestMagnitude) {
          best = c;
          bestMagnitude = m;
        }
      }
      if (best == null) return (Offset.zero, 0, null);
      final v = InputProcessors.apply(def.processors, best.read(), settings);
      return (v, _magnitude(v), best);
    }
    final behavior = composite;
    if (behavior == null) return (Offset.zero, 0, null);
    final values = <String, List<Offset>>{};
    InputControl? loudest;
    var loudestMagnitude = 0.0;
    for (final p in parts) {
      var best = Offset.zero;
      for (final c in p.controls) {
        final m = c.magnitude();
        if (m > best.distance) best = c.read();
        if (m > loudestMagnitude) {
          loudest = c;
          loudestMagnitude = m;
        }
      }
      (values[p.part] ??= []).add(
        InputProcessors.apply(p.processors, best, settings),
      );
    }
    final params = (def as CompositeBindingDef).params;
    final v = InputProcessors.apply(
      def.processors,
      behavior.evaluate(values, params, settings),
      settings,
    );
    return (v, _magnitude(v), loudest);
  }

  double _magnitude(Offset v) =>
      valueType == ControlValueType.vector2 ? v.distance : v.dx.abs();

  /// Reads the controls. True if the value changed.
  bool evaluate(InputSettingsDef settings, ActionValueType actionType) {
    var (v, a, control) = _raw(settings);
    if (suppressed) {
      // Let go means let go in both states: a press still in the queue has
      // not been let go of just because the applied state has not seen it.
      final release = settings.releasePoint;
      if (a < release &&
          controls.every((c) => c.magnitude(live: true) < release)) {
        suppressed = false;
      } else {
        v = Offset.zero;
        a = 0;
      }
    }
    // A single number where the action wants a vector reads along x; a
    // vector where it wants a number reads as its length.
    if (actionType != ActionValueType.vector2 &&
        valueType == ControlValueType.vector2) {
      v = Offset(v.distance, 0);
    }
    if (control != null) activeControl = control;
    final changed = v != value;
    value = v;
    actuation = a;
    return changed;
  }

  void _takeStateOf(_Slot other) {
    _owner = other._owner;
    if (_machinePhases.length == other._machinePhases.length) {
      _machinePhases.setAll(0, other._machinePhases);
    }
    value = other.value;
    actuation = other.actuation;
    activeControl = other.activeControl;
    phase = other.phase;
    suppressed = other.suppressed;
    _last = other._last;
  }

  /// Held now — by the live state, so a press still waiting in the queue
  /// counts too (the key a rebind just heard, the Enter that closed a menu).
  void suppressIfHeld(InputSettingsDef settings) {
    if (controls.any((c) => c.magnitude(live: true) >= settings.pressPoint)) {
      suppressed = true;
    }
  }

  Offset _last = Offset.zero;

  void feed(double now, InteractionHost host) {
    final changed = value != _last;
    _last = value;
    for (var i = 0; i < machines.length; i++) {
      machines[i].onInput(actuation, changed, now, _MachineHost(this, i, host));
    }
  }

  void tick(double now, InteractionHost host) {
    for (var i = 0; i < machines.length; i++) {
      final d = machines[i].deadline;
      if (d != null && d <= now) {
        machines[i].onTime(now, _MachineHost(this, i, host));
      }
    }
  }

  /// Which of [machines] is driving this binding, and where each one is.
  /// The first to start owns it; if it gives up while another is still
  /// going, that one carries on without the action seeing a cancel — a
  /// tap held too long becomes a hold.
  int? _owner;
  late final List<InputActionPhase> _machinePhases = List.filled(
    machines.length,
    InputActionPhase.waiting,
  );

  void reset() {
    phase = InputActionPhase.waiting;
    _owner = null;
    _machinePhases.fillRange(
      0,
      _machinePhases.length,
      InputActionPhase.waiting,
    );
    value = Offset.zero;
    _last = Offset.zero;
    actuation = 0;
    suppressed = false;
    for (final m in machines) {
      m.reset();
    }
  }
}

/// One interaction's reports, passed to the binding only while it owns it.
final class _MachineHost implements InteractionHost {
  _MachineHost(this.slot, this.index, this.outer);

  final _Slot slot;
  final int index;
  final InteractionHost outer;

  bool get _owns => slot._owner == null || slot._owner == index;

  @override
  InputActionPhase get phase => slot._machinePhases[index];

  @override
  void started() {
    slot._machinePhases[index] = InputActionPhase.started;
    if (!_owns) return;
    slot._owner = index;
    outer.started();
  }

  @override
  void performed() {
    slot._machinePhases[index] = InputActionPhase.performed;
    if (!_owns) return;
    slot._owner = index;
    // It happened: the others' chances are over.
    for (var i = 0; i < slot.machines.length; i++) {
      if (i == index) continue;
      slot.machines[i].reset();
      slot._machinePhases[i] = InputActionPhase.waiting;
    }
    outer.performed();
  }

  @override
  void canceled() {
    slot._machinePhases[index] = InputActionPhase.waiting;
    if (slot._owner != index) return;
    for (var i = 0; i < slot.machines.length; i++) {
      final p = slot._machinePhases[i];
      if (i != index &&
          (p == InputActionPhase.started || p == InputActionPhase.performed)) {
        slot._owner = i;
        return;
      }
    }
    slot._owner = null;
    outer.canceled();
  }

  @override
  void waiting() {
    slot._machinePhases[index] = InputActionPhase.waiting;
    if (slot._owner != index) return;
    slot._owner = null;
    outer.waiting();
  }
}

final class _Part {
  _Part(this.part, this.controls, this.processors);

  final String part;
  final List<InputControl> controls;
  final List<ProcessorDef> processors;
}

/// Builds the maps and actions of an [InputActions] — kept here so the
/// private constructors stay private.
abstract final class ActionBuilder {
  static InputActionMap map(InputActions owner, String name, bool enabled) =>
      InputActionMap._(owner, name, enabled);

  static InputAction action(InputActionMap map, InputActionDef def) {
    final a = InputAction._(map, def);
    map._actions[def.name] = a;
    return a;
  }

  static void setActions(InputActionMap map, Map<String, InputAction> actions) {
    map._actions
      ..clear()
      ..addAll(actions);
  }

  static void resolve(
    InputAction action,
    List<InputDevice> devices,
    String? group,
    Map<String, String> overrides, {
    required bool keepState,
  }) => action._resolve(devices, group, overrides, keepState: keepState);

  /// Stops [action] cleanly before its definition changes under it.
  static void retire(InputAction action) => action._disable();

  /// [action]'s single-control bindings in use now, each as the controls it
  /// resolved to and the processors it applies — for reading movement a
  /// frame at a time (`FrameMotion`).
  static Iterable<(List<InputControl>, List<ProcessorDef>)> controlBindings(
    InputAction action,
  ) sync* {
    for (final s in action._slots) {
      if (s.def is ControlBindingDef) yield (s.controls, s.def.processors);
    }
  }
}
