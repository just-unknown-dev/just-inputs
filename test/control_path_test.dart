import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_inputs/just_inputs.dart';

void main() {
  group('a control path', () {
    test('reads layout and control, and writes them back', () {
      final path = ControlPath.parse('<Gamepad>/leftStick/up');
      expect(path.layout, 'Gamepad');
      expect(path.control, 'leftStick/up');
      expect(path.root, 'leftStick');
      expect(path.child, 'up');
      expect(path.segments, ['leftStick', 'up']);
      expect(path.toString(), '<Gamepad>/leftStick/up');
      expect(ControlPath.parse('<Keyboard>/space').child, isNull);
    });

    test('an empty or broken path is not one', () {
      for (final bad in [
        '',
        'space',
        '<Keyboard>',
        '<Keyboard>/',
        'Keyboard/space',
        '<Key board>/space',
        '<Keyboard>/sp ace',
      ]) {
        expect(ControlPath.tryParse(bad), isNull, reason: bad);
      }
      expect(() => ControlPath.parse('nope'), throwsFormatException);
    });

    test('face buttons by letter or shape read as their position', () {
      expect(ControlPath.parse('<Gamepad>/a').control, 'buttonSouth');
      expect(ControlPath.parse('<Gamepad>/cross').control, 'buttonSouth');
      expect(ControlPath.parse('<Gamepad>/circle').control, 'buttonEast');
      expect(ControlPath.parse('<Gamepad>/y').control, 'buttonNorth');
      expect(ControlPath.parse('<Gamepad>/options').control, 'start');
      // Only on a gamepad: a is a letter on a keyboard.
      expect(ControlPath.parse('<Keyboard>/a').control, 'a');
    });

    test('equal paths are equal', () {
      expect(
        ControlPath.parse('<Gamepad>/a'),
        ControlPath.parse('<Gamepad>/buttonSouth'),
      );
      expect({
        ControlPath.parse('<Keyboard>/w'),
        ControlPath.parse('<Keyboard>/w'),
      }, hasLength(1));
    });

    test('a whole control overlaps its parts, not its neighbours', () {
      final stick = ControlPath.parse('<Gamepad>/leftStick');
      final up = ControlPath.parse('<Gamepad>/leftStick/up');
      final right = ControlPath.parse('<Gamepad>/rightStick');
      final press = ControlPath.parse('<Gamepad>/leftStickPress');

      expect(stick.overlaps(up), isTrue);
      expect(up.overlaps(stick), isTrue);
      expect(stick.overlaps(stick), isTrue);
      expect(stick.overlaps(right), isFalse);
      expect(stick.overlaps(press), isFalse, reason: 'a prefix is not a part');
      expect(
        ControlPath.parse(
          '<Keyboard>/w',
        ).overlaps(ControlPath.parse('<Mouse>/w')),
        isFalse,
      );
    });
  });

  group('the keys a binding can name', () {
    test('every name is unique and every key has a face', () {
      final names = KeyboardKeys.all.map((k) => k.name).toList();
      expect(names.toSet(), hasLength(names.length));
      for (final k in KeyboardKeys.all) {
        expect(k.label, isNotEmpty, reason: k.name);
        expect(
          ControlPath.tryParse('<Keyboard>/${k.name}'),
          isNotNull,
          reason: k.name,
        );
      }
      expect(KeyboardKeys.all.length, greaterThan(100));
    });

    test('no physical key belongs to two single-key names', () {
      final usages = [
        for (final k in KeyboardKeys.all)
          if (k.keys.length == 1) k.keys.single.usbHidUsage,
      ];
      expect(usages.toSet(), hasLength(usages.length));
    });

    test('keys are found by position, whatever the layout', () {
      expect(KeyboardKeys.byPhysical(PhysicalKeyboardKey.keyW)!.name, 'w');
      expect(
        KeyboardKeys.byPhysical(PhysicalKeyboardKey.space)!.label,
        'Space',
      );
      expect(
        KeyboardKeys.byPhysical(PhysicalKeyboardKey.shiftLeft)!.name,
        'leftShift',
      );
      expect(
        KeyboardKeys.byName('upArrow')!.keys.single,
        PhysicalKeyboardKey.arrowUp,
      );
      expect(KeyboardKeys.byName('nope'), isNull);
    });

    test('shift is either Shift key; left shift is one of them', () {
      final shift = KeyboardKeys.byName('shift')!;
      expect(shift.isEitherSide, isTrue);
      expect(shift.keys, contains(PhysicalKeyboardKey.shiftRight));
      expect(
        KeyboardKeys.eitherSideOf(
          PhysicalKeyboardKey.shiftRight,
        ).map((k) => k.name),
        ['shift'],
      );
      expect(KeyboardKeys.eitherSideOf(PhysicalKeyboardKey.keyA), isEmpty);
    });
  });

  group('the catalogue', () {
    test('finds keys, buttons, sticks and their parts', () {
      ControlInfo? find(String p) => ControlCatalog.find(ControlPath.parse(p));

      expect(find('<Keyboard>/space')!.type, ControlValueType.button);
      expect(find('<Gamepad>/buttonSouth')!.label, 'Button South');
      expect(find('<Gamepad>/leftStick')!.type, ControlValueType.vector2);
      expect(find('<Gamepad>/leftStick/x')!.type, ControlValueType.axis);
      expect(find('<Gamepad>/leftStick/up')!.type, ControlValueType.button);
      expect(find('<Gamepad>/dpad/left')!.type, ControlValueType.button);
      expect(find('<Gamepad>/leftTrigger')!.type, ControlValueType.axis);
      expect(find('<Mouse>/scroll/y')!.type, ControlValueType.axis);
      expect(find('<Mouse>/leftButton')!.type, ControlValueType.button);
      expect(find('<Touchscreen>/press')!.type, ControlValueType.button);
      expect(find('<Gamepad>/nope'), isNull);
      expect(
        find('<Mouse>/position/up'),
        isNull,
        reason: 'a position has no directions',
      );
    });

    test('an on-screen control exists only if the asset lists it', () {
      const controls = [
        OnScreenControlDef(id: 'jump', label: 'JUMP'),
        OnScreenControlDef(id: 'stick', kind: OnScreenKind.stick),
      ];
      final jump = ControlPath.parse('<OnScreen>/jump');
      expect(ControlCatalog.find(jump), isNull);
      expect(
        ControlCatalog.find(jump, onScreen: controls)!.label,
        'On-screen JUMP',
      );
      expect(
        ControlCatalog.find(
          ControlPath.parse('<OnScreen>/stick/left'),
          onScreen: controls,
        )!.type,
        ControlValueType.button,
      );
    });

    test('every gamepad button maps to a W3C index', () {
      for (final info in ControlCatalog.gamepad.expand((c) => c.flattened)) {
        if (info.type != ControlValueType.button) continue;
        final control = info.path.control;
        if (control.contains('Stick/')) continue; // stick directions are axes
        expect(
          GamepadControls.buttonIndex.containsKey(control),
          isTrue,
          reason: control,
        );
      }
    });

    test('lists every layout, in order', () {
      expect(ControlCatalog.all().keys, InputLayouts.all);
    });
  });
}
