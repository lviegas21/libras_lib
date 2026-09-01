import 'package:flutter_test/flutter_test.dart';
import 'package:vlibras_player/src/vlibras_liveness_monitor.dart';

void main() {
  group('VLibrasLivenessMonitor', () {
    test('página viva não dispara nada', () async {
      var lost = 0;
      final monitor = VLibrasLivenessMonitor(
        evaluate: (_) async => true,
        onLost: () => lost++,
      );

      await monitor.checkNow();
      await monitor.checkNow();
      expect(lost, 0);
      expect(monitor.consecutiveFailures, 0);
      monitor.dispose();
    });

    test('aceita o booleano em qualquer forma que a plataforma devolva', () async {
      for (final value in <Object?>[true, 'true', 1, '1']) {
        var lost = 0;
        final monitor = VLibrasLivenessMonitor(
          evaluate: (_) async => value,
          onLost: () => lost++,
          failuresBeforeLost: 1,
        );
        await monitor.checkNow();
        expect(lost, 0, reason: 'valor $value deveria contar como vivo');
        monitor.dispose();
      }
    });

    test('uma falha isolada não recria o player', () async {
      var lost = 0;
      var alive = false;
      final monitor = VLibrasLivenessMonitor(
        evaluate: (_) async => alive,
        onLost: () => lost++,
      );

      await monitor.checkNow(); // 1a falha
      expect(lost, 0);
      alive = true;
      await monitor.checkNow(); // recuperou
      expect(monitor.consecutiveFailures, 0);
      alive = false;
      await monitor.checkNow(); // volta do zero
      expect(lost, 0);
      monitor.dispose();
    });

    test('duas falhas seguidas avisam uma única vez', () async {
      var lost = 0;
      final monitor = VLibrasLivenessMonitor(
        evaluate: (_) async => false,
        onLost: () => lost++,
      );

      await monitor.checkNow();
      await monitor.checkNow();
      expect(lost, 1);
      await monitor.checkNow();
      await monitor.checkNow();
      expect(lost, 1, reason: 'para de vigiar depois de avisar');
      monitor.dispose();
    });

    test('exceção do runJavaScript conta como falha', () async {
      var lost = 0;
      final monitor = VLibrasLivenessMonitor(
        evaluate: (_) async => throw StateError('WebView destruído'),
        onLost: () => lost++,
        failuresBeforeLost: 1,
      );

      await monitor.checkNow();
      expect(lost, 1);
      monitor.dispose();
    });

    test('start/stop controlam o timer e o dispose não deixa disparar', () async {
      var lost = 0;
      final monitor = VLibrasLivenessMonitor(
        evaluate: (_) async => false,
        onLost: () => lost++,
        interval: const Duration(milliseconds: 20),
        failuresBeforeLost: 1,
      );

      expect(monitor.isRunning, isFalse);
      monitor.start();
      expect(monitor.isRunning, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(lost, 1);
      expect(monitor.isRunning, isFalse, reason: 'para sozinho ao avisar');

      monitor.dispose();
      await monitor.checkNow();
      expect(lost, 1);
    });
  });
}
