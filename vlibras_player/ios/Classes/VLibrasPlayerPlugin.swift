import Flutter
import UIKit
import WebKit

/// Flutter plugin that wraps VLibras via a WKWebView (iOS side).
public class VLibrasPlayerPlugin: NSObject, FlutterPlugin {

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(
            name: "vlibras/methods",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "vlibras/events",
            binaryMessenger: registrar.messenger()
        )

        let instance = VLibrasPlayerPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - Private state

    private var webView: WKWebView?
    private var eventSink: FlutterEventSink?

    // MARK: - FlutterMethodCallDelegate

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "initialize":
            let avatar   = args?["avatar"]   as? String  ?? "icaro"
            let speed    = args?["speed"]    as? Double  ?? 1.0
            let autoPlay = args?["autoPlay"] as? Bool    ?? false
            let baseUrl  = args?["baseUrl"]  as? String  ?? "https://vlibras.gov.br/app"
            initialize(baseUrl: baseUrl, avatar: avatar, speed: speed, autoPlay: autoPlay, result: result)

        case "translate":
            let text = args?["text"] as? String ?? ""
            translate(text: text, result: result)

        case "show":
            setVisible(true)
            result(nil)

        case "hide":
            setVisible(false)
            result(nil)

        case "dispose":
            destroyWebView()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Private helpers

    private func initialize(
        baseUrl: String,
        avatar: String,
        speed: Double,
        autoPlay: Bool,
        result: @escaping FlutterResult
    ) {
        destroyWebView()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()
        // Receive messages from JavaScript
        contentController.add(self, name: "vlibrasReady")
        contentController.add(self, name: "vlibrasTranslateComplete")
        contentController.add(self, name: "vlibrasError")
        config.userContentController = contentController

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isHidden = false
        wv.navigationDelegate = self
        wv.scrollView.isScrollEnabled = false
        self.webView = wv

        let html = buildHostHtml(baseUrl: baseUrl, avatar: avatar, speed: speed, autoPlay: autoPlay)
        wv.loadHTMLString(html, baseURL: URL(string: "https://vlibras.gov.br"))

        result(nil)
    }

    private func translate(text: String, result: @escaping FlutterResult) {
        guard let wv = webView else {
            result(FlutterError(code: "NOT_INITIALIZED",
                                message: "Call initialize() first",
                                details: nil))
            return
        }
        let escaped = text
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        let js = "if(window.__vlibrasPlayer) window.__vlibrasPlayer.translate('\(escaped)');"
        wv.evaluateJavaScript(js, completionHandler: nil)
        result(nil)
    }

    private func setVisible(_ visible: Bool) {
        webView?.isHidden = !visible
        emitEvent(type: visible ? "shown" : "hidden")
    }

    private func destroyWebView() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView = nil
    }

    private func emitEvent(type: String, message: String? = nil) {
        var payload: [String: Any] = ["type": type]
        if let msg = message { payload["message"] = msg }
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }

    private func buildHostHtml(
        baseUrl: String,
        avatar: String,
        speed: Double,
        autoPlay: Bool
    ) -> String {
        return """
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
            window.__vlibrasConfig = { avatar: '\(avatar)', speed: \(speed), autoPlay: \(autoPlay) };

            (function() {
              var s = document.createElement('script');
              s.src = '\(baseUrl)/vlibras-plugin.js';
              s.onload = function() {
                new window.VLibras.Widget('\(baseUrl)');
                window.webkit.messageHandlers.vlibrasReady.postMessage({});
              };
              s.onerror = function() {
                window.webkit.messageHandlers.vlibrasError
                  .postMessage({ message: 'Failed to load vlibras-plugin.js' });
              };
              document.head.appendChild(s);
            })();
          </script>
        </body>
        </html>
        """
    }
}

// MARK: - WKScriptMessageHandler

extension VLibrasPlayerPlugin: WKScriptMessageHandler {
    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "vlibrasReady":
            emitEvent(type: "ready")
        case "vlibrasTranslateComplete":
            emitEvent(type: "translateComplete")
        case "vlibrasError":
            let body = message.body as? [String: Any]
            emitEvent(type: "error", message: body?["message"] as? String ?? "Unknown error")
        default:
            break
        }
    }
}

// MARK: - WKNavigationDelegate

extension VLibrasPlayerPlugin: WKNavigationDelegate {}

// MARK: - FlutterStreamHandler

extension VLibrasPlayerPlugin: FlutterStreamHandler {
    public func onListen(
        withArguments arguments: Any?,
        eventSink events: @escaping FlutterEventSink
    ) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
