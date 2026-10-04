/// A named step with settings — an interaction (`hold`, `tap`) or a
/// processor (`normalize`, `stickDeadzone`) as an asset stores it.
///
/// Only the name and the numbers are kept here. What a name means, and
/// which settings it reads, belongs to the runtime's registries, so a game
/// can add its own without the file format changing.
sealed class ParamDef {
  const ParamDef(this.type, [this.params = const {}]);

  /// The registry name: `hold`, `stickDeadzone`.
  final String type;

  /// Settings by name. Numbers, booleans and strings only. A setting left
  /// out takes the registry's default (often the asset's own setting — the
  /// hold time, say).
  final Map<String, Object> params;

  double? number(String name) => (params[name] as num?)?.toDouble();

  bool? flag(String name) => params[name] as bool?;

  String? text(String name) => params[name] as String?;

  Map<String, dynamic> toJson() => {
    'type': type,
    if (params.isNotEmpty) 'params': Map<String, Object>.of(params),
  };

  static (String, Map<String, Object>) _read(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw FormatException('A step needs a "type": $json');
    }
    final raw = (json['params'] as Map?)?.cast<String, Object?>() ?? const {};
    return (
      type,
      {
        for (final e in raw.entries)
          if (e.value is num || e.value is bool || e.value is String)
            e.key: e.value!,
      },
    );
  }

  @override
  String toString() => params.isEmpty ? type : '$type($params)';
}

/// How a press becomes an action: held for a while, tapped quickly, tapped
/// twice. An action with none behaves as a plain press.
final class InteractionDef extends ParamDef {
  const InteractionDef(super.type, [super.params]);

  factory InteractionDef.fromJson(Map<String, dynamic> json) {
    final (type, params) = ParamDef._read(json);
    return InteractionDef(type, params);
  }

  InteractionDef withParam(String name, Object? value) =>
      InteractionDef(type, _set(params, name, value));
}

/// A change made to a value on its way to the action: a dead zone, an
/// inversion, a scale.
final class ProcessorDef extends ParamDef {
  const ProcessorDef(super.type, [super.params]);

  factory ProcessorDef.fromJson(Map<String, dynamic> json) {
    final (type, params) = ParamDef._read(json);
    return ProcessorDef(type, params);
  }

  ProcessorDef withParam(String name, Object? value) =>
      ProcessorDef(type, _set(params, name, value));
}

Map<String, Object> _set(
  Map<String, Object> params,
  String name,
  Object? value,
) {
  final next = Map<String, Object>.of(params);
  if (value == null) {
    next.remove(name);
  } else {
    next[name] = value;
  }
  return Map.unmodifiable(next);
}

List<T> readList<T>(Object? raw, T Function(Map<String, dynamic>) read) => [
  for (final item in (raw as List?) ?? const [])
    read((item as Map).cast<String, dynamic>()),
];
