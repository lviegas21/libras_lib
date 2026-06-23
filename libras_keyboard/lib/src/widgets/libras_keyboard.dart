import 'package:flutter/material.dart';
import '../controller/libras_keyboard_controller.dart';
import '../models/libras_letter.dart';
import 'libras_key.dart';

/// The default key layout: A–Z rows followed by the action row.
const _alphaLetters = [
  LibrasLetter.a, LibrasLetter.b, LibrasLetter.c, LibrasLetter.d,
  LibrasLetter.e, LibrasLetter.f, LibrasLetter.g, LibrasLetter.h,
  LibrasLetter.i, LibrasLetter.j, LibrasLetter.k, LibrasLetter.l,
  LibrasLetter.m, LibrasLetter.n, LibrasLetter.o, LibrasLetter.p,
  LibrasLetter.q, LibrasLetter.r, LibrasLetter.s, LibrasLetter.t,
  LibrasLetter.u, LibrasLetter.v, LibrasLetter.w, LibrasLetter.x,
  LibrasLetter.y, LibrasLetter.z,
];

const _actionLetters = [
  LibrasLetter.space,
  LibrasLetter.backspace,
  LibrasLetter.clear,
];

/// Default builder that renders bundled PNG hand-sign assets.
///
/// The image fills the entire key tile area.
/// Assets are loaded from `packages/libras_keyboard/assets/libras/<letter>.png`.
Widget defaultLetterBuilder(String letter, bool isPressed) {
  return ColorFiltered(
    colorFilter: isPressed
        ? const ColorFilter.matrix(<double>[
            0.6, 0,   0,   0, 0,
            0,   0.6, 0,   0, 0,
            0,   0,   0.6, 0, 0,
            0,   0,   0,   1, 0,
          ])
        : const ColorFilter.matrix(<double>[
            1, 0, 0, 0, 0,
            0, 1, 0, 0, 0,
            0, 0, 1, 0, 0,
            0, 0, 0, 1, 0,
          ]),
    child: Image.asset(
      'packages/libras_keyboard/assets/libras/$letter.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    ),
  );
}

/// The full Libras datilologia keyboard widget.
///
/// Renders a scrollable grid of [LibrasKey] tiles. Calls [controller.onKey]
/// when the user taps a key.
///
/// ```dart
/// LibrasKeyboard(
///   controller: myLibrasController,
/// )
/// ```
///
/// To use custom assets, pass a [letterBuilder]:
/// ```dart
/// LibrasKeyboard(
///   controller: myLibrasController,
///   letterBuilder: (letter, isPressed) => Image.asset(
///     'assets/my_libras/$letter.png',
///     width: 48,
///   ),
/// )
/// ```
class LibrasKeyboard extends StatelessWidget {
  const LibrasKeyboard({
    super.key,
    required this.controller,
    this.letterBuilder,
    this.columns = 7,
    this.keyAspectRatio = 0.9,
    this.keySpacing = 6.0,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  });

  final LibrasKeyboardController controller;

  /// Custom builder for key visuals. Defaults to [defaultLetterBuilder].
  final LibrasLetterBuilder? letterBuilder;

  /// Number of columns in the alpha grid.
  final int columns;

  /// Width-to-height ratio of each alpha key.
  final double keyAspectRatio;

  /// Gap between keys.
  final double keySpacing;

  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  LibrasLetterBuilder get _builder => letterBuilder ?? defaultLetterBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainer;

    return Container(
      color: bg,
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AlphaGrid(
            letters: _alphaLetters,
            controller: controller,
            letterBuilder: _builder,
            columns: columns,
            keyAspectRatio: keyAspectRatio,
            spacing: keySpacing,
          ),
          SizedBox(height: keySpacing),
          _ActionRow(
            letters: _actionLetters,
            controller: controller,
            letterBuilder: _builder,
            spacing: keySpacing,
          ),
        ],
      ),
    );
  }
}

class _AlphaGrid extends StatelessWidget {
  const _AlphaGrid({
    required this.letters,
    required this.controller,
    required this.letterBuilder,
    required this.columns,
    required this.keyAspectRatio,
    required this.spacing,
  });

  final List<LibrasLetter> letters;
  final LibrasKeyboardController controller;
  final LibrasLetterBuilder letterBuilder;
  final int columns;
  final double keyAspectRatio;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        childAspectRatio: keyAspectRatio,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: letters.length,
      itemBuilder: (_, i) => LibrasKey(
        letter: letters[i],
        letterBuilder: letterBuilder,
        onTap: () => controller.onKey(letters[i]),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.letters,
    required this.controller,
    required this.letterBuilder,
    required this.spacing,
  });

  final List<LibrasLetter> letters;
  final LibrasKeyboardController controller;
  final LibrasLetterBuilder letterBuilder;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: letters.map((letter) {
        final isDestructive = letter == LibrasLetter.clear;
        return Expanded(
          flex: letter == LibrasLetter.space ? 3 : 1,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: LibrasKey(
              letter: letter,
              letterBuilder: (l, pressed) => _ActionKeyContent(
                letter: letter,
                isPressed: pressed,
              ),
              onTap: () => controller.onKey(letter),
              backgroundColor: isDestructive
                  ? theme.colorScheme.errorContainer
                  : null,
              pressedColor: isDestructive
                  ? theme.colorScheme.error
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionKeyContent extends StatelessWidget {
  const _ActionKeyContent({required this.letter, required this.isPressed});

  final LibrasLetter letter;
  final bool isPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPressed
        ? Colors.white
        : theme.colorScheme.onSurfaceVariant;

    IconData icon;
    switch (letter) {
      case LibrasLetter.backspace:
        icon = Icons.backspace_outlined;
      case LibrasLetter.space:
        icon = Icons.space_bar;
      case LibrasLetter.clear:
        icon = Icons.clear_all;
      default:
        icon = Icons.help_outline;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 2),
        Text(
          letter.semanticsLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
