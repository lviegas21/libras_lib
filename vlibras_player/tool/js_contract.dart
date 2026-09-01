/// Executa o JavaScript gerado por `buildVLibrasHtml()` num harness Node, com
/// o `<iframe>` do player e o canal do Dart mockados.
///
/// ```sh
/// dart run tool/js_contract.dart            # pula se não houver Node
/// dart run tool/js_contract.dart --strict   # falha se não houver Node (CI)
/// ```
///
/// Complementa o `flutter test`: lá só dá para afirmar que certas strings estão
/// no HTML; aqui a lógica roda de verdade. Ver `test/js/harness.js`.
library;

import 'dart:io';

import 'package:vlibras_player/src/vlibras_html.dart';

Future<void> main(List<String> args) async {
  final strict = args.contains('--strict');

  final page = buildVLibrasHtml(
    baseUrl: kVLibrasPortalBaseUrl,
    avatar: 'icaro',
    speed: 1.0,
    autoPlay: false,
    playerWidth: 144,
    playerHeight: 200,
    naturalHeight: 444.44,
    contentZoom: 2.2222,
  );

  final dir = Directory.systemTemp.createTempSync('vlibras_js_contract');
  final file = File('${dir.path}/page.html')..writeAsStringSync(page);

  try {
    final harness = File('test/js/harness.js');
    if (!harness.existsSync()) {
      stderr.writeln('test/js/harness.js não encontrado — rode a partir da '
          'raiz do pacote vlibras_player.');
      exit(2);
    }

    final ProcessResult result;
    try {
      result = Process.runSync('node', [harness.path, file.path]);
    } on ProcessException {
      final msg = 'Node não encontrado — harness do contrato JS não executado.';
      if (strict) {
        stderr.writeln('$msg (--strict)');
        exit(2);
      }
      stdout.writeln('SKIP: $msg');
      return;
    }

    stdout.write(result.stdout);
    stderr.write(result.stderr);
    exit(result.exitCode);
  } finally {
    dir.deleteSync(recursive: true);
  }
}
