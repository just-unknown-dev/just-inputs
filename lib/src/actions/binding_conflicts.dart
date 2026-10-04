import 'package:flutter/services.dart' show LogicalKeyboardKey;

import 'input_action.dart';
import 'input_action_set.dart';

/// Which physical input two or more actions ended up sharing.
enum ConflictSource { key, mouseButton, gamepadButton }

/// Two or more actions in the same map bound to the same physical input, so
/// triggering it fires all of them at once — almost always an authoring
/// mistake (e.g. two actions accidentally captured with the same key).
class BindingConflict {
  const BindingConflict({
    required this.mapId,
    required this.source,
    required this.actionIds,
    this.key,
    this.mouseButton,
    this.gamepadButton,
  });

  final String mapId;
  final ConflictSource source;

  /// The two or more actions sharing this input (always length >= 2).
  final List<String> actionIds;

  /// Set iff [source] is [ConflictSource.key].
  final LogicalKeyboardKey? key;

  /// Set iff [source] is [ConflictSource.mouseButton].
  final int? mouseButton;

  /// Set iff [source] is [ConflictSource.gamepadButton].
  final int? gamepadButton;
}

/// Finds actions within the same map that share a physical input. A
/// [ActionType.vector2] action's four directional key lists count as "using"
/// each key exactly like a [ActionType.button] action's `keys` list does, so
/// e.g. `move`'s WASD colliding with some other action bound to `W` is still
/// caught. [Vector2Binding.gamepadStick] doesn't participate — the editor's
/// own stick-picker UI already only lets one action claim a given stick.
///
/// Two directions of the *same* action sharing a key (a same-action, not
/// cross-action, mistake) is deliberately not flagged here — out of scope
/// for this check.
List<BindingConflict> findBindingConflicts(InputActionSet actionSet) {
  final keyUsers = <String, Map<LogicalKeyboardKey, List<String>>>{};
  final mouseUsers = <String, Map<int, List<String>>>{};
  final gamepadUsers = <String, Map<int, List<String>>>{};

  void addKey(String mapId, LogicalKeyboardKey key, String actionId) {
    keyUsers
        .putIfAbsent(mapId, () => {})
        .putIfAbsent(key, () => [])
        .add(actionId);
  }

  void addMouse(String mapId, int button, String actionId) {
    mouseUsers
        .putIfAbsent(mapId, () => {})
        .putIfAbsent(button, () => [])
        .add(actionId);
  }

  void addGamepad(String mapId, int button, String actionId) {
    gamepadUsers
        .putIfAbsent(mapId, () => {})
        .putIfAbsent(button, () => [])
        .add(actionId);
  }

  for (final entry in actionSet.defs.entries) {
    final id = entry.key;
    final def = entry.value;
    if (def.type == ActionType.button) {
      final binding = def.button;
      for (final key in binding.keys) {
        addKey(def.mapId, key, id);
      }
      if (binding.mouseButton != null) {
        addMouse(def.mapId, binding.mouseButton!, id);
      }
      if (binding.gamepadButton != null) {
        addGamepad(def.mapId, binding.gamepadButton!, id);
      }
    } else {
      final v = def.vector2;
      for (final key in [...v.up, ...v.down, ...v.left, ...v.right]) {
        addKey(def.mapId, key, id);
      }
    }
  }

  final conflicts = <BindingConflict>[];

  keyUsers.forEach((mapId, byKey) {
    byKey.forEach((key, ids) {
      final unique = ids.toSet().toList();
      if (unique.length > 1) {
        conflicts.add(
          BindingConflict(
            mapId: mapId,
            source: ConflictSource.key,
            actionIds: unique,
            key: key,
          ),
        );
      }
    });
  });

  mouseUsers.forEach((mapId, byButton) {
    byButton.forEach((button, ids) {
      final unique = ids.toSet().toList();
      if (unique.length > 1) {
        conflicts.add(
          BindingConflict(
            mapId: mapId,
            source: ConflictSource.mouseButton,
            actionIds: unique,
            mouseButton: button,
          ),
        );
      }
    });
  });

  gamepadUsers.forEach((mapId, byButton) {
    byButton.forEach((button, ids) {
      final unique = ids.toSet().toList();
      if (unique.length > 1) {
        conflicts.add(
          BindingConflict(
            mapId: mapId,
            source: ConflictSource.gamepadButton,
            actionIds: unique,
            gamepadButton: button,
          ),
        );
      }
    });
  });

  return conflicts;
}

/// Ids from [expectedActionIds] that have no entry at all in [actionSet] —
/// e.g. a game's own action-name constant added in code but never bound via
/// the editor's Input Setup panel, so it silently never triggers. Order
/// follows [expectedActionIds]; duplicates in [expectedActionIds] are
/// collapsed.
List<String> findMissingActionIds(
  InputActionSet actionSet,
  Iterable<String> expectedActionIds,
) {
  final seen = <String>{};
  return [
    for (final id in expectedActionIds)
      if (!actionSet.defs.containsKey(id) && seen.add(id)) id,
  ];
}
