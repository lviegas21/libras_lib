# vlibras_player

Flutter plugin for [VLibras](https://vlibras.gov.br/) — the official Brazilian Sign Language (Libras) text-to-avatar translation service.

## Features

- **Inline player** — embed the VLibras avatar inside any widget tree
- **Floating overlay button** — accessibility button that follows the system VLibras widget convention
- Text-to-Libras translation via `VLibrasPlayer.translate(text)`
- Event stream for ready / complete / error states
- Configurable avatar (Ícaro, Hosana, Guga), speed, and server URL
- Android (WebView + JavascriptInterface) and iOS (WKWebView)

## Getting started

```yaml
dependencies:
  vlibras_player:
    path: ../libs/vlibras_player
```

### Android

Add internet permission to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS

Add to `Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
</dict>
```

## Usage

### Inline player

```dart
VLibrasPlayerWidget(
  config: VLibrasConfig(
    avatar: VLibrasAvatar.icaro,
    autoPlay: true,
  ),
  onReady: () => VLibrasPlayer.translate('Olá, bem-vindo!'),
)
```

### Floating overlay button

```dart
Stack(
  children: [
    YourPageContent(),
    VLibrasOverlayButton(
      config: VLibrasConfig(),
    ),
  ],
)
```

### Programmatic API

```dart
await VLibrasPlayer.initialize(VLibrasConfig());
await VLibrasPlayer.translate('Texto para traduzir em Libras');

VLibrasPlayer.eventStream.listen((event) {
  switch (event.type) {
    case VLibrasEventType.ready:
      // SDK pronto
    case VLibrasEventType.translateComplete:
      // tradução concluída
    case VLibrasEventType.error:
      debugPrint(event.message);
  }
});

await VLibrasPlayer.dispose();
```
