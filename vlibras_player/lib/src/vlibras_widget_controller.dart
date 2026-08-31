import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/vlibras_event.dart';
import 'vlibras_player_api.dart';

/// Controls a [VLibrasPlayerWidget] or [VLibrasOverlayButton] from outside
/// the widget tree.
///
/// ```dart
/// final controller = VLibrasPlayerController();
///
/// VLibrasPlayerWidget(
///   controller: controller,
///   onReady: () => controller.translate('Olá, mundo!'),
/// )
/// ```
class VLibrasPlayerController {
  WebViewController? _webViewController;
  final _eventController = StreamController<VLibrasEvent>.broadcast();

  /// Stream of events emitted by the VLibras player (ready, translateComplete, error).
  Stream<VLibrasEvent> get eventStream => _eventController.stream;

  /// Sends [text] to the VLibras avatar for translation.
  Future<void> translate(String text) async {
    assert(text.isNotEmpty, 'text must not be empty');
    final escaped = text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('\n', '\\n');
    await _runJs(
      "if(window.__vlibrasTranslate) window.__vlibrasTranslate('$escaped');",
      reason: 'controller-translate',
      data: {'chars': text.length},
    );
  }

  /// Called internally by the widget when the WebViewController is ready.
  Future<void> skip() async {
    await _runJs(
      'if(window.__vlibrasSkip) window.__vlibrasSkip();',
      reason: 'controller-skip',
    );
  }

  /// Executa JS no WebView reportando (sem relançar) qualquer falha —
  /// `runJavaScript` pode lançar `PlatformException` se o WebView já foi
  /// destruído ou a página não carregou. Antes isso subia cru pro `await`
  /// do chamador e, na prática, era engolido.
  Future<void> _runJs(
    String script, {
    required String reason,
    Map<String, Object?>? data,
  }) async {
    final wvc = _webViewController;
    if (wvc == null) return;
    try {
      await wvc.runJavaScript(script);
    } catch (e, s) {
      VLibrasPlayer.reportError(e, s, reason: reason, context: data);
    }
  }

  void attach(WebViewController wvc) => _webViewController = wvc;

  /// Called internally to emit events from the JS channel.
  void emitEvent(VLibrasEvent event) => _eventController.add(event);

  void dispose() {
    _eventController.close();
    _webViewController = null;
  }
}
