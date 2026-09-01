library vlibras_player;

export 'src/libras_error_reporter.dart'
    show LibrasErrorReporter, debugPrintLibrasError;
export 'src/models/vlibras_config.dart';
export 'src/models/vlibras_event.dart';
export 'src/vlibras_html.dart'
    show
        kVLibrasPanelCssWidth,
        kVLibrasAvatarOnlyViewport,
        kVLibrasAvatarStageAspect,
        kVLibrasAvatarZoom,
        kVLibrasPlayerVersion,
        kVLibrasPortalBaseUrl,
        kVLibrasPinnedPlayerAssetsUrl,
        kVLibrasDictionaryUrl,
        kVLibrasTranslateUrl,
        vlibrasNaturalWidth,
        vlibrasStageFraming,
        vlibrasAvatarStage;
export 'src/vlibras_method_channel.dart';
export 'src/vlibras_platform_interface.dart';
export 'src/vlibras_player_api.dart';
export 'src/vlibras_liveness_monitor.dart';
export 'src/vlibras_translation_service.dart';
export 'src/vlibras_widget_controller.dart';
export 'src/widgets/vlibras_overlay_button.dart';
export 'src/widgets/vlibras_player_widget.dart';
export 'src/widgets/vlibras_responsive_player.dart';
