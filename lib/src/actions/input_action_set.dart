import 'input_action.dart';

/// A named collection of [InputAction] definitions, keyed by action name
/// (e.g. `'dash'`, `'move'`) — the whole editable/persistable state behind
/// [InputActionResolver].
class InputActionSet {
  InputActionSet([
    Map<String, InputAction>? defs,
    List<String>? mapOrder,
    List<String>? actionOrder,
  ]) : defs = defs ?? {},
       mapOrder = mapOrder ?? [],
       actionOrder = actionOrder ?? [];

  final Map<String, InputAction> defs;

  /// Explicit developer-controlled display/drag order for known map ids —
  /// reorderable via the editor's Input Setup panel. May be incomplete (an
  /// old save file predating this field, or a map that only just gained its
  /// first action) — [allMapIds] is the complete, gap-filled view to
  /// actually render from; this raw list is what the editor's drag-reorder
  /// directly rewrites.
  final List<String> mapOrder;

  /// Same idea as [mapOrder], but for action keys. Order is global across
  /// every map at once; a given map's actions are shown in whatever
  /// relative order they appear in this list, filtered down by `mapId` (see
  /// [allActionKeys]) — reordering the actions displayed for one map only
  /// ever rewrites the affected entries' positions, leaving every other
  /// map's actions' relative order untouched.
  final List<String> actionOrder;

  /// Every map id currently in play, in [mapOrder]'s order — any map id
  /// implied by an [InputAction.mapId] but missing from [mapOrder] (a map
  /// that only just gained its first action, or an old save file predating
  /// this field) is appended at the end, so nothing is ever silently
  /// hidden.
  List<String> get allMapIds {
    final seen = <String>{};
    final result = <String>[];
    for (final id in mapOrder) {
      if (seen.add(id)) result.add(id);
    }
    for (final def in defs.values) {
      if (seen.add(def.mapId)) result.add(def.mapId);
    }
    return result;
  }

  /// Every action key currently in [defs], in [actionOrder]'s order — a key
  /// present in [defs] but missing from [actionOrder] (same reasons as
  /// [allMapIds]) is appended at the end; a key listed in [actionOrder] that
  /// no longer exists in [defs] (deleted) is silently skipped.
  List<String> get allActionKeys {
    final seen = <String>{};
    final result = <String>[];
    for (final key in actionOrder) {
      if (defs.containsKey(key) && seen.add(key)) result.add(key);
    }
    for (final key in defs.keys) {
      if (seen.add(key)) result.add(key);
    }
    return result;
  }

  /// Overlays [other] onto this set, action-by-action — an action missing
  /// from [other] keeps its current definition, so an older/partial JSON
  /// file never silently drops actions it doesn't know about yet. Map/action
  /// order lists are unioned (appending anything new, keeping existing
  /// relative order) rather than replaced, for the same reason.
  void mergeFrom(InputActionSet other) {
    defs.addAll(other.defs);
    for (final id in other.mapOrder) {
      if (!mapOrder.contains(id)) mapOrder.add(id);
    }
    for (final key in other.actionOrder) {
      if (!actionOrder.contains(key)) actionOrder.add(key);
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'mapOrder': mapOrder,
    'actionOrder': actionOrder,
    'actions': defs.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory InputActionSet.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as Map<String, dynamic>? ?? const {};
    // 'mapIds' was this field's name before per-map/per-action reordering
    // existed (an unordered-set shape) — still accepted as a fallback so a
    // save file written during that brief window keeps its declared empty
    // maps instead of silently losing them.
    final rawMapOrder =
        (json['mapOrder'] ?? json['mapIds']) as List<dynamic>? ?? const [];
    final rawActionOrder = json['actionOrder'] as List<dynamic>? ?? const [];
    return InputActionSet(
      rawActions.map(
        (key, value) =>
            MapEntry(key, InputAction.fromJson(value as Map<String, dynamic>)),
      ),
      rawMapOrder.map((id) => id as String).toList(),
      rawActionOrder.map((id) => id as String).toList(),
    );
  }
}
