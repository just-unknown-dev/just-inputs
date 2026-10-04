import 'dart:ui' show Offset;

import '../devices/gamepad_device.dart' show axisDeadzone, stickDeadzone;
import '../model/param_def.dart';
import '../model/settings_def.dart';
import 'param_info.dart';

/// Changes a value: `(value, the step's settings, the asset's settings)`.
/// An axis is the value's `dx`.
typedef ProcessorFn =
    Offset Function(Offset value, ProcessorDef def, InputSettingsDef settings);

/// A registered processor: what it is called and shows, and what it does.
final class ProcessorEntry {
  const ProcessorEntry(this.info, this.apply, {this.forVector = false});

  final StepInfo info;
  final ProcessorFn apply;

  /// Made for two-axis values; the editor offers it on vector actions.
  final bool forVector;
}

/// The processors an asset can name — the built-ins and any a game adds.
abstract final class InputProcessors {
  static final Map<String, ProcessorEntry> _entries = {
    for (final e in _builtIns) e.info.type: e,
  };

  /// Adds (or replaces) a processor a game brings.
  static void register(ProcessorEntry entry) =>
      _entries[entry.info.type] = entry;

  static bool has(String type) => _entries.containsKey(type);

  static ProcessorEntry? entry(String type) => _entries[type];

  static Iterable<ProcessorEntry> get all => _entries.values;

  /// Runs [defs] over [value] in order. A processor nobody registered is
  /// passed over — the asset still loads, and validation says so.
  static Offset apply(
    List<ProcessorDef> defs,
    Offset value,
    InputSettingsDef settings,
  ) {
    var v = value;
    for (final d in defs) {
      final e = _entries[d.type];
      if (e != null) v = e.apply(v, d, settings);
    }
    return v;
  }

  static final List<ProcessorEntry> _builtIns = [
    ProcessorEntry(
      const StepInfo('normalize', 'Normalize', [
        ParamInfo.number('min', 'Min', defaultValue: 0.0),
        ParamInfo.number('max', 'Max', defaultValue: 1.0),
      ], description: 'Maps min…max onto 0…1.'),
      (v, d, _) {
        final min = d.number('min') ?? 0, max = d.number('max') ?? 1;
        return max == min ? Offset.zero : Offset((v.dx - min) / (max - min), 0);
      },
    ),
    ProcessorEntry(
      const StepInfo(
        'normalizeVector2',
        'Normalize Vector 2',
        [],
        description:
            'Makes any push full length: diagonals as fast as straights.',
      ),
      (v, _, _) => v == Offset.zero ? v : v / v.distance,
      forVector: true,
    ),
    ProcessorEntry(
      const StepInfo('axisDeadzone', 'Axis Deadzone', [
        ParamInfo.number(
          'min',
          'Min',
          min: 0,
          max: 1,
          fromSettings: 'axisDeadzoneMin',
        ),
        ParamInfo.number(
          'max',
          'Max',
          min: 0,
          max: 1,
          fromSettings: 'axisDeadzoneMax',
        ),
      ], description: 'Nothing below min; full past max.'),
      (v, d, s) => Offset(
        axisDeadzone(
          v.dx,
          d.number('min') ?? s.axisDeadzoneMin,
          d.number('max') ?? s.axisDeadzoneMax,
        ),
        0,
      ),
    ),
    ProcessorEntry(
      const StepInfo(
        'stickDeadzone',
        'Stick Deadzone',
        [
          ParamInfo.number(
            'min',
            'Min',
            min: 0,
            max: 1,
            fromSettings: 'stickDeadzoneMin',
          ),
          ParamInfo.number(
            'max',
            'Max',
            min: 0,
            max: 1,
            fromSettings: 'stickDeadzoneMax',
          ),
        ],
        description:
            'Measured on the stick\'s length, so diagonals are not clipped.',
      ),
      (v, d, s) => stickDeadzone(
        v,
        d.number('min') ?? s.stickDeadzoneMin,
        d.number('max') ?? s.stickDeadzoneMax,
      ),
      forVector: true,
    ),
    ProcessorEntry(
      const StepInfo('invert', 'Invert', []),
      (v, _, _) => Offset(-v.dx, 0),
    ),
    ProcessorEntry(
      const StepInfo('invertVector2', 'Invert Vector 2', [
        ParamInfo.flag('invertX', 'Invert X', defaultValue: true),
        ParamInfo.flag('invertY', 'Invert Y', defaultValue: true),
      ]),
      (v, d, _) => Offset(
        (d.flag('invertX') ?? true) ? -v.dx : v.dx,
        (d.flag('invertY') ?? true) ? -v.dy : v.dy,
      ),
      forVector: true,
    ),
    ProcessorEntry(
      const StepInfo('scale', 'Scale', [
        ParamInfo.number('factor', 'Factor', defaultValue: 1.0, step: 0.1),
      ]),
      (v, d, _) => Offset(v.dx * (d.number('factor') ?? 1), 0),
    ),
    ProcessorEntry(
      const StepInfo('scaleVector2', 'Scale Vector 2', [
        ParamInfo.number('x', 'X', defaultValue: 1.0, step: 0.1),
        ParamInfo.number('y', 'Y', defaultValue: 1.0, step: 0.1),
      ]),
      (v, d, _) =>
          Offset(v.dx * (d.number('x') ?? 1), v.dy * (d.number('y') ?? 1)),
      forVector: true,
    ),
    ProcessorEntry(
      const StepInfo('clamp', 'Clamp', [
        ParamInfo.number('min', 'Min', defaultValue: 0.0),
        ParamInfo.number('max', 'Max', defaultValue: 1.0),
      ]),
      (v, d, _) => Offset(
        v.dx.clamp(d.number('min') ?? 0, d.number('max') ?? 1).toDouble(),
        0,
      ),
    ),
  ];
}
