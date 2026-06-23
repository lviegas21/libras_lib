/// Represents a single key on the Libras datilologia keyboard.
enum LibrasLetter {
  a, b, c, d, e, f, g, h, i, j, k, l, m,
  n, o, p, q, r, s, t, u, v, w, x, y, z,
  backspace,
  space,
  clear;

  /// The text value inserted when this key is pressed.
  /// Returns `null` for action keys (backspace, space, clear).
  String? get character {
    switch (this) {
      case LibrasLetter.backspace:
      case LibrasLetter.clear:
        return null;
      case LibrasLetter.space:
        return ' ';
      default:
        return name.toUpperCase();
    }
  }

  /// Whether this key inserts a character (as opposed to performing an action).
  bool get isAlpha => index <= LibrasLetter.z.index;

  /// Whether this key is an action key (backspace, space, clear).
  bool get isAction => !isAlpha;

  /// The asset filename for this letter's SVG, relative to `assets/libras/`.
  String get assetName => '$name.svg';

  /// Human-readable label used for semantics / accessibility.
  String get semanticsLabel {
    switch (this) {
      case LibrasLetter.backspace:
        return 'Apagar';
      case LibrasLetter.space:
        return 'Espaço';
      case LibrasLetter.clear:
        return 'Limpar';
      default:
        return name.toUpperCase();
    }
  }
}
