import 'control_path.dart';

/// One control a binding can name, as the catalogue describes it.
final class ControlInfo {
  const ControlInfo(
    this.path,
    this.label,
    this.type, {
    this.children = const [],
  });

  final ControlPath path;

  /// Generic, brand-free: `Left Stick`, `Button South`. Brand glyphs are the
  /// display layer's job.
  final String label;

  final ControlValueType type;

  /// The parts that can be bound on their own — a stick's `x`, `y` and four
  /// directions, the d-pad's four buttons.
  final List<ControlInfo> children;

  /// This control and everything under it.
  Iterable<ControlInfo> get flattened sync* {
    yield this;
    for (final c in children) {
      yield* c.flattened;
    }
  }
}

/// The children every two-axis control has: `x` and `y` from -1 to 1, and
/// the four directions from 0 to 1 — the ones a button or a composite part
/// can take. Y grows downwards, as it does in the world: up is -1.
List<ControlInfo> vector2Children(
  ControlPath parent,
  String label, {
  bool directions = true,
}) {
  ControlInfo part(String name, String what, ControlValueType type) =>
      ControlInfo(
        ControlPath(parent.layout, '${parent.control}/$name'),
        '$label $what',
        type,
      );
  return [
    part('x', 'X', ControlValueType.axis),
    part('y', 'Y', ControlValueType.axis),
    if (directions) ...[
      part('up', 'Up', ControlValueType.button),
      part('down', 'Down', ControlValueType.button),
      part('left', 'Left', ControlValueType.button),
      part('right', 'Right', ControlValueType.button),
    ],
  ];
}
