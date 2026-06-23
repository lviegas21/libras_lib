/// The type of event emitted by the native VLibras layer.
enum VLibrasEventType {
  /// Native WebView and VLibras script finished loading.
  ready,

  /// The avatar finished signing the last submitted text.
  translateComplete,

  /// An error occurred in the native layer or the VLibras script.
  error,

  /// The player was shown (after a [VLibrasPlayer.show] call).
  shown,

  /// The player was hidden (after a [VLibrasPlayer.hide] call).
  hidden,
}

/// An event received from the native VLibras layer via the EventChannel.
class VLibrasEvent {
  const VLibrasEvent({
    required this.type,
    this.message,
    this.data,
  });

  final VLibrasEventType type;

  /// Human-readable message (mainly for [VLibrasEventType.error]).
  final String? message;

  /// Optional extra payload sent by the native side.
  final Map<String, dynamic>? data;

  /// Deserialise from the raw map received on the EventChannel.
  factory VLibrasEvent.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String? ?? 'error';
    final type = switch (typeStr) {
      'ready' => VLibrasEventType.ready,
      'translateComplete' => VLibrasEventType.translateComplete,
      'shown' => VLibrasEventType.shown,
      'hidden' => VLibrasEventType.hidden,
      _ => VLibrasEventType.error,
    };
    return VLibrasEvent(
      type: type,
      message: map['message'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
    );
  }

  @override
  String toString() => 'VLibrasEvent(type: $type, message: $message)';
}
