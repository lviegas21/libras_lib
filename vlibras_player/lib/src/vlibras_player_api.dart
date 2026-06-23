import 'models/vlibras_config.dart';
import 'models/vlibras_event.dart';
import 'vlibras_platform_interface.dart';

/// High-level Dart API for the VLibras text-to-Libras service.
///
/// All calls are forwarded to [VLibrasPlatformInterface.instance], which
/// defaults to the [VLibrasMethodChannel] backed by native Android/iOS code.
///
/// Typical setup:
/// ```dart
/// await VLibrasPlayer.initialize(VLibrasConfig(avatar: VLibrasAvatar.icaro));
/// VLibrasPlayer.eventStream.listen((e) { ... });
/// await VLibrasPlayer.translate('Olá, mundo!');
/// ```
class VLibrasPlayer {
  VLibrasPlayer._();

  static VLibrasPlatformInterface get _impl => VLibrasPlatformInterface.instance;

  /// Initialises the native VLibras runtime with the given [config].
  ///
  /// Must be called before any other method. Safe to call again after
  /// [dispose] to reinitialise with different settings.
  static Future<void> initialize(VLibrasConfig config) =>
      _impl.initialize(config);

  /// Sends [text] to the VLibras avatar for translation into sign language.
  ///
  /// The avatar begins signing immediately (or queues if [VLibrasConfig.autoPlay]
  /// is false). Listen to [eventStream] for [VLibrasEventType.translateComplete].
  static Future<void> translate(String text) {
    assert(text.isNotEmpty, 'text must not be empty');
    return _impl.translate(text);
  }

  /// Makes the player visible if it was previously hidden.
  static Future<void> show() => _impl.show();

  /// Hides the player without releasing native resources.
  static Future<void> hide() => _impl.hide();

  /// Releases all native resources. Call [initialize] again to reuse.
  static Future<void> dispose() => _impl.dispose();

  /// Broadcast stream of events from the native layer.
  ///
  /// Events:
  /// - [VLibrasEventType.ready] — SDK loaded, safe to call [translate]
  /// - [VLibrasEventType.translateComplete] — avatar finished signing
  /// - [VLibrasEventType.error] — something went wrong; check [VLibrasEvent.message]
  /// - [VLibrasEventType.shown] / [VLibrasEventType.hidden] — visibility changes
  static Stream<VLibrasEvent> get eventStream => _impl.eventStream;
}
