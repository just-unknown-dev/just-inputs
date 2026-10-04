import '../paths/control_path.dart';
import 'binding_def.dart';
import 'input_action_asset.dart';
import 'settings_def.dart';

/// Two actions in one map that the same press would set off together.
final class BindingConflict {
  const BindingConflict({
    required this.mapId,
    required this.first,
    required this.second,
  });

  final String mapId;
  final ConflictSide first;
  final ConflictSide second;

  Iterable<String> get bindingIds => {first.bindingId, second.bindingId};
  Iterable<String> get actionIds => {first.actionId, second.actionId};

  @override
  String toString() => '${first.path} ⇄ ${second.path} in map $mapId';
}

/// One end of a [BindingConflict].
final class ConflictSide {
  const ConflictSide(this.actionId, this.bindingId, this.path);

  final String actionId;

  /// The binding or composite part.
  final String bindingId;

  /// What it reads — for a modifier composite, the whole chord:
  /// `<Keyboard>/shift + <Keyboard>/e`.
  final String path;
}

/// Every pair of different actions in the same map whose bindings would
/// fire on the same input — the same control, or one inside the other (the
/// whole stick and its up direction).
///
/// With [group], only bindings in that scheme count. Without, two bindings
/// clash only if some scheme has both: a keyboard binding and a gamepad
/// binding never do.
///
/// A modifier composite is one chord: Shift + E clashes with another
/// Shift + E, not with a plain E — that difference is what it is for.
///
/// While players join by action, the join actions clash with nothing: they
/// listen only to devices nobody is using, and every other action only to
/// a player's own — Start can pause for player 1 and join player 2.
List<BindingConflict> findBindingConflicts(
  InputActionAsset asset, {
  String? group,
}) {
  final joinActions = asset.players.joining == JoinBehavior.onJoinAction
      ? {
          for (final path in asset.players.joinActions)
            ?asset.findAction(path)?.action.id,
        }
      : const <String>{};
  final conflicts = <BindingConflict>[];
  for (final map in asset.maps) {
    final entries = <_Entry>[];
    for (final action in map.actions) {
      if (joinActions.contains(action.id)) continue;
      for (final binding in action.bindings) {
        if (!binding.inGroup(group)) continue;
        switch (binding) {
          case ControlBindingDef(:final control?):
            entries.add(
              _Entry(action.id, binding.id, binding.groups, [control]),
            );
          case ControlBindingDef():
            break;
          case CompositeBindingDef()
              when binding.composite == CompositeKinds.oneModifier ||
                  binding.composite == CompositeKinds.twoModifiers:
            final chord = [for (final p in binding.parts) ?p.control];
            if (chord.length == binding.parts.length && chord.isNotEmpty) {
              entries.add(_Entry(action.id, binding.id, binding.groups, chord));
            }
          case CompositeBindingDef():
            for (final part in binding.parts) {
              final control = part.control;
              if (control == null) continue;
              entries.add(
                _Entry(action.id, part.id, binding.groups, [control]),
              );
            }
        }
      }
    }
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final a = entries[i], b = entries[j];
        if (a.actionId == b.actionId) continue;
        if (group == null && !_shareAScheme(a.groups, b.groups)) continue;
        if (!a.clashesWith(b)) continue;
        conflicts.add(
          BindingConflict(
            mapId: map.id,
            first: ConflictSide(a.actionId, a.bindingId, a.label),
            second: ConflictSide(b.actionId, b.bindingId, b.label),
          ),
        );
      }
    }
  }
  return conflicts;
}

bool _shareAScheme(List<String> a, List<String> b) =>
    a.isEmpty || b.isEmpty || a.any(b.contains);

final class _Entry {
  _Entry(this.actionId, this.bindingId, this.groups, this.controls);

  final String actionId;
  final String bindingId;
  final List<String> groups;

  /// One control, or a whole chord.
  final List<ControlPath> controls;

  String get label => controls.join(' + ');

  bool clashesWith(_Entry other) {
    if (controls.length == 1 && other.controls.length == 1) {
      return controls.single.overlaps(other.controls.single);
    }
    // Chords clash only with the same chord, in any order.
    if (controls.length != other.controls.length) return false;
    return controls.every(other.controls.contains);
  }
}
