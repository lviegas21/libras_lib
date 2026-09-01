/// Canário do contrato com a infraestrutura do VLibras.
///
/// Verifica, contra os serviços reais, tudo de que este plugin depende — e
/// avisa quando o portal publica uma versão nova do player. Serve para
/// descobrir uma quebra **antes** dos usuários: foi exatamente uma migração
/// silenciosa (6.x → 7.x) que derrubou a integração anterior.
///
/// ```sh
/// dart run tool/check_vlibras_contract.dart
/// dart run tool/check_vlibras_contract.dart --base=https://vlibras.gov.br/app
/// ```
///
/// Sai com código 1 se algum contrato quebrou. A diferença de versão entre o
/// player fixado e o publicado no portal é **aviso**, não falha.
library;

import 'dart:convert';
import 'dart:io';

import 'package:vlibras_player/src/vlibras_html.dart';
import 'package:vlibras_player/src/vlibras_translation_service.dart';

const _portalPluginUrl = '$kVLibrasPortalBaseUrl/vlibras-plugin.js';

/// Sinal do dicionário usado para provar que os bundles ainda respondem.
const _probeSign = 'OI';

final _failures = <String>[];
final _warnings = <String>[];

Future<void> main(List<String> args) async {
  final base = _arg(args, '--base') ?? kVLibrasPortalBaseUrl;
  final dictionary = _arg(args, '--dictionary') ?? kVLibrasDictionaryUrl;
  final translate = _arg(args, '--translate') ?? kVLibrasTranslateUrl;

  stdout.writeln('Contrato VLibras — player: $base');
  stdout.writeln('');

  await _checkPlayerPage(base);
  await _checkPlayerBridge(base);
  await _checkPlayerAssets(base);
  await _checkDictionary(dictionary);
  await _checkTranslate(translate);
  await _checkPublishedVersion();

  stdout.writeln('');
  for (final w in _warnings) {
    stdout.writeln('AVISO  $w');
  }
  if (_failures.isEmpty) {
    stdout.writeln('OK — todos os contratos externos continuam de pé.');
    exit(0);
  }
  stdout.writeln('${_failures.length} CONTRATO(S) QUEBRADO(S):');
  for (final f in _failures) {
    stdout.writeln('  - $f');
  }
  stdout.writeln('');
  stdout.writeln('Ver lib/src/vlibras_html.dart (protocolo do player) e '
      'lib/src/vlibras_translation_service.dart (texto → glosa).');
  exit(1);
}

// ---------------------------------------------------------------------------

Future<void> _checkPlayerPage(String base) async {
  final r = await _get('$base/unity/index.html');
  _expect(
    'página do player responde',
    r.status == 200,
    detail: 'HTTP ${r.status}',
  );
  _expect(
    'página do player carrega o loader e o glue',
    r.body.contains('unity-loader.js') && r.body.contains('index.js'),
  );
  _expect(
    'página do player tem o #gameContainer',
    r.body.contains('gameContainer'),
  );
  // O jsDelivr serve .html como text/plain + nosniff: o navegador mostra a
  // página como texto, nenhum script roda e o player nunca inicializa. Foi
  // exatamente assim que uma tentativa de fixar a versão apontando o baseUrl
  // para o CDN falhou — esta checagem pega isso na hora.
  _expect(
    'página do player servida como text/html',
    r.contentType.contains('text/html'),
    detail: 'Content-Type: ${r.contentType}',
  );
}

/// O contrato de verdade: o `index.js` do iframe traduz `postMessage` em
/// `SendMessage` do Unity e devolve os eventos que consumimos.
Future<void> _checkPlayerBridge(String base) async {
  final r = await _get('$base/unity/index.js');
  if (!_expect('glue do player responde', r.status == 200,
      detail: 'HTTP ${r.status}')) {
    return;
  }
  final js = r.body;

  _expect('glue aceita comandos {type:"unity"}',
      _hasToken(js, 'unity') && js.contains('SendMessage'));
  _expect('glue publica eventos {type:"unity_event"}', _hasToken(js, 'unity_event'));

  // Os eventos que a nossa página escuta.
  for (final event in const [
    'on_load_player',
    'update_progress',
    'on_playing_state_change',
    'counter_gloss',
    'finish_welcome',
    'on_error',
  ]) {
    _expect('glue emite $event', _hasToken(js, event));
  }
}

Future<void> _checkPlayerAssets(String base) async {
  final r = await _get('$base/unity/playerweb.json');
  if (!_expect('manifesto do Unity responde', r.status == 200,
      detail: 'HTTP ${r.status}')) {
    return;
  }

  Map<String, dynamic> manifest;
  try {
    manifest = jsonDecode(r.body) as Map<String, dynamic>;
  } catch (e) {
    _expect('manifesto do Unity é JSON', false, detail: '$e');
    return;
  }

  for (final key in const ['dataUrl', 'wasmCodeUrl', 'wasmFrameworkUrl']) {
    final value = manifest[key];
    if (value is! String || value.isEmpty) {
      _expect('manifesto declara $key', false);
      continue;
    }
    final head = await _head('$base/unity/$value');
    _expect(
      'asset $key disponível',
      head.status == 200,
      detail: 'HTTP ${head.status} em $value',
    );
  }
}

Future<void> _checkDictionary(String dictionary) async {
  final r = await _get('$dictionary$_probeSign');
  _expect(
    'bundle de sinal "$_probeSign" disponível',
    r.status == 200 && r.bytes > 0,
    detail: 'HTTP ${r.status}, ${r.bytes} bytes',
  );
}

/// Usa o mesmo serviço que o app usa em produção — se o formato mudar
/// (`{"text": ...}` → glosa em texto), quebra aqui.
Future<void> _checkTranslate(String translate) async {
  final service = VLibrasTranslationService(endpoint: translate);
  try {
    String gloss;
    try {
      gloss = await service.toGloss('bom dia');
    } on VLibrasTranslationException {
      await Future<void>.delayed(const Duration(seconds: 2));
      service.clearCache();
      gloss = await service.toGloss('bom dia');
    }
    _expect('tradução devolve glosa', gloss.isNotEmpty, detail: gloss);
    _expect(
      'glosa vem em caixa alta (formato esperado pelo player)',
      gloss == gloss.toUpperCase(),
      detail: gloss,
    );
    stdout.writeln('       "bom dia" -> "$gloss"');
  } on VLibrasTranslationException catch (e) {
    _expect('tradução devolve glosa', false, detail: '$e');
  }
}

/// Aviso quando o portal já publica uma versão diferente da que fixamos: é o
/// gatilho para testar e atualizar o pin com calma, em vez de descobrir na
/// mão do usuário.
Future<void> _checkPublishedVersion() async {
  final r = await _get(_portalPluginUrl);
  if (r.status != 200) {
    _warnings.add('não deu para ler a versão publicada no portal '
        '(HTTP ${r.status} em $_portalPluginUrl)');
    return;
  }
  final match = RegExp(r'vlibras-plugin-app\.js\?v=([0-9]+\.[0-9]+\.[0-9]+)')
      .firstMatch(r.body);
  if (match == null) {
    _warnings.add('o portal mudou de formato: não achei a versão em '
        '$_portalPluginUrl — pode ser uma migração grande, vale olhar.');
    return;
  }
  final published = match.group(1)!;
  stdout.writeln('  ..   portal publica $published; fixamos '
      '$kVLibrasPlayerVersion');
  if (published != kVLibrasPlayerVersion) {
    _warnings.add('portal já está em $published (fixamos '
        '$kVLibrasPlayerVersion). Teste e atualize '
        'kVLibrasPlayerVersion / kVLibrasPinnedPlayerAssetsUrl.');
  }
}

// ---------------------------------------------------------------------------

bool _expect(String name, bool ok, {String? detail}) {
  stdout.writeln('  ${ok ? 'ok  ' : 'FALHA'} $name'
      '${detail != null && !ok ? ' -> $detail' : ''}');
  if (!ok) _failures.add(name + (detail != null ? ' ($detail)' : ''));
  return ok;
}

/// Casa a palavra tanto em `'x'`, `"x"` quanto em crase (o bundle minificado
/// do VLibras usa template literals).
bool _hasToken(String source, String token) =>
    source.contains("'$token'") ||
    source.contains('"$token"') ||
    source.contains('`$token`');

class _Response {
  const _Response(this.status, this.body, this.bytes, this.contentType);
  final int status;
  final String body;
  final int bytes;
  final String contentType;
}

Future<_Response> _get(String url) => _retry('GET', url);
Future<_Response> _head(String url) => _retry('HEAD', url);

/// Soluço de rede não é contrato quebrado: um canário que dá alarme falso vira
/// ruído e para de ser levado a sério. Só falha de verdade depois de insistir.
Future<_Response> _retry(String method, String url) async {
  _Response last = const _Response(-1, 'sem tentativa', 0, '');
  for (var attempt = 1; attempt <= 3; attempt++) {
    last = await _request(method, url);
    final transient = last.status < 0 || last.status >= 500;
    if (!transient) return last;
    if (attempt < 3) {
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    }
  }
  return last;
}

Future<_Response> _request(String method, String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.followRedirects = true;
    final response = await request.close().timeout(const Duration(seconds: 30));
    final bytes = await response
        .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
    return _Response(
      response.statusCode,
      method == 'HEAD' ? '' : utf8.decode(bytes, allowMalformed: true),
      method == 'HEAD' ? (response.contentLength) : bytes.length,
      response.headers.contentType?.toString() ?? '',
    );
  } catch (e) {
    return _Response(-1, 'erro de rede: $e', 0, '');
  } finally {
    client.close(force: true);
  }
}

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('$name=')) return a.substring(name.length + 1);
  }
  return null;
}
