import 'dart:ui' show Offset;

import '../model/binding_def.dart';
import '../model/settings_def.dart';
import '../paths/control_path.dart';
import 'param_info.dart';

/// The values of a composite's parts, by part name: one value per entry (a
/// part may be bound twice), each already through its part's processors.
typedef CompositeParts = Map<String, List<Offset>>;

/// One running composite. Made fresh for every binding that uses it, so a
/// composite that remembers (which key came first) remembers per binding.
abstract class CompositeBehavior {
  Offset evaluate(
    CompositeParts parts,
    Map<String, Object> params,
    InputSettingsDef settings,
  );
}

/// A registered composite.
final class CompositeEntry {
  const CompositeEntry(this.info, this.parts, this.valueType, this.create);

  final StepInfo info;

  /// The parts it reads, in the order the editor lists them.
  final List<String> parts;

  final ControlValueType valueType;
  final CompositeBehavior Function() create;
}

/// The composites an asset can name.
abstract final class InputComposites {
  static final Map<String, CompositeEntry> _entries = {
    for (final e in _builtIns) e.info.type: e,
  };

  static void register(CompositeEntry entry) =>
      _entries[entry.info.type] = entry;

  static CompositeEntry? entry(String type) => _entries[type];

  static Iterable<CompositeEntry> get all => _entries.values;

  static final List<CompositeEntry> _builtIns = [
    CompositeEntry(
      const StepInfo(CompositeKinds.vector2, '2D Vector', [
        ParamInfo.choice('mode', 'Mode', [
          'digitalNormalized',
          'digital',
          'analog',
        ], defaultValue: 'digitalNormalized'),
      ], description: 'Four directions into one vector — WASD.'),
      CompositeKinds.parts[CompositeKinds.vector2]!,
      ControlValueType.vector2,
      _Vector2Composite.new,
    ),
    CompositeEntry(
      const StepInfo(CompositeKinds.axis1D, '1D Axis', [
        ParamInfo.choice('whichSideWins', 'Both held', [
          'neither',
          'positive',
          'negative',
        ], defaultValue: 'neither'),
        ParamInfo.number('minValue', 'Negative value', defaultValue: -1.0),
        ParamInfo.number('maxValue', 'Positive value', defaultValue: 1.0),
      ], description: 'Two buttons into one axis — Q/E.'),
      CompositeKinds.parts[CompositeKinds.axis1D]!,
      ControlValueType.axis,
      _AxisComposite.new,
    ),
    CompositeEntry(
      const StepInfo(CompositeKinds.oneModifier, 'Button + Modifier', [
        ParamInfo.choice('modifiersOrder', 'Order', [
          'ordered',
          'unordered',
        ], defaultValue: 'ordered'),
      ], description: 'Counts only while the modifier is held — Shift + E.'),
      CompositeKinds.parts[CompositeKinds.oneModifier]!,
      ControlValueType.button,
      () => _ModifierComposite(const ['modifier']),
    ),
    CompositeEntry(
      const StepInfo(CompositeKinds.twoModifiers, 'Button + 2 Modifiers', [
        ParamInfo.choice('modifiersOrder', 'Order', [
          'ordered',
          'unordered',
        ], defaultValue: 'ordered'),
      ], description: 'Counts only while both are held — Ctrl + Shift + E.'),
      CompositeKinds.parts[CompositeKinds.twoModifiers]!,
      ControlValueType.button,
      () => _ModifierComposite(const ['modifier1', 'modifier2']),
    ),
  ];
}

double _strongest(List<Offset>? values) {
  var best = 0.0;
  for (final v in values ?? const <Offset>[]) {
    final m = v.distance;
    if (m > best) best = m;
  }
  return best;
}

final class _Vector2Composite extends CompositeBehavior {
  @override
  Offset evaluate(
    CompositeParts parts,
    Map<String, Object> params,
    InputSettingsDef settings,
  ) {
    final mode = params['mode'] as String? ?? 'digitalNormalized';
    double part(String name) {
      final m = _strongest(parts[name]);
      return mode == 'analog' ? m : (m >= settings.pressPoint ? 1 : 0);
    }

    final v = Offset(part('right') - part('left'), part('down') - part('up'));
    if (mode == 'digitalNormalized' && v != Offset.zero) return v / v.distance;
    return v;
  }
}

final class _AxisComposite extends CompositeBehavior {
  @override
  Offset evaluate(
    CompositeParts parts,
    Map<String, Object> params,
    InputSettingsDef settings,
  ) {
    var negative = _strongest(parts['negative']);
    var positive = _strongest(parts['positive']);
    if (negative > 0 && positive > 0) {
      switch (params['whichSideWins'] as String? ?? 'neither') {
        case 'positive':
          negative = 0;
        case 'negative':
          positive = 0;
        default:
          return Offset.zero;
      }
    }
    final min = (params['minValue'] as num?)?.toDouble() ?? -1;
    final max = (params['maxValue'] as num?)?.toDouble() ?? 1;
    if (positive > 0) return Offset(positive * max, 0);
    if (negative > 0) return Offset(negative * min, 0);
    return Offset.zero;
  }
}

/// A button that only counts with its modifiers held. Ordered, it counts
/// only if they were down first — so typing E and then Shift is not
/// Shift + E.
final class _ModifierComposite extends CompositeBehavior {
  _ModifierComposite(this.modifiers);

  final List<String> modifiers;
  bool _wasDown = false;
  bool _counts = false;

  @override
  Offset evaluate(
    CompositeParts parts,
    Map<String, Object> params,
    InputSettingsDef settings,
  ) {
    final held = modifiers.every(
      (m) => _strongest(parts[m]) >= settings.pressPoint,
    );
    final button = _strongest(parts['binding']);
    final down = button >= settings.pressPoint;
    final ordered =
        (params['modifiersOrder'] as String? ?? 'ordered') == 'ordered';
    if (down && !_wasDown) _counts = held;
    if (!down) _counts = false;
    _wasDown = down;
    final on = ordered ? _counts && held : held;
    return on ? Offset(button, 0) : Offset.zero;
  }
}
