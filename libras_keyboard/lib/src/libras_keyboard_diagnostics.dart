/// Sink de diagnóstico que o app hospedeiro pode injetar para receber falhas
/// não-fatais do teclado de Libras — hoje: asset PNG de sinal de mão ausente
/// ou corrompido (o teclado degrada para o rótulo textual, mas queremos saber
/// em produção).
///
/// O pacote não depende de Firebase: o app liga o que quiser.
typedef LibrasKeyboardErrorReporter = void Function(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, Object?>? context,
});

/// Ponto de configuração global.
class LibrasKeyboardDiagnostics {
  LibrasKeyboardDiagnostics._();

  static LibrasKeyboardErrorReporter? reporter;

  static final Set<String> _reportedOnce = {};

  /// Reporta uma única vez por [dedupeKey] (evita floodar com o mesmo asset
  /// faltando a cada rebuild).
  static void reportOnce(
    String dedupeKey,
    Object error,
    StackTrace? stack, {
    String? reason,
    Map<String, Object?>? context,
  }) {
    if (reporter == null || !_reportedOnce.add(dedupeKey)) return;
    try {
      reporter!(error, stack, reason: reason, context: context);
    } catch (_) {}
  }
}
