import 'package:flutter/widgets.dart';
import '../models/libras_letter.dart';

/// Controls text input for a [TextField] driven by the Libras keyboard.
///
/// Wraps a [TextEditingController] and exposes high-level operations that
/// preserve cursor position correctly (insert at cursor, backspace before
/// cursor, etc.).
///
/// Usage:
/// ```dart
/// final tec = TextEditingController();
/// final controller = LibrasKeyboardController(tec);
///
/// // Later, dispose both:
/// controller.dispose();
/// tec.dispose();
/// ```
class LibrasKeyboardController extends ChangeNotifier {
  LibrasKeyboardController(this.textController);

  final TextEditingController textController;

  /// Processes a key press from the keyboard.
  void onKey(LibrasLetter letter) {
    switch (letter) {
      case LibrasLetter.backspace:
        backspace();
      case LibrasLetter.space:
        space();
      case LibrasLetter.clear:
        clear();
      default:
        final char = letter.character;
        if (char != null) insert(char);
    }
  }

  /// Inserts [text] at the current cursor position (or replaces selection).
  void insert(String text) {
    final controller = textController;
    final selection = controller.selection;
    final current = controller.text;

    if (!selection.isValid) {
      controller.text = current + text;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
      notifyListeners();
      return;
    }

    final before = selection.textBefore(current);
    final after = selection.textAfter(current);
    final newText = before + text + after;

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: before.length + text.length),
    );
    notifyListeners();
  }

  /// Deletes the character immediately before the cursor (or the selection).
  void backspace() {
    final controller = textController;
    final selection = controller.selection;
    final current = controller.text;

    if (!selection.isValid || current.isEmpty) return;

    if (selection.isCollapsed) {
      if (selection.baseOffset == 0) return;
      final before = current.substring(0, selection.baseOffset - 1);
      final after = current.substring(selection.baseOffset);
      controller.value = TextEditingValue(
        text: before + after,
        selection: TextSelection.collapsed(offset: before.length),
      );
    } else {
      final before = selection.textBefore(current);
      final after = selection.textAfter(current);
      controller.value = TextEditingValue(
        text: before + after,
        selection: TextSelection.collapsed(offset: before.length),
      );
    }
    notifyListeners();
  }

  /// Inserts a space character at the cursor position.
  void space() => insert(' ');

  /// Clears all text in the controller.
  void clear() {
    textController.value = TextEditingValue.empty;
    notifyListeners();
  }

  /// The current text value.
  String get text => textController.text;
}
