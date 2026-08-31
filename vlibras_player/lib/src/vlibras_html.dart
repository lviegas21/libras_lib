/// CSS selectors that hide VLibras native chrome when Flutter owns the panel UI.
const _pluginChromeHideSelectors = '''
    .vw-plugin-top-wrapper,
    [vw-plugin-wrapper] [class*="top-wrapper"],
    [vw-plugin-wrapper] [class*="TopWrapper"],
    [vw-plugin-wrapper] [class*="top-bar"],
    [vw-plugin-wrapper] [class*="TopBar"],
    [vw-plugin-wrapper] [class*="header"],
    [vw-plugin-wrapper] [class*="Header"],
    [vw-plugin-wrapper] [class*="side"],
    [vw-plugin-wrapper] [class*="Side"],
    [vw-plugin-wrapper] [class*="toolbar"],
    [vw-plugin-wrapper] [class*="Toolbar"],
    [vw-plugin-wrapper] [class*="menu"],
    [vw-plugin-wrapper] [class*="Menu"],
    [vw-plugin-wrapper] [class*="help"],
    [vw-plugin-wrapper] [class*="Help"],
    [vw-plugin-wrapper] [class*="option"],
    [vw-plugin-wrapper] [class*="Option"],
    [vw-plugin-wrapper] [class*="avatar-select"],
    [vw-plugin-wrapper] [class*="AvatarSelect"],
    [vw-plugin-wrapper] [class*="feedback"],
    [vw-plugin-wrapper] [class*="Feedback"],
    [vw-plugin-wrapper] [class*="progress"],
    [vw-plugin-wrapper] [class*="Progress"],
    [vw-plugin-wrapper] [class*="caption"],
    [vw-plugin-wrapper] [class*="Caption"],
    [vw-plugin-wrapper] footer,
    [vw-plugin-wrapper] button,
    [vw-plugin-wrapper] a[href]''';

/// JS array literal of selectors passed to suppressPluginUi().
const _pluginChromeHideSelectorsJs = '''
            '.vw-plugin-top-wrapper',
            '[vw-plugin-wrapper] [class*="top-wrapper"]',
            '[vw-plugin-wrapper] [class*="TopWrapper"]',
            '[vw-plugin-wrapper] [class*="top-bar"]',
            '[vw-plugin-wrapper] [class*="TopBar"]',
            '[vw-plugin-wrapper] [class*="header"]',
            '[vw-plugin-wrapper] [class*="Header"]',
            '[vw-plugin-wrapper] button',
            '[vw-plugin-wrapper] a[href]',
            '[vw-plugin-wrapper] [class*="side"]',
            '[vw-plugin-wrapper] [class*="Side"]',
            '[vw-plugin-wrapper] [class*="toolbar"]',
            '[vw-plugin-wrapper] [class*="Toolbar"]',
            '[vw-plugin-wrapper] [class*="menu"]',
            '[vw-plugin-wrapper] [class*="Menu"]',
            '[vw-plugin-wrapper] [class*="help"]',
            '[vw-plugin-wrapper] [class*="Help"]',
            '[vw-plugin-wrapper] [class*="option"]',
            '[vw-plugin-wrapper] [class*="Option"]',
            '[vw-plugin-wrapper] [class*="avatar-select"]',
            '[vw-plugin-wrapper] [class*="AvatarSelect"]',
            '[vw-plugin-wrapper] [class*="feedback"]',
            '[vw-plugin-wrapper] [class*="Feedback"]',
            '[vw-plugin-wrapper] [class*="progress"]',
            '[vw-plugin-wrapper] [class*="Progress"]',
            '[vw-plugin-wrapper] [class*="caption"]',
            '[vw-plugin-wrapper] [class*="Caption"]',
            '[vw-plugin-wrapper] footer',
''';

/// Design width of the official VLibras web plugin panel, in CSS pixels.
const double kVLibrasPanelCssWidth = 320.0;

/// Default virtual canvas height for an avatar-only close-up (Flutter owns chrome).
const double kVLibrasAvatarOnlyViewport = 200.0;

/// Width/height of a portrait stage that frames mainly the signing figure.
const double kVLibrasAvatarStageAspect = 0.72;

/// Flutter logical width that matches the scaled VLibras panel for a given
/// widget [height] and virtual canvas [avatarViewportHeight].
double vlibrasNaturalWidth({
  required double height,
  required double avatarViewportHeight,
}) =>
    height * (kVLibrasPanelCssWidth / avatarViewportHeight);

/// Portrait [width] × [height] for an avatar-only stage inside a larger card.
///
/// Prefer this over stretching the WebView to full card width — a portrait
/// window + tight [kVLibrasAvatarOnlyViewport] shows mostly the figure.
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

/// Builds the HTML page that hosts the VLibras widget inside a WebView.
///
/// Scaling strategy — `initial-scale` viewport:
///   VLibras renders its signing avatar in a panel whose height equals
///   `window.innerHeight`.  By setting
///     `initial-scale = playerHeight / naturalHeight`
///   the browser's CSS viewport height equals [naturalHeight] even though the
///   physical WebView is only [playerHeight] px tall.  VLibras renders the
///   avatar in [naturalHeight] CSS px; the browser scales the result down to
///   [playerHeight] physical px automatically.
///
/// Side crop / optical centering is done with CSS `transform: scale` on the
/// plugin wrapper (platform-view safe — do not rely on Flutter OverflowBox).
///
/// [playerHeight] — Flutter widget height in logical pixels.
/// [naturalHeight] — virtual canvas height the VLibras Unity scene renders at
///   so the panel fills the WebView width (typically
///   `height × 320 / frameWidth`).
/// [contentZoom] — extra scale (>1 crops sides / zooms the avatar).
/// [originX] / [originY] — transform-origin in 0..1 (0.5 = center).
/// [playerWidth] — unused for scaling; kept for API compatibility.
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
}) {
  // initial-scale = widget_height / naturalHeight
  // window.innerHeight = physical_height / initial-scale = naturalHeight
  // VLibras sizes its panel to window.innerHeight → renders at naturalHeight px.
  // The browser scales that down to physical_height automatically.
  final double _initScale =
      (playerHeight != null && playerHeight > 0) ? playerHeight / naturalHeight : 1.0;
  final String _initScaleStr = _initScale.toStringAsFixed(4);
  final String _panelWidth = kVLibrasPanelCssWidth.toStringAsFixed(0);
  final double _zoom = contentZoom < 1.0 ? 1.0 : contentZoom;
  final String _zoomStr = _zoom.toStringAsFixed(4);
  final String _originXStr = (originX.clamp(0.0, 1.0) * 100).toStringAsFixed(2);
  final String _originYStr = (originY.clamp(0.0, 1.0) * 100).toStringAsFixed(2);

  return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=$_panelWidth,initial-scale=$_initScaleStr,user-scalable=no"/>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background: white;
      overflow: hidden;
    }

    /* Fill the WebView and keep the plugin panel centered. */
    [vw] {
      position: relative !important;
      width: 100% !important;
      height: 100% !important;
      overflow: hidden !important;
      display: flex !important;
      justify-content: center !important;
      align-items: center !important;
    }
    [vw-plugin-wrapper] {
      position: absolute !important;
      left: 50% !important;
      top: 0 !important;
      width: 100% !important;
      height: 100% !important;
      margin: 0 !important;
      overflow: hidden !important;
      transform: translateX(-50%) scale($_zoomStr) !important;
      transform-origin: ${_originXStr}% ${_originYStr}% !important;
    }
    [vw-plugin-wrapper] canvas,
    [vw-plugin-wrapper] iframe,
    [vw-plugin-wrapper] video {
      display: block !important;
      margin-left: auto !important;
      margin-right: auto !important;
      max-width: 100% !important;
      max-height: 100% !important;
    }

    /* Hide the circular access button — opened programmatically */
    [vw-access-button] {
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Hide native plugin chrome (profile, help, menu, skip, top bar).
       Translation and skip are driven from Flutter via JS bridges. */
    $_pluginChromeHideSelectors {
      display: none !important;
      pointer-events: none !important;
      opacity: 0 !important;
    }

    /* Chrome nativo oculto via display:none — sem translateY para não cortar a cabeça. */

  </style>
</head>
<body>
  <div vw class="enabled">
    <div vw-access-button class="active"></div>
    <div vw-plugin-wrapper>
      <div class="vw-plugin-top-wrapper"></div>
    </div>
  </div>

  <script>
    // Rede de captura global de JS: erros e promises rejeitadas que antes
    // morriam no console do WebView agora sobem pro Dart (canal VLibrasChannel)
    // -> VLibrasPlayer.errorReporter -> Crashlytics. "kind" separa a origem.
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

    window.__vlibrasConfig = {
      avatar: '$avatar',
      speed: $speed,
      autoPlay: $autoPlay,
    };
  </script>

  <script>
    /*
     * Strip headers that trigger a CORS preflight on the jsDelivr CDN redirect
     * used by vlibras.gov.br for Unity WASM files.  jsDelivr only allows
     * simple GET requests; adding if-none-match, cache-control, pragma, etc.
     * causes the preflight OPTIONS to fail, blocking Unity from loading.
     *
     * By removing these headers the request becomes a simple CORS GET, which
     * the CDN accepts.  Unity's own IndexedDB cache still works independently.
     */
    (function() {
      var _blocked = /^(if-none-match|if-modified-since|cache-control|pragma)\$/i;

      // Marca de "houve tráfego de rede agora" — o poll de init usa isso para
      // NÃO declarar timeout enquanto o Unity/WASM ainda está baixando numa
      // conexão lenta (progresso de download não muda o DOM).
      window.__vlibrasNetTick = 0;
      function _tick() { window.__vlibrasNetTick = Date.now(); }

      var _origSRH = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        if (_blocked.test(name)) return;
        return _origSRH.call(this, name, value);
      };
      var _origSend = XMLHttpRequest.prototype.send;
      XMLHttpRequest.prototype.send = function() {
        try {
          _tick();
          this.addEventListener('progress', _tick);
          this.addEventListener('loadend', _tick);
        } catch (e) {}
        return _origSend.apply(this, arguments);
      };

      var _origFetch = window.fetch;
      if (_origFetch) {
        window.fetch = function(url, init) {
          if (init && init.headers) {
            var h = init.headers;
            var keys = ['if-none-match','If-None-Match',
                        'if-modified-since','If-Modified-Since',
                        'cache-control','Cache-Control',
                        'pragma','Pragma'];
            if (h instanceof Headers) {
              keys.forEach(function(k) { h.delete(k); });
            } else if (h && typeof h === 'object') {
              keys.forEach(function(k) { delete h[k]; });
            }
          }
          _tick();
          return _origFetch.call(this, url, init).then(function(r) {
            _tick();
            return r;
          });
        };
      }
    })();

    // Called from Dart to skip/stop the current translation.
    window.__vlibrasSkip = function() {
      try {
        var p = window.plugin;
        if (p && p.player) {
          if (typeof p.player.cancel === 'function') { p.player.cancel(); return; }
          if (typeof p.player.stop   === 'function') { p.player.stop();   return; }
        }
      } catch(e) {}
    };

    // Called from Dart to sign text.
    // VLibras 6 exposes the API as window.plugin.player.translate(text).
    window.__vlibrasTranslate = function(text) {
      try {
        var p = window.plugin;
        if (p && p.player && typeof p.player.translate === 'function') {
          console.log('[VLibras] translate via window.plugin.player.translate');
          p.player.translate(text);
          VLibrasChannel.postMessage(JSON.stringify({ type: 'translateComplete' }));
          return;
        }
        console.log('[VLibras] plugin not ready — plugin=' + !!p +
          ' player=' + !!(p && p.player) +
          ' loaded=' + !!(p && p.player && p.player.loaded));
        VLibrasChannel.postMessage(JSON.stringify({ type: 'error', message: 'plugin not ready' }));
      } catch(e) {
        console.log('[VLibras] translate error: ' + e.message);
        VLibrasChannel.postMessage(JSON.stringify({ type: 'error', message: e.message }));
      }
    };
  </script>

  <script>
    /*
     * Carregador resiliente do VLibras para redes móveis instáveis (uso em
     * campo). Diferenças em relação ao antigo `<script src onerror>`:
     *
     *  - re-tenta baixar `vlibras-plugin.js` com backoff exponencial
     *    (1s, 2s, 4s, 8s...), até `sdkLoadRetries` vezes, em vez de falhar
     *    no primeiro soluço de conexão;
     *  - quando o device está offline, PAUSA (não conta como tentativa) e
     *    espera o evento `online` para retomar na hora;
     *  - o timeout do boot do avatar só corre enquanto há conexão E nenhum
     *    progresso visível — download lento ou queda intermitente não
     *    "gastam" o orçamento;
     *  - emite eventos `loading` (phase/attempt/next_ms) para o app mostrar
     *    "reconectando…" em vez de spinner cego ou erro prematuro.
     */
    (function() {
      var SDK_URL       = '$baseUrl/vlibras-plugin.js';
      var MAX_RETRIES   = $sdkLoadRetries;
      var POLL_MS       = 250;
      var BOOT_BUDGET_MS = $initTimeoutMs;

      var scriptAttempt = 0;
      var widgetStarted = false;

      function post(o) {
        try { VLibrasChannel.postMessage(JSON.stringify(o)); } catch (e) {}
      }
      function loading(phase, extra) {
        var d = { phase: phase };
        if (extra) for (var k in extra) d[k] = extra[k];
        post({ type: 'loading', message: phase, data: d });
      }
      function isOffline() { return navigator && navigator.onLine === false; }
      function onceOnline(cb) {
        function h() { window.removeEventListener('online', h); cb(); }
        window.addEventListener('online', h);
      }

      function loadSdk() {
        if (widgetStarted) return;
        if (isOffline()) {
          loading('waiting-network', { attempt: scriptAttempt });
          onceOnline(loadSdk);
          return;
        }
        scriptAttempt++;
        loading('loading-sdk', { attempt: scriptAttempt });

        var s = document.createElement('script');
        // Cache-bust a partir da 2a tentativa: cobre o caso de um 0-byte /
        // resposta truncada ter sido cacheada pela WebView.
        s.src = SDK_URL + (scriptAttempt > 1 ? ('?r=' + Date.now()) : '');
        s.async = true;
        s.onload = function() { startWidget(s); };
        s.onerror = function() {
          try { s.remove(); } catch (e) {}
          if (scriptAttempt <= MAX_RETRIES) {
            var delay = Math.min(1000 * Math.pow(2, scriptAttempt - 1), 8000);
            loading('retrying-sdk', { attempt: scriptAttempt, next_ms: delay });
            setTimeout(loadSdk, delay);
          } else {
            post({
              type: 'error',
              message: 'Não foi possível carregar o VLibras. Verifique sua conexão e tente de novo.',
              data: { kind: 'sdk-load', attempts: scriptAttempt }
            });
          }
        };
        document.head.appendChild(s);
      }

      // Se esgotou as tentativas e a conexão volta depois, tenta de novo.
      window.addEventListener('online', function() {
        if (!widgetStarted && scriptAttempt > MAX_RETRIES) {
          scriptAttempt = 0;
          loadSdk();
        }
      });

      function startWidget(scriptEl) {
        if (widgetStarted) return;
        if (!window.VLibras || !window.VLibras.Widget) {
          // "load" disparou mas o corpo do script não veio inteiro — trata
          // como falha de rede e re-tenta.
          if (scriptEl && scriptEl.onerror) { scriptEl.onerror(); }
          return;
        }
        widgetStarted = true;
        loading('initializing-avatar');
        try {
          runVLibras();
        } catch (e) {
          post({ type: 'error', message: e.message, data: { kind: 'widget-init' } });
        }
      }

      function runVLibras() {
        // Initialise the VLibras Widget.  The Widget constructor sets window.onload
        // to register its internal click handler.  If the page's load event has
        // already fired (common with loadHtmlString in WebView), call it manually.
        new window.VLibras.Widget({
          rootPath: '$baseUrl',
          avatar: '$avatar',
        });

        // Hide controls injected after Unity loads (profile, help, menu, etc.).
        function suppressPluginUi() {
          var selectors = [
            $_pluginChromeHideSelectorsJs
          ];
          selectors.forEach(function(sel) {
            document.querySelectorAll(sel).forEach(function(el) {
              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('pointer-events', 'none', 'important');
              el.style.setProperty('opacity', '0', 'important');
            });
          });
          // Re-apply framing — VLibras may overwrite wrapper styles on load.
          var wrap = document.querySelector('[vw-plugin-wrapper]');
          if (wrap) {
            wrap.style.setProperty(
              'transform',
              'translateX(-50%) scale($_zoomStr)',
              'important'
            );
            wrap.style.setProperty('left', '50%', 'important');
            wrap.style.setProperty('top', '0', 'important');
            wrap.style.setProperty(
              'transform-origin',
              '${_originXStr}% ${_originYStr}%',
              'important'
            );
            wrap.style.setProperty('overflow', 'hidden', 'important');
          }
        }

        // Apply once immediately, then keep it applied reactively via a
        // MutationObserver instead of unconditionally re-running the
        // querySelectorAll sweep on every 250ms poll tick. Running that sweep
        // every tick — regardless of whether the DOM actually changed — used
        // to compete with Unity's synchronous boot burst for the same JS
        // thread, which was enough on low-end devices to trip the WebView's
        // "page unresponsive" watchdog. The observer only reacts when nodes
        // are actually inserted, and requestIdleCallback (with a setTimeout
        // fallback) defers the work instead of running it inline on the
        // mutation callback, so it never competes directly with Unity's boot.
        suppressPluginUi();

        var _suppressScheduled = false;
        function _scheduleSuppressPluginUi() {
          if (_suppressScheduled) return;
          _suppressScheduled = true;
          var run = function() {
            _suppressScheduled = false;
            suppressPluginUi();
          };
          if (window.requestIdleCallback) {
            window.requestIdleCallback(run, { timeout: 500 });
          } else {
            setTimeout(run, 0);
          }
        }

        var chromeObserver = new MutationObserver(function() {
          _scheduleSuppressPluginUi();
        });
        chromeObserver.observe(document.body, { childList: true, subtree: true });

        if (document.readyState === 'complete' && typeof window.onload === 'function') {
          window.onload();
        }

        var clicked   = false;
        var attempts  = 0;
        var stalledMs = 0;         // tempo sem progresso E online
        var lastSig   = '';        // "assinatura" de progresso do boot
        var netWaitAnnounced = false;

        var poll = setInterval(function() {
          attempts++;

          // Offline: não conta contra o orçamento — avisa uma vez e espera.
          if (isOffline()) {
            if (!netWaitAnnounced) {
              netWaitAnnounced = true;
              loading('waiting-network', { attempt: attempts });
            }
            return;
          }
          netWaitAnnounced = false;

          // Click the access button ONCE to open the panel and trigger
          // window.plugin = new VLibras.Plugin({...}).
          // The button is a toggle — clicking it a second time would CLOSE the
          // panel again, so we guard with the `clicked` flag.
          // We also wait until AccessButton.load() has run: before it runs the
          // button's innerHTML is empty; after it runs the button has child nodes.
          if (!clicked) {
            var btn = document.querySelector('[vw-access-button]');
            if (btn && btn.children.length > 0) {
              clicked = true;
              btn.click();
              console.log('[VLibras] btn.click() — opening panel');
            }
          }

          // window.plugin.player.loaded becomes true once Unity has finished
          // initialising inside the plugin.
          var p = window.plugin;
          if (p && p.player && p.player.loaded) {
            clearInterval(poll);
            chromeObserver.disconnect();
            console.log('[VLibras] plugin.player ready after ' + attempts + ' polls');
            setTimeout(function() {
              VLibrasChannel.postMessage(JSON.stringify({ type: 'ready' }));
            }, 500);
            return;
          }

          // Progresso do boot: mudança no DOM/plugin OU tráfego de rede
          // recente (download de WASM numa conexão lenta) zera o contador de
          // "travado" — o orçamento de timeout só corre quando está de fato
          // parado.
          var sig = '' + clicked +
            '|' + !!window.plugin +
            '|' + !!(p && p.player) +
            '|' + document.querySelectorAll('canvas').length;
          var netRecent =
            (Date.now() - (window.__vlibrasNetTick || 0)) < 8000;
          if (sig !== lastSig || netRecent) {
            lastSig = sig;
            stalledMs = 0;
          } else {
            stalledMs += POLL_MS;
          }

          if (attempts % 20 === 0) {
            console.log('[VLibras] poll #' + attempts + ' sig=' + sig +
              ' stalledMs=' + stalledMs);
          }

          // Só falha quando ficou REALMENTE travado (online, sem progresso
          // nenhum) por mais que o orçamento — não por lentidão de download.
          if (stalledMs > BOOT_BUDGET_MS) {
            clearInterval(poll);
            chromeObserver.disconnect();
            console.log('[VLibras] timeout (stalled ' + stalledMs + 'ms)');
            VLibrasChannel.postMessage(JSON.stringify({
              type: 'error',
              message: 'O VLibras demorou demais para iniciar. Tente novamente.',
              data: { kind: 'init-timeout', stalled_ms: stalledMs }
            }));
          }
        }, POLL_MS);
      }

      loadSdk();
    })();
  </script>
</body>
</html>
''';
}

