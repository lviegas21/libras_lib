import '../vlibras_html.dart'
    show
        kVLibrasDictionaryUrl,
        kVLibrasPlayerVersion,
        kVLibrasPortalBaseUrl,
        kVLibrasTranslateUrl;

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
    this.baseUrl = kVLibrasPortalBaseUrl,
    this.sdkLoadRetries = 4,
    this.initTimeout = const Duration(seconds: 45),
    this.playerVersion = kVLibrasPlayerVersion,
    this.dictionaryUrl = kVLibrasDictionaryUrl,
    this.translateUrl = kVLibrasTranslateUrl,
    this.showSubtitles = false,
    this.playWelcome = false,
    this.pauseWhenIdle = true,
  })  : assert(speed >= 0.5 && speed <= 2.0, 'speed must be between 0.5 and 2.0'),
        assert(sdkLoadRetries >= 0);

  /// Which avatar renders the signs.
  final VLibrasAvatar avatar;

  /// Playback speed. Valid range: 0.5 – 2.0.
  final double speed;

  /// Whether to start translating immediately after [VLibrasPlayer.initialize].
  final bool autoPlay;

  /// De onde o player Unity é carregado.
  ///
  /// Padrão: `kVLibrasPortalBaseUrl` — o portal oficial, que serve **sempre a
  /// versão mais recente**. Uma migração publicada lá entra no app sem aviso
  /// (foi assim que a troca 6.x → 7.x quebrou a integração anterior); o canário
  /// `tool/check_vlibras_contract.dart` existe para avisar antes do usuário
  /// sentir.
  ///
  /// Para congelar a versão é preciso hospedar os dois arquivos pequenos do
  /// player você mesmo — ver `kVLibrasPinnedPlayerAssetsUrl` e a seção de
  /// manutenção no README. Apontar direto para o jsDelivr **não** funciona.
  final String baseUrl;

  /// Quantas vezes remontar o `<iframe>` do player quando o boot travar antes
  /// de desistir. Ajustado para uso em campo, em rede móvel instável.
  /// `0` = tentativa única.
  final int sdkLoadRetries;

  /// Budget for the avatar (Unity) to finish booting. The clock only advances
  /// while the device is online **and** no boot progress is observed — a slow
  /// download or a connection that keeps dropping does not burn the budget.
  final Duration initTimeout;

  /// Versão do player Unity (`<baseUrl>/unity/index.html?v=...`).
  final String playerVersion;

  /// Bundles de sinais enviados ao player via `setBaseUrl` no boot.
  final String dictionaryUrl;

  /// Serviço que converte português em glosa antes de mandar para o avatar.
  final String translateUrl;

  /// Legendas desenhadas pelo próprio Unity dentro do canvas. Desligadas por
  /// padrão porque a UI é do Flutter — não há como escondê-las por CSS.
  final bool showSubtitles;

  /// Congela o desenho do avatar quando ele não está sinalizando.
  ///
  /// O Unity desenha a 60 fps para sempre, mesmo com o avatar parado: num
  /// Galaxy A22 isso mede ~200% de CPU só exibindo a figura em repouso. Com a
  /// pausa, cai para o custo do próprio WebView. Visualmente não muda nada
  /// (avatar parado é avatar parado) e o desenho volta antes de qualquer
  /// sinalização. Desligue se algum aparelho não retomar corretamente.
  final bool pauseWhenIdle;

  /// Toca a saudação do avatar ao ficar pronto. Desligado por padrão: sinalizar
  /// sem o app ter pedido só atrasa a primeira tradução.
  final bool playWelcome;

  /// Serialised form sent through the MethodChannel.
  Map<String, dynamic> toMap() => {
        'avatar': avatar.apiId,
        'speed': speed,
        'autoPlay': autoPlay,
        'baseUrl': baseUrl,
        'sdkLoadRetries': sdkLoadRetries,
        'initTimeoutMs': initTimeout.inMilliseconds,
        'playerVersion': playerVersion,
        'dictionaryUrl': dictionaryUrl,
        'translateUrl': translateUrl,
        'showSubtitles': showSubtitles,
        'playWelcome': playWelcome,
        'pauseWhenIdle': pauseWhenIdle,
      };

  VLibrasConfig copyWith({
    VLibrasAvatar? avatar,
    double? speed,
    bool? autoPlay,
    String? baseUrl,
    int? sdkLoadRetries,
    Duration? initTimeout,
    String? playerVersion,
    String? dictionaryUrl,
    String? translateUrl,
    bool? showSubtitles,
    bool? playWelcome,
    bool? pauseWhenIdle,
  }) {
    return VLibrasConfig(
      avatar: avatar ?? this.avatar,
      speed: speed ?? this.speed,
      autoPlay: autoPlay ?? this.autoPlay,
      baseUrl: baseUrl ?? this.baseUrl,
      sdkLoadRetries: sdkLoadRetries ?? this.sdkLoadRetries,
      initTimeout: initTimeout ?? this.initTimeout,
      playerVersion: playerVersion ?? this.playerVersion,
      dictionaryUrl: dictionaryUrl ?? this.dictionaryUrl,
      translateUrl: translateUrl ?? this.translateUrl,
      showSubtitles: showSubtitles ?? this.showSubtitles,
      playWelcome: playWelcome ?? this.playWelcome,
      pauseWhenIdle: pauseWhenIdle ?? this.pauseWhenIdle,
    );
  }

  @override
  String toString() =>
      'VLibrasConfig(avatar: ${avatar.apiId}, speed: $speed, '
      'autoPlay: $autoPlay, baseUrl: $baseUrl, '
      'sdkLoadRetries: $sdkLoadRetries, initTimeout: $initTimeout)';
}
