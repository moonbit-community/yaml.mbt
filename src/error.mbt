///|
pub suberror YamlError {
  /// - `mark`: The position at which the error happened in the source.
  /// - `info`: Human-readable details about the error.
  YamlError(mark~ : Marker, info~ : String)
} derive(Show)
