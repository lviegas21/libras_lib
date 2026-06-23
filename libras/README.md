# libras

Umbrella package for Libras (Brazilian Sign Language) accessibility tools.

Add this single package to your app and you get everything:

- `libras_keyboard` — in-app datilologia (fingerspelling) keyboard widget
- `vlibras_player` — VLibras text-to-Libras avatar player (Android + iOS)

## Usage

```yaml
# your_app/pubspec.yaml
dependencies:
  libras:
    path: ../libs/libras
```

```dart
import 'package:libras/libras.dart';

// Keyboard
LibrasTextField(controller: myController)

// VLibras player
VLibrasPlayerWidget(config: VLibrasConfig(avatar: VLibrasAvatar.hosana))

// Floating overlay
VLibrasOverlayButton(config: VLibrasConfig())
```

See individual package READMEs for full documentation:
- [`libras_keyboard`](../libras_keyboard/README.md)
- [`vlibras_player`](../vlibras_player/README.md)
