import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/vlibras_config.dart';
import '../models/vlibras_event.dart';
import '../vlibras_html.dart';
import '../vlibras_liveness_monitor.dart';
import '../vlibras_player_api.dart';
import '../vlibras_widget_controller.dart';

/// An inline widget that embeds the VLibras avatar player.
///
/// Uses a [WebViewWidget] to render the VLibras web player directly inside
/// the Flutter widget tree. Pass a [VLibrasPlayerController] to translate
/// text programmatically.
///
/// Flutter should own header / footer chrome. For **only the signing figure**,
/// use [VLibrasPlayerWidget.avatarOnly] (or a portrait [visibleWidth] + low
/// [avatarViewportHeight]) centered inside your card:
///
/// ```dart
/// final stage = vlibrasAvatarStage(maxWidth: cardW, maxHeight: 260);
/// Center(
///   child: VLibrasPlayerWidget.avatarOnly(
///     height: stage.height,
///     visibleWidth: stage.width,
///     controller: ctrl,
///   ),
/// )
/// ```
class VLibrasPlayerWidget extends StatefulWidget {
  const VLibrasPlayerWidget({
    super.key,
    this.config = const VLibrasConfig(),
    this.controller,
    this.onReady,
    this.onTranslateComplete,
    this.onError,
    this.height = 200,
    this.width,
    this.visibleWidth,
    this.contentAlignment = Alignment.center,
    this.avatarViewportHeight,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// Close-up of the signing figure only (hide empty scene; Flutter owns UI).
  ///
  /// Uses a tight [avatarViewportHeight] and centers the Unity crop. Pair with
  /// a portrait [visibleWidth] from [vlibrasAvatarStage] for best results.
  factory VLibrasPlayerWidget.avatarOnly({
    Key? key,
    VLibrasConfig config = const VLibrasConfig(),
    VLibrasPlayerController? controller,
    VoidCallback? onReady,
    VoidCallback? onTranslateComplete,
    ValueChanged<String>? onError,
    required double height,
    double? visibleWidth,
    Alignment contentAlignment = Alignment.center,
    double? avatarViewportHeight,
    BorderRadius borderRadius = BorderRadius.zero,
    WidgetBuilder? loadingBuilder,
    Widget Function(BuildContext context, String error)? errorBuilder,
  }) {
    final width = visibleWidth ?? height * kVLibrasAvatarStageAspect;
    return VLibrasPlayerWidget(
      key: key,
      config: config,
      controller: controller,
      onReady: onReady,
      onTranslateComplete: onTranslateComplete,
      onError: onError,
      height: height,
      visibleWidth: width,
      contentAlignment: contentAlignment,
      avatarViewportHeight: avatarViewportHeight,
      borderRadius: borderRadius,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }

  final VLibrasConfig config;

  /// Optional external controller. If null, the widget manages its own state.
  final VLibrasPlayerController? controller;

  final VoidCallback? onReady;
  final VoidCallback? onTranslateComplete;
  final ValueChanged<String>? onError;

  /// Height of the player. Defaults to 200.
  final double height;

  /// Explicit WebView width. Prefer [visibleWidth] for cropped cards.
  ///
  /// When null, width is derived from [visibleWidth] or from
  /// `height × ([kVLibrasPanelCssWidth] / [avatarViewportHeight])`.
  final double? width;

  /// Visible frame width. The WebView is sized to this width; side crop / zoom
  /// is applied in HTML (platform-view safe) using [avatarViewportHeight] and
  /// [contentAlignment].
  final double? visibleWidth;

  /// Optical alignment of the zoomed Unity scene inside the frame.
  /// Defaults to [Alignment.center].
  final Alignment contentAlignment;

  /// Altura da tela virtual (CSS px) que controla o zoom do avatar.
  ///
  /// **Deixe nulo (padrão)** para o enquadramento ser derivado de
  /// [kVLibrasAvatarZoom]: aí ele não depende do tamanho **nem da proporção**
  /// do palco — o avatar aparece igual num card estreito de celular, num tablet
  /// ou em paisagem. É o que a maioria dos apps quer.
  ///
  /// Fixar um valor em CSS px prende o enquadramento à proporção em que o
  /// número foi escolhido (menor = mais zoom; abaixo de ~280 num palco retrato
  /// as **mãos saem do quadro**). Só faça isso para casar com um layout
  /// específico.
  final double? avatarViewportHeight;

  final BorderRadius borderRadius;

  /// Custom widget shown while VLibras is loading.
  final WidgetBuilder? loadingBuilder;

  /// Custom widget shown when VLibras fails to load.
  final Widget Function(BuildContext context, String error)? errorBuilder;

  @override
  State<VLibrasPlayerWidget> createState() => _VLibrasPlayerWidgetState();
}

class _VLibrasPlayerWidgetState extends State<VLibrasPlayerWidget>
    with WidgetsBindingObserver {
  late WebViewController _webController;
  int _webViewKey = 0;

  // ValueNotifier avoids rebuilding the WebViewWidget when the state changes.
  final _state = ValueNotifier<_LoadState>(_LoadState.loading);

  /// % de download do avatar (`update_progress` do player), quando conhecido.
  final _progress = ValueNotifier<int?>(null);
  String? _errorMessage;
  bool _errorReported = false;

  /// Width of the Flutter WebView / visible frame.
  double get _frameWidth {
    if (widget.visibleWidth != null) return widget.visibleWidth!;
    if (widget.width != null) return widget.width!;
    final viewport = widget.avatarViewportHeight;
    // Sem largura explícita: com viewport fixo, a largura sai dele (modo
    // antigo); sem viewport, cai no palco retrato padrão.
    return viewport != null
        ? vlibrasNaturalWidth(
            height: widget.height,
            avatarViewportHeight: viewport,
          )
        : widget.height * kVLibrasAvatarStageAspect;
  }

  /// Tela virtual + zoom deste palco (ver [vlibrasStageFraming]).
  ({double canvasHeight, double zoom}) get _framing => vlibrasStageFraming(
        frameWidth: _frameWidth,
        frameHeight: widget.height,
        avatarViewportHeight: widget.avatarViewportHeight,
      );

  double get _fillNaturalHeight => _framing.canvasHeight;

  double get _contentZoom => _framing.zoom;

  /// transform-origin in 0..1 from [contentAlignment].
  double get _originX => (widget.contentAlignment.x + 1) / 2;
  double get _originY => (widget.contentAlignment.y + 1) / 2;

  /// Vigia se a página sobreviveu (o renderer do WebView roda em outro
  /// processo e pode ser morto sob pressão de memória).
  late final VLibrasLivenessMonitor _liveness = VLibrasLivenessMonitor(
    evaluate: (js) => _webController.runJavaScriptReturningResult(js),
    onLost: _onPlayerLost,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _buildWebViewController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _liveness.dispose();
    _state.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Com o app fora de foco não há por que desenhar o avatar (nem vigiar a
  /// página): o Unity continuaria a 60 fps atrás de outro app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    _setActive(resumed);
    if (resumed) {
      if (_state.value == _LoadState.ready) _liveness.start();
    } else {
      _liveness.stop();
    }
  }

  Future<void> _setActive(bool active) async {
    try {
      await _webController.runJavaScript(
        'if(window.__vlibrasSetActive) window.__vlibrasSetActive($active);',
      );
    } catch (e, s) {
      VLibrasPlayer.reportError(e, s, reason: 'player-widget-set-active');
    }
  }

  /// A página sumiu debaixo de nós: recria a WebView do zero. É caro (~12 s de
  /// boot), por isso o vigia só chama depois de falhas seguidas.
  void _onPlayerLost() {
    if (!mounted) return;
    VLibrasPlayer.reportError(
      'A página do VLibras sumiu do WebView',
      null,
      reason: 'player-widget-renderer-gone',
      context: {'avatar': widget.config.avatar.apiId},
    );
    _state.value = _LoadState.loading;
    _progress.value = null;
    _errorMessage = null;
    _errorReported = false;
    _buildWebViewController(reload: true);
  }

  /// Tolerância para comparação de dimensões — evita trabalho por ruído de
  /// ponto flutuante entre builds (ex.: MediaQuery recalculado com diferença
  /// de fração de pixel) que não representa uma mudança de layout real.
  static const _dimensionEpsilon = 0.5;

  bool _dimensionChanged(double? a, double? b) {
    if (a == null || b == null) return a != b;
    return (a - b).abs() > _dimensionEpsilon;
  }

  /// Alguma mudança de runtime foi pedida antes de o JS da página existir e
  /// precisa ser reaplicada quando a página der o primeiro sinal de vida.
  bool _runtimeDirty = false;

  @override
  void didUpdateWidget(covariant VLibrasPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Só o que está costurado no HTML gerado exige recarregar a página.
    final needsReload = oldWidget.config.baseUrl != widget.config.baseUrl ||
        oldWidget.config.playerVersion != widget.config.playerVersion ||
        oldWidget.config.dictionaryUrl != widget.config.dictionaryUrl ||
        oldWidget.config.playWelcome != widget.config.playWelcome ||
        oldWidget.config.autoPlay != widget.config.autoPlay;

    if (needsReload) {
      _liveness.stop();
      _state.value = _LoadState.loading;
      _progress.value = null;
      _errorMessage = null;
      _errorReported = false;
      _runtimeDirty = false;
      _buildWebViewController(reload: true);
      return;
    }

    // Avatar, velocidade, legendas e enquadramento são aplicados ao vivo: o
    // canvas do Unity vive num iframe de tamanho virtual fixo, então girar a
    // tela ou trocar o avatar não custa mais um reboot do player.
    final layoutChanged =
        _dimensionChanged(oldWidget.height, widget.height) ||
        _dimensionChanged(oldWidget.width, widget.width) ||
        _dimensionChanged(oldWidget.visibleWidth, widget.visibleWidth) ||
        _dimensionChanged(
          oldWidget.avatarViewportHeight,
          widget.avatarViewportHeight,
        ) ||
        oldWidget.contentAlignment != widget.contentAlignment;
    if (oldWidget.config.translateUrl != widget.config.translateUrl ||
        oldWidget.config.initTimeout != widget.config.initTimeout) {
      _attachController();
    }

    final runtimeChanged = layoutChanged ||
        oldWidget.config.avatar != widget.config.avatar ||
        oldWidget.config.speed != widget.config.speed ||
        oldWidget.config.showSubtitles != widget.config.showSubtitles;

    if (runtimeChanged) {
      _runtimeDirty = true;
      _syncRuntime();
    }
  }

  /// Empurra para a página os valores que mudam sem recarregar.
  ///
  /// Idempotente e seguro antes do `ready`: o JS guarda tudo em `CFG` e a
  /// sequência de boot lê os valores atuais na hora de mandar para o Unity.
  Future<void> _syncRuntime() async {
    final cfg = widget.config;
    final js = 'if(window.__vlibrasSetStage)window.__vlibrasSetStage('
        '${_fillNaturalHeight.toStringAsFixed(2)},'
        '${_contentZoom.toStringAsFixed(4)},'
        '${_originX.toStringAsFixed(4)},${_originY.toStringAsFixed(4)});'
        'if(window.__vlibrasSetAvatar)'
        "window.__vlibrasSetAvatar('${cfg.avatar.apiId}');"
        'if(window.__vlibrasSetSpeed)window.__vlibrasSetSpeed(${cfg.speed});'
        'if(window.__vlibrasSetSubtitles)'
        'window.__vlibrasSetSubtitles(${cfg.showSubtitles});';
    try {
      await _webController.runJavaScript(js);
    } catch (e, s) {
      VLibrasPlayer.reportError(e, s, reason: 'player-widget-sync');
    }
  }

  void _reportError(
    String message, {
    Object? cause,
    StackTrace? stack,
    Map<String, dynamic>? data,
  }) {
    if (_errorReported) return;
    _errorReported = true;
    if (mounted) {
      _errorMessage = message;
      _state.value = _LoadState.error;
    }
    final event =
        VLibrasEvent(type: VLibrasEventType.error, message: message);
    widget.controller?.emitEvent(event);
    widget.onError?.call(message);
    VLibrasPlayer.reportError(
      cause ?? message,
      stack,
      reason: 'player-widget',
      context: {
        'avatar': widget.config.avatar.apiId,
        'message': message,
        ...?data,
      },
    );
  }

  void _buildWebViewController({bool reload = false}) {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            // Ignore secondary resource noise after init succeeded/failed.
            if (_state.value != _LoadState.loading || _errorReported) return;
            // Falha num sub-recurso (fonte, ícone, um chunk do WASM) não
            // significa que a página principal falhou — só erros do
            // documento principal são tratados como fatais aqui. `null`
            // (plataforma não informa) é tratado como potencialmente fatal,
            // por segurança.
            if (error.isForMainFrame == false) return;
            final desc = error.description.trim();
            _reportError(
              desc.isEmpty
                  ? 'Falha ao carregar o VLibras'
                  : 'Falha ao carregar o VLibras: $desc',
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'VLibrasChannel',
        onMessageReceived: _onJsMessage,
      )
      ..loadHtmlString(
        buildVLibrasHtml(
          baseUrl: widget.config.baseUrl,
          avatar: widget.config.avatar.apiId,
          speed: widget.config.speed,
          autoPlay: widget.config.autoPlay,
          playerWidth: _frameWidth,
          playerHeight: widget.height,
          // Fill the WebView width; extra zoom is applied via contentZoom.
          naturalHeight: _fillNaturalHeight,
          contentZoom: _contentZoom,
          originX: _originX,
          originY: _originY,
          sdkLoadRetries: widget.config.sdkLoadRetries,
          initTimeoutMs: widget.config.initTimeout.inMilliseconds,
          playerVersion: widget.config.playerVersion,
          dictionaryUrl: widget.config.dictionaryUrl,
          showSubtitles: widget.config.showSubtitles,
          playWelcome: widget.config.playWelcome,
          pauseWhenIdle: widget.config.pauseWhenIdle,
        ),
        baseUrl: widget.config.baseUrl,
      );

    _attachController();
    if (reload && mounted) setState(() => _webViewKey++);
  }

  /// Liga o controller a esta WebView e ao serviço de tradução da config.
  void _attachController() {
    widget.controller?.attach(
      _webController,
      translateUrl: widget.config.translateUrl,
      onLocalEvent: _onLocalEvent,
    );
  }

  /// Erro gerado no Dart (tradução), não vindo da página: repassa ao app sem
  /// derrubar o player.
  void _onLocalEvent(VLibrasEvent event) {
    if (!mounted) return;
    if (event.type == VLibrasEventType.error && event.data?['fatal'] == false) {
      widget.onError?.call(event.message ?? 'Erro desconhecido');
    }
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final event = _parseEvent(message.message);

      // Primeiro sinal de vida da página: se o widget mudou enquanto ela
      // carregava, o `runJavaScript` de então caiu no vazio (as funções ainda
      // não existiam) — reaplica agora.
      if (_runtimeDirty) {
        _runtimeDirty = false;
        _syncRuntime();
      }

      switch (event.type) {
        case VLibrasEventType.ready:
          if (_errorReported) return;
          widget.controller?.emitEvent(event);
          if (mounted) _state.value = _LoadState.ready;
          _liveness.start();
          widget.onReady?.call();
        case VLibrasEventType.loading:
          // Progresso de inicialização (loading-player / downloading-avatar /
          // retrying-player / waiting-network / initializing-avatar). Não é
          // erro — mantém o estado de carregando e repassa a fase para quem
          // quiser mostrar o texto.
          if (_errorReported) return;
          widget.controller?.emitEvent(event);
          final progress = event.data?['progress'];
          if (mounted && progress is num) {
            _progress.value = progress.round();
          }
          if (mounted && _state.value != _LoadState.ready) {
            _state.value = _LoadState.loading;
          }
        case VLibrasEventType.translateComplete:
          widget.controller?.emitEvent(event);
          widget.onTranslateComplete?.call();
        case VLibrasEventType.error:
          // `fatal: false` = falha pontual (uma tradução que não foi), não o
          // player morrendo: reporta e avisa o app, mas mantém o avatar de pé
          // para a próxima frase.
          if (event.data?['fatal'] == false) {
            widget.controller?.emitEvent(event);
            final message = event.message ?? 'Erro desconhecido';
            widget.onError?.call(message);
            VLibrasPlayer.reportError(
              message,
              null,
              reason: 'player-widget-soft',
              context: {
                'avatar': widget.config.avatar.apiId,
                ...?event.data,
              },
            );
            return;
          }
          _reportError(event.message ?? 'Erro desconhecido', data: event.data);
        default:
          break;
      }
    } catch (e, s) {
      _reportError('Erro ao processar evento do VLibras', cause: e, stack: s);
    }
  }

  VLibrasEvent _parseEvent(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return VLibrasEvent.fromMap(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // cai no parse tolerante abaixo
    }
    if (json.contains('"ready"')) {
      return const VLibrasEvent(type: VLibrasEventType.ready);
    } else if (json.contains('"translateComplete"')) {
      return const VLibrasEvent(type: VLibrasEventType.translateComplete);
    } else if (json.contains('"error"')) {
      final m = RegExp(r'"message"\s*:\s*"([^"]*)"').firstMatch(json);
      return VLibrasEvent(type: VLibrasEventType.error, message: m?.group(1));
    }
    return const VLibrasEvent(type: VLibrasEventType.error);
  }

  @override
  Widget build(BuildContext context) {
    // Do NOT wrap the WebView in ClipRRect on iOS — platform views are
    // mis-positioned (often shifted left) when an ancestor clips them.
    final frame = SizedBox(
      height: widget.height,
      width: _frameWidth,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(
            key: ValueKey(_webViewKey),
            controller: _webController,
          ),
          ValueListenableBuilder<_LoadState>(
            valueListenable: _state,
            builder: (context, state, _) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: state == _LoadState.loading ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    child: ColoredBox(
                      color: Colors.black,
                      child: widget.loadingBuilder?.call(context) ??
                          ValueListenableBuilder<int?>(
                            valueListenable: _progress,
                            builder: (context, progress, _) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    // O player informa o download real do
                                    // avatar; sem isso, indeterminado.
                                    value: progress == null
                                        ? null
                                        : progress / 100,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    progress == null
                                        ? 'Carregando VLibras…'
                                        : 'Carregando VLibras… $progress%',
                                    style: const TextStyle(
                                        color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                  ),
                  if (state == _LoadState.error)
                    ColoredBox(
                      color: Colors.black87,
                      child: widget.errorBuilder
                              ?.call(context, _errorMessage ?? 'Erro') ??
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.red, size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage ??
                                        'Erro ao carregar VLibras',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );

    final radius = widget.borderRadius;
    final canClip = radius != BorderRadius.zero &&
        defaultTargetPlatform != TargetPlatform.iOS;
    if (!canClip) return frame;
    return ClipRRect(borderRadius: radius, child: frame);
  }
}

enum _LoadState { loading, ready, error }
