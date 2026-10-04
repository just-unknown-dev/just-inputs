/// The asset-wide defaults interactions and processors fall back on. In
/// seconds and shares of full travel.
final class InputSettingsDef {
  const InputSettingsDef({
    this.pressPoint = 0.5,
    this.releaseRatio = 0.75,
    this.holdTime = 0.4,
    this.tapTime = 0.2,
    this.slowTapTime = 0.5,
    this.multiTapDelay = 0.75,
    this.stickDeadzoneMin = 0.125,
    this.stickDeadzoneMax = 0.925,
    this.axisDeadzoneMin = 0.125,
    this.axisDeadzoneMax = 0.925,
  });

  factory InputSettingsDef.fromJson(Map<String, dynamic> json) {
    const d = InputSettingsDef();
    double n(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;
    return InputSettingsDef(
      pressPoint: n('pressPoint', d.pressPoint),
      releaseRatio: n('releaseRatio', d.releaseRatio),
      holdTime: n('holdTime', d.holdTime),
      tapTime: n('tapTime', d.tapTime),
      slowTapTime: n('slowTapTime', d.slowTapTime),
      multiTapDelay: n('multiTapDelay', d.multiTapDelay),
      stickDeadzoneMin: n('stickDeadzoneMin', d.stickDeadzoneMin),
      stickDeadzoneMax: n('stickDeadzoneMax', d.stickDeadzoneMax),
      axisDeadzoneMin: n('axisDeadzoneMin', d.axisDeadzoneMin),
      axisDeadzoneMax: n('axisDeadzoneMax', d.axisDeadzoneMax),
    );
  }

  /// How far a trigger or stick has to travel to count as pressed.
  final double pressPoint;

  /// Released again below `pressPoint * releaseRatio`, so a value resting on
  /// the press point does not chatter.
  final double releaseRatio;

  /// How long a hold takes.
  final double holdTime;

  /// The longest press that is still a tap.
  final double tapTime;

  /// The shortest press that is a slow tap.
  final double slowTapTime;

  /// The longest gap between the taps of a multi-tap.
  final double multiTapDelay;

  /// A stick nearer the centre than this reads as centred; past the max it
  /// reads as fully over.
  final double stickDeadzoneMin;
  final double stickDeadzoneMax;

  /// The same for a single axis — a trigger.
  final double axisDeadzoneMin;
  final double axisDeadzoneMax;

  double get releasePoint => pressPoint * releaseRatio;

  InputSettingsDef copyWith({
    double? pressPoint,
    double? releaseRatio,
    double? holdTime,
    double? tapTime,
    double? slowTapTime,
    double? multiTapDelay,
    double? stickDeadzoneMin,
    double? stickDeadzoneMax,
    double? axisDeadzoneMin,
    double? axisDeadzoneMax,
  }) => InputSettingsDef(
    pressPoint: pressPoint ?? this.pressPoint,
    releaseRatio: releaseRatio ?? this.releaseRatio,
    holdTime: holdTime ?? this.holdTime,
    tapTime: tapTime ?? this.tapTime,
    slowTapTime: slowTapTime ?? this.slowTapTime,
    multiTapDelay: multiTapDelay ?? this.multiTapDelay,
    stickDeadzoneMin: stickDeadzoneMin ?? this.stickDeadzoneMin,
    stickDeadzoneMax: stickDeadzoneMax ?? this.stickDeadzoneMax,
    axisDeadzoneMin: axisDeadzoneMin ?? this.axisDeadzoneMin,
    axisDeadzoneMax: axisDeadzoneMax ?? this.axisDeadzoneMax,
  );

  Map<String, dynamic> toJson() => {
    'pressPoint': pressPoint,
    'releaseRatio': releaseRatio,
    'holdTime': holdTime,
    'tapTime': tapTime,
    'slowTapTime': slowTapTime,
    'multiTapDelay': multiTapDelay,
    'stickDeadzoneMin': stickDeadzoneMin,
    'stickDeadzoneMax': stickDeadzoneMax,
    'axisDeadzoneMin': axisDeadzoneMin,
    'axisDeadzoneMax': axisDeadzoneMax,
  };
}

/// How players come into a game.
enum JoinBehavior {
  /// One player, who plays with whatever they touch.
  disabled,

  /// A device nobody is using joins as the next player when one of the
  /// [PlayerSettingsDef.joinActions] is performed on it.
  onJoinAction,
}

/// Local multiplayer.
final class PlayerSettingsDef {
  const PlayerSettingsDef({
    this.maxPlayers = 1,
    this.joining = JoinBehavior.disabled,
    this.joinActions = const [],
    this.autoJoinFirst = true,
    this.autoSwitch = true,
  });

  factory PlayerSettingsDef.fromJson(Map<String, dynamic> json) =>
      PlayerSettingsDef(
        maxPlayers: (json['max'] as num?)?.toInt() ?? 1,
        joining: JoinBehavior.values.byName(
          json['joining'] as String? ?? 'disabled',
        ),
        joinActions: [
          for (final a in (json['joinActions'] as List?) ?? const [])
            a as String,
        ],
        autoJoinFirst: json['autoJoinFirst'] != false,
        autoSwitch: json['autoSwitch'] != false,
      );

  /// At most this many at once.
  final int maxPlayers;

  final JoinBehavior joining;

  /// `map/action` paths. Give them a hold interaction and a quick press can
  /// mean something else — switching devices while alone.
  final List<String> joinActions;

  /// Player 1 is whoever plays first, with whatever they touch.
  final bool autoJoinFirst;

  /// While there is only one player, a device nobody is using takes over
  /// from theirs the moment it is used, and the scheme follows.
  final bool autoSwitch;

  PlayerSettingsDef copyWith({
    int? maxPlayers,
    JoinBehavior? joining,
    List<String>? joinActions,
    bool? autoJoinFirst,
    bool? autoSwitch,
  }) => PlayerSettingsDef(
    maxPlayers: maxPlayers ?? this.maxPlayers,
    joining: joining ?? this.joining,
    joinActions: joinActions ?? this.joinActions,
    autoJoinFirst: autoJoinFirst ?? this.autoJoinFirst,
    autoSwitch: autoSwitch ?? this.autoSwitch,
  );

  Map<String, dynamic> toJson() => {
    'max': maxPlayers,
    'joining': joining.name,
    'joinActions': joinActions,
    'autoJoinFirst': autoJoinFirst,
    'autoSwitch': autoSwitch,
  };
}
