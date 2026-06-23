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
///     VLibrasOverlayButton(config: VLibrasConfig()),
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
    this.panelHeight = 300,
    this.margin = const EdgeInsets.only(bottom: 24, right: 16),
  });

  final VLibrasConfig config;
  final VLibrasPlayerController? controller;

  /// Text translated immediately after the player finishes loading.
  final String? initialText;

  final double buttonSize;
  final double panelHeight;
  final EdgeInsetsGeometry margin;

  @override
  State<VLibrasOverlayButton> createState() => _VLibrasOverlayButtonState();
}

class _VLibrasOverlayButtonState extends State<VLibrasOverlayButton>
    with SingleTickerProviderStateMixin {
  late final WebViewController _webController;
  late final AnimationController _anim;
  late final Animation<double> _slideAnim;

  bool _isOpen = false;
  bool _isReady = false;
  late final VLibrasPlayerController _ctrl;

  @override
  void initState() {
    super.initState();

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

    // Listen to events so we can update isReady
    _ctrl.eventStream.listen(_handleEvent);
  }

  void _buildWebViewController() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
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
          avatar: widget.config.avatar.name,
          speed: widget.config.speed,
          autoPlay: widget.config.autoPlay,
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

  @override
  void dispose() {
    _anim.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              child: Container(
                height: widget.panelHeight,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _webController),
                      if (!_isReady)
                        const ColoredBox(
                          color: Colors.black87,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Toggle button ─────────────────────────────────────────────
            Semantics(
              button: true,
              label: _isOpen
                  ? 'Fechar tradução em Libras'
                  : 'Abrir tradução em Libras',
              child: Tooltip(
                message: _isOpen ? 'Fechar Libras' : 'Abrir Libras',
                child: Material(
                  color: theme.colorScheme.primary,
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
                            ? Icon(Icons.close,
                                key: const ValueKey('close'),
                                color: theme.colorScheme.onPrimary)
                            : Icon(Icons.sign_language,
                                key: const ValueKey('open'),
                                color: theme.colorScheme.onPrimary),
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
