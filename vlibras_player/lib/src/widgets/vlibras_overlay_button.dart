import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/vlibras_config.dart';
import '../models/vlibras_event.dart';
import '../vlibras_html.dart';
import '../vlibras_widget_controller.dart';

/// A floating accessibility button that opens/closes the VLibras player panel.
///
/// Place inside a [Stack] so it floats above the page content:
///
/// ```dart
/// Stack(
///   children: [
///     YourContent(),
///     VLibrasOverlayButton(
///       config: VLibrasConfig(),
///       initialText: 'Bem-vindo!',
///     ),
///   ],
/// )
/// ```
class VLibrasOverlayButton extends StatefulWidget {
  const VLibrasOverlayButton({
    super.key,
    this.config = const VLibrasConfig(),
    this.controller,
    this.initialText,
    this.buttonSize = 56,
    this.panelWidth = 300,
    this.panelHeight = 220,
    this.margin = const EdgeInsets.only(bottom: 24, right: 16),
    this.primaryColor = const Color(0xFF1351B4),
    this.onSkip,
  });

  final VLibrasConfig config;
  final VLibrasPlayerController? controller;

  /// Text translated immediately after the player finishes loading.
  /// Also shown as the initial subtitle in the panel footer.
  final String? initialText;

  final double buttonSize;

  /// Width of the player panel card. Defaults to 300.
  final double panelWidth;

  /// Height of the WebView avatar area inside the panel. Defaults to 220.
  final double panelHeight;

  final EdgeInsetsGeometry margin;

  /// Color used for the panel header, footer and FAB. Defaults to gov.br blue.
  final Color primaryColor;

  /// Called when the user taps the "Pular" (skip) button.
  /// If null, the button still calls [VLibrasPlayerController.skip] internally.
  final VoidCallback? onSkip;

  @override
  State<VLibrasOverlayButton> createState() => _VLibrasOverlayButtonState();
}

class _VLibrasOverlayButtonState extends State<VLibrasOverlayButton>
    with SingleTickerProviderStateMixin {
  late final WebViewController _webController;
  late final AnimationController _anim;
  late final Animation<double> _slideAnim;
  late final VLibrasPlayerController _ctrl;

  bool _isOpen = false;
  bool _isReady = false;
  String? _subtitleText;

  @override
  void initState() {
    super.initState();
    _subtitleText = widget.initialText;
    _ctrl = widget.controller ?? VLibrasPlayerController();

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _buildWebViewController();
    _ctrl.eventStream.listen(_handleEvent);
  }

  void _buildWebViewController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'VLibrasChannel',
        onMessageReceived: (msg) {
          final event = _parseEvent(msg.message);
          _ctrl.emitEvent(event);
        },
      )
      ..loadHtmlString(
        buildVLibrasHtml(
          baseUrl: widget.config.baseUrl,
          avatar: widget.config.avatar.apiId,
          speed: widget.config.speed,
          autoPlay: widget.config.autoPlay,
          playerHeight: widget.panelHeight,
        ),
        baseUrl: widget.config.baseUrl,
      );

    _ctrl.attach(_webController);
  }

  void _handleEvent(VLibrasEvent event) {
    if (!mounted) return;
    if (event.type == VLibrasEventType.ready) {
      setState(() => _isReady = true);
      if (widget.initialText != null) {
        _ctrl.translate(widget.initialText!);
      }
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

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    if (_isOpen) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  void _skip() {
    _ctrl.skip();
    widget.onSkip?.call();
  }

  @override
  void dispose() {
    _anim.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      left: 0,
      child: Padding(
        padding: widget.margin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // ── Player panel ──────────────────────────────────────────────
            SizeTransition(
              sizeFactor: _slideAnim,
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: widget.panelWidth,
                  child: _Panel(
                    primaryColor: widget.primaryColor,
                    panelHeight: widget.panelHeight,
                    webController: _webController,
                    isReady: _isReady,
                    subtitleText: _subtitleText,
                    onClose: _toggle,
                    onSkip: _skip,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Toggle FAB ────────────────────────────────────────────────
            Semantics(
              button: true,
              label: _isOpen
                  ? 'Fechar tradução em Libras'
                  : 'Abrir tradução em Libras',
              child: Tooltip(
                message: _isOpen ? 'Fechar Libras' : 'Abrir Libras',
                child: Material(
                  color: widget.primaryColor,
                  shape: const CircleBorder(),
                  elevation: 4,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggle,
                    child: SizedBox(
                      width: widget.buttonSize,
                      height: widget.buttonSize,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isOpen
                            ? const Icon(Icons.close,
                                key: ValueKey('close'), color: Colors.white)
                            : const Icon(Icons.sign_language,
                                key: ValueKey('open'), color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Panel card ────────────────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.primaryColor,
    required this.panelHeight,
    required this.webController,
    required this.isReady,
    required this.subtitleText,
    required this.onClose,
    required this.onSkip,
  });

  final Color primaryColor;
  final double panelHeight;
  final WebViewController webController;
  final bool isReady;
  final String? subtitleText;
  final VoidCallback onClose;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      shadowColor: Colors.black38,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(primaryColor: primaryColor, onClose: onClose),
          _AvatarArea(
            height: panelHeight,
            webController: webController,
            isReady: isReady,
            onSkip: onSkip,
          ),
          _SubtitleBar(primaryColor: primaryColor, text: subtitleText),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.primaryColor, required this.onClose});

  final Color primaryColor;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: primaryColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _HeaderIcon(Icons.settings),
            const SizedBox(width: 4),
            _HeaderIcon(Icons.translate),
            const Expanded(
              child: Text(
                'VLIBRAS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            _HeaderIcon(Icons.info_outline),
            const SizedBox(width: 4),
            _HeaderIconButton(icon: Icons.close, onTap: onClose),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Colors.white, size: 20);
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Avatar area ───────────────────────────────────────────────────────────────

class _AvatarArea extends StatelessWidget {
  const _AvatarArea({
    required this.height,
    required this.webController,
    required this.isReady,
    required this.onSkip,
  });

  final double height;
  final WebViewController webController;
  final bool isReady;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.white, child: WebViewWidget(controller: webController)),
          if (!isReady)
            const ColoredBox(
              color: Colors.white,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _SkipButton(onTap: onSkip),
          ),
        ],
      ),
    );
  }
}

// ── Skip button ───────────────────────────────────────────────────────────────

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.skip_next, size: 16, color: Colors.black87),
              SizedBox(width: 4),
              Text(
                'Pular',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Subtitle bar ──────────────────────────────────────────────────────────────

class _SubtitleBar extends StatelessWidget {
  const _SubtitleBar({required this.primaryColor, this.text});
  final Color primaryColor;
  final String? text;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: primaryColor,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            text ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
