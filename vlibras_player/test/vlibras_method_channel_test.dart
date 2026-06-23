import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlibras_player/vlibras_player.dart';

// ---------------------------------------------------------------------------
// Fake platform implementation used in widget / integration tests.
// ---------------------------------------------------------------------------

class _FakeVLibrasPlatform implements VLibrasPlatformInterface {
  final List<String> calls = [];
  VLibrasConfig? lastConfig;
  String? lastText;

  final _eventController = StreamController<VLibrasEvent>.broadcast();

  void emitEvent(VLibrasEvent event) => _eventController.add(event);

  @override
  Future<void> initialize(VLibrasConfig config) async {
    calls.add('initialize');
    lastConfig = config;
  }

  @override
  Future<void> translate(String text) async {
    calls.add('translate');
    lastText = text;
  }

  @override
  Future<void> show() async => calls.add('show');

  @override
  Future<void> hide() async => calls.add('hide');

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Stream<VLibrasEvent> get eventStream => _eventController.stream;
}

// ---------------------------------------------------------------------------
// Mock MethodChannel handler (tests the real VLibrasMethodChannel codec path)
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VLibrasConfig', () {
    test('defaults are correct', () {
      const config = VLibrasConfig();
      expect(config.avatar, VLibrasAvatar.icaro);
      expect(config.speed, 1.0);
      expect(config.autoPlay, false);
      expect(config.baseUrl, 'https://vlibras.gov.br/app');
    });

    test('toMap serialises all fields', () {
      const config = VLibrasConfig(
        avatar: VLibrasAvatar.hosana,
        speed: 1.5,
        autoPlay: true,
        baseUrl: 'https://custom.host/vlibras',
      );
      final map = config.toMap();
      expect(map['avatar'], 'hosana');
      expect(map['speed'], 1.5);
      expect(map['autoPlay'], true);
      expect(map['baseUrl'], 'https://custom.host/vlibras');
    });

    test('copyWith overrides only specified fields', () {
      const base = VLibrasConfig(speed: 0.75);
      final copy = base.copyWith(avatar: VLibrasAvatar.guga);
      expect(copy.speed, 0.75);
      expect(copy.avatar, VLibrasAvatar.guga);
    });

    test('asserts on out-of-range speed', () {
      expect(
        () => VLibrasConfig(speed: 0.1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => VLibrasConfig(speed: 3.0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('VLibrasAvatar', () {
    test('apiId values match VLibras web API identifiers', () {
      expect(VLibrasAvatar.icaro.apiId, 'icaro');
      expect(VLibrasAvatar.hosana.apiId, 'hosana');
      expect(VLibrasAvatar.guga.apiId, 'guga');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('VLibrasEvent', () {
    test('fromMap parses ready event', () {
      final e = VLibrasEvent.fromMap({'type': 'ready'});
      expect(e.type, VLibrasEventType.ready);
      expect(e.message, isNull);
    });

    test('fromMap parses translateComplete', () {
      final e = VLibrasEvent.fromMap({'type': 'translateComplete'});
      expect(e.type, VLibrasEventType.translateComplete);
    });

    test('fromMap parses error with message', () {
      final e = VLibrasEvent.fromMap({
        'type': 'error',
        'message': 'Network failure',
      });
      expect(e.type, VLibrasEventType.error);
      expect(e.message, 'Network failure');
    });

    test('fromMap defaults to error for unknown type', () {
      final e = VLibrasEvent.fromMap({'type': 'unknown_xyz'});
      expect(e.type, VLibrasEventType.error);
    });

    test('fromMap parses shown / hidden', () {
      expect(VLibrasEvent.fromMap({'type': 'shown'}).type, VLibrasEventType.shown);
      expect(VLibrasEvent.fromMap({'type': 'hidden'}).type, VLibrasEventType.hidden);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('VLibrasPlayer (via fake platform)', () {
    late _FakeVLibrasPlatform fake;

    setUp(() {
      fake = _FakeVLibrasPlatform();
      VLibrasPlatformInterface.instance = fake;
    });

    test('initialize forwards config to platform', () async {
      const config = VLibrasConfig(avatar: VLibrasAvatar.hosana, speed: 1.5);
      await VLibrasPlayer.initialize(config);
      expect(fake.calls, ['initialize']);
      expect(fake.lastConfig?.avatar, VLibrasAvatar.hosana);
      expect(fake.lastConfig?.speed, 1.5);
    });

    test('translate forwards text to platform', () async {
      await VLibrasPlayer.initialize(const VLibrasConfig());
      await VLibrasPlayer.translate('Olá, mundo!');
      expect(fake.calls, contains('translate'));
      expect(fake.lastText, 'Olá, mundo!');
    });

    test('translate asserts non-empty text', () {
      expect(
        () => VLibrasPlayer.translate(''),
        throwsA(isA<AssertionError>()),
      );
    });

    test('show and hide are forwarded', () async {
      await VLibrasPlayer.show();
      await VLibrasPlayer.hide();
      expect(fake.calls, containsAll(['show', 'hide']));
    });

    test('dispose is forwarded', () async {
      await VLibrasPlayer.dispose();
      expect(fake.calls, contains('dispose'));
    });

    test('eventStream receives events from platform', () async {
      await VLibrasPlayer.initialize(const VLibrasConfig());

      final events = <VLibrasEvent>[];
      final sub = VLibrasPlayer.eventStream.listen(events.add);

      fake.emitEvent(const VLibrasEvent(type: VLibrasEventType.ready));
      fake.emitEvent(
        const VLibrasEvent(
            type: VLibrasEventType.error, message: 'test error'),
      );

      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(2));
      expect(events[0].type, VLibrasEventType.ready);
      expect(events[1].type, VLibrasEventType.error);
      expect(events[1].message, 'test error');

      await sub.cancel();
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('VLibrasMethodChannel (MethodChannel mock)', () {
    const methodChannel = MethodChannel('vlibras/methods');
    final log = <MethodCall>[];

    setUp(() {
      // Restore real method channel implementation
      VLibrasPlatformInterface.instance = VLibrasMethodChannel();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
        log.add(call);
        return null;
      });
      log.clear();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, null);
    });

    test('initialize sends correct method and arguments', () async {
      const config = VLibrasConfig(
        avatar: VLibrasAvatar.guga,
        speed: 0.8,
        autoPlay: true,
      );
      await VLibrasPlayer.initialize(config);

      expect(log, hasLength(1));
      expect(log.first.method, 'initialize');
      final args = log.first.arguments as Map;
      expect(args['avatar'], 'guga');
      expect(args['speed'], 0.8);
      expect(args['autoPlay'], true);
    });

    test('translate sends text argument', () async {
      await VLibrasPlayer.translate('Bom dia');
      expect(log.first.method, 'translate');
      expect((log.first.arguments as Map)['text'], 'Bom dia');
    });

    test('show sends correct method', () async {
      await VLibrasPlayer.show();
      expect(log.first.method, 'show');
    });

    test('hide sends correct method', () async {
      await VLibrasPlayer.hide();
      expect(log.first.method, 'hide');
    });

    test('dispose sends correct method', () async {
      await VLibrasPlayer.dispose();
      expect(log.first.method, 'dispose');
    });
  });
}

