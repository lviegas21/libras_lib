import 'package:flutter/material.dart';
import '../models/libras_letter.dart';

/// A builder function that returns the visual content for a single keyboard key.
///
/// [letter] is the lowercase letter name (e.g. `'a'`, `'b'`) or special key
/// name (`'backspace'`, `'space'`, `'clear'`).
/// [isPressed] is `true` while the key is held down.
typedef LibrasLetterBuilder = Widget Function(
  String letter,
  bool isPressed,
);

/// A single key tile on the Libras keyboard.
///
/// Renders the content via [letterBuilder] and notifies [onTap] when pressed.
/// Includes a [Semantics] wrapper for screen-reader accessibility.
class LibrasKey extends StatefulWidget {
  const LibrasKey({
    super.key,
    required this.letter,
    required this.letterBuilder,
    required this.onTap,
    this.backgroundColor,
    this.pressedColor,
    this.borderRadius = 8.0,
    this.padding = EdgeInsets.zero,
  });

  final LibrasLetter letter;
  final LibrasLetterBuilder letterBuilder;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? pressedColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  State<LibrasKey> createState() => _LibrasKeyState();
}

class _LibrasKeyState extends State<LibrasKey> {
  bool _pressed = false;

  void _handleTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _handleTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _handleTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _pressed
        ? (widget.pressedColor ?? theme.colorScheme.primaryContainer)
        : (widget.backgroundColor ?? theme.colorScheme.surfaceContainerHighest);

    return Semantics(
      button: true,
      label: widget.letter.semanticsLabel,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _pressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      offset: const Offset(0, 2),
                      blurRadius: 3,
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          padding: widget.padding,
          child: widget.letterBuilder(widget.letter.name, _pressed),
        ),
      ),
    );
  }
}
