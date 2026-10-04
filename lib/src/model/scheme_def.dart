/// A device a control scheme uses.
final class DeviceRequirement {
  const DeviceRequirement(this.layout, {this.optional = false});

  factory DeviceRequirement.fromJson(Map<String, dynamic> json) =>
      DeviceRequirement(
        json['layout'] as String,
        optional: json['optional'] == true,
      );

  /// A layout name: `Keyboard`, `Gamepad`.
  final String layout;

  /// Used when there is one, not needed to play — the mouse beside a
  /// keyboard.
  final bool optional;

  Map<String, dynamic> toJson() => {
    'layout': layout,
    if (optional) 'optional': true,
  };
}

/// A way of playing — keyboard and mouse, a gamepad, touch — and the
/// bindings that go with it. A player plays one scheme at a time; bindings
/// outside it do nothing for them.
final class ControlSchemeDef {
  const ControlSchemeDef({
    required this.name,
    required this.group,
    this.devices = const [],
  });

  factory ControlSchemeDef.fromJson(Map<String, dynamic> json) =>
      ControlSchemeDef(
        name: json['name'] as String,
        group: json['group'] as String? ?? json['name'] as String,
        devices: [
          for (final d in (json['devices'] as List?) ?? const [])
            DeviceRequirement.fromJson((d as Map).cast<String, dynamic>()),
        ],
      );

  /// What a player sees: `Keyboard & Mouse`.
  final String name;

  /// What bindings name in their `groups`: `KeyboardMouse`.
  final String group;

  final List<DeviceRequirement> devices;

  Iterable<String> get requiredLayouts =>
      devices.where((d) => !d.optional).map((d) => d.layout);

  Iterable<String> get layouts => devices.map((d) => d.layout);

  ControlSchemeDef copyWith({
    String? name,
    String? group,
    List<DeviceRequirement>? devices,
  }) => ControlSchemeDef(
    name: name ?? this.name,
    group: group ?? this.group,
    devices: devices ?? this.devices,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'group': group,
    'devices': [for (final d in devices) d.toJson()],
  };
}
