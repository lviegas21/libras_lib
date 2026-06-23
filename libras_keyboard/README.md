# libras_keyboard

An accessible in-app Libras (Brazilian Sign Language) datilologia keyboard for Flutter.

## Features

- Full A–Z datilologia keyboard rendered as a bottom panel
- Bundled flat-style SVG hand-sign assets for every letter — no extra setup
- Pluggable `LibrasLetterBuilder` so you can swap in your own photos, animations, or vectors
- `LibrasTextField` drop-in widget: one line replaces a standard `TextField`
- Works on Android and iOS — no native (Kotlin/Swift) code required

## Getting started

Add the dependency using a path (internal usage):

```yaml
dependencies:
  libras_keyboard:
    path: ../libs/libras_keyboard
```

## Usage

### Drop-in replacement (simplest)

```dart
import 'package:libras_keyboard/libras_keyboard.dart';

LibrasTextField(
  controller: myTextEditingController,
  decoration: InputDecoration(labelText: 'Digite em Libras'),
)
```

### Manual control (advanced)

```dart
final librasController = LibrasKeyboardController(myTextEditingController);

// In your widget tree:
Column(
  children: [
    TextField(controller: myTextEditingController),
    LibrasKeyboard(controller: librasController),
  ],
)
```

### Custom assets

```dart
LibrasTextField(
  controller: myTextEditingController,
  letterBuilder: (letter, isPressed) => Image.asset(
    'assets/my_libras/$letter.png',
    width: 48,
  ),
)
```

## API

| Symbol | Description |
|---|---|
| `LibrasKeyboardController` | `ChangeNotifier` wrapping a `TextEditingController` |
| `LibrasLetterBuilder` | `typedef Widget Function(String letter, bool isPressed)` |
| `LibrasKeyboard` | Full keyboard grid widget |
| `LibrasTextField` | Bundled `TextField` + toggle + keyboard panel |
| `defaultLetterBuilder` | Built-in SVG builder (used when no builder is provided) |

## Roadmap

- [ ] Animated key-press feedback
- [ ] Dark-mode SVG variants
- [ ] System IME extension (`libras_keyboard_system` package)
