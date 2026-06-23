import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/vlibras_event.dart';

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
    await _webViewController?.runJavaScript(
      "if(window.__vlibrasTranslate) window.__vlibrasTranslate('$escaped');",
    );
  }

  /// Called internally by the widget when the WebViewController is ready.
  void attach(WebViewController wvc) => _webViewController = wvc;

  /// Called internally to emit events from the JS channel.
  void emitEvent(VLibrasEvent event) => _eventController.add(event);

  void dispose() {
    _eventController.close();
    _webViewController = null;
  }
}
