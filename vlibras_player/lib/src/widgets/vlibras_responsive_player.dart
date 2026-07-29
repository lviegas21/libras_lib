import 'package:flutter/material.dart';

import '../models/vlibras_config.dart';
import '../vlibras_html.dart';
import '../vlibras_widget_controller.dart';
import 'vlibras_player_widget.dart';

/// Responsive, centered VLibras avatar frame for Android and iOS apps.
///
/// Fits a portrait avatar-only stage inside the parent constraints (or optional
/// [maxWidth] / [maxHeight] caps) and centers it. Init failures are reported via
/// [onError] and [VLibrasPlayerController.eventStream].
///
/// ```dart
/// VLibrasResponsivePlayer(
///   controller: ctrl,
///   onReady: () => ctrl.translate('Olá'),
///   onError: (msg) => debugPrint(msg),
/// )
/// ```
class VLibrasResponsivePlayer extends StatelessWidget {
  const VLibrasResponsivePlayer({
    super.key,
    this.config = const VLibrasConfig(),
    this.controller,
    this.onReady,
    this.onTranslateComplete,
    this.onError,
    this.maxWidth = 170,
    this.maxHeight = 220,
    this.contentAlignment = Alignment.center,
    this.avatarViewportHeight = kVLibrasAvatarOnlyViewport,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final VLibrasConfig config;
  final VLibrasPlayerController? controller;
  final VoidCallback? onReady;
  final VoidCallback? onTranslateComplete;
  final ValueChanged<String>? onError;

  /// Upper bound for the avatar frame width. Defaults to 170.
  final double maxWidth;

  /// Upper bound for the avatar frame height. Defaults to 220.
  final double maxHeight;

  final Alignment contentAlignment;
  final double avatarViewportHeight;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxWidth;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxHeight;

        final stage = vlibrasAvatarStage(
          maxWidth: availableWidth.clamp(0.0, maxWidth),
          maxHeight: availableHeight.clamp(0.0, maxHeight),
        );

        return Center(
          child: VLibrasPlayerWidget.avatarOnly(
            config: config,
            controller: controller,
            onReady: onReady,
            onTranslateComplete: onTranslateComplete,
            onError: onError,
            height: stage.height,
            visibleWidth: stage.width,
            contentAlignment: contentAlignment,
            avatarViewportHeight: avatarViewportHeight,
            loadingBuilder: loadingBuilder,
            errorBuilder: errorBuilder,
          ),
        );
      },
    );
  }
}
