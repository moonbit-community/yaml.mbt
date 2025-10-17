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
  mut possible : Bool
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
struct Lexer {
  mut input : StringView
  /// The index (in chars) in the input string.
  mut index : Int
  /// The line (1-indexed).
  mut line : Int
  /// The column (1-indexed).
  mut col : Int
  /// Buffer for tokens to be returned (can hold some temporary tokens that are not yet ready to be returned)
  tokens : Array[Token]
  /// Buffer for the next characters to consume.
  buffer : @deque.Deque[Char]
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
  mut simple_key_allowed : Bool
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
  mut leading_whitespace : Bool
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

///|
/// The initial size of the buffer in `Lexer` .
///
/// The buffer is pre-allocated to avoid conditions for reallocations each time we
/// consume/push a character. As of now, almost all lookaheads are 4 characters maximum, except:
///   - Escape sequences parsing: some escape codes are 8 characters
///   - Scanning indent in scalars: this looks ahead `indent + 2` characters
///
/// This constant must be set to at least 8. When scanning indent in scalars, the lookahead is done
/// in a single call if and only if the indent is `BUFFER_LEN - 2` or less. If the indent is higher
/// than that, the code will fall back to a loop of lookaheads.
const BUFFER_LEN = 16

///|
pub fn Lexer::new(input : StringView) -> Lexer {
  Lexer::{
    input,
    index: 0,
    line: 1,
    col: 0,
    buffer: @deque.new(capacity=BUFFER_LEN),
    tokens: Array::new(),
    error: None,
    stream_end_produced: false,
    adjacent_value_allowed_at: 0,
    simple_key_allowed: true,
    simple_keys: Array::new(),
    indent: -1,
    indents: Array::new(),
    flow_level: 0,
    tokens_parsed: 0,
    token_available: false,
    leading_whitespace: true,
    flow_mapping_started: false,
    implicit_flow_mapping: false,
  }
}

///|
/// Get the last error that was encountered, if any.
fn Lexer::get_error(self : Lexer) -> ScanError? {
  self.error
}

///|
/// Get current position (`index`, `line`, `col`) as a `Marker`.
fn Lexer::get_marker(self : Lexer) -> Marker {
  Marker::{ index: self.index, line: self.line, col: self.col }
}

///|
/// Fill `self.buffer` with at least `count` characters.
///
/// The characters that are extracted this way are not consumed but only placed in the buffer.
fn Lexer::lookahead(self : Lexer, count : Int) -> Unit {
  if self.buffer.length() >= count {
    return
  }
  for _ in 0..<(count - self.buffer.length()) {
    let chr = match self.input {
      "" => '\u{0}'
      [chr, .. rest] => {
        self.input = rest
        chr
      }
    }
    self.buffer.push_back(chr)
  }
}

///|
/// Consume the next character. It is assumed the next character is a blank.
fn Lexer::skip_blank(self : Lexer) -> Unit {
  ignore(self.buffer.pop_front())
  self.index += 1
  self.col += 1
}

///|
/// Consume the next character. It is assumed the next character is not a blank.
fn Lexer::skip_non_blank(self : Lexer) -> Unit {
  ignore(self.buffer.pop_front())
  self.index += 1
  self.col += 1
  self.leading_whitespace = false
}

///|
/// Consume the next n characters. It is assumed none of the next characters are blanks.
fn Lexer::skip_n_non_blank(self : Lexer, n : Int) -> Unit {
  ignore(self.buffer.drain(start=0, len=n))
  self.index += n
  self.col += n
  self.leading_whitespace = false
}

///|
/// Consume the next character. It is assumed the next character is a newline.
fn Lexer::skip_newline(self : Lexer) -> Unit {
  ignore(self.buffer.pop_front())
  self.index += 1
  self.line += 1
  self.col = 0
  self.leading_whitespace = true
}

///|
/// Consume a linebreak (either CR, LF or CRLF), if any. Do nothing if there's none.
fn Lexer::skip_linebreak(self : Lexer) -> Unit {
  if self.buffer.length() > 2 &&
    self.buffer[0] == '\r' &&
    self.buffer[1] == '\n' {
    // CRLF
    self.skip_blank()
    self.skip_newline()
  } else if self.buffer.length() > 0 && self.buffer[0].is_break() {
    // CR or LF
    self.skip_newline()
  }
}

///|
/// Return the next character in the buffer.
///
/// The character is not consumed.
fn Lexer::char(self : Lexer) -> Char {
  self.buffer[0]
}

///|
/// Look for the next character and return it.
///
/// The character is not consumed.
fn Lexer::look_char(self : Lexer) -> Char {
  self.lookahead(1)
  self.buffer[0]
}

///|
/// Read a character from the input, returning it directly.
/// 
/// The buffer is bypassed and `self.{index, line, col}` needs to be updated manually.
fn Lexer::raw_read_char(self : Lexer) -> Char {
  match self.input {
    "" => '\u{0}'
    [chr, .. rest] => {
      self.input = rest
      chr
    }
  }
}

///|
/// Return whether the next character is `c`.
fn Lexer::char_is(self : Lexer, c : Char) -> Bool {
  self.buffer[0] == c
}

///|
/// Return whether the `TokenType::StreamEnd` event has been emitted.
pub fn Lexer::stream_ended(self : Lexer) -> Bool {
  self.stream_end_produced
}

///|
/// Read and consume a line break (either `\r`, `\n` or `\r\n`).
///
/// A `\n` is pushed into `s`.
fn Lexer::read_break(self : Lexer, buf : StringBuilder) -> Unit {
  let c = self.buffer[0]
  let nc = self.buffer[1]
  guard c.is_break()
  if c == '\r' && nc == '\n' {
    self.skip_blank()
  }
  self.skip_newline()
  buf.write_char('\n')
}

///|
/// Check whether the next characters correspond to an end of document.
///
/// `Self::lookahead` must have been called before calling this function.
fn Lexer::next_is_document_end(self : Lexer) -> Bool {
  guard self.buffer.length() >= 4
  self.buffer[0] == '.' &&
  self.buffer[1] == '.' &&
  self.buffer[2] == '.' &&
  self.buffer[3].is_blank_or_breakz()
}

///|
/// Check whether the next characters correspond to a document indicator.
///
/// `Self::lookahead` must have been called before calling this function.
fn Lexer::next_is_document_indicator(self : Lexer) -> Bool {
  guard self.buffer.length() >= 4
  self.col == 0 &&
  (
    (self.buffer[0] == '-' && self.buffer[1] == '-' && self.buffer[2] == '-') ||
    (self.buffer[0] == '.' && self.buffer[1] == '.' && self.buffer[2] == '.')
  ) &&
  self.buffer[3].is_blank_or_breakz()
}

///|
/// Insert a token at the given position.
fn Lexer::insert_token(self : Lexer, pos : Int, token : Token) -> Unit {
  guard pos <= self.tokens.length()
  self.tokens[pos] = token
}

///|
fn Lexer::allow_simple_key(self : Lexer) -> Unit {
  self.simple_key_allowed = true
}

///|
fn Lexer::disallow_simple_key(self : Lexer) -> Unit {
  self.simple_key_allowed = false
}

///|
/// Fetch the next token in the stream.
/// Returns `ScanError` when the scanner does not find the next expected token.
pub fn Lexer::fetch_next_token(self : Lexer) -> Unit raise ScanError {
  self.lookahead(1)
  self.skip_to_next_token()
  self.stale_simple_keys()
}

///|
/// Mark simple keys that can no longer be keys as such.
///
/// This function sets `possible` to `false` to each key that, now we have more context, we
/// know will not be keys.
///
/// # Errors
/// This function returns an error if one of the key we would stale was required to be a key.
fn Lexer::stale_simple_keys(self : Lexer) -> Unit raise ScanError {
  for sk in self.simple_keys {
    if sk.possible &&
      self.flow_level == 0 &&
      (sk.mark.line < self.line || sk.mark.index + 1024 < self.index) {
      if sk.required {
        raise ScanError::ScanError(
          mark=self.get_marker(),
          info="simple key expect ':'",
        )
      }
      sk.possible = false
    }
  }
}

///|
/// Skip over all whitespace and comments until the next token.
///
/// # Errors
/// This function returns an error if a tabulation is encountered where there should not be
/// one.
fn Lexer::skip_to_next_token(self : Lexer) -> Unit raise ScanError {
  while true {
    match self.look_char() {
      // Tabs may not be used as indentation.
      // "Indentation" only exists as long as a block is started, but does not exist
      // inside of flow-style constructs. Tabs are allowed as part of leading
      // whitespaces outside of indentation.
      // If a flow-style construct is in an indented block, its contents must still be
      // indented. Also, tabs are allowed anywhere in it if it has no content.
      '\t' if self.is_within_block() &&
        self.leading_whitespace &&
        self.col < self.indent => {
        ignore(self.skip_ws_to_eol(SkipTabs::Yes))
        // If we have content on that line with a tab, return an error.
        if self.char().is_breakz() {
          raise ScanError::ScanError(
            mark=self.get_marker(),
            info="tabs disallowed within this context (block indentation)",
          )
        }
      }
      '\t' | ' ' => self.skip_blank()
      '\n' | '\r' => {
        self.lookahead(2)
        self.skip_linebreak()
        if self.flow_level == 0 {
          self.allow_simple_key()
        }
      }
      '#' =>
        while self.look_char().is_breakz() {
          self.skip_non_blank()
        }
      _ => break
    }
  }
}

///|
/// Skip yaml whitespace at most up to eol. Also skips comments.
fn Lexer::skip_ws_to_eol(
  self : Lexer,
  skip_tabs : SkipTabs,
) -> SkipTabs raise ScanError {
  let mut encountered_tab = false
  let mut has_onemore_whitespace = false
  while true {
    match self.look_char() {
      ' ' => {
        has_onemore_whitespace = true
        self.skip_blank()
      }
      '\t' if skip_tabs != SkipTabs::No => {
        encountered_tab = true
        self.skip_blank()
      }
      // YAML comments must be preceded by whitespace.
      '#' if !encountered_tab && !has_onemore_whitespace =>
        raise ScanError::ScanError(
          mark=self.get_marker(),
          info="comments must be separated from other tokens by whitespace",
        )
      '#' =>
        while !self.look_char().is_breakz() {
          self.skip_non_blank()
        }
      _ => break
    }
  }
  SkipTabs::Result(encountered_tab~, has_onemore_whitespace~)
}

///|
fn Lexer::is_within_block(self : Lexer) -> Bool {
  !self.indents.is_empty()
}

///|
enum SkipTabs {
  /// Skip all tabs as whitespace.
  Yes
  /// Don't skip any tab. Return from the function when encountering one.
  No
  /// Return value from the function.
  /// - `encountered_tab`: Whether tabs were encountered.
  /// - `has_onemore_whitespace`: Whether at least 1 valid yaml whitespace has been encountered.
  Result(encountered_tab~ : Bool, has_onemore_whitespace~ : Bool)
} derive(Eq)
