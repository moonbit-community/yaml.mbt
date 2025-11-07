///|
pub enum TScalarStyle {
  /// A YAML plain scalar.
  Plain
  /// A YAML single quoted scalar.
  SingleQuoted
  /// A YAML double quoted scalar.
  DoubleQuoted
  /// A YAML literal block (`|` block).
  Literal
  /// A YAML folded block (`>` block).
  Folded
} derive(Eq, Show)
