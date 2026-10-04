/// The device families a binding can name, as they are written inside the
/// angle brackets of a [ControlPath]: `<Keyboard>/space`.
abstract final class InputLayouts {
  static const String keyboard = 'Keyboard';
  static const String mouse = 'Mouse';
  static const String gamepad = 'Gamepad';
  static const String touchscreen = 'Touchscreen';

  /// The controls a game draws on a touch screen — the on-screen buttons and
  /// sticks its asset lists. Their names are the ids in the asset.
  static const String onScreen = 'OnScreen';

  static const List<String> all = [
    keyboard,
    mouse,
    gamepad,
    touchscreen,
    onScreen,
  ];
}

/// What a control produces.
///
/// A button is also an axis from 0 to 1 — that is how a trigger can be bound
/// where a button is wanted and a key where an axis is.
enum ControlValueType { button, axis, vector2 }

/// Where a binding reads from: a device family and a control on it, written
/// `<Layout>/control[/child]` — `<Keyboard>/w`, `<Gamepad>/leftStick/up`,
/// `<OnScreen>/jump`.
///
/// Only the syntax is checked here. Whether the control exists is the
/// catalogue's business ([ControlCatalog]), because an on-screen control only
/// exists if the asset lists it.
final class ControlPath {
  const ControlPath(this.layout, this.control);

  /// Reads `<Layout>/control`. Throws [FormatException] on anything else.
  factory ControlPath.parse(String source) {
    final path = tryParse(source);
    if (path == null) {
      throw FormatException('Not a control path: "$source"', source);
    }
    return path;
  }

  /// Reads `<Layout>/control`, or null when [source] is not one — an empty
  /// string (an unbound slot) included.
  static ControlPath? tryParse(String source) {
    final match = _pattern.firstMatch(source.trim());
    if (match == null) return null;
    final layout = match.group(1)!;
    var control = match.group(2)!;
    if (layout == InputLayouts.gamepad) control = _gamepadAlias(control);
    return ControlPath(layout, control);
  }

  static final RegExp _pattern = RegExp(
    r'^<([A-Za-z]+)>/([A-Za-z0-9_]+(?:/[A-Za-z0-9_]+)*)$',
  );

  /// The device family, without brackets: `Keyboard`.
  final String layout;

  /// The control, children after slashes: `leftStick/up`.
  final String control;

  List<String> get segments => control.split('/');

  /// The top-level control — `leftStick` for `leftStick/up`.
  String get root => segments.first;

  /// The child below [root], or null for a top-level control.
  String? get child {
    final i = control.indexOf('/');
    return i < 0 ? null : control.substring(i + 1);
  }

  /// Whether this path names [other] or something [other] is part of — the
  /// whole stick covers `leftStick/up`, and each covers itself.
  bool overlaps(ControlPath other) {
    if (layout != other.layout) return false;
    if (control == other.control) return true;
    return other.control.startsWith('$control/') ||
        control.startsWith('${other.control}/');
  }

  @override
  bool operator ==(Object other) =>
      other is ControlPath &&
      other.layout == layout &&
      other.control == control;

  @override
  int get hashCode => Object.hash(layout, control);

  @override
  String toString() => '<$layout>/$control';

  /// Face buttons by letter or by shape read as their position, so a path
  /// written for one brand means the same button on every pad.
  static String _gamepadAlias(String control) {
    final slash = control.indexOf('/');
    final head = slash < 0 ? control : control.substring(0, slash);
    final canonical = switch (head) {
      'a' || 'cross' => 'buttonSouth',
      'b' || 'circle' => 'buttonEast',
      'x' || 'square' => 'buttonWest',
      'y' || 'triangle' => 'buttonNorth',
      'lb' || 'leftBumper' => 'leftShoulder',
      'rb' || 'rightBumper' => 'rightShoulder',
      'back' || 'share' || 'view' => 'select',
      'options' || 'menu' => 'start',
      'l3' => 'leftStickPress',
      'r3' => 'rightStickPress',
      _ => head,
    };
    return slash < 0 ? canonical : '$canonical${control.substring(slash)}';
  }
}
