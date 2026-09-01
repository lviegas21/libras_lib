import 'package:flutter_test/flutter_test.dart';
import 'package:vlibras_player/src/vlibras_translation_service.dart';

void main() {
  group('VLibrasTranslationService', () {
    test('traduz texto em glosa pelo endpoint configurado', () async {
      Uri? seen;
      String? sentText;
      final service = VLibrasTranslationService(
        endpoint: 'https://traducao.example/translate',
        fetcher: (uri, text) async {
          seen = uri;
          sentText = text;
          return 'OL BOM_DIA [PONTO]\n';
        },
      );

      expect(await service.toGloss('  Olá, bom dia  '), 'OL BOM_DIA [PONTO]');
      expect(seen, Uri.parse('https://traducao.example/translate'));
      expect(sentText, 'Olá, bom dia');
    });

    test('repete a mesma frase sem novo request', () async {
      var calls = 0;
      final service = VLibrasTranslationService(
        fetcher: (_, __) async {
          calls++;
          return 'OI';
        },
      );

      await service.toGloss('oi');
      await service.toGloss('oi');
      expect(calls, 1);

      service.clearCache();
      await service.toGloss('oi');
      expect(calls, 2);
    });

    test('cache descarta a entrada mais antiga ao estourar o limite', () async {
      var calls = 0;
      final service = VLibrasTranslationService(
        cacheSize: 2,
        fetcher: (_, text) async {
          calls++;
          return text.toUpperCase();
        },
      );

      await service.toGloss('a');
      await service.toGloss('b');
      await service.toGloss('c'); // expulsa 'a'
      await service.toGloss('b'); // ainda em cache
      expect(calls, 3);
      await service.toGloss('a'); // saiu do cache
      expect(calls, 4);
    });

    test('resposta vazia vira erro "empty"', () async {
      final service = VLibrasTranslationService(fetcher: (_, __) async => '   ');
      await expectLater(
        service.toGloss('oi'),
        throwsA(isA<VLibrasTranslationException>()
            .having((e) => e.kind, 'kind', 'empty')),
      );
    });

    test('texto vazio nem chega a pedir tradução', () async {
      var calls = 0;
      final service = VLibrasTranslationService(fetcher: (_, __) async {
        calls++;
        return 'X';
      });
      await expectLater(
        service.toGloss('   '),
        throwsA(isA<VLibrasTranslationException>()),
      );
      expect(calls, 0);
    });

    test('estouro de tempo vira erro "timeout" com mensagem própria', () async {
      final service = VLibrasTranslationService(
        timeout: const Duration(milliseconds: 30),
        fetcher: (_, __) => Future.delayed(
          const Duration(seconds: 5),
          () => 'tarde demais',
        ),
      );

      await expectLater(
        service.toGloss('oi'),
        throwsA(isA<VLibrasTranslationException>()
            .having((e) => e.kind, 'kind', 'timeout')
            .having((e) => e.userMessage, 'userMessage',
                contains('demorou demais'))),
      );
    });

    test('erro HTTP preserva o status code', () async {
      final service = VLibrasTranslationService(
        fetcher: (_, __) async =>
            throw const VLibrasTranslationException('http', 'HTTP 503',
                statusCode: 503),
      );

      await expectLater(
        service.toGloss('oi'),
        throwsA(isA<VLibrasTranslationException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.kind, 'kind', 'http')),
      );
    });

    test('falha de rede não vaza a exceção crua', () async {
      final service = VLibrasTranslationService(
        fetcher: (_, __) async => throw StateError('sem rota para o host'),
      );

      await expectLater(
        service.toGloss('oi'),
        throwsA(isA<VLibrasTranslationException>()
            .having((e) => e.kind, 'kind', 'network')
            .having((e) => e.userMessage, 'userMessage',
                contains('Verifique sua conexão'))),
      );
    });
  });
}
