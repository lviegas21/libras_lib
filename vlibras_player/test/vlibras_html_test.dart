import 'package:flutter_test/flutter_test.dart';
import 'package:vlibras_player/src/vlibras_html.dart';

void main() {
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
    });
  });
}
