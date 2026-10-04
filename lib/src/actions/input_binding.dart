import 'package:flutter/painting.dart' show Alignment;
import 'package:flutter/services.dart';

import 'key_list_codec.dart';

/// How an action can be triggered from a touch surface.
enum TouchBindingKind { none, onScreenButton }

/// A single action's bound inputs — zero or more simultaneous keys, an
/// optional mouse button, an optional gamepad button, and an optional
/// on-screen touch button.
///
/// A [List] of keys (not a single nullable key) is required because a
/// binding may legitimately map to more than one key at once (e.g. both
/// WASD and arrow keys driving the same movement action).
class InputBinding {
  const InputBinding({
    this.keys = const [],
    this.mouseButton,
    this.gamepadButton,
    this.touch = TouchBindingKind.none,
    this.touchPosition,
  });

  final List<LogicalKeyboardKey> keys;
  final int? mouseButton;

  /// A `GamepadButton.*` constant (see `controller_input.dart`) — a single
  /// nullable int, not a list, mirroring [mouseButton]: the standard-layout
  /// normalization already makes "button 0" mean the same physical position
  /// regardless of controller brand, so one action needs at most one gamepad
  /// button, same reasoning as mouse.
  final int? gamepadButton;
  final TouchBindingKind touch;

  /// Freeform on-screen position, normalized the same way [Alignment] is
  /// (0,0 = center, -1,-1 = top-left, 1,1 = bottom-right) — resolution
  /// independent, and directly usable as the `alignment` of an [Align]
  /// widget. Only meaningful when [touch] is [TouchBindingKind.onScreenButton].
  final Alignment? touchPosition;

  Map<String, dynamic> toJson() => {
    'keys': keyListToJson(keys),
    'mouseButton': mouseButton,
    'gamepadButton': gamepadButton,
    'touch': touch.name,
    'touchPosition': touchPosition == null
        ? null
        : {'x': touchPosition!.x, 'y': touchPosition!.y},
  };

  factory InputBinding.fromJson(Map<String, dynamic> json) {
    final rawPosition = json['touchPosition'] as Map<String, dynamic>?;
    return InputBinding(
      keys: parseKeyList(json['keys'] as List<dynamic>?),
      mouseButton: (json['mouseButton'] as num?)?.toInt(),
      gamepadButton: (json['gamepadButton'] as num?)?.toInt(),
      touch: TouchBindingKind.values.firstWhere(
        (value) => value.name == json['touch'],
        orElse: () => TouchBindingKind.none,
      ),
      touchPosition: rawPosition == null
          ? null
          : Alignment(
              (rawPosition['x'] as num?)?.toDouble() ?? 0,
              (rawPosition['y'] as num?)?.toDouble() ?? 0,
            ),
    );
  }
}
