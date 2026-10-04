import '../model/on_screen_control_def.dart';
import 'control_info.dart';
import 'control_path.dart';
import 'gamepad_controls.dart';
import 'keyboard_keys.dart';
import 'pointer_controls.dart';

/// Every control a binding can name — what the editor's picker lists, and
/// what validation checks a path against.
///
/// On-screen controls exist only if the asset lists them, so the lookups
/// take the asset's list.
abstract final class ControlCatalog {
  static final List<ControlInfo> keyboard = [
    for (final k in KeyboardKeys.all)
      ControlInfo(k.path, k.label, ControlValueType.button),
  ];

  static List<ControlInfo> get gamepad => GamepadControls.all;
  static List<ControlInfo> get mouse => MouseControls.all;
  static List<ControlInfo> get touchscreen => TouchscreenControls.all;

  /// The asset's on-screen buttons and sticks as controls.
  static List<ControlInfo> onScreenControls(
    List<OnScreenControlDef> controls,
  ) => [
    for (final c in controls)
      if (c.kind == OnScreenKind.button)
        ControlInfo(_onScreen(c.id), _onScreenLabel(c), ControlValueType.button)
      else
        ControlInfo(
          _onScreen(c.id),
          _onScreenLabel(c),
          ControlValueType.vector2,
          children: vector2Children(_onScreen(c.id), _onScreenLabel(c)),
        ),
  ];

  static ControlPath _onScreen(String id) =>
      ControlPath(InputLayouts.onScreen, id);

  static String _onScreenLabel(OnScreenControlDef c) =>
      c.label.isNotEmpty ? 'On-screen ${c.label}' : 'On-screen ${c.id}';

  /// The top-level controls of [layout].
  static List<ControlInfo> forLayout(
    String layout, {
    List<OnScreenControlDef> onScreen = const [],
  }) => switch (layout) {
    InputLayouts.keyboard => keyboard,
    InputLayouts.mouse => mouse,
    InputLayouts.gamepad => gamepad,
    InputLayouts.touchscreen => touchscreen,
    InputLayouts.onScreen => onScreenControls(onScreen),
    _ => const [],
  };

  /// The control [path] names, children included, or null when there is no
  /// such control.
  static ControlInfo? find(
    ControlPath path, {
    List<OnScreenControlDef> onScreen = const [],
  }) {
    for (final top in forLayout(path.layout, onScreen: onScreen)) {
      if (top.path.root != path.root) continue;
      for (final c in top.flattened) {
        if (c.path == path) return c;
      }
    }
    return null;
  }

  /// Everything, grouped by layout in [InputLayouts.all] order.
  static Map<String, List<ControlInfo>> all({
    List<OnScreenControlDef> onScreen = const [],
  }) => {
    for (final layout in InputLayouts.all)
      layout: forLayout(layout, onScreen: onScreen),
  };
}
