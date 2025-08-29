///|
/// YAML Parser implementation
/// Simplified version based on js-yaml v3.13.1

// Parser state
struct ParserState {
  input : String
  mut position : Int
  mut line : Int
  mut column : Int
  length : Int
  options : ParseOptions
}

///|
fn ParserState::new(input : String, options : ParseOptions) -> ParserState {
  let sanitized_input = sanitize_input_internal(input)
  {
    input: sanitized_input,
    position: 0,
    line: 1,
    column: 1,
    length: sanitized_input.length(),
    options,
  }
}

///|
fn ParserState::current_char(self : ParserState) -> Int {
  if self.position >= self.length {
    0
  } else {
    self.input[self.position]
  }
}

///|
fn ParserState::peek_char(self : ParserState, offset : Int) -> Int {
  let pos = self.position + offset
  if pos >= self.length {
    0
  } else {
    self.input[pos]
  }
}

///|
fn ParserState::advance(self : ParserState) -> Unit {
  if self.position < self.length {
    let ch = self.current_char()
    self.position += 1
    if is_eol(ch) {
      self.line += 1
      self.column = 1
    } else {
      self.column += 1
    }
  }
}

///|
fn ParserState::skip_whitespace(self : ParserState) -> Unit {
  while is_whitespace_or_eol(self.current_char()) {
    self.advance()
  }
}

///|
fn ParserState::read_until(
  self : ParserState,
  predicate : (Int) -> Bool,
) -> String {
  let start = self.position
  while self.position < self.length && predicate(self.current_char()) {
    self.advance()
  }
  self.input.substring(start~, end=self.position)
}

///|
fn ParserState::error(self : ParserState, message : String) -> YamlParseError {
  YamlParseError(YamlError::ParseError(message, self.line, self.column))
}

///|
/// Sanitize input string for parsing (internal)
fn sanitize_input_internal(input : String) -> String {
  // Use the improved sanitize_input from utils
  let normalized = normalize_line_endings(input)
  sanitize_input(normalized)
}

///|
/// Parse a scalar value
fn parse_scalar(state : ParserState) -> YamlValue raise YamlParseError {
  state.skip_whitespace()
  if state.current_char() == 0 {
    return YamlValue::Null
  }
  let ch = state.current_char()

  // String literals
  if ch == DOUBLE_QUOTE {
    parse_double_quoted_string(state)
  } else if ch == SINGLE_QUOTE {
    parse_single_quoted_string(state)
  } else {
    parse_plain_scalar(state)
  }
}

///|
/// Parse double-quoted string
fn parse_double_quoted_string(
  state : ParserState,
) -> YamlValue raise YamlParseError {
  state.advance() // Skip opening quote
  let mut result = ""
  while state.current_char() != DOUBLE_QUOTE && state.current_char() != 0 {
    let ch = state.current_char()
    if ch == BACKSLASH {
      state.advance()
      let escaped = state.current_char()
      match escaped {
        0x22 => result += "\"" // " 
        0x5c => result += "\\" // \
        0x0a => result += "\n" // \n
        0x09 => result += "\t" // \t
        _ => {
          result += "\\"
          result += Char::from_int(escaped).to_string()
        }
      }
    } else {
      result += Char::from_int(ch).to_string()
    }
    state.advance()
  }
  if state.current_char() == DOUBLE_QUOTE {
    state.advance() // Skip closing quote
    YamlValue::String(result)
  } else {
    raise state.error("Unterminated quoted string")
  }
}

///|
/// Parse single-quoted string
fn parse_single_quoted_string(
  state : ParserState,
) -> YamlValue raise YamlParseError {
  state.advance() // Skip opening quote
  let mut result = ""
  while state.current_char() != SINGLE_QUOTE && state.current_char() != 0 {
    let ch = state.current_char()
    if ch == SINGLE_QUOTE && state.peek_char(1) == SINGLE_QUOTE {
      // Escaped single quote
      result += "'"
      state.advance()
      state.advance()
    } else {
      result += Char::from_int(ch).to_string()
      state.advance()
    }
  }
  if state.current_char() == SINGLE_QUOTE {
    state.advance() // Skip closing quote
    YamlValue::String(result)
  } else {
    raise state.error("Unterminated quoted string")
  }
}

///|
/// Parse plain scalar (unquoted)
fn parse_plain_scalar(state : ParserState) -> YamlValue {
  let text = state.read_until(fn(ch) {
    !is_whitespace_or_eol(ch) &&
    !is_flow_indicator(ch) &&
    ch != COLON &&
    ch != 0
  })
  if text.is_empty() {
    return YamlValue::Null
  }

  // Try to parse as number
  match parse_number(text) {
    Some(value) => value
    None =>
      // Check for boolean values
      match text.to_lower() {
        "true" | "yes" | "on" => YamlValue::Bool(true)
        "false" | "no" | "off" => YamlValue::Bool(false)
        "null" | "~" | "" => YamlValue::Null
        _ => YamlValue::String(text)
      }
  }
}

///|
/// Try to parse a string as a number
fn parse_number(text : String) -> YamlValue? {
  // Simple number parsing - this is a basic implementation
  // Try integer first - simple check for digits only
  if is_all_digits(text) {
    let i = parse_int_simple(text)
    Some(YamlValue::Int(i))
  } else if contains_dot(text) {
    // Try to parse as float
    let f = parse_double_simple(text)
    Some(YamlValue::Float(f))
  } else {
    None
  }
}

///|
/// Check if string contains only digits (and optional minus sign)
fn is_all_digits(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  let start = if text[0] == 45 { 1 } else { 0 } // 45 is '-'
  if start >= text.length() {
    return false
  }
  for i = start; i < text.length(); i = i + 1 {
    let ch = text[i]
    if ch < 48 || ch > 57 { // 48-57 are '0'-'9'
      return false
    }
  }
  true
}

///|
/// Check if string contains a dot
fn contains_dot(text : String) -> Bool {
  for i = 0; i < text.length(); i = i + 1 {
    if text[i] == 46 { // 46 is '.'
      return true
    }
  }
  false
}

///|
/// Simple integer parsing
fn parse_int_simple(text : String) -> Int {
  let mut result = 0
  let mut negative = false
  let start = if text[0] == 45 { // 45 is '-'
    negative = true
    1
  } else {
    0
  }
  for i = start; i < text.length(); i = i + 1 {
    let digit = text[i] - 48 // Convert '0'-'9' to 0-9
    result = result * 10 + digit
  }
  if negative {
    -result
  } else {
    result
  }
}

///|
/// Simple double parsing - basic implementation
fn parse_double_simple(text : String) -> Double {
  // Very basic implementation - just convert to Int and then to Double for now
  // A full implementation would handle decimal points properly
  let parts = text.split(".")
  if parts.length() == 2 {
    let int_part = parse_int_simple(parts[0])
    let frac_part = parse_int_simple(parts[1])
    let divisor = power_of_10(parts[1].length())
    int_part.to_double() + frac_part.to_double() / divisor.to_double()
  } else {
    parse_int_simple(text).to_double()
  }
}

///|
/// Calculate 10^n
fn power_of_10(n : Int) -> Int {
  let mut result = 1
  for i = 0; i < n; i = i + 1 {
    result = result * 10
  }
  result
}

///|
/// Parse array (sequence)
fn parse_array(state : ParserState) -> YamlValue raise YamlParseError {
  state.advance() // Skip '['
  state.skip_whitespace()
  let result = []
  if state.current_char() == RIGHT_SQUARE_BRACKET {
    state.advance()
    return YamlValue::Array(result)
  }
  while true {
    let value = parse_value(state)
    result.push(value)
    state.skip_whitespace()
    let ch = state.current_char()
    if ch == RIGHT_SQUARE_BRACKET {
      state.advance()
      break
    } else if ch == COMMA {
      state.advance()
      state.skip_whitespace()
    } else if ch == 0 {
      raise state.error("Unterminated array")
    } else {
      raise state.error("Expected ',' or ']' in array")
    }
  }
  YamlValue::Array(result)
}

///|
/// Parse object (mapping)
fn parse_object(state : ParserState) -> YamlValue raise YamlParseError {
  state.advance() // Skip '{'
  state.skip_whitespace()
  let result = Map::new()
  if state.current_char() == RIGHT_CURLY_BRACKET {
    state.advance()
    return YamlValue::Object(result)
  }
  while true {
    // Parse key
    let key_value = parse_value(state)
    let key = match key_value {
      String(s) => s
      _ => raise state.error("Object key must be a string")
    }
    state.skip_whitespace()
    if state.current_char() != COLON {
      raise state.error("Expected ':' after object key")
    }
    state.advance() // Skip ':'
    state.skip_whitespace()

    // Parse value
    let value = parse_value(state)
    if !state.options.allow_duplicate_keys && result.contains(key) {
      raise state.error("Duplicate key: \{key}")
    }
    result.set(key, value)
    state.skip_whitespace()
    let ch = state.current_char()
    if ch == RIGHT_CURLY_BRACKET {
      state.advance()
      break
    } else if ch == COMMA {
      state.advance()
      state.skip_whitespace()
    } else if ch == 0 {
      raise state.error("Unterminated object")
    } else {
      raise state.error("Expected ',' or '}' in object")
    }
  }
  YamlValue::Object(result)
}

///|
/// Parse any YAML value
fn parse_value(state : ParserState) -> YamlValue raise YamlParseError {
  state.skip_whitespace()
  let ch = state.current_char()
  if ch == 0 {
    YamlValue::Null
  } else if ch == LEFT_SQUARE_BRACKET {
    parse_array(state)
  } else if ch == LEFT_CURLY_BRACKET {
    parse_object(state)
  } else {
    parse_scalar(state)
  }
}

///|
/// Check if current position is at a document separator
fn ParserState::is_at_document_separator(self : ParserState) -> Bool {
  self.current_char() == MINUS &&
  self.peek_char(1) == MINUS &&
  self.peek_char(2) == MINUS &&
  (self.peek_char(3) == 0 || is_whitespace_or_eol(self.peek_char(3)))
}

///|
/// Skip document separator (---)
fn ParserState::skip_document_separator(self : ParserState) -> Unit {
  if self.is_at_document_separator() {
    self.advance() // Skip first '-'
    self.advance() // Skip second '-'
    self.advance() // Skip third '-'
    self.skip_whitespace()
  }
}

///|
/// Read all documents from the input
fn ParserState::read_documents(self : ParserState) -> Array[YamlValue] raise YamlParseError {
  let documents = []
  self.skip_whitespace()
  
  // Handle initial document separator if present
  self.skip_document_separator()
  
  while self.current_char() != 0 {
    self.skip_whitespace()
    if self.current_char() == 0 {
      break
    }
    
    let document = parse_value(self)
    documents.push(document)
    
    self.skip_whitespace()
    
    if self.is_at_document_separator() {
      self.skip_document_separator()
    } else if self.current_char() != 0 {
      // If there's more content but no separator, it's an error
      break
    }
  }
  
  documents
}

///|
/// Parse a YAML string and return the parsed value
pub fn parse(
  content : String,
  options? : ParseOptions = ParseOptions::new(),
) -> YamlValue raise YamlParseError {
  let state = ParserState::new(content, options)
  
  // Use read_documents to get all documents
  let documents = state.read_documents()
  
  if documents.length() == 0 {
    YamlValue::Null
  } else if documents.length() == 1 {
    documents[0]
  } else {
    raise state.error(
      "Found more than 1 document in the stream: expected a single document",
    )
  }
}

///|
/// Parse multiple YAML documents from a single string
/// Returns an array of parsed documents
pub fn parse_all(
  content : String,
  options? : ParseOptions = ParseOptions::new(),
) -> Array[YamlValue] raise YamlParseError {
  let state = ParserState::new(content, options)
  state.read_documents()
}
