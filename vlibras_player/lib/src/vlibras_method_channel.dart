import 'package:flutter/services.dart';
import 'models/vlibras_config.dart';
import 'models/vlibras_event.dart';
import 'vlibras_platform_interface.dart';
import 'vlibras_player_api.dart';

/// The default [VLibrasPlatformInterface] implementation backed by a
/// [MethodChannel] (for imperative calls) and an [EventChannel] (for events).
class VLibrasMethodChannel implements VLibrasPlatformInterface {
  static const _methodChannel = MethodChannel('vlibras/methods');
  static const _eventChannel = EventChannel('vlibras/events');

  @override
  Future<void> initialize(VLibrasConfig config) =>
      _invoke('initialize', config.toMap());

  @override
  Future<void> translate(String text) =>
      _invoke('translate', {'text': text});

  @override
  Future<void> show() => _invoke('show');

  @override
  Future<void> hide() => _invoke('hide');

  @override
  Future<void> dispose() => _invoke('dispose');

  /// Encapsula toda chamada nativa: relança para o caller (contrato público
  /// mantido) **e** reporta ao [VLibrasPlayer.errorReporter]. Antes,
  /// `MissingPluginException` (plugin não registrado) e `PlatformException`
  /// (falha nativa) subiam sem nenhum registro central.
  Future<void> _invoke(String method, [Object? args]) async {
    try {
      await _methodChannel.invokeMethod<void>(method, args);
    } catch (e, s) {
      VLibrasPlayer.reportError(
        e,
        s,
        reason: 'method-channel',
        context: {'method_channel': method},
      );
      rethrow;
    }
  }

  @override
  Stream<VLibrasEvent> get eventStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((dynamic raw) =>
            VLibrasEvent.fromMap(Map<String, dynamic>.from(raw as Map)))
        .handleError((Object e, StackTrace s) {
      VLibrasPlayer.reportError(e, s, reason: 'event-channel');
      throw e; // mantém o erro fluindo para quem escuta o eventStream
    });
  }
}
