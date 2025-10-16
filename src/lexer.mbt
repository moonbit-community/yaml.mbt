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

///|
pub struct Marker {
  /// The index (in chars) in the input string.
  index : Int
  /// The line (1-indexed).
  line : Int
  /// The column (1-indexed).
  col : Int
}

///|
pub suberror ScanError {
  /// - `mark`: The position at which the error happened in the source.
  /// - `info`: Human-readable details about the error.
  ScanError(mark~ : Marker, info~ : String)
}

///|
pub enum TokenType {
  /// The end of the stream, EOF.
  StreamEnd
  /// A YAML version directive `(Major, Minor)`.
  VersionDirective(Int, Int)
  /// A YAML tag directive `(Handle, Prefix)` (e.g.: `!!str`, `!foo!bar`, ...).
  TagDirective(String, String)
  /// The start of a YAML document (`---`).
  DocumentStart
  /// The end of a YAML document (`...`).
  DocumentEnd
  /// The start of a sequence block.
  ///
  /// Sequence blocks are arrays starting with a `-`.
  BlockSequenceStart
  /// The start of a sequence mapping.
  ///
  /// Sequence mappings are "dictionaries" with "key: value" entries.
  BlockMappingStart
  /// End of the corresponding `BlockSequenceStart` or `BlockMappingStart`.
  BlockEnd
  /// Start of an inline array (`[ a, b ]`).
  FlowSequenceStart
  /// End of an inline array.
  FlowSequenceEnd
  /// Start of an inline mapping (`{ a: b, c: d }`).
  FlowMappingStart
  /// End of an inline mapping.
  FlowMappingEnd
  /// An entry in a block sequence (c.f.: [`TokenType::BlockSequenceStart`]).
  BlockEntry
  /// An entry in a flow sequence (c.f.: [`TokenType::FlowSequenceStart`]).
  FlowEntry
  /// A key in a mapping.
  Key
  /// A value in a mapping.
  Value
  /// A reference to an anchor.
  Alias(String)
  /// A YAML anchor (`&`/`*`).
  Anchor(String)
  /// A YAML tag `(Handle, Suffix)` (starting with bangs `!`).
  Tag(String, String)
  /// A regular YAML scalar.
  Scalar(TScalarStyle, String)
}

///|
pub struct Token {
  marker : Marker
  token_type : TokenType
}

///|
struct SimpleKey {
  /// Whether the token this [`SimpleKey`] refers to may still be a key.
  ///
  /// Sometimes, when we have more context, we notice that what we thought could be a key no
  /// longer can be. In that case, [`Self::possible`] is set to `false`.
  ///
  /// For instance, let us consider the following invalid YAML:
  /// ```yaml
  /// key
  ///   : value
  /// ```
  /// Upon reading the `\n` after `key`, the [`SimpleKey`] that was created for `key` is staled
  /// and [`Self::possible`] set to `false`.
  possible : Bool
  /// Whether the token this [`SimpleKey`] refers to is required to be a key.
  ///
  /// With more context, we may know for sure that the token must be a key. If the YAML is
  /// invalid, it may happen that the token be deemed not a key. In such event, an error has to
  /// be raised. This boolean helps us know when to raise such error.
  ///
  /// TODO(ethiraric, 30/12/2023): Example of when this happens.
  required : Bool
  /// The index of the token referred to by the [`SimpleKey`].
  ///
  /// This is the index in the scanner, which takes into account both the tokens that have been
  /// emitted and those about to be emitted. See [`Scanner::tokens_parsed`] and
  /// [`Scanner::tokens`] for more details.
  token_number : Int
  /// The position at which the token the [`SimpleKey`] refers to is.
  mark : Marker
}

///|
/// An indentation level on the stack of indentations.
struct Indent {
  /// The former indentation level.
  indent : Int
  /// Whether, upon closing, this indents generates a `BlockEnd` token.
  ///
  /// There are levels of indentation which do not start a block. Examples of this would be:
  /// ```yaml
  /// -
  ///   foo # ok
  /// -
  /// bar # ko, bar needs to be indented further than the `-`.
  /// - [
  ///  baz, # ok
  /// quux # ko, quux needs to be indented further than the '-'.
  /// ] # ko, the closing bracket needs to be indented further than the `-`.
  /// ```
  ///
  /// The indentation level created by the `-` is for a single entry in the sequence. Emitting a
  /// `BlockEnd` when this indentation block ends would generate one `BlockEnd` per entry in the
  /// sequence, although we must have exactly one to end the sequence.
  needs_block_end : Bool
}

///|
pub struct Lexer {
  input : StringView
  /// The index (in chars) in the input string.
  index : Int
  /// The line (1-indexed).
  line : Int
  /// The column (1-indexed).
  col : Int
  /// Buffer for tokens to be returned (can hold some temporary tokens that are not yet ready to be returned)
  tokens : Array[Token]
  /// The last error that happened.
  error : ScanError?
  /// Whether we have already emitted the `StreamEnd` token.
  stream_end_produced : Bool
  /// In some flow contexts, the value of a mapping is allowed to be adjacent to the `:`. When it
  /// is, the index at which the `:` may be must be stored in `adjacent_value_allowed_at`.
  adjacent_value_allowed_at : Int
  /// Whether a simple key could potentially start at the current position.
  ///
  /// Simple keys are the opposite of complex keys which are keys starting with `?`.
  simple_key_allowed : Bool
  /// A stack of potential simple keys.
  ///
  /// Refer to the documentation of `SimpleKey` for a more in-depth explanation of what they
  /// are.
  simple_keys : Array[SimpleKey]
  /// The current indentation level.
  indent : Int
  /// List of all block indentation levels we are in (except the current one).
  indents : Array[Indent]
  /// Level of nesting of flow sequences.
  flow_level : Int
  /// The number of tokens that have been returned from the scanner.
  ///
  /// This excludes the tokens from [`Self::tokens`].
  tokens_parsed : Int
  /// Whether a token is ready to be taken from [`Self::tokens`].
  token_available : Bool
  /// Whether all characters encountered since the last newline were whitespace.
  leading_whitespace : Bool
  /// Whether we started a flow mapping.
  ///
  /// This is used to detect implicit flow mapping starts such as:
  /// ```yaml
  /// [ : foo ] # { null: "foo" }
  /// ```
  flow_mapping_started : Bool
  /// Whether we currently are in an implicit flow mapping.
  implicit_flow_mapping : Bool
}
