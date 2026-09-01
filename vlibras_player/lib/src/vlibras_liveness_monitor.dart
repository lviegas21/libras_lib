import 'dart:async';

/// Avalia JS no WebView e devolve o resultado (o `runJavaScriptReturningResult`
/// do controller, em forma injetável para teste).
typedef VLibrasJsEvaluator = Future<Object?> Function(String js);

/// Vigia se a página do player continua viva dentro do WebView.
///
/// O renderer do WebView roda **em outro processo**, e o Android o mata sob
/// pressão de memória — coisa provável quando se mantém o player carregado
/// (~600 MB) e o usuário vai usar outros apps. Quando isso acontece a página
/// some: o avatar volta em branco e nada percebe, porque do lado Dart o player
/// já estava marcado como pronto e o watchdog de boot já se desarmou.
///
/// O vigia faz um `ping` barato de tempos em tempos (uma expressão JS a cada
/// [interval]) e avisa por [onLost] quando a página não responde
/// [failuresBeforeLost] vezes seguidas — aí quem usa recria o WebView. Exige
/// mais de uma falha porque um `runJavaScript` pode falhar de forma
/// passageira, e recriar custa ~12 s de boot do Unity.
class VLibrasLivenessMonitor {
  VLibrasLivenessMonitor({
    required VLibrasJsEvaluator evaluate,
    required void Function() onLost,
    this.interval = const Duration(seconds: 30),
    this.failuresBeforeLost = 2,
  })  : assert(failuresBeforeLost >= 1),
        _evaluate = evaluate,
        _onLost = onLost;

  /// Marca que a página define assim que carrega.
  static const String aliveExpression = 'window.__vlibrasAlive === true';

  final VLibrasJsEvaluator _evaluate;
  final void Function() _onLost;
  final Duration interval;
  final int failuresBeforeLost;

  Timer? _timer;
  bool _checking = false;
  bool _disposed = false;
  bool _lost = false;
  int _failures = 0;

  bool get isRunning => _timer != null;

  /// Falhas seguidas até agora (visível para teste/diagnóstico).
  int get consecutiveFailures => _failures;

  void start() {
    if (_disposed || _timer != null) return;
    _failures = 0;
    _lost = false;   // quem reinicia é quem recriou o WebView
    _timer = Timer.periodic(interval, (_) => checkNow());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _failures = 0;
  }

  /// Faz um ping agora. Ignorado se já houver um em andamento ou se a perda
  /// já foi avisada — quem recria o WebView chama [start] de novo.
  Future<void> checkNow() async {
    if (_disposed || _checking || _lost) return;
    _checking = true;
    try {
      final result = await _evaluate(aliveExpression);
      if (_isAlive(result)) {
        _failures = 0;
        return;
      }
      _registerFailure();
    } catch (_) {
      // WebView destruído, renderer morto ou JS inacessível: conta como falha.
      _registerFailure();
    } finally {
      _checking = false;
    }
  }

  void _registerFailure() {
    _failures++;
    if (_failures < failuresBeforeLost || _disposed) return;
    _lost = true;   // avisa uma vez só por ciclo de vida do WebView
    stop();
    _onLost();
  }

  /// Cada plataforma devolve o booleano de um jeito (`true`, `'true'`, `1`).
  static bool _isAlive(Object? result) {
    if (result is bool) return result;
    if (result is num) return result == 1;
    if (result is String) return result == 'true' || result == '1';
    return false;
  }

  void dispose() {
    _disposed = true;
    stop();
  }
}
