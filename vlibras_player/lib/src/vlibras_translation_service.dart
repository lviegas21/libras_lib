import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'vlibras_html.dart' show kVLibrasTranslateUrl;

/// Converte português em **glosa** — a notação que o player Unity do VLibras
/// toca (`playNow`). Ex.: `"Olá, bom dia"` → `"OL BOM_DIA [PONTO]"`.
///
/// Fica no Dart, e não em `fetch` dentro da WebView, de propósito: a página do
/// player é carregada via `loadDataWithBaseURL`/`loadHTMLString`, cuja origem é
/// tratada de forma especial pelo WebView — requisição cross-origin de lá é
/// terreno de CORS com origem opaca, difícil de diagnosticar e diferente entre
/// Android e iOS. Pelo `HttpClient` não existe CORS, o status HTTP chega
/// inteiro no erro e dá para testar sem WebView.
typedef VLibrasGlossFetcher = Future<String> Function(Uri endpoint, String text);

/// Falha ao converter texto em glosa.
class VLibrasTranslationException implements Exception {
  const VLibrasTranslationException(this.kind, this.message, {this.statusCode});

  /// `http` | `timeout` | `empty` | `network`
  final String kind;
  final String message;
  final int? statusCode;

  /// Mensagem pronta para mostrar ao usuário.
  String get userMessage => switch (kind) {
        'timeout' => 'A tradução para Libras demorou demais. Tente de novo.',
        'empty' => 'Não foi possível traduzir este texto para Libras.',
        _ => 'Falha ao traduzir para Libras. Verifique sua conexão.',
      };

  @override
  String toString() =>
      'VLibrasTranslationException($kind${statusCode != null ? ' $statusCode' : ''}: $message)';
}

class VLibrasTranslationService {
  VLibrasTranslationService({
    this.endpoint = kVLibrasTranslateUrl,
    this.timeout = const Duration(seconds: 10),
    VLibrasGlossFetcher? fetcher,
    this.cacheSize = 40,
  }) : _fetch = fetcher ?? _httpFetch;

  /// Serviço de tradução (`POST {"text": "..."}` → glosa em texto puro).
  final String endpoint;

  /// Teto por requisição — o mesmo que o widget oficial usa.
  final Duration timeout;

  /// Quantas glosas ficam em cache. Repetir a mesma frase (bem comum num
  /// teclado ou numa lista de mensagens) não refaz o POST.
  final int cacheSize;

  final VLibrasGlossFetcher _fetch;
  final _cache = <String, String>{};   // LinkedHashMap: ordem = LRU

  /// Traduz [text], usando cache quando possível.
  ///
  /// Lança [VLibrasTranslationException] em qualquer falha.
  Future<String> toGloss(String text) async {
    final key = text.trim();
    if (key.isEmpty) {
      throw const VLibrasTranslationException('empty', 'texto vazio');
    }

    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // renova a posição no LRU
      return cached;
    }

    late final String gloss;
    try {
      gloss = (await _fetch(Uri.parse(endpoint), key).timeout(timeout)).trim();
    } on TimeoutException {
      throw const VLibrasTranslationException('timeout', 'timeout');
    } on VLibrasTranslationException {
      rethrow;
    } on SocketException catch (e) {
      throw VLibrasTranslationException('network', e.message);
    } catch (e) {
      throw VLibrasTranslationException('network', e.toString());
    }

    if (gloss.isEmpty) {
      throw const VLibrasTranslationException('empty', 'resposta vazia');
    }

    _cache[key] = gloss;
    if (_cache.length > cacheSize) _cache.remove(_cache.keys.first);
    return gloss;
  }

  /// Esquece as glosas em cache.
  void clearCache() => _cache.clear();

  static Future<String> _httpFetch(Uri endpoint, String text) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(endpoint);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'text': text}));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VLibrasTranslationException(
          'http',
          'HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
      return body;
    } finally {
      client.close(force: true);
    }
  }
}
