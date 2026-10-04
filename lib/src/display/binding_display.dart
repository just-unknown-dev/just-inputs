import 'package:just_gamepads/just_gamepads.dart' as gp;

import '../devices/gamepad_device.dart';
import '../devices/input_device.dart';
import '../devices/keyboard_device.dart';
import '../model/binding_def.dart';
import '../model/input_action_asset.dart';
import '../paths/control_path.dart';
import '../paths/keyboard_keys.dart';
import '../paths/pointer_controls.dart';
import '../runtime/input_actions.dart';
import 'gamepad_glyphs.dart';

/// Turns bindings into what a player reads: `Space`, `W/A/S/D`,
/// `Shift + E`, `Ⓐ`.
final class BindingDisplay {
  const BindingDisplay({
    this.keyboard,
    this.padType = gp.GamepadType.xbox,
    this.asset,
  });

  /// For each key's face on the player's own layout, once they have pressed
  /// it.
  final KeyboardDevice? keyboard;

  /// Which brand's glyphs to show.
  final gp.GamepadType padType;

  /// For the on-screen controls' labels.
  final InputActionAsset? asset;

  /// A display for [device]'s player: their pad's brand, the keyboard's
  /// learned faces.
  factory BindingDisplay.forDevice(
    InputDevice? device, {
    KeyboardDevice? keyboard,
    InputActionAsset? asset,
  }) => BindingDisplay(
    keyboard: keyboard,
    padType: device is GamepadDevice ? device.type : gp.GamepadType.xbox,
    asset: asset,
  );

  /// One control. Empty for an empty path.
  String control(String path) {
    final p = ControlPath.tryParse(path);
    if (p == null) return path.trim().isEmpty ? '' : path;
    switch (p.layout) {
      case InputLayouts.keyboard:
        final key = KeyboardKeys.byName(p.control);
        if (key == null) return p.control;
        return keyboard?.labelOf(key) ?? key.label;
      case InputLayouts.gamepad:
        return GamepadGlyphs.label(padType, p.control);
      case InputLayouts.mouse:
        return switch (p.control) {
          MouseControls.leftButton => 'LMB',
          MouseControls.rightButton => 'RMB',
          MouseControls.middleButton => 'MMB',
          MouseControls.backButton => 'Mouse 4',
          MouseControls.forwardButton => 'Mouse 5',
          MouseControls.position => 'Mouse',
          MouseControls.delta => 'Mouse move',
          'scroll/up' => 'Wheel ↑',
          'scroll/down' => 'Wheel ↓',
          _ when p.root == MouseControls.scroll => 'Wheel',
          _ => 'Mouse ${p.control}',
        };
      case InputLayouts.touchscreen:
        return p.root == TouchscreenControls.press ? 'Tap' : 'Touch';
      case InputLayouts.onScreen:
        final def = asset?.onScreenControl(p.root);
        final name = def == null || def.label.isEmpty ? p.root : def.label;
        return p.child == null ? name : '$name ${p.child}';
    }
    return path;
  }

  /// A whole binding, [overrides] applied.
  String binding(
    InputBindingDef b, [
    Map<String, String> overrides = const {},
  ]) {
    switch (b) {
      case ControlBindingDef():
        return control(overrides[b.id] ?? b.path);
      case CompositeBindingDef():
        String part(String name) => [
          for (final p in b.partsNamed(name))
            control(overrides[p.id] ?? p.path),
        ].where((s) => s.isNotEmpty).join('|');
        switch (b.composite) {
          case CompositeKinds.vector2:
            return [
              part('up'),
              part('left'),
              part('down'),
              part('right'),
            ].join('/');
          case CompositeKinds.axis1D:
            return '${part('negative')}/${part('positive')}';
          case CompositeKinds.oneModifier:
            return '${part('modifier')} + ${part('binding')}';
          case CompositeKinds.twoModifiers:
            return '${part('modifier1')} + ${part('modifier2')} + ${part('binding')}';
        }
        return [
          for (final p in b.parts) control(overrides[p.id] ?? p.path),
        ].join(' ');
    }
  }

  /// How [actions] does the action at [path] now: its first binding in
  /// the scheme in use. Empty when it has none.
  String action(InputActions actions, String path) {
    final a = actions.tryAction(path);
    if (a == null) return '';
    for (final b in a.def.bindings) {
      if (!b.inGroup(actions.group)) continue;
      final text = binding(b, actions.overrides);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
}
