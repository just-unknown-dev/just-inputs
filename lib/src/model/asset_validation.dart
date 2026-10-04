import '../paths/control_catalog.dart';
import '../paths/control_path.dart';
import 'action_def.dart';
import 'binding_def.dart';
import 'input_action_asset.dart';
import 'settings_def.dart';

enum IssueSeverity {
  /// The asset will not do what it says: a name code cannot reach, a path
  /// that names nothing.
  error,

  /// Probably a mistake, but it runs: an unbound slot, a vector action on a
  /// single key.
  warning,
}

/// Something wrong with an asset, and where.
final class AssetIssue {
  const AssetIssue(
    this.severity,
    this.code,
    this.message, {
    this.mapId,
    this.actionId,
    this.bindingId,
  });

  final IssueSeverity severity;

  /// Stable, for tests and for the editor to pick an icon: `unknownControl`.
  final String code;

  final String message;
  final String? mapId;
  final String? actionId;

  /// A binding or composite part.
  final String? bindingId;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() => '${severity.name}: $message';
}

final RegExp _namePattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// Everything wrong with [asset], errors and warnings alike.
List<AssetIssue> validateAsset(InputActionAsset asset) {
  final issues = <AssetIssue>[];
  void error(
    String code,
    String message, {
    String? map,
    String? action,
    String? binding,
  }) => issues.add(
    AssetIssue(
      IssueSeverity.error,
      code,
      message,
      mapId: map,
      actionId: action,
      bindingId: binding,
    ),
  );
  void warn(
    String code,
    String message, {
    String? map,
    String? action,
    String? binding,
  }) => issues.add(
    AssetIssue(
      IssueSeverity.warning,
      code,
      message,
      mapId: map,
      actionId: action,
      bindingId: binding,
    ),
  );

  // Ids: unique everywhere, and behind the counter so a new one can't land
  // on an old one.
  final seen = <String>{};
  void id(String id, {String? map, String? action, String? binding}) {
    if (!seen.add(id)) {
      error(
        'duplicateId',
        'The id "$id" is used twice.',
        map: map,
        action: action,
        binding: binding,
      );
    }
    final number = int.tryParse(id.replaceFirst(RegExp(r'^[A-Za-z]+'), ''));
    if (number != null && number >= asset.nextId) {
      error(
        'idAhead',
        'The id "$id" is not below nextId (${asset.nextId}).',
        map: map,
        action: action,
        binding: binding,
      );
    }
  }

  // Schemes.
  final groups = <String>{};
  final schemeNames = <String>{};
  for (final s in asset.schemes) {
    if (!schemeNames.add(s.name)) {
      error('duplicateScheme', 'Two schemes are called "${s.name}".');
    }
    if (!groups.add(s.group)) {
      error('duplicateGroup', 'Two schemes use the group "${s.group}".');
    }
    for (final d in s.devices) {
      if (!InputLayouts.all.contains(d.layout)) {
        error(
          'unknownLayout',
          'The scheme "${s.name}" asks for a "${d.layout}", which is not a device.',
        );
      }
    }
  }

  // On-screen controls.
  final onScreenIds = <String>{};
  for (final c in asset.onScreen) {
    if (!_namePattern.hasMatch(c.id)) {
      error(
        'badOnScreenId',
        'The on-screen control "${c.id}" needs a name of letters, digits and _.',
      );
    }
    if (!onScreenIds.add(c.id)) {
      error(
        'duplicateOnScreen',
        'Two on-screen controls are called "${c.id}".',
      );
    }
  }

  // Maps, actions, bindings.
  final mapNames = <String>{};
  for (final map in asset.maps) {
    id(map.id, map: map.id);
    if (!_namePattern.hasMatch(map.name)) {
      error(
        'badName',
        'The map "${map.name}" needs a name of letters, digits and _.',
        map: map.id,
      );
    }
    if (!mapNames.add(map.name)) {
      error('duplicateMap', 'Two maps are called "${map.name}".', map: map.id);
    }

    final actionNames = <String>{};
    for (final action in map.actions) {
      id(action.id, map: map.id, action: action.id);
      if (!_namePattern.hasMatch(action.name)) {
        error(
          'badName',
          'The action "${action.name}" needs a name of letters, digits and _.',
          map: map.id,
          action: action.id,
        );
      }
      if (!actionNames.add(action.name)) {
        error(
          'duplicateAction',
          'Two actions in "${map.name}" are called "${action.name}".',
          map: map.id,
          action: action.id,
        );
      }
      if (action.bindings.isEmpty) {
        warn(
          'noBindings',
          '"${map.name}/${action.name}" has no bindings.',
          map: map.id,
          action: action.id,
        );
      }

      for (final binding in action.bindings) {
        id(binding.id, map: map.id, action: action.id, binding: binding.id);
        for (final g in binding.groups) {
          if (!groups.contains(g)) {
            warn(
              'unknownGroup',
              'A binding of "${action.name}" is in the group "$g", which no scheme has.',
              map: map.id,
              action: action.id,
              binding: binding.id,
            );
          }
        }
        switch (binding) {
          case ControlBindingDef():
            _checkPath(asset, binding.path, binding.id, map.id, action, issues);
          case CompositeBindingDef():
            final parts = CompositeKinds.parts[binding.composite];
            if (parts == null) {
              warn(
                'unknownComposite',
                '"${binding.composite}" is not a built-in composite.',
                map: map.id,
                action: action.id,
                binding: binding.id,
              );
            } else {
              for (final p in binding.parts) {
                if (!parts.contains(p.part)) {
                  error(
                    'unknownPart',
                    'A ${CompositeKinds.label(binding.composite)} has no "${p.part}" part.',
                    map: map.id,
                    action: action.id,
                    binding: p.id,
                  );
                }
              }
              for (final want in parts) {
                if (binding.partsNamed(want).isEmpty) {
                  warn(
                    'missingPart',
                    'The ${CompositeKinds.label(binding.composite)} of "${action.name}" has no "$want".',
                    map: map.id,
                    action: action.id,
                    binding: binding.id,
                  );
                }
              }
              final kind = _compositeType(binding.composite);
              if (kind != null && !_fits(action.type, kind)) {
                warn(
                  'typeMismatch',
                  'A ${CompositeKinds.label(binding.composite)} gives the ${action.type.name} action "${action.name}" the wrong kind of value.',
                  map: map.id,
                  action: action.id,
                  binding: binding.id,
                );
              }
            }
            for (final p in binding.parts) {
              id(p.id, map: map.id, action: action.id, binding: p.id);
              _checkPath(asset, p.path, p.id, map.id, null, issues);
            }
        }
      }
    }
  }

  // Players.
  final players = asset.players;
  if (players.maxPlayers < 1) {
    error('maxPlayers', 'At least one player has to be able to play.');
  }
  if (players.joining == JoinBehavior.onJoinAction &&
      players.joinActions.isEmpty) {
    warn(
      'noJoinActions',
      'Players join by an action, but no action is named for it.',
    );
  }
  for (final path in players.joinActions) {
    if (asset.findAction(path) == null) {
      error(
        'unknownJoinAction',
        'The join action "$path" is not in the asset.',
      );
    }
  }
  return issues;
}

/// A path's own problems, and — given the action — whether its value suits.
void _checkPath(
  InputActionAsset asset,
  String path,
  String bindingId,
  String mapId,
  InputActionDef? action,
  List<AssetIssue> issues,
) {
  if (path.trim().isEmpty) {
    issues.add(
      AssetIssue(
        IssueSeverity.warning,
        'unbound',
        'A binding has no control yet.',
        mapId: mapId,
        actionId: action?.id,
        bindingId: bindingId,
      ),
    );
    return;
  }
  final parsed = ControlPath.tryParse(path);
  if (parsed == null) {
    issues.add(
      AssetIssue(
        IssueSeverity.error,
        'badPath',
        '"$path" is not a control path.',
        mapId: mapId,
        actionId: action?.id,
        bindingId: bindingId,
      ),
    );
    return;
  }
  final info = ControlCatalog.find(parsed, onScreen: asset.onScreen);
  if (info == null) {
    issues.add(
      AssetIssue(
        IssueSeverity.error,
        'unknownControl',
        'There is no control "$path".',
        mapId: mapId,
        actionId: action?.id,
        bindingId: bindingId,
      ),
    );
    return;
  }
  if (action != null && !_fits(action.type, info.type)) {
    issues.add(
      AssetIssue(
        IssueSeverity.warning,
        'typeMismatch',
        '"$path" gives the ${action.type.name} action "${action.name}" the wrong kind of value.',
        mapId: mapId,
        actionId: action.id,
        bindingId: bindingId,
      ),
    );
  }
}

ControlValueType? _compositeType(String composite) => switch (composite) {
  CompositeKinds.vector2 => ControlValueType.vector2,
  CompositeKinds.axis1D => ControlValueType.axis,
  CompositeKinds.oneModifier ||
  CompositeKinds.twoModifiers => ControlValueType.button,
  _ => null,
};

/// A button or axis goes anywhere a number is wanted — a button action
/// takes a stick's tilt as how far it is pressed. What doesn't fit is a
/// single number where two are needed, or two where one is.
bool _fits(ActionValueType action, ControlValueType control) =>
    switch (action) {
      ActionValueType.vector2 => control == ControlValueType.vector2,
      ActionValueType.axis => control != ControlValueType.vector2,
      ActionValueType.button => true,
    };
