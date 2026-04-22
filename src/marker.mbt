///|
pub struct Marker {
  /// The index (in chars) in the input string.
  index : Int
  /// The line (1-indexed).
  line : Int
  /// The column (1-indexed).
  col : Int
} derive(Debug, Eq)

///|
pub impl Show for Marker with output(self, logger) {
  self.to_repr().output(logger)
}
