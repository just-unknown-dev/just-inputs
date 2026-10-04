import 'binding_def.dart';
import 'param_def.dart';

/// What an action reads out.
enum ActionValueType {
  /// Down or up, with pressed/released edges. Takes the strongest binding.
  button,

  /// One number: a trigger, Q/E. Takes the strongest binding.
  axis,

  /// Two numbers: a stick, WASD. Takes the strongest binding.
  vector2,
}

/// Something the player does — jump, move, pause — and every way of doing it.
final class InputActionDef {
  const InputActionDef({
    required this.id,
    required this.name,
    this.type = ActionValueType.button,
    this.passThrough = false,
    this.displayName = '',
    this.rebindable = true,
    this.interactions = const [],
    this.processors = const [],
    this.bindings = const [],
  });

  factory InputActionDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw FormatException('An action needs an "id" and a "name": $json');
    }
    return InputActionDef(
      id: id,
      name: name,
      type: ActionValueType.values.byName(json['type'] as String? ?? 'button'),
      passThrough: json['passThrough'] == true,
      displayName: json['displayName'] as String? ?? '',
      rebindable: json['rebindable'] != false,
      interactions: readList(json['interactions'], InteractionDef.fromJson),
      processors: readList(json['processors'], ProcessorDef.fromJson),
      bindings: readList(json['bindings'], InputBindingDef.fromJson),
    );
  }

  /// Stable across renames.
  final String id;

  /// What code asks for: `jump`. Unique within its map; no `/`.
  final String name;

  final ActionValueType type;

  /// Every change from every binding goes straight through — the latest
  /// wins, rather than the strongest. For pointer positions and aim.
  final bool passThrough;

  /// What a player sees — "Jump". Empty means [name], tidied.
  final String displayName;

  /// Whether a Controls screen offers it to players.
  final bool rebindable;

  final List<InteractionDef> interactions;

  final List<ProcessorDef> processors;

  final List<InputBindingDef> bindings;

  String get label => displayName.isNotEmpty ? displayName : prettifyName(name);

  InputActionDef copyWith({
    String? name,
    ActionValueType? type,
    bool? passThrough,
    String? displayName,
    bool? rebindable,
    List<InteractionDef>? interactions,
    List<ProcessorDef>? processors,
    List<InputBindingDef>? bindings,
  }) => InputActionDef(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    passThrough: passThrough ?? this.passThrough,
    displayName: displayName ?? this.displayName,
    rebindable: rebindable ?? this.rebindable,
    interactions: interactions ?? this.interactions,
    processors: processors ?? this.processors,
    bindings: bindings ?? this.bindings,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (passThrough) 'passThrough': true,
    if (displayName.isNotEmpty) 'displayName': displayName,
    if (!rebindable) 'rebindable': false,
    if (interactions.isNotEmpty)
      'interactions': [for (final i in interactions) i.toJson()],
    if (processors.isNotEmpty)
      'processors': [for (final p in processors) p.toJson()],
    'bindings': [for (final b in bindings) b.toJson()],
  };
}

/// `moveLeft` → `Move Left`, `jump_high` → `Jump High`.
String prettifyName(String name) {
  final spaced = name
      .replaceAll('_', ' ')
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .trim();
  return spaced
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// A group of actions switched on and off together — `player` while
/// playing, `ui` in menus.
final class ActionMapDef {
  const ActionMapDef({
    required this.id,
    required this.name,
    this.enabled = true,
    this.actions = const [],
  });

  factory ActionMapDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw FormatException('A map needs an "id" and a "name": $json');
    }
    return ActionMapDef(
      id: id,
      name: name,
      enabled: json['enabled'] != false,
      actions: readList(json['actions'], InputActionDef.fromJson),
    );
  }

  final String id;

  /// Unique in the asset; no `/`.
  final String name;

  /// Switched on when the game starts.
  final bool enabled;

  final List<InputActionDef> actions;

  InputActionDef? actionNamed(String name) {
    for (final a in actions) {
      if (a.name == name) return a;
    }
    return null;
  }

  ActionMapDef copyWith({
    String? name,
    bool? enabled,
    List<InputActionDef>? actions,
  }) => ActionMapDef(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    actions: actions ?? this.actions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'actions': [for (final a in actions) a.toJson()],
  };
}
