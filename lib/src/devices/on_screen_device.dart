import 'dart:ui' show Offset;

import '../model/on_screen_control_def.dart';
import '../paths/control_path.dart';
import 'input_device.dart';

final class OnScreenState extends DeviceState<OnScreenState> {
  OnScreenState([Map<String, bool>? buttons, Map<String, Offset>? sticks])
    : buttons = buttons ?? {},
      sticks = sticks ?? {};

  final Map<String, bool> buttons;
  final Map<String, Offset> sticks;

  @override
  OnScreenState copy() => OnScreenState({...buttons}, {...sticks});
}

/// The controls a game draws on a touch screen, as a device: the widget
/// that draws them sets them, and bindings read them like any other button
/// or stick — `<OnScreen>/jump`.
final class OnScreenDevice extends StatefulDevice<OnScreenState> {
  OnScreenDevice({required super.deviceId})
    : super(
        layout: InputLayouts.onScreen,
        displayName: 'On-screen controls',
        initial: OnScreenState(),
      );

  List<InputControl> _controls = const [];
  Map<String, InputControl> _byName = const {};

  @override
  List<InputControl> get controls => _controls;

  @override
  InputControl? control(String name) => _byName[name];

  /// Makes a control for each of [defs] — the asset's list, whenever an
  /// asset is loaded.
  void configure(List<OnScreenControlDef> defs) {
    _controls = [
      for (final d in defs)
        if (d.kind == OnScreenKind.button)
          InputControl(
            this,
            ControlPath(layout, d.id),
            ControlValueType.button,
            (s) => buttonValue((s as OnScreenState).buttons[d.id] ?? false),
          )
        else
          ...vector2Controls(
            this,
            d.id,
            (s) => (s as OnScreenState).sticks[d.id] ?? Offset.zero,
          ),
    ];
    _byName = {for (final c in _controls) c.name: c};
    // A control the new asset lacks lets go.
    final ids = {for (final d in defs) d.id};
    if (live.buttons.keys.any((k) => !ids.contains(k)) ||
        live.sticks.keys.any((k) => !ids.contains(k))) {
      queue((s) {
        s.buttons.removeWhere((k, _) => !ids.contains(k));
        s.sticks.removeWhere((k, _) => !ids.contains(k));
      });
    }
  }

  void setButton(String id, bool down) {
    if ((live.buttons[id] ?? false) == down) return;
    queue((s) => s.buttons[id] = down);
  }

  /// [value] from -1 to 1 on each axis, y down.
  void setStick(String id, Offset value) {
    final clamped = value.distance > 1 ? value / value.distance : value;
    if ((live.sticks[id] ?? Offset.zero) == clamped) return;
    queue((s) => s.sticks[id] = clamped);
  }

  void releaseAll() {
    if (live.buttons.values.every((d) => !d) &&
        live.sticks.values.every((v) => v == Offset.zero)) {
      return;
    }
    queue((s) {
      s.buttons.updateAll((_, _) => false);
      s.sticks.updateAll((_, _) => Offset.zero);
    });
  }
}
