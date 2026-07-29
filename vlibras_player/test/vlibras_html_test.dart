import 'package:flutter_test/flutter_test.dart';
import 'package:vlibras_player/src/vlibras_html.dart';

void main() {
  group('vlibrasNaturalWidth', () {
    test('matches height * (panelCssWidth / viewport)', () {
      expect(
        vlibrasNaturalWidth(height: 240, avatarViewportHeight: 280),
        closeTo(240 * (kVLibrasPanelCssWidth / 280), 0.001),
      );
    });
  });

  group('vlibrasAvatarStage', () {
    test('keeps portrait aspect within max bounds', () {
      final stage = vlibrasAvatarStage(maxWidth: 400, maxHeight: 300);
      expect(stage.width / stage.height, closeTo(kVLibrasAvatarStageAspect, 0.01));
      expect(stage.width, lessThanOrEqualTo(400));
      expect(stage.height, lessThanOrEqualTo(300));
    });
  });

  group('buildVLibrasHtml', () {
    test('injects __vlibrasConfig with avatar, speed and autoPlay', () {
      final html = buildVLibrasHtml(
        baseUrl: 'https://vlibras.gov.br/app',
        avatar: 'guga',
        speed: 1.5,
        autoPlay: true,
        playerHeight: 240,
        naturalHeight: 280,
      );

      expect(html, contains("avatar: 'guga'"));
      expect(html, contains('speed: 1.5'));
      expect(html, contains('autoPlay: true'));
    });

    test('uses panel CSS width and centering styles', () {
      final html = buildVLibrasHtml(
        baseUrl: 'https://vlibras.gov.br/app',
        avatar: 'guga',
        speed: 1.0,
        autoPlay: false,
        playerHeight: 220,
        naturalHeight: 280,
        contentZoom: 1.25,
        originX: 0.5,
        originY: 0.5,
      );

      expect(
        html,
        contains(
          'width=${kVLibrasPanelCssWidth.toStringAsFixed(0)},initial-scale=',
        ),
      );
      expect(html, contains('[vw-plugin-wrapper]'));
      expect(html, contains('margin-left: auto'));
      expect(html, contains('translateX(-50%) scale(1.2500)'));
      expect(html, contains('transform-origin: 50.00% 50.00%'));
    });

    test('initialises Widget with rootPath and avatar', () {
      final html = buildVLibrasHtml(
        baseUrl: 'https://vlibras.gov.br/app',
        avatar: 'hosana',
        speed: 1.0,
        autoPlay: false,
      );

      expect(html, contains("rootPath: 'https://vlibras.gov.br/app'"));
      expect(html, contains("avatar: 'hosana'"));
      expect(html, contains('new window.VLibras.Widget({'));
    });

    test('hides native plugin chrome via CSS and JS', () {
      final html = buildVLibrasHtml(
        baseUrl: 'https://vlibras.gov.br/app',
        avatar: 'icaro',
        speed: 1.0,
        autoPlay: false,
      );

      expect(html, contains('.vw-plugin-top-wrapper'));
      expect(html, contains('suppressPluginUi'));
      expect(html, contains('[vw-plugin-wrapper] button'));
      expect(html, contains("'[vw-plugin-wrapper] footer',"));
    });

    test('init timeout reports error instead of ready', () {
      final html = buildVLibrasHtml(
        baseUrl: 'https://vlibras.gov.br/app',
        avatar: 'guga',
        speed: 1.0,
        autoPlay: false,
      );

      expect(html, contains("message: 'Falha ao inicializar o VLibras'"));
      expect(html, contains("type: 'error'"));
      // Must not fake success on timeout.
      expect(
        html.contains("console.log('[VLibras] timeout');\n            VLibrasChannel.postMessage(JSON.stringify({ type: 'ready' }))"),
        isFalse,
      );
    });
  });
}
