/// Returns a JavaScript snippet injected into the live VLibras page after load.
///
/// This is used when the WebView navigates directly to `baseUrl/app` instead
/// of loading a custom HTML string.  The script:
/// - Strips CORS-problematic request headers (same as the HTML version)
/// - Injects CSS overrides (hide the access button chrome)
/// - Registers [window.__vlibrasTranslate] for Dart to call
/// - Polls until the VLibras player element appears, then signals ready
String buildVLibrasInitScript() {
  return r'''
(function() {
  // ── CORS header interceptor ──────────────────────────────────────────────
  var _blocked = /^(if-none-match|if-modified-since|cache-control|pragma)$/i;
  var _origSRH = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
    if (_blocked.test(name)) return;
    return _origSRH.call(this, name, value);
  };
  var _origFetch = window.fetch;
  if (_origFetch) {
    window.fetch = function(url, init) {
      if (init && init.headers) {
        var h = init.headers;
        var keys = ['if-none-match','If-None-Match','if-modified-since','If-Modified-Since',
                    'cache-control','Cache-Control','pragma','Pragma'];
        if (h instanceof Headers) keys.forEach(function(k){h.delete(k);});
        else if (h && typeof h==='object') keys.forEach(function(k){delete h[k];});
      }
      return _origFetch.call(this, url, init);
    };
  }

  // ── CSS overrides ────────────────────────────────────────────────────────
  var s = document.createElement('style');
  s.textContent =
    '* { margin:0; padding:0; box-sizing:border-box; }' +
    'html,body { width:100%; height:100%; background:black; overflow:hidden; }' +
    '[vw-access-button] { opacity:0 !important; pointer-events:none !important; }';
  document.head.appendChild(s);

  // ── Translate API ────────────────────────────────────────────────────────
  window.__vlibrasTranslate = function(text) {
    try {
      var p = window.plugin;
      if (p && p.player && typeof p.player.translate === 'function') {
        console.log('[VLibras] translate via window.plugin.player.translate');
        p.player.translate(text);
        VLibrasChannel.postMessage(JSON.stringify({type:'translateComplete'}));
        return;
      }
      console.log('[VLibras] plugin not ready — plugin=' + !!window.plugin +
        ' player=' + !!(p && p.player) +
        ' loaded=' + !!(p && p.player && p.player.loaded));
      VLibrasChannel.postMessage(JSON.stringify({type:'error', message:'plugin not ready'}));
    } catch(e) {
      console.log('[VLibras] translate error: ' + e.message);
      VLibrasChannel.postMessage(JSON.stringify({type:'error', message:e.message}));
    }
  };

  // ── Poll: wait for window.plugin.player.loaded ───────────────────────────
  var clicked  = false;
  var attempts = 0;
  var poll = setInterval(function() {
    attempts++;

    // Open the panel once (single click — it is a toggle)
    if (!clicked) {
      var btn = document.querySelector('[vw-access-button]');
      if (btn && btn.children.length > 0) {
        clicked = true;
        btn.click();
        console.log('[VLibras] btn.click() — opening panel');
      }
    }

    var p = window.plugin;
    if (p && p.player && p.player.loaded) {
      clearInterval(poll);
      console.log('[VLibras] plugin.player ready after ' + attempts + ' polls');
      setTimeout(function() {
        VLibrasChannel.postMessage(JSON.stringify({type:'ready'}));
      }, 500);
      return;
    }

    if (attempts % 20 === 0) {
      console.log('[VLibras] poll #' + attempts +
        ' clicked=' + clicked +
        ' plugin=' + !!window.plugin +
        ' player=' + !!(p && p.player) +
        ' loaded=' + !!(p && p.player && p.player.loaded) +
        ' canvases=' + document.querySelectorAll('canvas').length);
    }

    if (attempts > 240) {
      clearInterval(poll);
      console.log('[VLibras] timeout');
      VLibrasChannel.postMessage(JSON.stringify({type:'ready'}));
    }
  }, 250);
})();
''';
}

// ─────────────────────────────────────────────────────────────────────────────

/// Builds the HTML page that hosts the VLibras widget inside a WebView.
///
/// Scaling strategy — `initial-scale` viewport:
///   VLibras renders its signing avatar in a panel whose height equals
///   `window.innerHeight`.  By setting
///     `initial-scale = playerHeight / naturalHeight`
///   the browser's CSS viewport height equals [naturalHeight] even though the
///   physical WebView is only [playerHeight] px tall.  VLibras renders the
///   avatar in [naturalHeight] CSS px; the browser scales the result down to
///   [playerHeight] physical px automatically.  No JS transform is needed.
///
/// [playerHeight] — Flutter widget height in logical pixels.
/// [naturalHeight] — virtual canvas height the VLibras Unity scene renders at.
///   Lower values zoom in (avatar fills more of the widget, less black margin).
///   Higher values zoom out (avatar appears smaller with more scene context).
///   Typical useful range: 300 – 700.  Default: 500.
/// [playerWidth] — unused for scaling; kept for API compatibility.
String buildVLibrasHtml({
  required String baseUrl,
  required String avatar,
  required double speed,
  required bool autoPlay,
  double? playerWidth,
  double? playerHeight,
  double naturalHeight = 500.0,
}) {
  // initial-scale = widget_height / naturalHeight
  // window.innerHeight = physical_height / initial-scale = naturalHeight
  // VLibras sizes its panel to window.innerHeight → renders at naturalHeight px.
  // The browser scales that down to physical_height automatically.
  final double _initScale =
      (playerHeight != null && playerHeight > 0) ? playerHeight / naturalHeight : 1.0;
  final String _initScaleStr = _initScale.toStringAsFixed(4);

  return '''
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=320,initial-scale=$_initScaleStr,user-scalable=no"/>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body {
      width: 100%;
      height: 100%;
      background: white;
      overflow: hidden;
    }

    /* Hide the circular access button — opened programmatically */
    [vw-access-button] {
      opacity: 0 !important;
      pointer-events: none !important;
    }

    /* Hide native plugin chrome (profile, help, menu, skip, top bar).
       Translation and skip are driven from Flutter via JS bridges. */
    .vw-plugin-top-wrapper,
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
    [vw-plugin-wrapper] button,
    [vw-plugin-wrapper] a[href] {
      display: none !important;
      pointer-events: none !important;
      opacity: 0 !important;
    }

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

      var _origSRH = XMLHttpRequest.prototype.setRequestHeader;
      XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
        if (_blocked.test(name)) return;
        return _origSRH.call(this, name, value);
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
          return _origFetch.call(this, url, init);
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

  <script
    src="$baseUrl/vlibras-plugin.js"
    onerror="VLibrasChannel.postMessage(JSON.stringify({type:'error',message:'Falha ao carregar vlibras-plugin.js'}))">
  </script>

  <script>
    (function() {
      try {
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
            '.vw-plugin-top-wrapper',
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
            '[vw-plugin-wrapper] [class*="AvatarSelect"]'
          ];
          selectors.forEach(function(sel) {
            document.querySelectorAll(sel).forEach(function(el) {
              el.style.setProperty('display', 'none', 'important');
              el.style.setProperty('pointer-events', 'none', 'important');
              el.style.setProperty('opacity', '0', 'important');
            });
          });
        }

        if (document.readyState === 'complete' && typeof window.onload === 'function') {
          window.onload();
        }

        var clicked  = false;
        var attempts = 0;

        var poll = setInterval(function() {
          attempts++;
          suppressPluginUi();

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
            console.log('[VLibras] plugin.player ready after ' + attempts + ' polls');
            setTimeout(function() {
              VLibrasChannel.postMessage(JSON.stringify({ type: 'ready' }));
            }, 500);
            return;
          }

          if (attempts % 20 === 0) {
            console.log('[VLibras] poll #' + attempts +
              ' clicked=' + clicked +
              ' plugin=' + !!window.plugin +
              ' player=' + !!(p && p.player) +
              ' loaded=' + !!(p && p.player && p.player.loaded) +
              ' canvases=' + document.querySelectorAll('canvas').length);
          }

          if (attempts > 240) {
            clearInterval(poll);
            console.log('[VLibras] timeout');
            VLibrasChannel.postMessage(JSON.stringify({ type: 'ready' }));
          }
        }, 250);

      } catch(e) {
        VLibrasChannel.postMessage(JSON.stringify({ type: 'error', message: e.message }));
      }
    })();
  </script>
</body>
</html>
''';
}

