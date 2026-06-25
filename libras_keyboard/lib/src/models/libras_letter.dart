/// Represents a single key on the Libras datilologia keyboard.
enum LibrasLetter {
  a, b, c, d, e, f, g, h, i, j, k, l, m,
  n, o, p, q, r, s, t, u, v, w, x, y, z,
  num0, num1, num2, num3, num4, num5, num6, num7, num8, num9,
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
        if (isNumber) return name.substring(3); // 'num7' -> '7'
        return name.toUpperCase();
    }
  }

  /// Whether this key inserts a letter A–Z.
  bool get isAlpha => index <= LibrasLetter.z.index;

  /// Whether this key inserts a digit 0–9.
  bool get isNumber =>
      index >= LibrasLetter.num0.index && index <= LibrasLetter.num9.index;

  /// Whether this key is an action key (backspace, space, clear).
  bool get isAction => !isAlpha && !isNumber;

  /// The asset key used to resolve this key's image, e.g. `'a'` or `'7'`.
  ///
  /// Letters and action keys use their enum name; digits use the bare numeral
  /// (so the asset file is `7.png`, not `num7.png`).
  String get assetKey => isNumber ? name.substring(3) : name;

  /// The asset filename for this key's image, relative to `assets/libras/`.
  String get assetName => '$assetKey.png';

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
        if (isNumber) return name.substring(3);
        return name.toUpperCase();
    }
  }
}
