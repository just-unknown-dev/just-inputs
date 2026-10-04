import 'package:flutter/services.dart';

import '../paths/control_path.dart';
import '../paths/keyboard_keys.dart';
import 'input_device.dart';

final class KeyboardState extends DeviceState<KeyboardState> {
  KeyboardState([Set<int>? down]) : down = down ?? {};

  /// The USB HID usages of the keys held.
  final Set<int> down;

  @override
  KeyboardState copy() => KeyboardState({...down});
}

/// The keyboard. Keys are by position; see [KeyboardKeys].
final class KeyboardDevice extends StatefulDevice<KeyboardState> {
  KeyboardDevice({required super.deviceId})
    : super(
        layout: InputLayouts.keyboard,
        displayName: 'Keyboard',
        initial: KeyboardState(),
      );

  late final List<InputControl> _controls = [
    for (final k in KeyboardKeys.all)
      InputControl(
        this,
        k.path,
        ControlValueType.button,
        k.name == KeyboardKeys.anyKey
            ? (s) => buttonValue((s as KeyboardState).down.isNotEmpty)
            : k.keys.length == 1
            ? _single(k.keys.single.usbHidUsage)
            : _either([for (final key in k.keys) key.usbHidUsage]),
        synthetic: k.isEitherSide || k.name == KeyboardKeys.anyKey,
      ),
  ];

  late final Map<String, InputControl> _byName = {
    for (final c in _controls) c.name: c,
  };

  static Offset Function(Object) _single(int usage) =>
      (s) => buttonValue((s as KeyboardState).down.contains(usage));

  static Offset Function(Object) _either(List<int> usages) =>
      (s) => buttonValue(usages.any((s as KeyboardState).down.contains));

  @override
  List<InputControl> get controls => _controls;

  @override
  InputControl? control(String name) => _byName[name];

  /// What each key says on the player's own layout, learned from the keys
  /// they press — `Z` where a US board has `W`. Keyed by USB HID usage.
  final Map<int, String> layoutLabels = {};

  /// The key's face on this player's layout if a press has taught it,
  /// else the US face.
  String labelOf(KeyboardKeyInfo key) {
    if (key.keys.length != 1) return key.label;
    return layoutLabels[key.keys.single.usbHidUsage] ?? key.label;
  }

  /// Feeds a key event in. Repeats are not presses and are ignored.
  void handleKeyEvent(KeyEvent event) {
    final usage = event.physicalKey.usbHidUsage;
    switch (event) {
      case KeyDownEvent():
        _learn(event);
        if (live.down.contains(usage)) return;
        queue((s) => s.down.add(usage));
      case KeyUpEvent():
        if (!live.down.contains(usage)) return;
        queue((s) => s.down.remove(usage));
      case KeyRepeatEvent():
        return;
    }
  }

  void _learn(KeyDownEvent event) {
    final label = event.logicalKey.keyLabel;
    // One printable character is the key's face. Named keys (Enter,
    // Arrow Left) keep the table's short labels.
    if (label.runes.length == 1 && label.trim().isNotEmpty) {
      layoutLabels[event.physicalKey.usbHidUsage] = label.toUpperCase();
    }
  }

  /// Lets go of every key — the window lost focus, and the key-ups will
  /// never come.
  void releaseAll() {
    final held = [...live.down];
    for (final usage in held) {
      queue((s) => s.down.remove(usage));
    }
  }

  bool isDown(PhysicalKeyboardKey key, {bool live = false}) =>
      (live ? this.live : applied).down.contains(key.usbHidUsage);
}
