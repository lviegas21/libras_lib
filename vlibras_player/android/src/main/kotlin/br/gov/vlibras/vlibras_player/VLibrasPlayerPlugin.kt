package br.gov.vlibras.vlibras_player

import android.content.Context
import android.webkit.JavascriptInterface
import android.webkit.JsPromptResult
import android.webkit.JsResult
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Flutter plugin that wraps VLibras via a headless WebView. */
class VLibrasPlayerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null

    private var webView: WebView? = null
    private var context: Context? = null

    // ── FlutterPlugin ──────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "vlibras/methods")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "vlibras/events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                eventSink = sink
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        destroyWebView()
    }

    // ── MethodCallHandler ──────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                val avatar  = call.argument<String>("avatar")  ?: "icaro"
                val speed   = call.argument<Double>("speed")   ?: 1.0
                val autoPlay = call.argument<Boolean>("autoPlay") ?: false
                val baseUrl = call.argument<String>("baseUrl") ?: "https://vlibras.gov.br/app"
                initialize(baseUrl, avatar, speed, autoPlay, result)
            }
            "translate" -> {
                val text = call.argument<String>("text") ?: ""
                translate(text, result)
            }
            "show"    -> { setVisible(true);  result.success(null) }
            "hide"    -> { setVisible(false); result.success(null) }
            "dispose" -> { destroyWebView();  result.success(null) }
            else      -> result.notImplemented()
        }
    }

    // ── Private helpers ────────────────────────────────────────────────────────

    private fun initialize(
        baseUrl: String,
        avatar: String,
        speed: Double,
        autoPlay: Boolean,
        result: Result,
    ) {
        destroyWebView()
        val ctx = context ?: run { result.error("NO_CONTEXT", "Context not available", null); return }

        val wv = WebView(ctx).also { webView = it }

        wv.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_DEFAULT
            // NEVER_ALLOW (não ALWAYS_ALLOW): a página é servida via HTTPS
            // (vlibras.gov.br); não há motivo para permitir sub-recursos HTTP
            // misturados, e ALWAYS_ALLOW é uma superfície de risco desnecessária.
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
        // WebChromeClient customizado: a classe padrão (sem overrides) mostra
        // diálogos NATIVOS do Android para window.alert()/confirm()/prompt() —
        // texto de JS cru, por cima de todo o app, bloqueando a thread principal
        // até o usuário tocar OK. Este WebView é headless/embutido: nenhum
        // diálogo de JS deve escapar para a UI do sistema.
        wv.webChromeClient = object : WebChromeClient() {
            override fun onJsAlert(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?,
            ): Boolean {
                result?.confirm()
                return true
            }

            override fun onJsConfirm(
                view: WebView?,
                url: String?,
                message: String?,
                result: JsResult?,
            ): Boolean {
                result?.confirm()
                return true
            }

            override fun onJsPrompt(
                view: WebView?,
                url: String?,
                message: String?,
                defaultValue: String?,
                result: JsPromptResult?,
            ): Boolean {
                result?.cancel()
                return true
            }
        }
        wv.addJavascriptInterface(
            VLibrasJsInterface(
                onReady           = { emitEvent("ready") },
                onTranslateComplete = { emitEvent("translateComplete") },
                onError           = { msg -> emitEvent("error", message = msg) },
            ),
            "VLibrasFlutter",
        )

        wv.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                // Inject VLibras plugin script and bootstrap
                val js = """
                    (function() {
                        var script = document.createElement('script');
                        script.src = '$baseUrl/vlibras-plugin.js';
                        script.onload = function() {
                            new window.VLibras.Widget('$baseUrl');
                            var player = document.querySelector('[vw] .active');
                            VLibrasFlutter.onReady();
                        };
                        script.onerror = function(e) {
                            VLibrasFlutter.onError('Failed to load vlibras-plugin.js');
                        };
                        document.head.appendChild(script);
                    })();
                """.trimIndent()
                view?.evaluateJavascript(js, null)
            }
        }

        // Load a minimal HTML host page
        wv.loadDataWithBaseURL(
            "https://vlibras.gov.br",
            buildHostHtml(avatar, speed, autoPlay),
            "text/html",
            "utf-8",
            null,
        )

        result.success(null)
    }

    private fun translate(text: String, result: Result) {
        val wv = webView ?: run {
            result.error("NOT_INITIALIZED", "Call initialize() first", null)
            return
        }
        val escaped = text.replace("'", "\\'").replace("\n", "\\n")
        wv.evaluateJavascript(
            "if(window.__vlibrasPlayer) window.__vlibrasPlayer.translate('$escaped');",
            null,
        )
        result.success(null)
    }

    private fun setVisible(visible: Boolean) {
        webView?.visibility = if (visible)
            android.view.View.VISIBLE
        else
            android.view.View.INVISIBLE
        emitEvent(if (visible) "shown" else "hidden")
    }

    private fun destroyWebView() {
        webView?.destroy()
        webView = null
    }

    private fun emitEvent(type: String, message: String? = null) {
        val payload = mutableMapOf<String, Any?>("type" to type)
        if (message != null) payload["message"] = message
        // Must be called on the main thread
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }

    private fun buildHostHtml(avatar: String, speed: Double, autoPlay: Boolean): String = """
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
          <meta charset="UTF-8"/>
          <meta name="viewport" content="width=device-width,initial-scale=1"/>
          <style>
            html, body { margin:0; padding:0; background:transparent; overflow:hidden; }
            [vw] { position:fixed; bottom:0; right:0; width:100%; height:100%; }
            [vw] .active { display:flex!important; }
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
        </body>
        </html>
    """.trimIndent()
}

/** JavaScript → Kotlin bridge. All methods are called from the WebView JS thread. */
class VLibrasJsInterface(
    private val onReady: () -> Unit,
    private val onTranslateComplete: () -> Unit,
    private val onError: (String) -> Unit,
) {
    @JavascriptInterface
    fun onReady() = onReady.invoke()

    @JavascriptInterface
    fun onTranslateComplete() = onTranslateComplete.invoke()

    @JavascriptInterface
    fun onError(message: String) = onError.invoke(message)
}
