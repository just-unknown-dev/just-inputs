import 'dart:convert';

import 'action_def.dart';
import 'binding_def.dart';
import 'on_screen_control_def.dart';
import 'scheme_def.dart';
import 'settings_def.dart';

/// Everything a game's input is: its action maps, the control schemes, the
/// on-screen controls and the player rules. Saved as a `.input.json` file.
///
/// Immutable: every edit makes a new asset, which is what lets the editor's
/// undo keep whole assets and the runtime swap one in between two frames.
final class InputActionAsset {
  const InputActionAsset({
    this.name = '',
    this.nextId = 1,
    this.settings = const InputSettingsDef(),
    this.players = const PlayerSettingsDef(),
    this.schemes = const [],
    this.onScreen = const [],
    this.maps = const [],
  });

  /// The asset has nothing in it — what a game runs on before it loads one.
  static const InputActionAsset empty = InputActionAsset();

  /// The `format` every file carries.
  static const String format = 'just_inputs';

  /// The file version this code reads and writes.
  static const int version = 3;

  /// The file ending an asset is saved under.
  static const String extension = 'input.json';

  /// Reads a file's JSON. Throws [FormatException] for anything that is not
  /// a version-3 input asset.
  factory InputActionAsset.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw FormatException('Not a $format file (format: ${json['format']}).');
    }
    if (json['version'] != version) {
      throw FormatException(
        'This is a version ${json['version']} input asset; '
        'only version $version can be read.',
      );
    }
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
      for (final item in (json[key] as List?) ?? const [])
        read((item as Map).cast<String, dynamic>()),
    ];
    return InputActionAsset(
      name: json['name'] as String? ?? '',
      nextId: (json['nextId'] as num?)?.toInt() ?? 1,
      settings: InputSettingsDef.fromJson(
        (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      players: PlayerSettingsDef.fromJson(
        (json['players'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      schemes: list('schemes', ControlSchemeDef.fromJson),
      onScreen: list('onScreen', OnScreenControlDef.fromJson),
      maps: list('maps', ActionMapDef.fromJson),
    );
  }

  /// Reads a file's text; see [InputActionAsset.fromJson].
  factory InputActionAsset.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map) {
      throw const FormatException('An input asset is a JSON object.');
    }
    return InputActionAsset.fromJson(json.cast<String, dynamic>());
  }

  /// What people call it: `game`.
  final String name;

  /// The number the next new id is made from. Ids are never reused, so an
  /// override saved against a deleted binding can never land on a new one.
  final int nextId;

  final InputSettingsDef settings;
  final PlayerSettingsDef players;
  final List<ControlSchemeDef> schemes;
  final List<OnScreenControlDef> onScreen;
  final List<ActionMapDef> maps;

  ActionMapDef? mapNamed(String name) {
    for (final m in maps) {
      if (m.name == name) return m;
    }
    return null;
  }

  ActionMapDef? mapById(String id) {
    for (final m in maps) {
      if (m.id == id) return m;
    }
    return null;
  }

  ControlSchemeDef? schemeNamed(String name) {
    for (final s in schemes) {
      if (s.name == name) return s;
    }
    return null;
  }

  ControlSchemeDef? schemeWithGroup(String group) {
    for (final s in schemes) {
      if (s.group == group) return s;
    }
    return null;
  }

  OnScreenControlDef? onScreenControl(String id) {
    for (final c in onScreen) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Every action, with the map it is in.
  Iterable<ActionRef> get actions sync* {
    for (final m in maps) {
      for (final a in m.actions) {
        yield ActionRef(m, a);
      }
    }
  }

  /// The action [path] names: `map/action`, or a bare `action` when only
  /// one map has one by that name. Null when there is none, or several.
  ActionRef? findAction(String path) {
    final slash = path.indexOf('/');
    if (slash >= 0) {
      final map = mapNamed(path.substring(0, slash));
      final action = map?.actionNamed(path.substring(slash + 1));
      return action == null ? null : ActionRef(map!, action);
    }
    ActionRef? found;
    for (final ref in actions) {
      if (ref.action.name != path) continue;
      if (found != null) return null;
      found = ref;
    }
    return found;
  }

  ActionRef? actionById(String id) {
    for (final ref in actions) {
      if (ref.action.id == id) return ref;
    }
    return null;
  }

  /// The binding — or composite part — with [id], and where it is.
  BindingRef? findBinding(String id) {
    for (final ref in actions) {
      for (final b in ref.action.bindings) {
        if (b.id == id) return BindingRef(ref.map, ref.action, b);
        if (b is CompositeBindingDef) {
          for (final p in b.parts) {
            if (p.id == id) return BindingRef(ref.map, ref.action, b, p);
          }
        }
      }
    }
    return null;
  }

  InputActionAsset copyWith({
    String? name,
    int? nextId,
    InputSettingsDef? settings,
    PlayerSettingsDef? players,
    List<ControlSchemeDef>? schemes,
    List<OnScreenControlDef>? onScreen,
    List<ActionMapDef>? maps,
  }) => InputActionAsset(
    name: name ?? this.name,
    nextId: nextId ?? this.nextId,
    settings: settings ?? this.settings,
    players: players ?? this.players,
    schemes: schemes ?? this.schemes,
    onScreen: onScreen ?? this.onScreen,
    maps: maps ?? this.maps,
  );

  /// A new id and the asset that has spent it: `b17`, then 18 is next.
  (String, InputActionAsset) takeId(String prefix) =>
      ('$prefix$nextId', copyWith(nextId: nextId + 1));

  Map<String, dynamic> toJson() => {
    'format': format,
    'version': version,
    'name': name,
    'nextId': nextId,
    'settings': settings.toJson(),
    'players': players.toJson(),
    'schemes': [for (final s in schemes) s.toJson()],
    'onScreen': [for (final c in onScreen) c.toJson()],
    'maps': [for (final m in maps) m.toJson()],
  };

  /// The file's text: two-space indent, keys in a fixed order, ending in a
  /// newline — the same asset always writes the same bytes, so a save that
  /// changed nothing changes nothing in version control.
  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert(toJson())}\n';
}

/// An action and the map it is in.
final class ActionRef {
  const ActionRef(this.map, this.action);

  final ActionMapDef map;
  final InputActionDef action;

  /// `map/action`.
  String get path => '${map.name}/${action.name}';
}

/// A binding, the action and map it is in, and — for a composite part —
/// the part.
final class BindingRef {
  const BindingRef(this.map, this.action, this.binding, [this.part]);

  final ActionMapDef map;
  final InputActionDef action;
  final InputBindingDef binding;
  final CompositePartDef? part;

  /// The id the reference was found by.
  String get id => part?.id ?? binding.id;

  /// The path it reads — the part's, or a single binding's. Empty for a
  /// composite itself.
  String get path => switch ((part, binding)) {
    (final CompositePartDef p, _) => p.path,
    (_, final ControlBindingDef b) => b.path,
    _ => '',
  };
}
