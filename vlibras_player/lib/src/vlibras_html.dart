/// Página que hospeda o avatar do VLibras dentro da WebView.
///
/// ## Por que não usamos mais o `vlibras-plugin.js`
///
/// Até o VLibras 6 o `vlibras-plugin.js` era um bundle que montava o painel no
/// DOM da página (`[vw]`, `[vw-access-button]`, `[vw-plugin-wrapper]`) e expunha
/// `window.plugin.player.translate()`. A partir do 7.x ele virou um stub de
/// 2 KB: ao clicar no botão de acesso, carrega um app Preact
/// (`vlibras-plugin-app.js`) que se monta **dentro de dois shadow roots** e
/// renderiza o avatar num `<iframe>` (`app/unity/index.html`).
///
/// Consequências para nós: o botão de acesso ficou inalcançável por
/// `document.querySelector` (está no shadow DOM), o CSS que escondia o chrome
/// nativo não atravessa shadow DOM, e `window.plugin.player.loaded` deixou de
/// existir. Ou seja: nada do caminho antigo sobrevive.
///
/// ## O que fazemos no lugar
///
/// Montamos o **mesmo `<iframe>` do player** direto na nossa página e
/// conversamos com ele pelo protocolo que o próprio `unity/index.js` publica:
///
/// ```text
/// enviar  → iframe.contentWindow.postMessage(
///             { type: 'unity', object, method, params }, '*')
///           → gameInstance.SendMessage(object, method, params)
/// receber ← { type: 'unity_event', event, data }
///           events: update_progress | on_load_player | on_playing_state_change
///                 | counter_gloss | finish_welcome | on_error
/// ```
///
/// A conversão texto → glosa (que o app do widget fazia) passa a ser nossa,
/// mas no **Dart** (`VLibrasTranslationService` → [kVLibrasTranslateUrl]): a
/// página só recebe a glosa pronta e a entrega ao Unity via `playNow`. Fora da
/// WebView não há CORS nem origem opaca de `loadDataWithBaseURL` no caminho, e
/// o status HTTP chega inteiro ao relatório de erro.
///
/// Ganhos: não existe chrome nativo para esconder, não há shadow DOM para
/// atravessar, o app do widget (dialogs, drag, analytics, fontes, lazy chunks)
/// não compete com o boot do Unity, e `update_progress` dá progresso real de
/// download — o que substitui o polling de 250 ms por um watchdog de
/// inatividade (nada de trabalho recorrente na thread JS durante o boot).
library;

/// Versão do player Unity que este plugin foi testado e fixado.
///
/// Também vira cache-buster na URL do iframe (o `index.js` de dentro do iframe
/// carrega o `playerweb.json` da sua própria versão).
const String kVLibrasPlayerVersion = '7.9.1';

/// Portal oficial. Serve **sempre a versão mais recente** do VLibras: qualquer
/// migração publicada lá entra no app sem aviso — foi assim que a troca 6.x →
/// 7.x quebrou a integração anterior. Use quando quiser acompanhar o portal.
const String kVLibrasPortalBaseUrl = 'https://vlibras.gov.br/app';

/// Assets do player fixados na versão [kVLibrasPlayerVersion] (jsDelivr, que
/// espelha as tags de `spbgovbr-vlibras/vlibras-portal` e guarda todas elas).
///
/// **Não serve como `baseUrl` sozinho.** O jsDelivr entrega `.html` como
/// `Content-Type: text/plain` + `nosniff` — de propósito, para ninguém hospedar
/// site nele. O navegador então trata `unity/index.html` como texto, nenhum
/// script roda e o player nunca inicializa (testado no device: o iframe fica
/// sendo remontado pelo watchdog). Só os arquivos não-HTML (`unity-loader.js`,
/// `playerweb.json`, `*.unityweb`) vêm com o tipo certo.
///
/// Para de fato congelar a versão, hospede os dois arquivos pequenos —
/// `unity/index.html` (686 B) e `unity/index.js` (1,2 kB), copiados desta tag —
/// no seu próprio domínio, com `Content-Type: text/html` e `text/javascript`, e
/// aponte `VLibrasConfig.baseUrl` para lá. Eles carregam o resto por caminho
/// relativo, então mantenha a estrutura `<sua-base>/unity/…`. Ver a seção de
/// manutenção no README.
const String kVLibrasPinnedPlayerAssetsUrl =
    'https://cdn.jsdelivr.net/gh/spbgovbr-vlibras/vlibras-portal@v$kVLibrasPlayerVersion/app';

/// Bundles de sinais que o player precisa receber via `setBaseUrl` no boot.
const String kVLibrasDictionaryUrl =
    'https://dicionario2.vlibras.gov.br/2018.3.1/WEBGL/';

/// Serviço de tradução português → glosa (`POST {"text": "..."}` → glosa).
const String kVLibrasTranslateUrl =
    'https://traducao2.vlibras.gov.br/translate';

/// Largura, em CSS px, da tela virtual em que o Unity desenha o avatar.
///
/// Mantida em 320 (a largura do painel oficial) porque é a proporção em que a
/// cena foi enquadrada — mudar isso reenquadra o avatar, não dá zoom nele.
const double kVLibrasPanelCssWidth = 320.0;

/// Zoom do palco só-avatar: quanto da tela virtual fica visível.
///
/// É um **fator**, não uma medida em px — por isso não depende do tamanho nem
/// da proporção do frame. `1.39` mostra da folga acima da cabeça até abaixo das
/// mãos na cena do player 7.x; foi medido no device (ver
/// [kVLibrasAvatarOnlyViewport]). `1.0` mostra a tela virtual inteira.
const double kVLibrasAvatarZoom = 1.39;

/// Altura de tela virtual para um close-up só do avatar (Flutter dona da UI).
///
/// Calibrado no device contra a cena do player 7.x, num palco retrato de
/// 158 × 220: em 200 (o valor que servia no 6.x) o corte de 2,2× deixa as
/// **mãos fora do quadro** — e é exatamente onde o sinal acontece. Em 320 o
/// enquadramento pega da folga acima da cabeça até abaixo das mãos, sem sobrar
/// fundo vazio. A geometria da transform não mudou entre 6.x e 7.x; o que
/// mudou foi a cena do Unity, que passou a enquadrar o avatar mais perto.
///
/// **Atenção:** este valor é em CSS px e só equivale a [kVLibrasAvatarZoom] na
/// proporção em que foi calibrado ([kVLibrasAvatarStageAspect]). Num palco de
/// outra proporção ele enquadra diferente. Prefira deixar
/// `avatarViewportHeight` nulo e deixar o widget derivar de
/// [kVLibrasAvatarZoom] — aí o enquadramento é o mesmo em qualquer palco.
const double kVLibrasAvatarOnlyViewport = 320.0;

/// Proporção largura/altura de um palco retrato que mostra quase só a figura.
const double kVLibrasAvatarStageAspect = 0.72;

/// Largura Flutter que casa com a tela virtual de [avatarViewportHeight] para
/// um widget de altura [height].
double vlibrasNaturalWidth({
  required double height,
  required double avatarViewportHeight,
}) =>
    height * (kVLibrasPanelCssWidth / avatarViewportHeight);

/// Retrato [width] × [height] para um palco só-avatar dentro de um card maior.
///
/// Prefira isso a esticar a WebView na largura toda do card — janela retrato +
/// [kVLibrasAvatarOnlyViewport] baixo mostra majoritariamente a figura.
({double width, double height}) vlibrasAvatarStage({
  required double maxWidth,
  required double maxHeight,
  double aspect = kVLibrasAvatarStageAspect,
}) {
  var height = maxHeight;
  var width = height * aspect;
  if (width > maxWidth) {
    width = maxWidth;
    height = width / aspect;
  }
  return (width: width, height: height);
}

/// Tela virtual + zoom para um frame de [frameWidth] × [frameHeight].
///
/// A tela virtual tem sempre [kVLibrasPanelCssWidth] de largura e a **mesma
/// proporção do frame**, então o `cover` aplicado na página nunca deforma nada;
/// o enquadramento é decidido só pelo zoom.
///
/// - [avatarViewportHeight] nulo (recomendado) ⇒ zoom fixo [avatarZoom]: o
///   avatar aparece igual em qualquer tamanho **e** em qualquer proporção de
///   palco — retrato, quadrado ou paisagem, celular ou tablet.
/// - [avatarViewportHeight] em CSS px ⇒ zoom = `canvasHeight / valor`, o modo
///   antigo: preso à proporção em que o valor foi escolhido. Valores maiores
///   que a tela virtual não afastam a câmera (zoom mínimo 1.0).
({double canvasHeight, double zoom}) vlibrasStageFraming({
  required double frameWidth,
  required double frameHeight,
  double? avatarViewportHeight,
  double avatarZoom = kVLibrasAvatarZoom,
}) {
  if (frameWidth <= 0 || frameHeight <= 0) {
    return (canvasHeight: 500.0, zoom: 1.0);
  }
  final canvasHeight = frameHeight * kVLibrasPanelCssWidth / frameWidth;
  if (avatarViewportHeight == null) {
    return (canvasHeight: canvasHeight, zoom: avatarZoom < 1.0 ? 1.0 : avatarZoom);
  }
  if (avatarViewportHeight <= 0 || avatarViewportHeight >= canvasHeight) {
    return (canvasHeight: canvasHeight, zoom: 1.0);
  }
  return (canvasHeight: canvasHeight, zoom: canvasHeight / avatarViewportHeight);
}

/// Monta a página que hospeda o player Unity do VLibras na WebView.
///
/// ## Enquadramento
///
/// O `<iframe>` do player tem tamanho fixo em CSS px
/// ([kVLibrasPanelCssWidth] × [naturalHeight]) — essa é a tela virtual em que o
/// Unity desenha. A página então aplica `translate(tx, ty) scale(s)` com
/// `transform-origin: 0 0`, onde
/// `s = max(frameW / 320, frameH / naturalHeight) × contentZoom` (cover) e
/// `tx`/`ty` posicionam a tela virtual escalada dentro do frame conforme
/// [originX] / [originY]. Assim:
///
/// - [naturalHeight] **menor** ⇒ tela virtual mais baixa ⇒ mais zoom no avatar;
/// - [contentZoom] > 1 ⇒ zoom extra, cortando as sobras;
/// - [originY] = 0 ancora o topo (não corta a cabeça), 0.5 centraliza.
///
/// Como a tela virtual não depende do tamanho da WebView, girar a tela ou
/// redimensionar **não precisa recarregar a página**: o `resize` reaplica só a
/// transform, e `window.__vlibrasSetStage()` troca tela virtual / zoom / âncora
/// ao vivo.
///
/// ## Ponte JS ↔ Dart
///
/// Expostos para o Dart chamar via `runJavaScript`:
/// `__vlibrasPlay(gloss)`, `__vlibrasSkip()`, `__vlibrasSetSpeed(v)`,
/// `__vlibrasSetAvatar(id)`, `__vlibrasSetSubtitles(bool)`,
/// `__vlibrasSetStage(canvasH, zoom, originX, originY)`.
///
/// Eventos postados em `VLibrasChannel`: `loading` (com `phase`), `ready`,
/// `translateComplete` (avatar terminou de sinalizar) e `error` (com `kind`).
///
/// [playerHeight] / [playerWidth] — tamanho do widget Flutter, em px lógicos;
///   só dicas para o primeiro layout (o JS mede a viewport real).
/// [naturalHeight] — altura da tela virtual do Unity, em CSS px.
/// [sdkLoadRetries] — quantas vezes remontar o iframe se o boot travar.
/// [initTimeoutMs] — orçamento de **inatividade** por tentativa: o relógio só
///   corre enquanto o device está online e nenhum progresso chega.
String buildVLibrasHtml({
  required String baseUrl,
  required String avatar,
  required double speed,
  required bool autoPlay,
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
}) {
  final String canvasW = kVLibrasPanelCssWidth.toStringAsFixed(0);
  final String canvasH =
      (naturalHeight > 0 ? naturalHeight : 500.0).toStringAsFixed(2);
  final String zoom =
      (contentZoom < 1.0 ? 1.0 : contentZoom).toStringAsFixed(4);
  final String originXStr = originX.clamp(0.0, 1.0).toStringAsFixed(4);
  final String originYStr = originY.clamp(0.0, 1.0).toStringAsFixed(4);
  final String hintW =
      (playerWidth ?? kVLibrasPanelCssWidth).toStringAsFixed(2);
  final String hintH = (playerHeight ?? naturalHeight).toStringAsFixed(2);

  return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no"/>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background: #ffffff;
      overflow: hidden;
    }
    /* Recorte do palco: o iframe é maior que o frame visível e a sobra é
       cortada aqui — nada de OverflowBox no Flutter (platform view). */
    #vlibras-stage {
      position: absolute;
      inset: 0;
      overflow: hidden;
    }
    /* Tela virtual do Unity. Tamanho fixo em CSS px; posição e escala vêm da
       transform aplicada por applyLayout(). */
    #vlibras-player {
      position: absolute;
      left: 0;
      top: 0;
      width: ${canvasW}px;
      height: ${canvasH}px;
      border: 0;
      display: block;
      background: transparent;
      transform-origin: 0 0;
    }
  </style>
</head>
<body>
  <div id="vlibras-stage"></div>

  <script>
    // Rede de captura global de JS: erros e promises rejeitadas que antes
    // morriam no console da WebView sobem pro Dart (canal VLibrasChannel)
    // -> VLibrasPlayer.errorReporter -> Crashlytics. "kind" separa a origem.
    // Erros de dentro do iframe do player não chegam aqui (documento
    // separado) — aqueles viram evento `on_error` ou estouro do watchdog.
    (function() {
      function post(payload) {
        try { VLibrasChannel.postMessage(JSON.stringify(payload)); } catch (e) {}
      }
      window.addEventListener('error', function(e) {
        post({
          type: 'error',
          message: (e && e.message) || 'Erro JS desconhecido',
          data: {
            kind: 'js-error',
            source: e && e.filename,
            lineno: e && e.lineno,
            colno: e && e.colno,
            stack: e && e.error && e.error.stack ? String(e.error.stack).slice(0, 800) : null
          }
        });
      });
      window.addEventListener('unhandledrejection', function(e) {
        var r = e && e.reason;
        post({
          type: 'error',
          message: (r && (r.message || r)) ? String(r.message || r) : 'Promise rejeitada sem motivo',
          data: {
            kind: 'unhandled-rejection',
            stack: r && r.stack ? String(r.stack).slice(0, 800) : null
          }
        });
      });
    })();

    // Marca lida pelo VLibrasLivenessMonitor: se o renderer do WebView morrer,
    // a página some e esta expressão deixa de ser verdadeira.
    window.__vlibrasAlive = true;

    window.__vlibrasConfig = {
      avatar: '$avatar',
      speed: $speed,
      autoPlay: $autoPlay,
    };
  </script>

  <script>
    (function() {
      /* ---------------------------------------------------------------
       * Configuração vinda do Dart
       * --------------------------------------------------------------- */
      var CFG = {
        base:         '$baseUrl',
        version:      '$playerVersion',
        dictionary:   '$dictionaryUrl',
        avatar:       '$avatar',
        speed:        $speed,
        subtitles:    $showSubtitles,
        welcome:      $playWelcome,
        maxRetries:   $sdkLoadRetries,
        stallMs:      $initTimeoutMs
      };

      // Protocolo do unity/index.js (SendMessage do Unity 2018).
      var OBJ = {
        PLAYER:  'PlayerManager',
        EMOTION: 'EmotionBridge',
        CUSTOM:  'CustomizationBridge'
      };
      var M = {
        PLAY:      'playNow',
        STOP:      'stopAll',
        REPEAT:    'repeat',
        SPEED:     'setSlider',
        AVATAR:    'Change',
        PAUSE:     'setPauseState',
        BASE_URL:  'setBaseUrl',
        SUBTITLES: 'setSubtitlesState',
        WELCOME:   'playWellcome'
      };
      var AVATARS = ['icaro', 'guga', 'hosana'];
      var TRANSLATE_TIMEOUT_MS = 10000;   // mesmo teto do widget oficial
      var AVATAR_SETTLE_MS = 500;         // idem: Unity não aceita Change antes
      var PAUSE_WHEN_IDLE = $pauseWhenIdle;
      var IDLE_PAUSE_MS = 1500;           // folga antes de congelar o quadro

      /* ---------------------------------------------------------------
       * Canal com o Dart
       * --------------------------------------------------------------- */
      var bootStart = Date.now();
      function post(o) {
        try { VLibrasChannel.postMessage(JSON.stringify(o)); } catch (e) {}
      }
      var lastPhase = null;
      function loading(phase, extra) {
        var d = { phase: phase };
        if (extra) for (var k in extra) d[k] = extra[k];
        // Uma linha por transição de fase (não por tick de progresso): dá para
        // ver no logcat onde o boot gastou o tempo, sem poluir.
        if (phase !== lastPhase) {
          lastPhase = phase;
          console.log('[VLibras] ' + phase + ' +' +
            (Date.now() - bootStart) + 'ms');
        }
        post({ type: 'loading', message: phase, data: d });
      }
      // Erro fatal: derruba o player (o Dart troca para o estado de erro).
      function fail(message, data) {
        console.log('[VLibras] erro: ' + message + ' ' + JSON.stringify(data));
        post({ type: 'error', message: message, data: data });
      }
      // Erro transitório (uma tradução que falhou): reporta sem matar o player,
      // que continua carregado e pronto para a próxima frase.
      function failSoft(message, data) {
        data = data || {};
        data.fatal = false;
        console.log('[VLibras] erro (nao fatal): ' + message + ' ' + JSON.stringify(data));
        post({ type: 'error', message: message, data: data });
      }
      function isOffline() { return navigator && navigator.onLine === false; }
      function onceOnline(cb) {
        function h() { window.removeEventListener('online', h); cb(); }
        window.addEventListener('online', h);
      }

      /* ---------------------------------------------------------------
       * Enquadramento (tela virtual -> frame visível)
       * --------------------------------------------------------------- */
      var CANVAS_W = $canvasW;
      var CANVAS_H = $canvasH;
      var ZOOM     = $zoom;
      var ORIGIN_X = $originXStr;
      var ORIGIN_Y = $originYStr;
      var HINT_W   = $hintW;
      var HINT_H   = $hintH;

      var stage = document.getElementById('vlibras-stage');
      var frame = null;

      function applyLayout() {
        if (!frame) return;
        var vw = window.innerWidth  || HINT_W;
        var vh = window.innerHeight || HINT_H;
        // cover: preenche o frame nas duas direções e corta a sobra.
        var s = Math.max(vw / CANVAS_W, vh / CANVAS_H) * ZOOM;
        var sw = CANVAS_W * s, sh = CANVAS_H * s;
        var tx = (vw - sw) * ORIGIN_X;
        var ty = (vh - sh) * ORIGIN_Y;
        frame.style.transform =
          'translate(' + tx.toFixed(2) + 'px,' + ty.toFixed(2) + 'px) ' +
          'scale(' + s.toFixed(4) + ')';
      }

      var layoutTimer = null;
      function scheduleLayout() {
        if (layoutTimer) clearTimeout(layoutTimer);
        layoutTimer = setTimeout(function() {
          layoutTimer = null;
          applyLayout();
        }, 80);
      }
      window.addEventListener('resize', scheduleLayout);
      window.addEventListener('orientationchange', scheduleLayout);

      // Troca tela virtual / zoom / âncora ao vivo, sem rebootar o Unity.
      window.__vlibrasSetStage = function(canvasH, zoom, ox, oy) {
        var h = Number(canvasH), z = Number(zoom);
        var x = Number(ox), y = Number(oy);
        if (isFinite(h) && h > 0) CANVAS_H = h;
        if (isFinite(z) && z > 0) ZOOM = z;
        if (isFinite(x)) ORIGIN_X = Math.min(1, Math.max(0, x));
        if (isFinite(y)) ORIGIN_Y = Math.min(1, Math.max(0, y));
        if (frame) frame.style.height = CANVAS_H + 'px';
        applyLayout();
      };

      /* ---------------------------------------------------------------
       * Ciclo de vida do iframe do player
       * --------------------------------------------------------------- */
      var attempt      = 0;      // quantas montagens do iframe já houve
      var playerReady  = false;  // on_load_player + init aplicado
      var lastProgress = -1;     // último % de download reportado
      var watchdog     = null;

      // Watchdog de INATIVIDADE: qualquer sinal de vida (html carregado,
      // update_progress, on_load_player) rearma o timer. Sem sinal nenhum por
      // CFG.stallMs *estando online*, remonta o iframe; esgotadas as
      // tentativas, reporta erro. Sem polling: zero trabalho recorrente na
      // thread JS enquanto o Unity boota.
      function touch() {
        if (playerReady) return;
        if (watchdog) clearTimeout(watchdog);
        watchdog = setTimeout(onStalled, CFG.stallMs);
      }
      function stopWatchdog() {
        if (watchdog) { clearTimeout(watchdog); watchdog = null; }
      }
      function onStalled() {
        watchdog = null;
        if (playerReady) return;
        if (isOffline()) {
          loading('waiting-network', { attempt: attempt });
          onceOnline(function() { touch(); });
          return;
        }
        if (attempt <= CFG.maxRetries) {
          loading('retrying-player', { attempt: attempt, progress: lastProgress });
          mount();
          return;
        }
        fail('O VLibras demorou demais para iniciar. Tente novamente.', {
          kind: 'init-timeout',
          attempts: attempt,
          progress: lastProgress
        });
      }

      function mount() {
        if (isOffline()) {
          loading('waiting-network', { attempt: attempt });
          onceOnline(mount);
          return;
        }
        attempt++;
        lastProgress = -1;
        if (frame) {
          try {
            frame.onload = null;
            frame.onerror = null;
            frame.remove();
          } catch (e) {}
          frame = null;
        }
        loading('loading-player', { attempt: attempt });
        console.log('[VLibras] montando player (tentativa ' + attempt + ')');

        var f = document.createElement('iframe');
        f.id = 'vlibras-player';
        f.title = 'vlibras-player';
        f.setAttribute('tabindex', '-1');
        f.setAttribute('scrolling', 'no');
        // Mesma sandbox do widget oficial: script + origem própria (o player
        // precisa da própria origem para o XHR/IndexedDB dos bundles) e nada
        // além disso — sem navegação do topo, popups ou formulários.
        f.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-pointer-lock');
        f.style.height = CANVAS_H + 'px';
        f.onload = function() {
          loading('booting-avatar', { attempt: attempt });
          touch();
        };
        f.onerror = function() {
          // Raro (o iframe engole a maioria dos erros de rede) — o watchdog é
          // quem cobre o caso normal.
          onStalled();
        };
        f.src = CFG.base + '/unity/index.html?v=' + CFG.version +
                (attempt > 1 ? '&r=' + Date.now() : '');
        frame = f;
        stage.appendChild(f);
        applyLayout();
        touch();
      }

      // Se as tentativas esgotaram e a conexão volta depois, tenta de novo.
      window.addEventListener('online', function() {
        if (!playerReady && attempt > CFG.maxRetries) {
          attempt = 0;
          mount();
        }
      });

      /* ---------------------------------------------------------------
       * Pausa do render loop
       *
       * O Unity desenha a 60fps para sempre, mesmo com o avatar parado — num
       * aparelho de entrada isso são ~2 núcleos queimando à toa (medido num
       * Galaxy A22: ~200% de CPU só exibindo o avatar em repouso). O widget
       * oficial pausa o `mainLoop` quando o painel fecha; fazemos o mesmo
       * quando não há sinalização em curso. Visualmente é idêntico (avatar
       * parado é avatar parado), mas a CPU cai para perto de zero.
       * --------------------------------------------------------------- */
      var unityInstance = null;   // null = ainda não procurado
      var unityReachable = null;  // null = desconhecido, false = sem acesso
      var renderPaused = false;
      var idleTimer = null;

      function getUnityInstance() {
        if (unityInstance) return unityInstance;
        if (unityReachable === false) return null;
        try {
          var w = frame && frame.contentWindow;
          var inst = w && w.getUnityInstance && w.getUnityInstance();
          if (inst && inst.Module &&
              typeof inst.Module.pauseMainLoop === 'function') {
            unityInstance = inst;
            unityReachable = true;
            return inst;
          }
        } catch (e) {}
        // Sem acesso (origem diferente): seguimos sem pausar — melhor gastar
        // CPU do que arriscar congelar o avatar no meio de um sinal.
        unityReachable = false;
        console.log('[VLibras] sem acesso ao Unity para pausar o render loop');
        return null;
      }

      function setRenderPaused(paused) {
        if (paused === renderPaused) return;
        var inst = getUnityInstance();
        if (!inst) return;
        try {
          if (paused) {
            inst.Module.pauseMainLoop();
          } else {
            inst.Module.resumeMainLoop();
          }
          renderPaused = paused;
          console.log('[VLibras] render ' + (paused ? 'pausado' : 'retomado'));
        } catch (e) {
          unityReachable = false;
        }
      }

      function cancelIdlePause() {
        if (idleTimer) { clearTimeout(idleTimer); idleTimer = null; }
      }

      // Volta a desenhar agora (antes de qualquer coisa que anime o avatar).
      function wakeRender() {
        cancelIdlePause();
        setRenderPaused(false);
      }

      // Agenda a pausa — com folga, para não cortar o fim de uma animação.
      function scheduleIdlePause() {
        if (!PAUSE_WHEN_IDLE) return;
        cancelIdlePause();
        idleTimer = setTimeout(function() {
          idleTimer = null;
          if (!signing) setRenderPaused(true);
        }, IDLE_PAUSE_MS);
      }

      function send(object, method, params) {
        var w = frame && frame.contentWindow;
        if (!w) return false;
        try {
          w.postMessage(
            { type: 'unity', object: object, method: method, params: params },
            '*'
          );
          return true;
        } catch (e) {
          return false;
        }
      }

      /* ---------------------------------------------------------------
       * Eventos vindos do player (unity/index.js)
       * --------------------------------------------------------------- */
      window.addEventListener('message', function(ev) {
        if (!frame || ev.source !== frame.contentWindow) return;
        var d = ev.data;
        if (!d || d.type !== 'unity_event') return;
        switch (d.event) {
          case 'update_progress':         onProgress(Number(d.data)); break;
          case 'on_load_player':          onPlayerLoaded();           break;
          case 'on_playing_state_change': onPlayingState(d.data);     break;
          case 'counter_gloss':           touch();                    break;
          case 'finish_welcome':          touch();                    break;
          case 'on_error':
            stopWatchdog();
            fail('Este dispositivo não conseguiu iniciar o avatar do VLibras.', {
              kind: 'unity-error',
              detail: String(d.data)
            });
            break;
        }
      });

      function onProgress(p) {
        if (!isFinite(p)) return;
        touch();
        var pct = Math.round(p * 100);
        if (pct <= lastProgress && pct < 100) return;
        // Reporta em degraus de 5% para não inundar o canal.
        if (lastProgress >= 0 && pct < 100 && pct - lastProgress < 5) return;
        lastProgress = pct;
        if (pct >= 100) {
          console.log('[VLibras] download 100% +' +
            (Date.now() - bootStart) + 'ms');
        }
        loading('downloading-avatar', { progress: pct, attempt: attempt });
      }

      function onPlayerLoaded() {
        if (playerReady) return;
        stopWatchdog();
        loading('initializing-avatar', { attempt: attempt });
        // Sequência que o widget oficial aplica no on_load_player.
        send(OBJ.PLAYER, M.BASE_URL, CFG.dictionary);
        send(OBJ.PLAYER, M.SPEED, CFG.speed);
        send(OBJ.PLAYER, M.SUBTITLES, CFG.subtitles ? 1 : 0);
        // O Unity só assenta a troca de avatar um tiquinho depois do boot — o
        // widget oficial também espera 500 ms aqui.
        setTimeout(function() {
          send(OBJ.PLAYER, M.AVATAR, CFG.avatar);
          if (CFG.welcome) send(OBJ.PLAYER, M.WELCOME);
          playerReady = true;
          var bootMs = Date.now() - bootStart;
          console.log('[VLibras] pronto em ' + bootMs + 'ms (tentativa ' +
            attempt + ')');
          post({ type: 'ready', data: { attempts: attempt, boot_ms: bootMs } });
          flushPending();
          scheduleIdlePause();
        }, AVATAR_SETTLE_MS);
      }

      // data = ['True'|'False'] x5:
      // [isPlaying, isPaused, isPlayingIntervalAnimation, isLoading, isRepeatable]
      var signing = false;
      function onPlayingState(raw) {
        var a = raw && raw.length ? raw : [];
        function flag(i) { return a[i] === 'True' || a[i] === true; }
        var isPlaying = flag(0), isPaused = flag(1), isLoadingSign = flag(3);
        if (isPlaying && !isPaused) {
          signing = true;
          wakeRender();
          return;
        }
        if (!isPlaying && !isLoadingSign && signing) {
          signing = false;
          post({ type: 'translateComplete' });
          scheduleIdlePause();
        }
      }

      /* ---------------------------------------------------------------
       * Sinalização (a glosa vem pronta do Dart)
       * --------------------------------------------------------------- */
      var pendingGloss = null;   // chegou antes de o player ficar pronto

      function flushPending() {
        var g = pendingGloss;
        pendingGloss = null;
        if (g) play(g);
      }

      function play(gloss) {
        wakeRender();
        signing = false;
        if (!send(OBJ.PLAYER, M.PLAY, gloss)) {
          failSoft('O player do VLibras não está mais disponível.', {
            kind: 'player-gone'
          });
        }
      }

      /* ---------------------------------------------------------------
       * API chamada pelo Dart
       * --------------------------------------------------------------- */
      // Recebe a glosa já traduzida pelo Dart (ver VLibrasTranslationService).
      window.__vlibrasPlay = function(gloss) {
        if (!gloss) return;
        if (!playerReady) {
          pendingGloss = gloss;   // toca assim que o player ficar pronto
          return;
        }
        play(gloss);
      };

      window.__vlibrasSkip = function() {
        pendingGloss = null;
        signing = false;
        if (playerReady) send(OBJ.PLAYER, M.STOP);
        scheduleIdlePause();
      };

      // Liga/desliga o desenho por conta do app (ex.: o player saiu de vista).
      window.__vlibrasSetActive = function(active) {
        if (active) {
          wakeRender();
        } else {
          cancelIdlePause();
          setRenderPaused(true);
        }
      };

      window.__vlibrasSetSpeed = function(v) {
        var s = Number(v);
        if (!isFinite(s) || s <= 0) return;
        CFG.speed = s;
        if (playerReady) send(OBJ.PLAYER, M.SPEED, s);
      };

      window.__vlibrasSetAvatar = function(id) {
        if (AVATARS.indexOf(id) === -1) return;
        CFG.avatar = id;
        if (playerReady) send(OBJ.PLAYER, M.AVATAR, id);
      };

      window.__vlibrasSetSubtitles = function(on) {
        CFG.subtitles = !!on;
        if (playerReady) send(OBJ.PLAYER, M.SUBTITLES, CFG.subtitles ? 1 : 0);
      };

      mount();
    })();
  </script>
</body>
</html>
''';
}
