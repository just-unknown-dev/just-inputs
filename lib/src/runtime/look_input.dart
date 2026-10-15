import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../model/look_actions.dart';
import 'frame_motion.dart';
import 'input_actions.dart';

/// How look input becomes a turn. Immutable; a settings screen makes a new
/// one with [copyWith] and gives it to [LookInput.settings].
final class LookSettings {
  const LookSettings({
    this.radiansPerPixel = 0.0025,
    this.yawDegreesPerSecond = 180,
    this.pitchDegreesPerSecond = 120,
    this.invertX = false,
    this.invertY = false,
  });

  /// The pointer's sensitivity: radians turned per pixel of movement. A
  /// locked pointer's raw movement comes in device counts, about one
  /// physical pixel each at Windows' default pointer speed. 0.0025 turns a
  /// half circle over about 1250 of them.
  final double radiansPerPixel;

  /// How fast the stick turns side to side at full deflection, in degrees
  /// per second.
  final double yawDegreesPerSecond;

  /// How fast the stick turns up and down at full deflection, in degrees per
  /// second.
  final double pitchDegreesPerSecond;

  /// Flips side to side, for both ways of looking.
  final bool invertX;

  /// Flips up and down ("inverted look"), for both ways of looking.
  final bool invertY;

  LookSettings copyWith({
    double? radiansPerPixel,
    double? yawDegreesPerSecond,
    double? pitchDegreesPerSecond,
    bool? invertX,
    bool? invertY,
  }) => LookSettings(
    radiansPerPixel: radiansPerPixel ?? this.radiansPerPixel,
    yawDegreesPerSecond: yawDegreesPerSecond ?? this.yawDegreesPerSecond,
    pitchDegreesPerSecond: pitchDegreesPerSecond ?? this.pitchDegreesPerSecond,
    invertX: invertX ?? this.invertX,
    invertY: invertY ?? this.invertY,
  );
}

/// A camera's look, read once per rendered frame from the two look actions
/// ([LookActions]):
///
/// - the `pointer` action's **movement** since the last read (its
///   [motion]) times [LookSettings.radiansPerPixel];
/// - the [stick] action's **deflection** now times
///   [LookSettings.yawDegreesPerSecond] (and pitch) times the frame's
///   seconds.
///
/// The first does not depend on the frame's length, the second does, so the
/// sum turns the same over a second at 30 frames as at 240.
///
/// ```dart
/// final look = LookInput(engine.input.actionsFor(0)!);
///
/// // Once per rendered frame:
/// final turn = look.read(dt);
/// yaw += turn.dx;
/// pitch = (pitch + turn.dy).clamp(-1.4, 1.4);
/// ```
///
/// Read through the actions, so look follows what the actions follow:
/// maps switched off (a pause menu), a player's own devices, their
/// rebinding. A player's actions change when they join; make a new one for
/// the new [InputActions] and [dispose] the old.
final class LookInput {
  LookInput(
    this.actions, {
    String pointer = LookActions.pointer,
    this.stick = LookActions.stick,
    this.settings = const LookSettings(),
    bool relativeMouseOnly = false,
  }) : motion = FrameMotion(
         actions,
         pointer,
         relativeMouseOnly: relativeMouseOnly,
       );

  /// The actions read: a player's own, or the service's shared ones.
  final InputActions actions;

  /// Where the pointer's movement is read; its action is `motion.action`.
  /// Its [FrameMotion.relativeMouseOnly] can change while playing.
  final FrameMotion motion;

  /// The stick action's path, `player/lookStick` or a bare `lookStick`. One
  /// the asset does not have reads as no stick.
  final String stick;

  LookSettings settings;

  /// This frame's turn, in radians: `dx` the yaw (positive turns right),
  /// `dy` the pitch (positive looks down, y down like the screen). [dt] is
  /// the frame's length in seconds; give the unscaled one if slow motion
  /// should not slow the stick.
  ///
  /// Call it once per frame: the pointer's part is everything that moved
  /// since the last call.
  Offset read(double dt) {
    final s = settings;
    var turn = motion.take() * s.radiansPerPixel;
    final rate = actions.tryAction(stick)?.readVector2() ?? Offset.zero;
    if (rate != Offset.zero && dt > 0) {
      // Degrees per second to radians this frame.
      final scale = dt * math.pi / 180;
      turn += Offset(
        rate.dx * s.yawDegreesPerSecond * scale,
        rate.dy * s.pitchDegreesPerSecond * scale,
      );
    }
    return Offset(
      s.invertX ? -turn.dx : turn.dx,
      s.invertY ? -turn.dy : turn.dy,
    );
  }

  /// Forgets the pointer movement since the last [read]: after a cut, or a
  /// time when the camera was not reading.
  void reset() => motion.reset();

  /// Stops listening to the service.
  void dispose() => motion.dispose();
}
