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
} derive(Eq, Debug)

///|
pub impl Show for TScalarStyle with output(self, logger) {
  self.to_repr().output(logger)
}
