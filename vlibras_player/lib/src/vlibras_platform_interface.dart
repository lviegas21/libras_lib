import 'models/vlibras_config.dart';
import 'models/vlibras_event.dart';
import 'vlibras_method_channel.dart';

/// Abstract contract for all platform implementations of VLibras.
///
/// Concrete implementations live in [VLibrasMethodChannel] (the default)
/// or can be swapped at test time via [VLibrasPlatformInterface.instance].
abstract class VLibrasPlatformInterface {
  static VLibrasPlatformInterface _instance = VLibrasMethodChannel();

  /// The active platform implementation.
  static VLibrasPlatformInterface get instance => _instance;

  /// Override the default implementation. Useful for testing.
  static set instance(VLibrasPlatformInterface impl) {
    _instance = impl;
  }

  /// Initialises the native VLibras runtime with the given [config].
  Future<void> initialize(VLibrasConfig config);

  /// Sends [text] to the avatar for translation/signing.
  Future<void> translate(String text);

  /// Shows the player/overlay if it was previously hidden.
  Future<void> show();

  /// Hides the player/overlay without disposing native resources.
  Future<void> hide();

  /// Releases all native resources.
  Future<void> dispose();

  /// Stream of events emitted by the native layer.
  Stream<VLibrasEvent> get eventStream;
}
