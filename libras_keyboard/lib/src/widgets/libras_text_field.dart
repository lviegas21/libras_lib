import 'package:flutter/material.dart';
import '../controller/libras_keyboard_controller.dart';
import 'libras_key.dart';
import 'libras_keyboard.dart';

/// A drop-in replacement for [TextField] that includes the Libras keyboard.
///
/// Shows a toggle button next to the field. Tapping it opens/closes the
/// keyboard panel with a smooth slide animation.
///
/// ```dart
/// LibrasTextField(
///   controller: myTextEditingController,
///   decoration: InputDecoration(labelText: 'Digite em Libras'),
/// )
/// ```
///
/// The system keyboard is automatically hidden when the Libras keyboard opens
/// (the [TextField] loses focus).
class LibrasTextField extends StatefulWidget {
  const LibrasTextField({
    super.key,
    required this.controller,
    this.letterBuilder,
    this.decoration,
    this.style,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.focusNode,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardColumns = 7,
    this.keyboardBackgroundColor,
  });

  /// The [TextEditingController] for the underlying [TextField].
  final TextEditingController controller;

  /// Custom visual builder for each key. Defaults to [defaultLetterBuilder].
  final LibrasLetterBuilder? letterBuilder;

  final InputDecoration? decoration;
  final TextStyle? style;
  final int? maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool autofocus;
  final int keyboardColumns;
  final Color? keyboardBackgroundColor;

  @override
  State<LibrasTextField> createState() => _LibrasTextFieldState();
}

class _LibrasTextFieldState extends State<LibrasTextField>
    with SingleTickerProviderStateMixin {
  late final LibrasKeyboardController _librasController;
  late final FocusNode _focusNode;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;

  bool _showLibrasKeyboard = false;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _librasController = LibrasKeyboardController(widget.controller);

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _librasController.dispose();
    _animController.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _toggleLibrasKeyboard() {
    setState(() {
      _showLibrasKeyboard = !_showLibrasKeyboard;
    });

    if (_showLibrasKeyboard) {
      // Dismiss system keyboard before showing Libras keyboard.
      _focusNode.unfocus();
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                decoration: widget.decoration,
                style: widget.style,
                maxLines: widget.maxLines,
                minLines: widget.minLines,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onSubmitted: widget.onSubmitted,
                onChanged: widget.onChanged,
                readOnly: widget.readOnly || _showLibrasKeyboard,
                autofocus: widget.autofocus,
                onTap: () {
                  if (_showLibrasKeyboard) {
                    // Keep Libras keyboard open when tapping the field.
                    _focusNode.unfocus();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: _showLibrasKeyboard
                  ? 'Fechar teclado Libras'
                  : 'Abrir teclado Libras',
              child: InkWell(
                onTap: _toggleLibrasKeyboard,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _showLibrasKeyboard
                        ? Icon(
                            Icons.keyboard_hide,
                            key: const ValueKey('hide'),
                            color: theme.colorScheme.primary,
                            size: 28,
                          )
                        : Icon(
                            Icons.sign_language,
                            key: const ValueKey('show'),
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 28,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizeTransition(
          sizeFactor: _slideAnimation,
          child: LibrasKeyboard(
            controller: _librasController,
            letterBuilder: widget.letterBuilder,
            columns: widget.keyboardColumns,
            backgroundColor: widget.keyboardBackgroundColor,
          ),
        ),
      ],
    );
  }
}
