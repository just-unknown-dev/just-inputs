/// What an on-screen control is.
enum OnScreenKind { button, stick }

/// Where an on-screen stick sits.
enum StickMode {
  /// Always in one place.
  fixed,

  /// Appears under the thumb, anywhere in its [OnScreenControlDef.region].
  floating,
}

/// Which way an on-screen stick moves.
enum StickAxis { both, horizontal, vertical }

/// A button or stick drawn on a touch screen. Bindings name it by id:
/// `<OnScreen>/jump`.
///
/// Placement is relative to the screen so one layout fits every device:
/// [anchorX] and [anchorY] run from -1 (left/top) to 1 (right/bottom), like
/// Flutter's `Alignment`, and [size] is a share of the screen's shorter
/// side.
final class OnScreenControlDef {
  const OnScreenControlDef({
    required this.id,
    this.kind = OnScreenKind.button,
    this.anchorX = 0,
    this.anchorY = 0,
    this.size = 0.16,
    this.label = '',
    this.stickMode = StickMode.fixed,
    this.stickAxis = StickAxis.both,
    this.region = const [0, 0, 1, 1],
  });

  factory OnScreenControlDef.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw FormatException('An on-screen control needs an "id": $json');
    }
    final anchor = (json['anchor'] as List?)?.cast<num>() ?? const [0, 0];
    final region = (json['region'] as List?)?.cast<num>();
    return OnScreenControlDef(
      id: id,
      kind: OnScreenKind.values.byName(json['kind'] as String? ?? 'button'),
      anchorX: anchor[0].toDouble(),
      anchorY: anchor[1].toDouble(),
      size: (json['size'] as num?)?.toDouble() ?? 0.16,
      label: json['label'] as String? ?? '',
      stickMode: StickMode.values.byName(json['mode'] as String? ?? 'fixed'),
      stickAxis: StickAxis.values.byName(json['axis'] as String? ?? 'both'),
      region: region == null || region.length != 4
          ? const [0, 0, 1, 1]
          : [for (final v in region) v.toDouble()],
    );
  }

  /// Also its control name — letters, digits and `_`.
  final String id;

  final OnScreenKind kind;
  final double anchorX;
  final double anchorY;
  final double size;

  /// Written on a button.
  final String label;

  final StickMode stickMode;
  final StickAxis stickAxis;

  /// Where a floating stick may appear: left, top, right, bottom as shares
  /// of the screen.
  final List<double> region;

  OnScreenControlDef copyWith({
    String? id,
    OnScreenKind? kind,
    double? anchorX,
    double? anchorY,
    double? size,
    String? label,
    StickMode? stickMode,
    StickAxis? stickAxis,
    List<double>? region,
  }) => OnScreenControlDef(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    anchorX: anchorX ?? this.anchorX,
    anchorY: anchorY ?? this.anchorY,
    size: size ?? this.size,
    label: label ?? this.label,
    stickMode: stickMode ?? this.stickMode,
    stickAxis: stickAxis ?? this.stickAxis,
    region: region ?? this.region,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'anchor': [anchorX, anchorY],
    'size': size,
    if (label.isNotEmpty) 'label': label,
    if (kind == OnScreenKind.stick) ...{
      'mode': stickMode.name,
      'axis': stickAxis.name,
      if (stickMode == StickMode.floating) 'region': region,
    },
  };
}
