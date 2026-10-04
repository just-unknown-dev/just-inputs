import '../model/param_def.dart';
import '../model/settings_def.dart';
import 'param_info.dart';

/// Where an action is in its life.
enum InputActionPhase {
  /// Its map is switched off.
  disabled,

  /// Nothing is happening.
  waiting,

  /// Something began — a hold is being held — but it has not happened yet.
  started,

  /// It happened. A held button stays here until let go.
  performed,

  /// It stopped: let go, or a hold let go too soon. Passes at once; see
  /// `wasCanceledThisFrame`.
  canceled,
}

/// What an interaction drives: it says what happened, and the action does
/// the rest.
abstract interface class InteractionHost {
  InputActionPhase get phase;
  void started();
  void performed();
  void canceled();

  /// Back to waiting with nothing said — a press-only press let go.
  void waiting();
}

/// One running interaction. Made fresh per binding.
abstract class InteractionMachine {
  /// The input changed. [actuation] is how far it is pushed; [changed]
  /// whether the value moved at all.
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  );

  /// The time it asked to be woken at has come.
  void onTime(double now, InteractionHost host) {}

  /// When it wants [onTime], or null.
  double? get deadline => null;

  /// Its map was switched off or on: forget everything.
  void reset() {}
}

/// A registered interaction.
final class InteractionEntry {
  const InteractionEntry(this.info, this.create);

  final StepInfo info;
  final InteractionMachine Function(
    InteractionDef def,
    InputSettingsDef settings,
  )
  create;
}

/// The interactions an asset can name.
abstract final class InputInteractions {
  static final Map<String, InteractionEntry> _entries = {
    for (final e in _builtIns) e.info.type: e,
  };

  static void register(InteractionEntry entry) =>
      _entries[entry.info.type] = entry;

  static InteractionEntry? entry(String type) => _entries[type];

  static Iterable<InteractionEntry> get all => _entries.values;

  /// A machine for [def], or null for a name nobody registered.
  static InteractionMachine? create(
    InteractionDef def,
    InputSettingsDef settings,
  ) => _entries[def.type]?.create(def, settings);

  static const _pressPoint = ParamInfo.number(
    'pressPoint',
    'Press point',
    min: 0,
    max: 1,
    fromSettings: 'pressPoint',
  );

  static final List<InteractionEntry> _builtIns = [
    InteractionEntry(
      const StepInfo('press', 'Press', [
        ParamInfo.choice('behavior', 'Trigger', [
          'pressOnly',
          'releaseOnly',
          'pressAndRelease',
        ], defaultValue: 'pressOnly'),
        _pressPoint,
      ], description: 'On press, on release, or both.'),
      (d, s) => PressInteraction(
        behavior: d.text('behavior') ?? 'pressOnly',
        pressPoint: d.number('pressPoint') ?? s.pressPoint,
        releaseRatio: s.releaseRatio,
      ),
    ),
    InteractionEntry(
      const StepInfo(
        'hold',
        'Hold',
        [
          ParamInfo.number(
            'duration',
            'Duration',
            min: 0,
            fromSettings: 'holdTime',
          ),
          _pressPoint,
        ],
        description:
            'Performed once held long enough; canceled if let go sooner.',
      ),
      (d, s) => HoldInteraction(
        duration: d.number('duration') ?? s.holdTime,
        pressPoint: d.number('pressPoint') ?? s.pressPoint,
        releaseRatio: s.releaseRatio,
      ),
    ),
    InteractionEntry(
      const StepInfo(
        'tap',
        'Tap',
        [
          ParamInfo.number(
            'duration',
            'Max duration',
            min: 0,
            fromSettings: 'tapTime',
          ),
          _pressPoint,
        ],
        description:
            'Performed when let go quickly; canceled if held too long.',
      ),
      (d, s) => TapInteraction(
        duration: d.number('duration') ?? s.tapTime,
        pressPoint: d.number('pressPoint') ?? s.pressPoint,
        releaseRatio: s.releaseRatio,
      ),
    ),
    InteractionEntry(
      const StepInfo('slowTap', 'Slow Tap', [
        ParamInfo.number(
          'duration',
          'Min duration',
          min: 0,
          fromSettings: 'slowTapTime',
        ),
        _pressPoint,
      ], description: 'Performed when let go after holding long enough.'),
      (d, s) => SlowTapInteraction(
        duration: d.number('duration') ?? s.slowTapTime,
        pressPoint: d.number('pressPoint') ?? s.pressPoint,
        releaseRatio: s.releaseRatio,
      ),
    ),
    InteractionEntry(
      const StepInfo(
        'multiTap',
        'Multi Tap',
        [
          ParamInfo.number(
            'tapCount',
            'Taps',
            defaultValue: 2.0,
            min: 2,
            step: 1,
          ),
          ParamInfo.number(
            'tapTime',
            'Max tap',
            min: 0,
            fromSettings: 'tapTime',
          ),
          ParamInfo.number(
            'tapDelay',
            'Max gap',
            min: 0,
            fromSettings: 'multiTapDelay',
          ),
          _pressPoint,
        ],
        description:
            'Performed on the last of several quick taps — a double tap.',
      ),
      (d, s) => MultiTapInteraction(
        tapCount: (d.number('tapCount') ?? 2).round(),
        tapTime: d.number('tapTime') ?? s.tapTime,
        tapDelay: d.number('tapDelay') ?? s.multiTapDelay,
        pressPoint: d.number('pressPoint') ?? s.pressPoint,
        releaseRatio: s.releaseRatio,
      ),
    ),
  ];
}

/// Tracks a press with a release point below the press point, so a value
/// resting on the line does not chatter.
mixin _Presses {
  double get pressPoint;
  double get releaseRatio;
  bool down = false;

  /// +1 on a press, -1 on a release, 0 otherwise.
  int edge(double actuation) {
    if (!down && actuation >= pressPoint) {
      down = true;
      return 1;
    }
    if (down && actuation < pressPoint * releaseRatio) {
      down = false;
      return -1;
    }
    return 0;
  }
}

/// A button with no interaction: started and performed on press, canceled
/// on release.
final class DefaultButtonInteraction extends InteractionMachine with _Presses {
  DefaultButtonInteraction(InputSettingsDef s)
    : pressPoint = s.pressPoint,
      releaseRatio = s.releaseRatio;

  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch (edge(actuation)) {
      case 1:
        host.started();
        host.performed();
      case -1:
        host.canceled();
    }
  }

  @override
  void reset() => down = false;
}

/// An axis or vector with no interaction: started when it leaves zero,
/// performed on every change, canceled back at zero.
final class DefaultValueInteraction extends InteractionMachine {
  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    if (actuation > 0) {
      if (host.phase == InputActionPhase.waiting) {
        host.started();
        host.performed();
      } else if (changed) {
        host.performed();
      }
    } else if (host.phase == InputActionPhase.started ||
        host.phase == InputActionPhase.performed) {
      host.canceled();
    }
  }
}

/// Every change goes straight through as performed.
final class PassThroughInteraction extends InteractionMachine {
  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    if (!changed) return;
    host.performed();
    if (actuation == 0) host.waiting();
  }
}

final class PressInteraction extends InteractionMachine with _Presses {
  PressInteraction({
    required this.behavior,
    required this.pressPoint,
    required this.releaseRatio,
  });

  final String behavior;
  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch ((edge(actuation), behavior)) {
      case (1, 'releaseOnly'):
        host.started();
      case (1, _):
        host.started();
        host.performed();
      case (-1, 'pressOnly'):
        host.waiting();
      case (-1, _):
        host.performed();
        host.waiting();
    }
  }

  @override
  void reset() => down = false;
}

final class HoldInteraction extends InteractionMachine with _Presses {
  HoldInteraction({
    required this.duration,
    required this.pressPoint,
    required this.releaseRatio,
  });

  final double duration;
  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  double? _deadline;

  @override
  double? get deadline => _deadline;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch (edge(actuation)) {
      case 1:
        host.started();
        if (duration <= 0) {
          host.performed();
        } else {
          _deadline = now + duration;
        }
      case -1:
        _deadline = null;
        host.canceled();
    }
  }

  @override
  void onTime(double now, InteractionHost host) {
    if (_deadline == null || now < _deadline!) return;
    _deadline = null;
    if (down) host.performed();
  }

  @override
  void reset() {
    down = false;
    _deadline = null;
  }
}

final class TapInteraction extends InteractionMachine with _Presses {
  TapInteraction({
    required this.duration,
    required this.pressPoint,
    required this.releaseRatio,
  });

  final double duration;
  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  double? _pressedAt;

  @override
  double? get deadline => _pressedAt == null ? null : _pressedAt! + duration;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch (edge(actuation)) {
      case 1:
        _pressedAt = now;
        host.started();
      case -1:
        final at = _pressedAt;
        _pressedAt = null;
        if (at == null) return; // already timed out
        if (now - at <= duration) {
          host.performed();
          host.waiting();
        } else {
          host.canceled();
        }
    }
  }

  @override
  void onTime(double now, InteractionHost host) {
    final at = _pressedAt;
    if (at == null || now - at <= duration) return;
    _pressedAt = null;
    host.canceled();
  }

  @override
  void reset() {
    down = false;
    _pressedAt = null;
  }
}

final class SlowTapInteraction extends InteractionMachine with _Presses {
  SlowTapInteraction({
    required this.duration,
    required this.pressPoint,
    required this.releaseRatio,
  });

  final double duration;
  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  double _pressedAt = 0;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch (edge(actuation)) {
      case 1:
        _pressedAt = now;
        host.started();
      case -1:
        if (now - _pressedAt >= duration) {
          host.performed();
          host.waiting();
        } else {
          host.canceled();
        }
    }
  }

  @override
  void reset() => down = false;
}

final class MultiTapInteraction extends InteractionMachine with _Presses {
  MultiTapInteraction({
    required this.tapCount,
    required this.tapTime,
    required this.tapDelay,
    required this.pressPoint,
    required this.releaseRatio,
  });

  final int tapCount;
  final double tapTime;
  final double tapDelay;
  @override
  final double pressPoint;
  @override
  final double releaseRatio;

  int _taps = 0;
  double _pressedAt = 0;
  double? _deadline;

  @override
  double? get deadline => _deadline;

  @override
  void onInput(
    double actuation,
    bool changed,
    double now,
    InteractionHost host,
  ) {
    switch (edge(actuation)) {
      case 1:
        if (_taps == 0) host.started();
        _pressedAt = now;
        _deadline = now + tapTime;
      case -1:
        if (now - _pressedAt > tapTime) {
          _fail(host);
          return;
        }
        _taps++;
        if (_taps >= tapCount) {
          _taps = 0;
          _deadline = null;
          host.performed();
          host.waiting();
        } else {
          _deadline = now + tapDelay;
        }
    }
  }

  @override
  void onTime(double now, InteractionHost host) {
    if (_deadline == null || now < _deadline!) return;
    _fail(host);
  }

  void _fail(InteractionHost host) {
    _taps = 0;
    _deadline = null;
    if (host.phase != InputActionPhase.waiting) host.canceled();
  }

  @override
  void reset() {
    down = false;
    _taps = 0;
    _deadline = null;
  }
}
