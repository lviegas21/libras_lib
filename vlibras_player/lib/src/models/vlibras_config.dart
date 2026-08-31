/// The avatar character rendered by the VLibras player.
enum VLibrasAvatar {
  /// Male avatar (default).
  icaro,

  /// Female avatar.
  hosana,

  /// Child avatar.
  guga;

  /// The identifier used by the VLibras web API.
  String get apiId {
    switch (this) {
      case VLibrasAvatar.icaro:
        return 'icaro';
      case VLibrasAvatar.hosana:
        return 'hosana';
      case VLibrasAvatar.guga:
        return 'guga';
    }
  }

  /// Human-readable name shown in avatar pickers.
  String get displayName {
    switch (this) {
      case VLibrasAvatar.icaro:
        return 'Ícaro';
      case VLibrasAvatar.hosana:
        return 'Hosana';
      case VLibrasAvatar.guga:
        return 'Guga';
    }
  }

  /// Short description for selection UI.
  String get description {
    switch (this) {
      case VLibrasAvatar.icaro:
        return 'Avatar masculino';
      case VLibrasAvatar.hosana:
        return 'Avatar feminino';
      case VLibrasAvatar.guga:
        return 'Avatar infantil';
    }
  }
}

/// Configuration passed to [VLibrasPlayer.initialize].
class VLibrasConfig {
  const VLibrasConfig({
    this.avatar = VLibrasAvatar.icaro,
    this.speed = 1.0,
    this.autoPlay = false,
    this.baseUrl = 'https://vlibras.gov.br/app',
    this.sdkLoadRetries = 4,
    this.initTimeout = const Duration(seconds: 90),
  })  : assert(speed >= 0.5 && speed <= 2.0, 'speed must be between 0.5 and 2.0'),
        assert(sdkLoadRetries >= 0);

  /// Which avatar renders the signs.
  final VLibrasAvatar avatar;

  /// Playback speed. Valid range: 0.5 – 2.0.
  final double speed;

  /// Whether to start translating immediately after [VLibrasPlayer.initialize].
  final bool autoPlay;

  /// Base URL of the VLibras application. Override for self-hosted instances.
  final String baseUrl;

  /// How many times to retry fetching `vlibras-plugin.js` (with exponential
  /// backoff, capped at 8s) before giving up. Tuned for field use on unstable
  /// mobile networks. `0` = single attempt (legacy behaviour).
  final int sdkLoadRetries;

  /// Budget for the avatar (Unity) to finish booting. The clock only advances
  /// while the device is online **and** no boot progress is observed — a slow
  /// download or a connection that keeps dropping does not burn the budget.
  final Duration initTimeout;

  /// Serialised form sent through the MethodChannel.
  Map<String, dynamic> toMap() => {
        'avatar': avatar.apiId,
        'speed': speed,
        'autoPlay': autoPlay,
        'baseUrl': baseUrl,
        'sdkLoadRetries': sdkLoadRetries,
        'initTimeoutMs': initTimeout.inMilliseconds,
      };

  VLibrasConfig copyWith({
    VLibrasAvatar? avatar,
    double? speed,
    bool? autoPlay,
    String? baseUrl,
    int? sdkLoadRetries,
    Duration? initTimeout,
  }) {
    return VLibrasConfig(
      avatar: avatar ?? this.avatar,
      speed: speed ?? this.speed,
      autoPlay: autoPlay ?? this.autoPlay,
      baseUrl: baseUrl ?? this.baseUrl,
      sdkLoadRetries: sdkLoadRetries ?? this.sdkLoadRetries,
      initTimeout: initTimeout ?? this.initTimeout,
    );
  }

  @override
  String toString() =>
      'VLibrasConfig(avatar: ${avatar.apiId}, speed: $speed, '
      'autoPlay: $autoPlay, baseUrl: $baseUrl, '
      'sdkLoadRetries: $sdkLoadRetries, initTimeout: $initTimeout)';
}
