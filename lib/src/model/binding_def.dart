import '../paths/control_path.dart';
import 'param_def.dart';

/// One way to drive an action: a single control ([ControlBindingDef]) or
/// several read together ([CompositeBindingDef] — WASD, Shift + E).
sealed class InputBindingDef {
  const InputBindingDef({
    required this.id,
    this.groups = const [],
    this.interactions = const [],
    this.processors = const [],
  });

  factory InputBindingDef.fromJson(Map<String, dynamic> json) =>
      json.containsKey('composite')
      ? CompositeBindingDef.fromJson(json)
      : ControlBindingDef.fromJson(json);

  /// Stable across edits and saves — a player's rebinding is stored against
  /// it.
  final String id;

  /// The control schemes this binding belongs to, by group name. Empty means
  /// every scheme.
  final List<String> groups;

  /// Replaces the action's own interactions for this binding.
  final List<InteractionDef> interactions;

  /// Applied after the control's own and before the action's.
  final List<ProcessorDef> processors;

  /// Whether this binding counts while [group] is the scheme in use. A null
  /// group (no scheme chosen) takes every binding.
  bool inGroup(String? group) =>
      group == null || groups.isEmpty || groups.contains(group);

  /// Every path this binding reads, parts included, unbound ones left out.
  Iterable<ControlPath> get paths;

  Map<String, dynamic> toJson();

  Map<String, dynamic> _common() => {
    'id': id,
    if (groups.isNotEmpty) 'groups': groups,
    if (interactions.isNotEmpty)
      'interactions': [for (final i in interactions) i.toJson()],
    if (processors.isNotEmpty)
      'processors': [for (final p in processors) p.toJson()],
  };
}

/// A binding to one control.
final class ControlBindingDef extends InputBindingDef {
  const ControlBindingDef({
    required super.id,
    this.path = '',
    super.groups,
    super.interactions,
    super.processors,
  });

  factory ControlBindingDef.fromJson(Map<String, dynamic> json) =>
      ControlBindingDef(
        id: _id(json),
        path: json['path'] as String? ?? '',
        groups: _strings(json['groups']),
        interactions: readList(json['interactions'], InteractionDef.fromJson),
        processors: readList(json['processors'], ProcessorDef.fromJson),
      );

  /// `<Keyboard>/space`. Empty while the slot is unbound.
  final String path;

  /// [path] read, or null when it is empty or not a path.
  ControlPath? get control => ControlPath.tryParse(path);

  @override
  Iterable<ControlPath> get paths => [?control];

  ControlBindingDef copyWith({
    String? path,
    List<String>? groups,
    List<InteractionDef>? interactions,
    List<ProcessorDef>? processors,
  }) => ControlBindingDef(
    id: id,
    path: path ?? this.path,
    groups: groups ?? this.groups,
    interactions: interactions ?? this.interactions,
    processors: processors ?? this.processors,
  );

  @override
  Map<String, dynamic> toJson() => {..._common(), 'path': path};
}

/// The composites an asset can use, and the parts each reads.
abstract final class CompositeKinds {
  /// Four directions into one vector: WASD, the arrow keys.
  static const String vector2 = '2DVector';

  /// A negative and a positive part into one axis: Q/E.
  static const String axis1D = '1DAxis';

  /// A button that counts only while a modifier is held: Shift + E.
  static const String oneModifier = 'OneModifier';

  /// The same with two modifiers: Ctrl + Shift + E.
  static const String twoModifiers = 'TwoModifiers';

  static const Map<String, List<String>> parts = {
    vector2: ['up', 'down', 'left', 'right'],
    axis1D: ['negative', 'positive'],
    oneModifier: ['modifier', 'binding'],
    twoModifiers: ['modifier1', 'modifier2', 'binding'],
  };

  static const List<String> all = [vector2, axis1D, oneModifier, twoModifiers];

  static String label(String kind) => switch (kind) {
    vector2 => '2D Vector',
    axis1D => '1D Axis',
    oneModifier => 'Button + Modifier',
    twoModifiers => 'Button + 2 Modifiers',
    _ => kind,
  };
}

/// One part of a composite: the "up" of WASD, the "modifier" of Shift + E.
final class CompositePartDef {
  const CompositePartDef({
    required this.id,
    required this.part,
    this.path = '',
    this.processors = const [],
  });

  factory CompositePartDef.fromJson(Map<String, dynamic> json) =>
      CompositePartDef(
        id: _id(json),
        part: json['part'] as String? ?? '',
        path: json['path'] as String? ?? '',
        processors: readList(json['processors'], ProcessorDef.fromJson),
      );

  /// Stable, like a binding's — a part can be rebound on its own.
  final String id;

  /// Which part: `up`, `modifier`. A part may appear more than once — two
  /// keys for "up" both count.
  final String part;

  final String path;

  final List<ProcessorDef> processors;

  ControlPath? get control => ControlPath.tryParse(path);

  CompositePartDef copyWith({
    String? part,
    String? path,
    List<ProcessorDef>? processors,
  }) => CompositePartDef(
    id: id,
    part: part ?? this.part,
    path: path ?? this.path,
    processors: processors ?? this.processors,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'part': part,
    'path': path,
    if (processors.isNotEmpty)
      'processors': [for (final p in processors) p.toJson()],
  };
}

/// Several controls read together into one value.
final class CompositeBindingDef extends InputBindingDef {
  const CompositeBindingDef({
    required super.id,
    required this.composite,
    this.name = '',
    this.params = const {},
    this.parts = const [],
    super.groups,
    super.interactions,
    super.processors,
  });

  factory CompositeBindingDef.fromJson(Map<String, dynamic> json) =>
      CompositeBindingDef(
        id: _id(json),
        composite: json['composite'] as String,
        name: json['name'] as String? ?? '',
        params: {
          for (final e in ((json['params'] as Map?) ?? const {}).entries)
            if (e.value is num || e.value is bool || e.value is String)
              e.key as String: e.value as Object,
        },
        parts: readList(json['parts'], CompositePartDef.fromJson),
        groups: _strings(json['groups']),
        interactions: readList(json['interactions'], InteractionDef.fromJson),
        processors: readList(json['processors'], ProcessorDef.fromJson),
      );

  /// Which composite — one of [CompositeKinds], or a game's own.
  final String composite;

  /// What people call it: `WASD`, `Arrows`. Optional.
  final String name;

  /// The composite's settings — a 2D vector's `mode`, an axis's
  /// `whichSideWins`.
  final Map<String, Object> params;

  final List<CompositePartDef> parts;

  Iterable<CompositePartDef> partsNamed(String part) =>
      parts.where((p) => p.part == part);

  @override
  Iterable<ControlPath> get paths => [for (final p in parts) ?p.control];

  CompositeBindingDef copyWith({
    String? name,
    Map<String, Object>? params,
    List<CompositePartDef>? parts,
    List<String>? groups,
    List<InteractionDef>? interactions,
    List<ProcessorDef>? processors,
  }) => CompositeBindingDef(
    id: id,
    composite: composite,
    name: name ?? this.name,
    params: params ?? this.params,
    parts: parts ?? this.parts,
    groups: groups ?? this.groups,
    interactions: interactions ?? this.interactions,
    processors: processors ?? this.processors,
  );

  @override
  Map<String, dynamic> toJson() => {
    ..._common(),
    'composite': composite,
    if (name.isNotEmpty) 'name': name,
    if (params.isNotEmpty) 'params': Map<String, Object>.of(params),
    'parts': [for (final p in parts) p.toJson()],
  };
}

String _id(Map<String, dynamic> json) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw FormatException('Every binding needs an "id": $json');
  }
  return id;
}

List<String> _strings(Object? raw) => [
  for (final s in (raw as List?) ?? const []) s as String,
];
