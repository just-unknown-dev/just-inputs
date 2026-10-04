import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../model/on_screen_control_def.dart';
import '../runtime/input_service.dart';

/// When the on-screen controls show.
enum OnScreenVisibility {
  always,

  /// On phones and tablets only.
  touchPlatforms,
}

/// Where each on-screen control sits in a box of [size]: its centre and
/// its diameter. Shared by the game and the editor's layout view, so what
/// is placed there is what is played.
({Offset center, double diameter}) onScreenPlacement(
  OnScreenControlDef def,
  Size size,
) {
  final shortest = math.min(size.width, size.height);
  return (
    center: Offset(
      (def.anchorX + 1) / 2 * size.width,
      (def.anchorY + 1) / 2 * size.height,
    ),
    diameter: def.size * shortest,
  );
}

/// The asset's on-screen buttons and sticks, drawn and working — each with
/// its own finger, so moving and jumping at once is two thumbs, not a
/// fight over one.
///
/// Presses go into [input]'s on-screen device, where bindings like
/// `<OnScreen>/jump` read them like any other control.
class OnScreenControls extends StatelessWidget {
  const OnScreenControls({
    super.key,
    required this.input,
    this.controls,
    this.visibility = OnScreenVisibility.touchPlatforms,
    this.color = const Color(0xFFFFFFFF),
    this.labelFor,
  });

  final InputService input;

  /// Defaults to the asset's.
  final List<OnScreenControlDef>? controls;

  final OnScreenVisibility visibility;
  final Color color;

  /// A button's text; defaults to its label.
  final String Function(OnScreenControlDef def)? labelFor;

  static bool get _touchPlatform =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (visibility == OnScreenVisibility.touchPlatforms && !_touchPlatform) {
      return const SizedBox.shrink();
    }
    final defs = controls ?? input.asset.onScreen;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          return Stack(
            children: [
              for (final def in defs)
                if (def.kind == OnScreenKind.button)
                  _positioned(
                    def,
                    size,
                    _Button(
                      input: input,
                      def: def,
                      color: color,
                      label: labelFor?.call(def) ?? def.label,
                    ),
                  )
                else if (def.stickMode == StickMode.floating)
                  Positioned.fromRect(
                    rect: Rect.fromLTRB(
                      def.region[0] * size.width,
                      def.region[1] * size.height,
                      def.region[2] * size.width,
                      def.region[3] * size.height,
                    ),
                    child: _Stick(
                      input: input,
                      def: def,
                      color: color,
                      radius: onScreenPlacement(def, size).diameter / 2,
                    ),
                  )
                else
                  _positioned(
                    def,
                    size,
                    _Stick(
                      input: input,
                      def: def,
                      color: color,
                      radius: onScreenPlacement(def, size).diameter / 2,
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _positioned(OnScreenControlDef def, Size size, Widget child) {
    final p = onScreenPlacement(def, size);
    return Positioned(
      left: p.center.dx - p.diameter / 2,
      top: p.center.dy - p.diameter / 2,
      width: p.diameter,
      height: p.diameter,
      child: child,
    );
  }
}

class _Button extends StatefulWidget {
  const _Button({
    required this.input,
    required this.def,
    required this.color,
    required this.label,
  });

  final InputService input;
  final OnScreenControlDef def;
  final Color color;
  final String label;

  @override
  State<_Button> createState() => _ButtonState();
}

class _ButtonState extends State<_Button> {
  final Set<int> _pointers = {};

  void _set() {
    widget.input.onScreen.setButton(widget.def.id, _pointers.isNotEmpty);
    setState(() {});
  }

  @override
  void dispose() {
    if (_pointers.isNotEmpty) {
      widget.input.onScreen.setButton(widget.def.id, false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final down = _pointers.isNotEmpty;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        _pointers.add(e.pointer);
        _set();
      },
      onPointerUp: (e) {
        _pointers.remove(e.pointer);
        _set();
      },
      onPointerCancel: (e) {
        _pointers.remove(e.pointer);
        _set();
      },
      child: OnScreenButtonFace(
        label: widget.label,
        color: widget.color,
        down: down,
      ),
    );
  }
}

/// How an on-screen button looks — the game's and the editor's.
class OnScreenButtonFace extends StatelessWidget {
  const OnScreenButtonFace({
    super.key,
    required this.label,
    required this.color,
    this.down = false,
  });

  final String label;
  final Color color;
  final bool down;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: down ? 0.45 : 0.22),
      border: Border.all(color: color.withValues(alpha: 0.7), width: 2),
    ),
    child: Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    ),
  );
}

class _Stick extends StatefulWidget {
  const _Stick({
    required this.input,
    required this.def,
    required this.color,
    required this.radius,
  });

  final InputService input;
  final OnScreenControlDef def;
  final Color color;
  final double radius;

  @override
  State<_Stick> createState() => _StickState();
}

class _StickState extends State<_Stick> {
  int? _pointer;
  Offset? _origin;
  Offset _knob = Offset.zero;

  bool get _floating => widget.def.stickMode == StickMode.floating;

  Offset _centre(Size size) => _floating
      ? (_origin ?? size.center(Offset.zero))
      : size.center(Offset.zero);

  void _move(Offset local, Size size) {
    final r = widget.radius;
    var d = local - _centre(size);
    switch (widget.def.stickAxis) {
      case StickAxis.horizontal:
        d = Offset(d.dx, 0);
      case StickAxis.vertical:
        d = Offset(0, d.dy);
      case StickAxis.both:
        break;
    }
    if (d.distance > r) d = d / d.distance * r;
    setState(() => _knob = d);
    widget.input.onScreen.setStick(widget.def.id, r == 0 ? Offset.zero : d / r);
  }

  void _end() {
    setState(() {
      _pointer = null;
      _origin = null;
      _knob = Offset.zero;
    });
    widget.input.onScreen.setStick(widget.def.id, Offset.zero);
  }

  @override
  void dispose() {
    if (_pointer != null) {
      widget.input.onScreen.setStick(widget.def.id, Offset.zero);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final showing = !_floating || _pointer != null;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer != null) return;
          _pointer = e.pointer;
          if (_floating) _origin = e.localPosition;
          _move(e.localPosition, size);
        },
        onPointerMove: (e) {
          if (e.pointer == _pointer) _move(e.localPosition, size);
        },
        onPointerUp: (e) {
          if (e.pointer == _pointer) _end();
        },
        onPointerCancel: (e) {
          if (e.pointer == _pointer) _end();
        },
        child: showing
            ? CustomPaint(
                size: size,
                painter: OnScreenStickPainter(
                  centre: _centre(size),
                  radius: widget.radius,
                  knob: _knob,
                  color: widget.color,
                ),
              )
            : const SizedBox.expand(),
      );
    },
  );
}

/// Draws a stick: its ring and its knob — the game's and the editor's.
class OnScreenStickPainter extends CustomPainter {
  OnScreenStickPainter({
    required this.centre,
    required this.radius,
    required this.knob,
    required this.color,
  });

  final Offset centre;
  final double radius;
  final Offset knob;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(
        centre,
        radius,
        Paint()..color = color.withValues(alpha: 0.15),
      )
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: 0.6),
      )
      ..drawCircle(
        centre + knob,
        radius * 0.42,
        Paint()..color = color.withValues(alpha: 0.55),
      );
  }

  @override
  bool shouldRepaint(OnScreenStickPainter old) =>
      old.centre != centre ||
      old.knob != knob ||
      old.radius != radius ||
      old.color != color;
}
