import '../model/binding_def.dart';
import '../model/input_action_asset.dart';

/// A player's own bindings: binding (or part) id → control path. Stored
/// apart from the asset, so the game's defaults are never touched.
final class BindingOverrides {
  const BindingOverrides([this.paths = const {}]);

  factory BindingOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['version'] != 1) return const BindingOverrides();
    final raw = (json['overrides'] as Map?) ?? const {};
    return BindingOverrides({
      for (final e in raw.entries)
        if (e.key is String && e.value is String)
          e.key as String: e.value as String,
    });
  }

  final Map<String, String> paths;

  bool get isEmpty => paths.isEmpty;

  String? operator [](String bindingId) => paths[bindingId];

  BindingOverrides withPath(String bindingId, String path) =>
      BindingOverrides({...paths, bindingId: path});

  BindingOverrides without(String bindingId) =>
      BindingOverrides({...paths}..remove(bindingId));

  /// Only the overrides [asset] still has a binding for — a binding deleted
  /// from the asset takes its override with it.
  BindingOverrides keptBy(InputActionAsset asset) => BindingOverrides({
    for (final e in paths.entries)
      if (asset.findBinding(e.key) != null) e.key: e.value,
  });

  Map<String, dynamic> toJson() => {'version': 1, 'overrides': paths};
}

/// [asset] with [overrides] written into its bindings — what conflict
/// checks and the Controls screen read.
InputActionAsset applyOverrides(
  InputActionAsset asset,
  BindingOverrides overrides,
) {
  if (overrides.isEmpty) return asset;
  InputBindingDef apply(InputBindingDef b) => switch (b) {
    ControlBindingDef() =>
      overrides[b.id] == null ? b : b.copyWith(path: overrides[b.id]),
    CompositeBindingDef() => b.copyWith(
      parts: [
        for (final p in b.parts)
          overrides[p.id] == null ? p : p.copyWith(path: overrides[p.id]),
      ],
    ),
  };
  return asset.copyWith(
    maps: [
      for (final m in asset.maps)
        m.copyWith(
          actions: [
            for (final a in m.actions)
              a.copyWith(bindings: [for (final b in a.bindings) apply(b)]),
          ],
        ),
    ],
  );
}

/// Where players' overrides are kept. The engine keeps them in its cache;
/// tests keep them in memory.
abstract interface class InputOverrideStore {
  Future<Map<String, dynamic>?> load(String key);
  Future<void> save(String key, Map<String, dynamic> json);
  Future<void> clear(String key);
}

final class MemoryInputOverrideStore implements InputOverrideStore {
  final Map<String, Map<String, dynamic>> data = {};

  @override
  Future<Map<String, dynamic>?> load(String key) async => data[key];

  @override
  Future<void> save(String key, Map<String, dynamic> json) async =>
      data[key] = json;

  @override
  Future<void> clear(String key) async => data.remove(key);
}
