import 'dart:async';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/vlibras_event.dart';
import 'vlibras_player_api.dart';
import 'vlibras_translation_service.dart';

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
  VLibrasPlayerController({VLibrasTranslationService? translationService})
      : _translation = translationService ?? VLibrasTranslationService();

  WebViewController? _webViewController;
  VLibrasTranslationService _translation;
  void Function(VLibrasEvent)? _onLocalEvent;
  final _eventController = StreamController<VLibrasEvent>.broadcast();

  /// Stream of events emitted by the VLibras player (ready, translateComplete, error).
  Stream<VLibrasEvent> get eventStream => _eventController.stream;

  /// Traduz [text] para glosa e manda o avatar sinalizar.
  ///
  /// A conversão texto → glosa acontece aqui, no Dart
  /// ([VLibrasTranslationService]); para a página vai só a glosa pronta. Se a
  /// tradução falhar, emite um evento de erro **não fatal** (`fatal: false`) —
  /// o player continua carregado e pronto para a próxima frase.
  Future<void> translate(String text) async {
    assert(text.isNotEmpty, 'text must not be empty');
    final String gloss;
    try {
      gloss = await _translation.toGloss(text);
    } on VLibrasTranslationException catch (e, s) {
      _emitLocal(
        VLibrasEvent(
          type: VLibrasEventType.error,
          message: e.userMessage,
          data: {
            'fatal': false,
            'kind': 'translate-${e.kind}',
            'chars': text.length,
            if (e.statusCode != null) 'status': e.statusCode,
          },
        ),
      );
      VLibrasPlayer.reportError(
        e,
        s,
        reason: 'controller-translate',
        context: {'kind': e.kind, 'chars': text.length},
      );
      return;
    }
    await play(gloss);
  }

  /// Manda o avatar sinalizar uma **glosa** já pronta (pula a tradução).
  ///
  /// Útil para glosas vindas de um dicionário próprio ou de cache do app.
  Future<void> play(String gloss) async {
    await _runJs(
      "if(window.__vlibrasPlay) window.__vlibrasPlay('${_escapeJs(gloss)}');",
      reason: 'controller-play',
      data: {'chars': gloss.length},
    );
  }

  /// Liga/desliga o desenho do avatar.
  ///
  /// Use quando o player sair de vista sem ser destruído (uma aba atrás, um
  /// card fora da tela): com `false` o render loop do Unity congela e a CPU cai
  /// para perto de zero, sem perder o estado nem recarregar nada. Voltar a
  /// sinalizar já religa o desenho sozinho.
  Future<void> setActive(bool active) async {
    await _runJs(
      'if(window.__vlibrasSetActive) window.__vlibrasSetActive($active);',
      reason: 'controller-set-active',
      data: {'active': active},
    );
  }

  /// Interrompe a sinalização em andamento.
  Future<void> skip() async {
    await _runJs(
      'if(window.__vlibrasSkip) window.__vlibrasSkip();',
      reason: 'controller-skip',
    );
  }

  static String _escapeJs(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\r', '\\r')
      .replaceAll('\n', '\\n');

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

  /// Called internally by the widget when the WebViewController is ready.
  ///
  /// [translateUrl] / [translateTimeout] vêm da `VLibrasConfig` do widget;
  /// [onLocalEvent] recebe os eventos gerados aqui no Dart (não vindos da
  /// página) para o widget poder repassá-los ao app.
  void attach(
    WebViewController wvc, {
    String? translateUrl,
    Duration? translateTimeout,
    void Function(VLibrasEvent)? onLocalEvent,
  }) {
    _webViewController = wvc;
    _onLocalEvent = onLocalEvent;
    if ((translateUrl != null && translateUrl != _translation.endpoint) ||
        (translateTimeout != null && translateTimeout != _translation.timeout)) {
      _translation = VLibrasTranslationService(
        endpoint: translateUrl ?? _translation.endpoint,
        timeout: translateTimeout ?? _translation.timeout,
      );
    }
  }

  /// Called internally to emit events from the JS channel.
  void emitEvent(VLibrasEvent event) => _eventController.add(event);

  void _emitLocal(VLibrasEvent event) {
    _onLocalEvent?.call(event);
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
    _webViewController = null;
    _onLocalEvent = null;
  }
}
