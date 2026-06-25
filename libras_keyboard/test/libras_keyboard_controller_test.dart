import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libras_keyboard/libras_keyboard.dart';

void main() {
  group('LibrasKeyboardController', () {
    late TextEditingController tec;
    late LibrasKeyboardController controller;

    setUp(() {
      tec = TextEditingController();
      controller = LibrasKeyboardController(tec);
    });

    tearDown(() {
      controller.dispose();
      tec.dispose();
    });

    // ── insert ──────────────────────────────────────────────────────────────

    test('insert appends character when field is empty', () {
      controller.insert('A');
      expect(tec.text, 'A');
    });

    test('insert appends at end when no explicit selection', () {
      tec.text = 'OL';
      tec.selection = TextSelection.collapsed(offset: tec.text.length);
      controller.insert('A');
      expect(tec.text, 'OLA');
    });

    test('insert places character at cursor position (mid-text)', () {
      tec.text = 'AC';
      tec.selection = const TextSelection.collapsed(offset: 1); // between A and C
      controller.insert('B');
      expect(tec.text, 'ABC');
      expect(tec.selection.baseOffset, 2);
    });

    test('insert replaces selected text', () {
      tec.text = 'ABC';
      tec.selection = const TextSelection(baseOffset: 1, extentOffset: 2); // selects B
      controller.insert('X');
      expect(tec.text, 'AXC');
      expect(tec.selection.baseOffset, 2);
    });

    // ── backspace ───────────────────────────────────────────────────────────

    test('backspace removes last character', () {
      tec.text = 'AB';
      tec.selection = TextSelection.collapsed(offset: tec.text.length);
      controller.backspace();
      expect(tec.text, 'A');
    });

    test('backspace at offset 0 does nothing', () {
      tec.text = 'AB';
      tec.selection = const TextSelection.collapsed(offset: 0);
      controller.backspace();
      expect(tec.text, 'AB');
    });

    test('backspace on empty text does nothing', () {
      controller.backspace();
      expect(tec.text, '');
    });

    test('backspace removes character before cursor (mid-text)', () {
      tec.text = 'ABC';
      tec.selection = const TextSelection.collapsed(offset: 2); // after B
      controller.backspace();
      expect(tec.text, 'AC');
      expect(tec.selection.baseOffset, 1);
    });

    test('backspace deletes entire selection', () {
      tec.text = 'ABCDE';
      tec.selection = const TextSelection(baseOffset: 1, extentOffset: 4); // BCD
      controller.backspace();
      expect(tec.text, 'AE');
      expect(tec.selection.baseOffset, 1);
    });

    // ── space ───────────────────────────────────────────────────────────────

    test('space inserts a space character', () {
      tec.text = 'OLA';
      tec.selection = TextSelection.collapsed(offset: tec.text.length);
      controller.space();
      expect(tec.text, 'OLA ');
    });

    // ── clear ───────────────────────────────────────────────────────────────

    test('clear empties the text field', () {
      tec.text = 'HELLO WORLD';
      controller.clear();
      expect(tec.text, '');
    });

    test('clear resets cursor position to zero', () {
      tec.text = 'TEST';
      tec.selection = const TextSelection.collapsed(offset: 4);
      controller.clear();
      expect(tec.selection.baseOffset, 0);
    });

    // ── onKey ───────────────────────────────────────────────────────────────

    test('onKey with alpha letter inserts the character', () {
      tec.selection = TextSelection.collapsed(offset: 0);
      controller.onKey(LibrasLetter.a);
      expect(tec.text, 'A');
    });

    test('onKey with a number inserts the digit', () {
      tec.selection = TextSelection.collapsed(offset: 0);
      controller.onKey(LibrasLetter.num7);
      expect(tec.text, '7');
    });

    test('onKey with backspace calls backspace', () {
      tec.text = 'AB';
      tec.selection = TextSelection.collapsed(offset: tec.text.length);
      controller.onKey(LibrasLetter.backspace);
      expect(tec.text, 'A');
    });

    test('onKey with space inserts space', () {
      tec.text = 'OLA';
      tec.selection = TextSelection.collapsed(offset: tec.text.length);
      controller.onKey(LibrasLetter.space);
      expect(tec.text, 'OLA ');
    });

    test('onKey with clear empties the field', () {
      tec.text = 'TEST';
      controller.onKey(LibrasLetter.clear);
      expect(tec.text, '');
    });

    // ── text getter ─────────────────────────────────────────────────────────

    test('text getter reflects current value', () {
      tec.text = 'LIBRAS';
      expect(controller.text, 'LIBRAS');
    });

    // ── notifyListeners ─────────────────────────────────────────────────────

    test('insert notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);
      tec.selection = TextSelection.collapsed(offset: 0);
      controller.insert('A');
      expect(notified, isTrue);
    });

    test('backspace notifies listeners when text is not empty', () {
      tec.text = 'A';
      tec.selection = const TextSelection.collapsed(offset: 1);
      var notified = false;
      controller.addListener(() => notified = true);
      controller.backspace();
      expect(notified, isTrue);
    });

    test('clear notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);
      controller.clear();
      expect(notified, isTrue);
    });
  });

  // ── LibrasLetter model ──────────────────────────────────────────────────────

  group('LibrasLetter', () {
    test('alpha letters have uppercase character', () {
      expect(LibrasLetter.a.character, 'A');
      expect(LibrasLetter.z.character, 'Z');
    });

    test('space has space character', () {
      expect(LibrasLetter.space.character, ' ');
    });

    test('backspace character is null', () {
      expect(LibrasLetter.backspace.character, isNull);
    });

    test('clear character is null', () {
      expect(LibrasLetter.clear.character, isNull);
    });

    test('number keys have digit character', () {
      expect(LibrasLetter.num0.character, '0');
      expect(LibrasLetter.num7.character, '7');
      expect(LibrasLetter.num9.character, '9');
    });

    test('isAlpha is true for letters and false for numbers/actions', () {
      expect(LibrasLetter.a.isAlpha, isTrue);
      expect(LibrasLetter.z.isAlpha, isTrue);
      expect(LibrasLetter.num0.isAlpha, isFalse);
      expect(LibrasLetter.backspace.isAlpha, isFalse);
      expect(LibrasLetter.space.isAlpha, isFalse);
      expect(LibrasLetter.clear.isAlpha, isFalse);
    });

    test('isNumber is true only for digits', () {
      expect(LibrasLetter.num0.isNumber, isTrue);
      expect(LibrasLetter.num9.isNumber, isTrue);
      expect(LibrasLetter.a.isNumber, isFalse);
      expect(LibrasLetter.space.isNumber, isFalse);
    });

    test('isAction is true only for action keys', () {
      expect(LibrasLetter.backspace.isAction, isTrue);
      expect(LibrasLetter.space.isAction, isTrue);
      expect(LibrasLetter.clear.isAction, isTrue);
      expect(LibrasLetter.a.isAction, isFalse);
      expect(LibrasLetter.num1.isAction, isFalse);
    });

    test('assetKey strips the num prefix for digits', () {
      expect(LibrasLetter.a.assetKey, 'a');
      expect(LibrasLetter.num5.assetKey, '5');
      expect(LibrasLetter.backspace.assetKey, 'backspace');
    });

    test('assetName is correct', () {
      expect(LibrasLetter.a.assetName, 'a.png');
      expect(LibrasLetter.num5.assetName, '5.png');
      expect(LibrasLetter.backspace.assetName, 'backspace.png');
    });

    test('semanticsLabel is human-readable', () {
      expect(LibrasLetter.a.semanticsLabel, 'A');
      expect(LibrasLetter.num3.semanticsLabel, '3');
      expect(LibrasLetter.backspace.semanticsLabel, 'Apagar');
      expect(LibrasLetter.space.semanticsLabel, 'Espaço');
      expect(LibrasLetter.clear.semanticsLabel, 'Limpar');
    });
  });
}
