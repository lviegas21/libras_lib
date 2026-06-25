import 'package:flutter/material.dart';
import '../controller/libras_keyboard_controller.dart';
import '../models/libras_letter.dart';
import 'libras_key.dart';

/// The default key layout: A–Z rows followed by the action row.
const _alphaLetters = [
  LibrasLetter.a,
  LibrasLetter.b,
  LibrasLetter.c,
  LibrasLetter.d,
  LibrasLetter.e,
  LibrasLetter.f,
  LibrasLetter.g,
  LibrasLetter.h,
  LibrasLetter.i,
  LibrasLetter.j,
  LibrasLetter.k,
  LibrasLetter.l,
  LibrasLetter.m,
  LibrasLetter.n,
  LibrasLetter.o,
  LibrasLetter.p,
  LibrasLetter.q,
  LibrasLetter.r,
  LibrasLetter.s,
  LibrasLetter.t,
  LibrasLetter.u,
  LibrasLetter.v,
  LibrasLetter.w,
  LibrasLetter.x,
  LibrasLetter.y,
  LibrasLetter.z,
];

const _numberLetters = [
  LibrasLetter.num0,
  LibrasLetter.num1,
  LibrasLetter.num2,
  LibrasLetter.num3,
  LibrasLetter.num4,
  LibrasLetter.num5,
  LibrasLetter.num6,
  LibrasLetter.num7,
  LibrasLetter.num8,
  LibrasLetter.num9,
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
/// Falls back to a text label when the asset file is not found (e.g. in
/// development before real images are added).
Widget defaultLetterBuilder(String letter, bool isPressed) {
  final opacity = isPressed ? 0.6 : 1.0;
  return Opacity(
    opacity: opacity,
    child: Image.asset(
      'packages/libras_keyboard/assets/libras/$letter.png',
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _LetterFallback(letter: letter),
    ),
  );
}

class _LetterFallback extends StatelessWidget {
  const _LetterFallback({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    final isAction = letter == 'backspace' || letter == 'clear';
    final label = switch (letter) {
      'backspace' => '⌫',
      'space' => '␣',
      'clear' => '✕',
      _ => letter.toUpperCase(),
    };
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isAction ? 16 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
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
class LibrasKeyboard extends StatefulWidget {
  const LibrasKeyboard({
    super.key,
    required this.controller,
    this.letterBuilder,
    this.columns = 7,
    this.numberColumns = 5,
    this.keyAspectRatio = 0.9,
    this.keySpacing = 6.0,
    this.showModeToggle = true,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
  });

  final LibrasKeyboardController controller;

  /// Custom builder for key visuals. Defaults to [defaultLetterBuilder].
  final LibrasLetterBuilder? letterBuilder;

  /// Number of columns in the alpha grid.
  final int columns;

  /// Number of columns in the numbers grid.
  final int numberColumns;

  /// Width-to-height ratio of each key.
  final double keyAspectRatio;

  /// Gap between keys.
  final double keySpacing;

  /// Whether to show the ABC / 123 toggle that switches between the letter
  /// and number layouts. When false the keyboard only shows letters.
  final bool showModeToggle;

  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;

  @override
  State<LibrasKeyboard> createState() => _LibrasKeyboardState();
}

class _LibrasKeyboardState extends State<LibrasKeyboard> {
  bool _showNumbers = false;

  LibrasLetterBuilder get _builder =>
      widget.letterBuilder ?? defaultLetterBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = widget.backgroundColor ?? theme.colorScheme.surfaceContainer;

    return Container(
      color: bg,
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _showNumbers ? widget.numberColumns : widget.columns;
          // Derive the action-row key height from the grid cell geometry
          // so both rows stay visually consistent.
          final cellWidth =
              (constraints.maxWidth - widget.keySpacing * (columns - 1)) /
                  columns;
          final keyHeight = cellWidth / widget.keyAspectRatio;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showModeToggle) ...[
                _ModeToggle(
                  showNumbers: _showNumbers,
                  onChanged: (v) => setState(() => _showNumbers = v),
                ),
                SizedBox(height: widget.keySpacing),
              ],
              _AlphaGrid(
                letters: _showNumbers ? _numberLetters : _alphaLetters,
                controller: widget.controller,
                letterBuilder: _builder,
                columns: columns,
                keyAspectRatio: widget.keyAspectRatio,
                spacing: widget.keySpacing,
              ),
              SizedBox(height: widget.keySpacing),
              _ActionRow(
                letters: _actionLetters,
                controller: widget.controller,
                letterBuilder: _builder,
                spacing: widget.keySpacing,
                keyHeight: keyHeight,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A small segmented control to switch between the ABC and 123 layouts.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.showNumbers, required this.onChanged});

  final bool showNumbers;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<bool>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: const [
          ButtonSegment(value: false, label: Text('ABC')),
          ButtonSegment(value: true, label: Text('123')),
        ],
        selected: {showNumbers},
        onSelectionChanged: (s) => onChanged(s.first),
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
    required this.keyHeight,
  });

  final List<LibrasLetter> letters;
  final LibrasKeyboardController controller;
  final LibrasLetterBuilder letterBuilder;
  final double spacing;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: keyHeight,
      child: Row(
        children: letters.map((letter) {
          final isDestructive = letter == LibrasLetter.clear;
          return Expanded(
            flex: letter == LibrasLetter.space ? 3 : 1,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing / 2),
              child: LibrasKey(
                letter: letter,
                letterBuilder: letterBuilder,
                onTap: () => controller.onKey(letter),
                backgroundColor:
                    isDestructive ? theme.colorScheme.errorContainer : null,
                pressedColor: isDestructive ? theme.colorScheme.error : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
