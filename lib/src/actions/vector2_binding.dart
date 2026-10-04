import 'package:flutter/services.dart';

import 'gamepad_stick.dart';
import 'key_list_codec.dart';

/// A composite binding for a Vector2-type action (e.g. movement, aim) — four
/// independent key-lists, one per direction, combined by
/// [InputActionResolver.getVector2] into a single axis pair, plus an optional
/// analog-stick fallback used when no bound key is currently held.
///
/// Touch stays entirely external to this class, same as it always has:
/// movement's touch path is the separate, always-on `VirtualJoystick`
/// widget, and aim's is a second instance of the same widget — neither goes
/// through [InputActionResolver.getVector2] at all, both write straight into
/// their own ECS component instead (see `lib/game/systems/aim_direction.dart`
/// for how aim's three sources — virtual joystick, [gamepadStick], and
/// [useMouseAim] — are combined into one direction outside this package,
/// since only the app knows about camera/world-position, which turning a
/// screen-space mouse position into a direction requires). Dpad-as-movement
/// is also deliberately unsupported here — the dpad stays usable only as
/// four separate [InputBinding.gamepadButton] bindings.
class Vector2Binding {
  const Vector2Binding({
    this.up = const [],
    this.down = const [],
    this.left = const [],
    this.right = const [],
    this.gamepadStick,
    this.useMouseAim = false,
  });

  final List<LogicalKeyboardKey> up;
  final List<LogicalKeyboardKey> down;
  final List<LogicalKeyboardKey> left;
  final List<LogicalKeyboardKey> right;

  /// Which analog stick, if any, drives this action when no bound key is
  /// currently held. `null` means no gamepad fallback is configured.
  final GamepadStick? gamepadStick;

  /// Whether this action falls back to a mouse-cursor-derived direction when
  /// no key/stick/touch source is currently active — meaningful for `aim`,
  /// not `move`. Resolving it requires camera + world-position context this
  /// package doesn't have, so [InputActionResolver.getVector2] never reads
  /// this flag itself; it's just carried here so the app-level aim resolver
  /// (and the editor's Input Setup panel) know whether mouse aim is enabled
  /// for a given action.
  final bool useMouseAim;

  Map<String, dynamic> toJson() => {
    'up': keyListToJson(up),
    'down': keyListToJson(down),
    'left': keyListToJson(left),
    'right': keyListToJson(right),
    'gamepadStick': gamepadStick?.name,
    'useMouseAim': useMouseAim,
  };

  factory Vector2Binding.fromJson(Map<String, dynamic> json) {
    final rawStick = json['gamepadStick'] as String?;
    return Vector2Binding(
      up: parseKeyList(json['up'] as List<dynamic>?),
      down: parseKeyList(json['down'] as List<dynamic>?),
      left: parseKeyList(json['left'] as List<dynamic>?),
      right: parseKeyList(json['right'] as List<dynamic>?),
      gamepadStick: rawStick == null
          ? null
          : GamepadStick.values.firstWhere(
              (value) => value.name == rawStick,
              orElse: () => GamepadStick.left,
            ),
      useMouseAim: json['useMouseAim'] as bool? ?? false,
    );
  }
}
