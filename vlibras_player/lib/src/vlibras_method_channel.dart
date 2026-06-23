import 'package:flutter/services.dart';
import 'models/vlibras_config.dart';
import 'models/vlibras_event.dart';
import 'vlibras_platform_interface.dart';

/// The default [VLibrasPlatformInterface] implementation backed by a
/// [MethodChannel] (for imperative calls) and an [EventChannel] (for events).
class VLibrasMethodChannel implements VLibrasPlatformInterface {
  static const _methodChannel = MethodChannel('vlibras/methods');
  static const _eventChannel = EventChannel('vlibras/events');

  @override
  Future<void> initialize(VLibrasConfig config) {
    return _methodChannel.invokeMethod('initialize', config.toMap());
  }

  @override
  Future<void> translate(String text) {
    return _methodChannel.invokeMethod('translate', {'text': text});
  }

  @override
  Future<void> show() {
    return _methodChannel.invokeMethod('show');
  }

  @override
  Future<void> hide() {
    return _methodChannel.invokeMethod('hide');
  }

  @override
  Future<void> dispose() {
    return _methodChannel.invokeMethod('dispose');
  }

  @override
  Stream<VLibrasEvent> get eventStream {
    return _eventChannel
        .receiveBroadcastStream()
        .map((dynamic raw) => VLibrasEvent.fromMap(Map<String, dynamic>.from(raw as Map)));
  }
}
