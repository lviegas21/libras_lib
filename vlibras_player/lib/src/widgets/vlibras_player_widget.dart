import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/vlibras_config.dart';
import '../models/vlibras_event.dart';
import '../vlibras_html.dart';
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
    this.avatarViewportHeight = 500.0,
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
    double avatarViewportHeight = kVLibrasAvatarOnlyViewport,
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

  /// Virtual canvas height (CSS px) that controls avatar zoom.
  ///
  /// - **Lower value** (e.g. 200): zooms in — avatar fills more of the widget.
  /// - **Higher value** (e.g. 650): zooms out — more scene context.
  ///
  /// When [visibleWidth] is set, values below the fill-width canvas height
  /// crop the sides via CSS `scale`. Typical useful range: 180 – 700.
  /// Defaults to 500. Prefer [kVLibrasAvatarOnlyViewport] for figure-only UI.
  final double avatarViewportHeight;

  final BorderRadius borderRadius;

  /// Custom widget shown while VLibras is loading.
  final WidgetBuilder? loadingBuilder;

  /// Custom widget shown when VLibras fails to load.
  final Widget Function(BuildContext context, String error)? errorBuilder;

  @override
  State<VLibrasPlayerWidget> createState() => _VLibrasPlayerWidgetState();
}

class _VLibrasPlayerWidgetState extends State<VLibrasPlayerWidget> {
  late WebViewController _webController;
  int _webViewKey = 0;

  // ValueNotifier avoids rebuilding the WebViewWidget when the state changes.
  final _state = ValueNotifier<_LoadState>(_LoadState.loading);
  String? _errorMessage;
  bool _errorReported = false;

  /// Width of the Flutter WebView / visible frame.
  double get _frameWidth {
    if (widget.visibleWidth != null) return widget.visibleWidth!;
    if (widget.width != null) return widget.width!;
    return vlibrasNaturalWidth(
      height: widget.height,
      avatarViewportHeight: widget.avatarViewportHeight,
    );
  }

  /// Canvas height that makes the 320 CSS panel exactly fill [_frameWidth].
  double get _fillNaturalHeight =>
      widget.height * kVLibrasPanelCssWidth / _frameWidth;

  /// Extra CSS zoom when [avatarViewportHeight] asks for a tighter crop.
  double get _contentZoom {
    final fill = _fillNaturalHeight;
    final desired = widget.avatarViewportHeight;
    if (desired <= 0 || desired >= fill) return 1.0;
    return fill / desired;
  }

  /// transform-origin in 0..1 from [contentAlignment].
  double get _originX => (widget.contentAlignment.x + 1) / 2;
  double get _originY => (widget.contentAlignment.y + 1) / 2;

  @override
  void initState() {
    super.initState();
    _buildWebViewController();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant VLibrasPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final configChanged = oldWidget.config.avatar != widget.config.avatar ||
        oldWidget.config.speed != widget.config.speed ||
        oldWidget.config.autoPlay != widget.config.autoPlay ||
        oldWidget.config.baseUrl != widget.config.baseUrl;
    final layoutChanged = oldWidget.height != widget.height ||
        oldWidget.width != widget.width ||
        oldWidget.visibleWidth != widget.visibleWidth ||
        oldWidget.avatarViewportHeight != widget.avatarViewportHeight ||
        oldWidget.contentAlignment != widget.contentAlignment;

    if (configChanged || layoutChanged) {
      _state.value = _LoadState.loading;
      _errorMessage = null;
      _errorReported = false;
      _buildWebViewController(reload: true);
    }
  }

  void _reportError(String message) {
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
        ),
        baseUrl: widget.config.baseUrl,
      );

    widget.controller?.attach(_webController);
    if (reload && mounted) setState(() => _webViewKey++);
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final event = _parseEvent(message.message);

      switch (event.type) {
        case VLibrasEventType.ready:
          if (_errorReported) return;
          widget.controller?.emitEvent(event);
          if (mounted) _state.value = _LoadState.ready;
          widget.onReady?.call();
        case VLibrasEventType.translateComplete:
          widget.controller?.emitEvent(event);
          widget.onTranslateComplete?.call();
        case VLibrasEventType.error:
          _reportError(event.message ?? 'Erro desconhecido');
        default:
          break;
      }
    } catch (_) {
      _reportError('Erro ao processar evento do VLibras');
    }
  }

  VLibrasEvent _parseEvent(String json) {
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
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                    color: Colors.white),
                                SizedBox(height: 12),
                                Text(
                                  'Carregando VLibras…',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
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
