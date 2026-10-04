import 'package:flutter/services.dart';

import 'control_path.dart';

/// Where a key sits on the board, for the picker and the keyboard view.
enum KeyGroup {
  letters,
  digits,
  symbols,
  whitespace,
  navigation,
  modifiers,
  function,
  numpad,
  system,
}

/// One key a binding can name.
///
/// Keys are bound by **position** ([PhysicalKeyboardKey]), the way a game
/// wants them: WASD stays under the left hand on an AZERTY board, and
/// holding Shift does not turn `1` into a different key. What the key says
/// on the player's own layout is learned at run time from the keys they
/// press; [label] is the US face, used until then.
///
/// Names are written out here rather than taken from `debugName`, which is
/// null in a release build.
final class KeyboardKeyInfo {
  const KeyboardKeyInfo(this.name, this.label, this.keys, this.group);

  /// The control name in a path: `<Keyboard>/[name]`.
  final String name;

  /// The US keycap.
  final String label;

  /// The physical keys that press it. More than one for the either-side
  /// modifiers (`shift` is both Shift keys); empty for [KeyboardKeys.anyKey].
  final List<PhysicalKeyboardKey> keys;

  final KeyGroup group;

  /// Either of two keys — the sided modifiers read as one.
  bool get isEitherSide => keys.length > 1;

  ControlPath get path => ControlPath(InputLayouts.keyboard, name);
}

/// Every key a binding can name.
abstract final class KeyboardKeys {
  /// Pressed by any key at all — "Press any key".
  static const String anyKey = 'anyKey';

  static const List<KeyboardKeyInfo> all = [
    // Letters.
    KeyboardKeyInfo('a', 'A', [PhysicalKeyboardKey.keyA], KeyGroup.letters),
    KeyboardKeyInfo('b', 'B', [PhysicalKeyboardKey.keyB], KeyGroup.letters),
    KeyboardKeyInfo('c', 'C', [PhysicalKeyboardKey.keyC], KeyGroup.letters),
    KeyboardKeyInfo('d', 'D', [PhysicalKeyboardKey.keyD], KeyGroup.letters),
    KeyboardKeyInfo('e', 'E', [PhysicalKeyboardKey.keyE], KeyGroup.letters),
    KeyboardKeyInfo('f', 'F', [PhysicalKeyboardKey.keyF], KeyGroup.letters),
    KeyboardKeyInfo('g', 'G', [PhysicalKeyboardKey.keyG], KeyGroup.letters),
    KeyboardKeyInfo('h', 'H', [PhysicalKeyboardKey.keyH], KeyGroup.letters),
    KeyboardKeyInfo('i', 'I', [PhysicalKeyboardKey.keyI], KeyGroup.letters),
    KeyboardKeyInfo('j', 'J', [PhysicalKeyboardKey.keyJ], KeyGroup.letters),
    KeyboardKeyInfo('k', 'K', [PhysicalKeyboardKey.keyK], KeyGroup.letters),
    KeyboardKeyInfo('l', 'L', [PhysicalKeyboardKey.keyL], KeyGroup.letters),
    KeyboardKeyInfo('m', 'M', [PhysicalKeyboardKey.keyM], KeyGroup.letters),
    KeyboardKeyInfo('n', 'N', [PhysicalKeyboardKey.keyN], KeyGroup.letters),
    KeyboardKeyInfo('o', 'O', [PhysicalKeyboardKey.keyO], KeyGroup.letters),
    KeyboardKeyInfo('p', 'P', [PhysicalKeyboardKey.keyP], KeyGroup.letters),
    KeyboardKeyInfo('q', 'Q', [PhysicalKeyboardKey.keyQ], KeyGroup.letters),
    KeyboardKeyInfo('r', 'R', [PhysicalKeyboardKey.keyR], KeyGroup.letters),
    KeyboardKeyInfo('s', 'S', [PhysicalKeyboardKey.keyS], KeyGroup.letters),
    KeyboardKeyInfo('t', 'T', [PhysicalKeyboardKey.keyT], KeyGroup.letters),
    KeyboardKeyInfo('u', 'U', [PhysicalKeyboardKey.keyU], KeyGroup.letters),
    KeyboardKeyInfo('v', 'V', [PhysicalKeyboardKey.keyV], KeyGroup.letters),
    KeyboardKeyInfo('w', 'W', [PhysicalKeyboardKey.keyW], KeyGroup.letters),
    KeyboardKeyInfo('x', 'X', [PhysicalKeyboardKey.keyX], KeyGroup.letters),
    KeyboardKeyInfo('y', 'Y', [PhysicalKeyboardKey.keyY], KeyGroup.letters),
    KeyboardKeyInfo('z', 'Z', [PhysicalKeyboardKey.keyZ], KeyGroup.letters),
    // The digit row.
    KeyboardKeyInfo('1', '1', [PhysicalKeyboardKey.digit1], KeyGroup.digits),
    KeyboardKeyInfo('2', '2', [PhysicalKeyboardKey.digit2], KeyGroup.digits),
    KeyboardKeyInfo('3', '3', [PhysicalKeyboardKey.digit3], KeyGroup.digits),
    KeyboardKeyInfo('4', '4', [PhysicalKeyboardKey.digit4], KeyGroup.digits),
    KeyboardKeyInfo('5', '5', [PhysicalKeyboardKey.digit5], KeyGroup.digits),
    KeyboardKeyInfo('6', '6', [PhysicalKeyboardKey.digit6], KeyGroup.digits),
    KeyboardKeyInfo('7', '7', [PhysicalKeyboardKey.digit7], KeyGroup.digits),
    KeyboardKeyInfo('8', '8', [PhysicalKeyboardKey.digit8], KeyGroup.digits),
    KeyboardKeyInfo('9', '9', [PhysicalKeyboardKey.digit9], KeyGroup.digits),
    KeyboardKeyInfo('0', '0', [PhysicalKeyboardKey.digit0], KeyGroup.digits),
    // Punctuation.
    KeyboardKeyInfo('backquote', '`', [
      PhysicalKeyboardKey.backquote,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('minus', '-', [
      PhysicalKeyboardKey.minus,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('equals', '=', [
      PhysicalKeyboardKey.equal,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('leftBracket', '[', [
      PhysicalKeyboardKey.bracketLeft,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('rightBracket', ']', [
      PhysicalKeyboardKey.bracketRight,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('backslash', r'\', [
      PhysicalKeyboardKey.backslash,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('semicolon', ';', [
      PhysicalKeyboardKey.semicolon,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('quote', "'", [
      PhysicalKeyboardKey.quote,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('comma', ',', [
      PhysicalKeyboardKey.comma,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('period', '.', [
      PhysicalKeyboardKey.period,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('slash', '/', [
      PhysicalKeyboardKey.slash,
    ], KeyGroup.symbols),
    KeyboardKeyInfo('intlBackslash', r'\ (ISO)', [
      PhysicalKeyboardKey.intlBackslash,
    ], KeyGroup.symbols),
    // Space, typing and editing.
    KeyboardKeyInfo('space', 'Space', [
      PhysicalKeyboardKey.space,
    ], KeyGroup.whitespace),
    KeyboardKeyInfo('enter', 'Enter', [
      PhysicalKeyboardKey.enter,
    ], KeyGroup.whitespace),
    KeyboardKeyInfo('tab', 'Tab', [
      PhysicalKeyboardKey.tab,
    ], KeyGroup.whitespace),
    KeyboardKeyInfo('backspace', 'Backspace', [
      PhysicalKeyboardKey.backspace,
    ], KeyGroup.whitespace),
    KeyboardKeyInfo('escape', 'Esc', [
      PhysicalKeyboardKey.escape,
    ], KeyGroup.system),
    // Arrows and the block above them.
    KeyboardKeyInfo('upArrow', '↑', [
      PhysicalKeyboardKey.arrowUp,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('downArrow', '↓', [
      PhysicalKeyboardKey.arrowDown,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('leftArrow', '←', [
      PhysicalKeyboardKey.arrowLeft,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('rightArrow', '→', [
      PhysicalKeyboardKey.arrowRight,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('insert', 'Insert', [
      PhysicalKeyboardKey.insert,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('delete', 'Delete', [
      PhysicalKeyboardKey.delete,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('home', 'Home', [
      PhysicalKeyboardKey.home,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('end', 'End', [
      PhysicalKeyboardKey.end,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('pageUp', 'Page Up', [
      PhysicalKeyboardKey.pageUp,
    ], KeyGroup.navigation),
    KeyboardKeyInfo('pageDown', 'Page Down', [
      PhysicalKeyboardKey.pageDown,
    ], KeyGroup.navigation),
    // Modifiers: one side, or either side.
    KeyboardKeyInfo('shift', 'Shift', [
      PhysicalKeyboardKey.shiftLeft,
      PhysicalKeyboardKey.shiftRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('ctrl', 'Ctrl', [
      PhysicalKeyboardKey.controlLeft,
      PhysicalKeyboardKey.controlRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('alt', 'Alt', [
      PhysicalKeyboardKey.altLeft,
      PhysicalKeyboardKey.altRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('meta', 'Meta', [
      PhysicalKeyboardKey.metaLeft,
      PhysicalKeyboardKey.metaRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('leftShift', 'Left Shift', [
      PhysicalKeyboardKey.shiftLeft,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('rightShift', 'Right Shift', [
      PhysicalKeyboardKey.shiftRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('leftCtrl', 'Left Ctrl', [
      PhysicalKeyboardKey.controlLeft,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('rightCtrl', 'Right Ctrl', [
      PhysicalKeyboardKey.controlRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('leftAlt', 'Left Alt', [
      PhysicalKeyboardKey.altLeft,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('rightAlt', 'Right Alt', [
      PhysicalKeyboardKey.altRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('leftMeta', 'Left Meta', [
      PhysicalKeyboardKey.metaLeft,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('rightMeta', 'Right Meta', [
      PhysicalKeyboardKey.metaRight,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('capsLock', 'Caps Lock', [
      PhysicalKeyboardKey.capsLock,
    ], KeyGroup.modifiers),
    KeyboardKeyInfo('contextMenu', 'Menu', [
      PhysicalKeyboardKey.contextMenu,
    ], KeyGroup.system),
    KeyboardKeyInfo('printScreen', 'Print Screen', [
      PhysicalKeyboardKey.printScreen,
    ], KeyGroup.system),
    KeyboardKeyInfo('scrollLock', 'Scroll Lock', [
      PhysicalKeyboardKey.scrollLock,
    ], KeyGroup.system),
    KeyboardKeyInfo('pause', 'Pause', [
      PhysicalKeyboardKey.pause,
    ], KeyGroup.system),
    // Function keys.
    KeyboardKeyInfo('f1', 'F1', [PhysicalKeyboardKey.f1], KeyGroup.function),
    KeyboardKeyInfo('f2', 'F2', [PhysicalKeyboardKey.f2], KeyGroup.function),
    KeyboardKeyInfo('f3', 'F3', [PhysicalKeyboardKey.f3], KeyGroup.function),
    KeyboardKeyInfo('f4', 'F4', [PhysicalKeyboardKey.f4], KeyGroup.function),
    KeyboardKeyInfo('f5', 'F5', [PhysicalKeyboardKey.f5], KeyGroup.function),
    KeyboardKeyInfo('f6', 'F6', [PhysicalKeyboardKey.f6], KeyGroup.function),
    KeyboardKeyInfo('f7', 'F7', [PhysicalKeyboardKey.f7], KeyGroup.function),
    KeyboardKeyInfo('f8', 'F8', [PhysicalKeyboardKey.f8], KeyGroup.function),
    KeyboardKeyInfo('f9', 'F9', [PhysicalKeyboardKey.f9], KeyGroup.function),
    KeyboardKeyInfo('f10', 'F10', [PhysicalKeyboardKey.f10], KeyGroup.function),
    KeyboardKeyInfo('f11', 'F11', [PhysicalKeyboardKey.f11], KeyGroup.function),
    KeyboardKeyInfo('f12', 'F12', [PhysicalKeyboardKey.f12], KeyGroup.function),
    // The number pad.
    KeyboardKeyInfo('numLock', 'Num Lock', [
      PhysicalKeyboardKey.numLock,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad0', 'Num 0', [
      PhysicalKeyboardKey.numpad0,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad1', 'Num 1', [
      PhysicalKeyboardKey.numpad1,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad2', 'Num 2', [
      PhysicalKeyboardKey.numpad2,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad3', 'Num 3', [
      PhysicalKeyboardKey.numpad3,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad4', 'Num 4', [
      PhysicalKeyboardKey.numpad4,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad5', 'Num 5', [
      PhysicalKeyboardKey.numpad5,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad6', 'Num 6', [
      PhysicalKeyboardKey.numpad6,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad7', 'Num 7', [
      PhysicalKeyboardKey.numpad7,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad8', 'Num 8', [
      PhysicalKeyboardKey.numpad8,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpad9', 'Num 9', [
      PhysicalKeyboardKey.numpad9,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadDivide', 'Num /', [
      PhysicalKeyboardKey.numpadDivide,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadMultiply', 'Num *', [
      PhysicalKeyboardKey.numpadMultiply,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadMinus', 'Num -', [
      PhysicalKeyboardKey.numpadSubtract,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadPlus', 'Num +', [
      PhysicalKeyboardKey.numpadAdd,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadEnter', 'Num Enter', [
      PhysicalKeyboardKey.numpadEnter,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadPeriod', 'Num .', [
      PhysicalKeyboardKey.numpadDecimal,
    ], KeyGroup.numpad),
    KeyboardKeyInfo('numpadEquals', 'Num =', [
      PhysicalKeyboardKey.numpadEqual,
    ], KeyGroup.numpad),
    // Any key at all.
    KeyboardKeyInfo(anyKey, 'Any key', [], KeyGroup.system),
  ];

  static final Map<String, KeyboardKeyInfo> _byName = {
    for (final k in all) k.name: k,
  };

  /// Single-key entries by the key's USB HID usage. The either-side
  /// modifiers are not here: a key belongs to its own side's entry.
  static final Map<int, KeyboardKeyInfo> _byUsage = {
    for (final k in all)
      if (k.keys.length == 1) k.keys.single.usbHidUsage: k,
  };

  /// The key a control name stands for, or null.
  static KeyboardKeyInfo? byName(String name) => _byName[name];

  /// The key [key] is, or null for a key no binding can name.
  static KeyboardKeyInfo? byPhysical(PhysicalKeyboardKey key) =>
      _byUsage[key.usbHidUsage];

  /// The either-side names ([KeyboardKeyInfo.isEitherSide]) [key] also
  /// presses — `shift` for Left Shift.
  static Iterable<KeyboardKeyInfo> eitherSideOf(PhysicalKeyboardKey key) =>
      all.where((k) => k.isEitherSide && k.keys.contains(key));
}
