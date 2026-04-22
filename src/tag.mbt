///|
pub struct Tag {
  /// Handle of the tag (`!` included).
  handle : String
  /// The suffix of the tag.
  suffix : String
} derive(Eq, Debug)

///|
pub impl Show for Tag with output(self, logger) {
  self.to_repr().output(logger)
}
