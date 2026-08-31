/// Assinatura de um sink de erros que o app hospedeiro pode injetar para
/// capturar **toda** falha do VLibras (WebView, script JS, canal nativo,
/// parse de evento) — inclusive as que o plugin trata internamente e antes
/// só chegavam via `onError`/`eventStream` ou eram engolidas.
///
/// O plugin **não** depende de Firebase/Crashlytics: o app liga o que quiser
/// (Crashlytics, Sentry, log). Default: [debugPrintLibrasError].
typedef LibrasErrorReporter = void Function(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, Object?>? context,
});

/// Reporter padrão — só imprime no console em debug.
void debugPrintLibrasError(
  Object error,
  StackTrace? stack, {
  String? reason,
  Map<String, Object?>? context,
}) {
  assert(() {
    // ignore: avoid_print
    print('[vlibras_player] ${reason ?? "erro"}: $error'
        '${context != null ? " $context" : ""}');
    return true;
  }());
}
