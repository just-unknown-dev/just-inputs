import '../paths/control_path.dart';
import '../paths/gamepad_controls.dart';
import '../paths/pointer_controls.dart';
import 'action_def.dart';
import 'binding_def.dart';
import 'input_action_asset.dart';

/// Ready-made look actions for a camera that turns, in the shape
/// `LookInput` reads. Look comes as two actions because it comes two ways:
///
/// - [pointer], `look`: **movement**: the mouse (a locked pointer's raw
///   movement included) and, if wanted, a finger's drag. A distance, turned
///   into an angle by a sensitivity and read once per rendered frame.
/// - [stick], `lookStick`: a **rate**: the right stick (and an on-screen
///   stick on touch screens). A deflection, turned into an angle by degrees
///   per second times the frame's time.
///
/// Mixing the two in one action would make one of them wrong: a stick held
/// still is a steady turn, a mouse held still is none.
abstract final class LookActions {
  /// The movement look's name.
  static const String pointer = 'look';

  /// The rate look's name.
  static const String stick = 'lookStick';

  /// [asset] with the two look actions added to the map called [map] (a new
  /// one, on at start, if there is none):
  ///
  /// - `look`, a pass-through vector 2, not offered for rebinding:
  ///   `<Mouse>/delta`, and `<Touchscreen>/delta` with [touchDrag]. The
  ///   touch screen follows the first finger down, which on a phone is often
  ///   the one moving, so it is off by default.
  /// - `lookStick`, a vector 2: `<Gamepad>/rightStick`, and
  ///   `<OnScreen>/[onScreenStick]` when given — the id of an on-screen
  ///   stick the asset places.
  ///
  /// Each binding joins the group of every scheme that uses its device, so
  /// a player on a gamepad does not turn with the mouse. An action already
  /// in the map under either name is left as it is. Ids come from the
  /// asset's counter.
  static InputActionAsset addTo(
    InputActionAsset asset, {
    String map = 'player',
    bool touchDrag = false,
    String? onScreenStick,
  }) {
    var next = asset;
    String id(String prefix) {
      final (taken, spent) = next.takeId(prefix);
      next = spent;
      return taken;
    }

    List<String> groupsOf(String layout) => [
      for (final s in asset.schemes)
        if (s.group.isNotEmpty && s.layouts.contains(layout)) s.group,
    ];

    ControlBindingDef bind(String layout, String control) => ControlBindingDef(
      id: id('b'),
      path: ControlPath(layout, control).toString(),
      groups: groupsOf(layout),
    );

    final existing = asset.mapNamed(map);
    final target = existing ?? ActionMapDef(id: id('m'), name: map);
    final added = <InputActionDef>[
      if (target.actionNamed(pointer) == null)
        InputActionDef(
          id: id('a'),
          name: pointer,
          type: ActionValueType.vector2,
          passThrough: true,
          displayName: 'Look',
          rebindable: false,
          bindings: [
            bind(InputLayouts.mouse, MouseControls.delta),
            if (touchDrag)
              bind(InputLayouts.touchscreen, TouchscreenControls.delta),
          ],
        ),
      if (target.actionNamed(stick) == null)
        InputActionDef(
          id: id('a'),
          name: stick,
          type: ActionValueType.vector2,
          displayName: 'Look (Stick)',
          bindings: [
            bind(InputLayouts.gamepad, GamepadControls.rightStick),
            if (onScreenStick != null)
              bind(InputLayouts.onScreen, onScreenStick),
          ],
        ),
    ];
    if (added.isEmpty) return asset;
    final updated = target.copyWith(actions: [...target.actions, ...added]);
    return next.copyWith(
      maps: existing == null
          ? [...asset.maps, updated]
          : [
              for (final m in asset.maps)
                if (identical(m, existing)) updated else m,
            ],
    );
  }
}
