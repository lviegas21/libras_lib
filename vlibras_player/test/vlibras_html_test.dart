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


  group('vlibrasStageFraming', () {
    ({double w, double h}) frame(double w, double h) => (w: w, h: h);

    test('sem viewport: mesmo zoom em qualquer proporção de palco', () {
      final palcos = [
        frame(158, 220),   // card retrato de celular (o calibrado)
        frame(110, 150),   // o mesmo card, menor
        frame(320, 440),   // tablet, mesma proporção
        frame(220, 220),   // quadrado
        frame(360, 200),   // paisagem
        frame(120, 400),   // faixa estreita
      ];

      for (final p in palcos) {
        final f = vlibrasStageFraming(frameWidth: p.w, frameHeight: p.h);
        expect(f.zoom, closeTo(kVLibrasAvatarZoom, 0.0001),
            reason: 'palco ${p.w}x${p.h}');
        // A tela virtual acompanha a proporção do frame, então o cover nunca
        // deforma: canvasHeight/320 == frameHeight/frameWidth.
        expect(f.canvasHeight / kVLibrasPanelCssWidth,
            closeTo(p.h / p.w, 0.0001), reason: 'palco ${p.w}x${p.h}');
      }
    });

    test('viewport fixo em px depende da proporção — por isso não é o padrão',
        () {
      final retrato =
          vlibrasStageFraming(frameWidth: 158, frameHeight: 220,
              avatarViewportHeight: kVLibrasAvatarOnlyViewport);
      final paisagem =
          vlibrasStageFraming(frameWidth: 360, frameHeight: 200,
              avatarViewportHeight: kVLibrasAvatarOnlyViewport);

      expect(retrato.zoom, closeTo(kVLibrasAvatarZoom, 0.01));
      expect(paisagem.zoom, lessThan(retrato.zoom));
    });

    test('viewport maior que a tela virtual não afasta a câmera', () {
      final f = vlibrasStageFraming(
          frameWidth: 158, frameHeight: 220, avatarViewportHeight: 5000);
      expect(f.zoom, 1.0);
    });

    test('frame degenerado não estoura', () {
      final f = vlibrasStageFraming(frameWidth: 0, frameHeight: 0);
      expect(f.zoom, 1.0);
      expect(f.canvasHeight, greaterThan(0));
    });
  });

  group('buildVLibrasHtml', () {
    String html({
      String baseUrl = 'https://vlibras.gov.br/app',
      String avatar = 'icaro',
      double speed = 1.0,
      bool autoPlay = false,
      double? playerWidth,
      double? playerHeight,
      double naturalHeight = 500.0,
      double contentZoom = 1.0,
      double originX = 0.5,
      double originY = 0.5,
      int sdkLoadRetries = 4,
      int initTimeoutMs = 45000,
      String playerVersion = kVLibrasPlayerVersion,
      String dictionaryUrl = kVLibrasDictionaryUrl,
      bool showSubtitles = false,
      bool playWelcome = false,
      bool pauseWhenIdle = true,
    }) =>
        buildVLibrasHtml(
          baseUrl: baseUrl,
          avatar: avatar,
          speed: speed,
          autoPlay: autoPlay,
          playerWidth: playerWidth,
          playerHeight: playerHeight,
          naturalHeight: naturalHeight,
          contentZoom: contentZoom,
          originX: originX,
          originY: originY,
          sdkLoadRetries: sdkLoadRetries,
          initTimeoutMs: initTimeoutMs,
          playerVersion: playerVersion,
          dictionaryUrl: dictionaryUrl,
          showSubtitles: showSubtitles,
          playWelcome: playWelcome,
          pauseWhenIdle: pauseWhenIdle,
        );

    test('injects __vlibrasConfig with avatar, speed and autoPlay', () {
      final page = html(avatar: 'guga', speed: 1.5, autoPlay: true);

      expect(page, contains("avatar: 'guga'"));
      expect(page, contains('speed: 1.5'));
      expect(page, contains('autoPlay: true'));
    });

    test('monta o iframe do player Unity a partir do baseUrl e da versão', () {
      final page = html(baseUrl: 'https://exemplo.gov.br/app', playerVersion: '7.9.1');

      expect(
        page,
        contains(
          "CFG.base + '/unity/index.html?v=' + CFG.version",
        ),
      );
      expect(page, contains("base:         'https://exemplo.gov.br/app'"));
      expect(page, contains("version:      '7.9.1'"));
      // O caminho v6 (widget + painel no DOM) não pode voltar por acidente.
      expect(page, isNot(contains('vlibras-plugin.js')));
      expect(page, isNot(contains('vw-plugin-wrapper')));
      expect(page, isNot(contains('vw-access-button')));
      expect(page, isNot(contains('window.plugin')));
    });

    test('fala com o player pelo protocolo postMessage do unity/index.js', () {
      final page = html();

      expect(page, contains("type: 'unity'"));
      expect(page, contains("PLAYER:  'PlayerManager'"));
      expect(page, contains("PLAY:      'playNow'"));
      expect(page, contains("STOP:      'stopAll'"));
      expect(page, contains("BASE_URL:  'setBaseUrl'"));
      expect(page, contains("d.type !== 'unity_event'"));
      expect(page, contains("case 'on_load_player'"));
      expect(page, contains("case 'update_progress'"));
    });

    test('boot envia dicionário, velocidade, legendas e avatar', () {
      final page = html(
        avatar: 'hosana',
        speed: 1.25,
        dictionaryUrl: 'https://dic.example/WEBGL/',
        showSubtitles: true,
      );

      expect(page, contains("dictionary:   'https://dic.example/WEBGL/'"));
      expect(page, contains('speed:        1.25'));
      expect(page, contains('subtitles:    true'));
      expect(page, contains("avatar:       'hosana'"));
      expect(page, contains('send(OBJ.PLAYER, M.BASE_URL, CFG.dictionary);'));
      expect(page, contains('send(OBJ.PLAYER, M.AVATAR, CFG.avatar);'));
    });

    test('recebe glosa pronta do Dart — nada de rede na página', () {
      final page = html();

      expect(page, contains('window.__vlibrasPlay = function(gloss)'));
      expect(page, contains('send(OBJ.PLAYER, M.PLAY, gloss)'));
      // A tradução saiu da WebView (CORS/origem opaca): nenhuma requisição
      // parte da página além do próprio player.
      expect(page, isNot(contains('fetch(')));
      expect(page, isNot(contains('traducao')));
      expect(page, isNot(contains('XMLHttpRequest')));
    });

    test('congela o render loop quando o avatar não sinaliza', () {
      final page = html();

      expect(page, contains('var PAUSE_WHEN_IDLE = true;'));
      expect(page, contains('inst.Module.pauseMainLoop();'));
      expect(page, contains('inst.Module.resumeMainLoop();'));
      // Tocar precisa acordar o desenho antes de mandar a glosa.
      expect(
        page.indexOf('wakeRender();'),
        lessThan(page.indexOf('send(OBJ.PLAYER, M.PLAY, gloss)')),
      );
    });

    test('pauseWhenIdle: false deixa o Unity desenhando', () {
      expect(html(pauseWhenIdle: false), contains('var PAUSE_WHEN_IDLE = false;'));
    });

    test('expõe a ponte chamada pelo Dart', () {
      final page = html();

      expect(page, contains('window.__vlibrasPlay = function(gloss)'));
      expect(page, contains('window.__vlibrasSkip = function()'));
      expect(page, contains('window.__vlibrasSetStage = function('));
      expect(page, contains('window.__vlibrasSetSpeed = function(v)'));
      expect(page, contains('window.__vlibrasSetAvatar = function(id)'));
      expect(page, contains('window.__vlibrasSetSubtitles = function(on)'));
      expect(page, contains('window.__vlibrasSetActive = function(active)'));
    });

    test('tela virtual usa a largura do painel e a naturalHeight pedida', () {
      final page = html(playerWidth: 160, playerHeight: 220, naturalHeight: 280);

      expect(page, contains('width: ${kVLibrasPanelCssWidth.toStringAsFixed(0)}px;'));
      expect(page, contains('height: 280.00px;'));
      expect(page, contains('var CANVAS_W = 320;'));
      expect(page, contains('var CANVAS_H = 280.00;'));
      expect(page, contains('var HINT_W   = 160.00;'));
      expect(page, contains('var HINT_H   = 220.00;'));
    });

    test('zoom e âncora entram no cálculo de cover', () {
      final page = html(contentZoom: 1.25, originX: 0.25, originY: 0.0);

      expect(page, contains('var ZOOM     = 1.2500;'));
      expect(page, contains('var ORIGIN_X = 0.2500;'));
      expect(page, contains('var ORIGIN_Y = 0.0000;'));
      expect(
        page,
        contains('var s = Math.max(vw / CANVAS_W, vh / CANVAS_H) * ZOOM;'),
      );
    });

    test('zoom abaixo de 1 não encolhe a cena', () {
      expect(html(contentZoom: 0.4), contains('var ZOOM     = 1.0000;'));
    });

    test('watchdog de inatividade usa o orçamento e as tentativas do config', () {
      final page = html(sdkLoadRetries: 2, initTimeoutMs: 30000);

      expect(page, contains('maxRetries:   2'));
      expect(page, contains('stallMs:      30000'));
      expect(page, contains('watchdog = setTimeout(onStalled, CFG.stallMs);'));
      // Sem polling: o boot não pode voltar a rodar trabalho a cada tick.
      expect(page, isNot(contains('setInterval')));
    });

    test('estouro do orçamento reporta erro, não sucesso', () {
      final page = html();

      expect(page, contains("kind: 'init-timeout'"));
      expect(page, contains('O VLibras demorou demais para iniciar.'));
      // `ready` sai de um único lugar: a sequência de on_load_player.
      expect("post({ type: 'ready'".allMatches(page).length, 1);
      final onStalled = page.substring(
        page.indexOf('function onStalled()'),
        page.indexOf('function mount()'),
      );
      expect(onStalled, isNot(contains("type: 'ready'")));
    });
  });
}
