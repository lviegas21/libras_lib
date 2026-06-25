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
/// ```dart
/// final ctrl = VLibrasPlayerController();
///
/// VLibrasPlayerWidget(
///   config: VLibrasConfig(avatar: VLibrasAvatar.hosana),
///   controller: ctrl,
///   onReady: () => ctrl.translate('Olá, bem-vindo!'),
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
    this.avatarViewportHeight = 500.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.loadingBuilder,
    this.errorBuilder,
  });

  final VLibrasConfig config;

  /// Optional external controller. If null, the widget manages its own state.
  final VLibrasPlayerController? controller;

  final VoidCallback? onReady;
  final VoidCallback? onTranslateComplete;
  final ValueChanged<String>? onError;

  /// Height of the player. Defaults to 200.
  final double height;

  /// Width of the player. When null it is auto-computed from [avatarViewportHeight].
  final double? width;

  /// Virtual canvas height (CSS px) that the VLibras Unity scene renders at.
  ///
  /// Controls how much of the 3D scene is visible and therefore the apparent
  /// size of the avatar figure:
  ///
  /// - **Lower value** (e.g. 380): zooms in — avatar fills more of the widget,
  ///   less black margin above/below the figure.
  /// - **Higher value** (e.g. 650): zooms out — avatar appears smaller with
  ///   more scene context around it.
  ///
  /// The auto-computed widget width is `height × (320 / avatarViewportHeight)`.
  /// Typical useful range: 300 – 700. Defaults to 500.
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
  late final WebViewController _webController;

  // ValueNotifier avoids rebuilding the WebViewWidget when the state changes.
  final _state = ValueNotifier<_LoadState>(_LoadState.loading);
  String? _errorMessage;

  // VLibras panel is 320 CSS px wide × avatarViewportHeight CSS px tall.
  // At initial-scale = height/avatarViewportHeight the physical width is:
  //   320 × (height / avatarViewportHeight) = height × (320 / avatarViewportHeight)
  // When the caller does not provide an explicit width we auto-size to this
  // value so the WebView exactly fits the rendered avatar with no empty sides.
  double get _avatarWidth =>
      widget.width ?? widget.height * (320.0 / widget.avatarViewportHeight);

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

  void _buildWebViewController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'VLibrasChannel',
        onMessageReceived: _onJsMessage,
      )
      ..loadHtmlString(
        buildVLibrasHtml(
          baseUrl: widget.config.baseUrl,
          avatar: widget.config.avatar.name,
          speed: widget.config.speed,
          autoPlay: widget.config.autoPlay,
          playerWidth: _avatarWidth,
          playerHeight: widget.height,
          naturalHeight: widget.avatarViewportHeight,
        ),
        baseUrl: widget.config.baseUrl,
      );

    widget.controller?.attach(_webController);
  }

  void _onJsMessage(JavaScriptMessage message) {
    try {
      final event = _parseEvent(message.message);
      widget.controller?.emitEvent(event);

      switch (event.type) {
        case VLibrasEventType.ready:
          if (mounted) _state.value = _LoadState.ready;
          widget.onReady?.call();
        case VLibrasEventType.translateComplete:
          widget.onTranslateComplete?.call();
        case VLibrasEventType.error:
          if (mounted) {
            _errorMessage = event.message ?? 'Erro desconhecido';
            _state.value = _LoadState.error;
          }
          widget.onError?.call(event.message ?? 'Erro desconhecido');
        default:
          break;
      }
    } catch (_) {}
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
    return ClipRRect(
      borderRadius: widget.borderRadius,
        child: SizedBox(
          height: widget.height,
          width: _avatarWidth,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // WebView is always in the tree and never rebuilt — avoids flicker.
            WebViewWidget(controller: _webController),

            // Overlays use ValueListenableBuilder so only they rebuild, not
            // the WebViewWidget above.
            ValueListenableBuilder<_LoadState>(
              valueListenable: _state,
              builder: (context, state, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Loading overlay — fades out when ready
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

                    // Error overlay
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
                                      style:
                                          const TextStyle(color: Colors.red),
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
      ),
    );
  }
}

enum _LoadState { loading, ready, error }
