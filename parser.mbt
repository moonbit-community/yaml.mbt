///|
/// YAML Parser implementation
/// Simplified version based on js-yaml v3.13.1

// Parser state
struct ParserState {
  mut input : String
  mut position : Int
  mut line : Int
  mut column : Int
  mut length : Int
  options : ParseOptions
}

///|
fn ParserState::new(input : String, options : ParseOptions) -> ParserState {
  let sanitized_input = sanitize_input(input)
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
    self.input[self.position].to_int()
  }
}

///|
fn ParserState::peek_char(self : ParserState, offset : Int) -> Int {
  let pos = self.position + offset
  if pos >= self.length {
    0
  } else {
    self.input[pos].to_int()
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
  self.input.substring(start, self.position)
}

///|
fn ParserState::error(self : ParserState, message : String) -> YamlError {
  YamlError::ParseError(message, self.line, self.column)
}

///|
/// Sanitize input string for parsing
fn sanitize_input(input : String) -> String {
  let mut result = input

  // Add trailing newline if not exists
  if result.length() > 0 && !is_eol(result[result.length() - 1].to_int()) {
    result = result + "\n"
  }

  // Strip BOM
  if result.length() > 0 && result[0].to_int() == BOM {
    result = result.substring(1)
  }

  // Add string terminator
  result + "\u{0000}"
}

///|
/// Parse a scalar value
fn parse_scalar(state : ParserState) -> YamlValue! {
  state.skip_whitespace()
  if state.current_char() == 0 {
    return YamlValue::Null
  }
  let ch = state.current_char()

  // String literals
  if ch == DOUBLE_QUOTE {
    parse_double_quoted_string(state)!
  } else if ch == SINGLE_QUOTE {
    parse_single_quoted_string(state)!
  } else {
    parse_plain_scalar(state)!
  }
}

///|
/// Parse double-quoted string
fn parse_double_quoted_string(state : ParserState) -> YamlValue! {
  state.advance() // Skip opening quote
  let mut result = ""
  while state.current_char() != DOUBLE_QUOTE && state.current_char() != 0 {
    let ch = state.current_char()
    if ch == BACKSLASH {
      state.advance()
      let escaped = state.current_char()
      match escaped {
        0x22 /* " */ => result += "\""
        0x5c /* \ */ => result += "\\"
        0x0a /* \n */ => result += "\n"
        0x09 /* \t */ => result += "\t"
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
fn parse_single_quoted_string(state : ParserState) -> YamlValue raise {
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
fn parse_plain_scalar(state : ParserState) -> YamlValue raise {
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
  // Try integer first
  try {
    let i = text.to_int()
    Some(YamlValue::Int(i))
  } catch {
    _ =>
      // Try float
      try {
        let f = text.to_double()
        Some(YamlValue::Float(f))
      } catch {
        _ => None
      }
  }
}

///|
/// Parse array (sequence)
fn parse_array(state : ParserState) -> YamlValue! {
  state.advance() // Skip '['
  state.skip_whitespace()
  
  let result = []
  
  if state.current_char() == RIGHT_SQUARE_BRACKET {
    state.advance()
    return YamlValue::Array(result)
  }
  
  while true {
    let value = parse_value(state)!
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
fn parse_object(state : ParserState) -> YamlValue! {
  state.advance() // Skip '{'
  state.skip_whitespace()
  
  let result = Map::new()
  
  if state.current_char() == RIGHT_CURLY_BRACKET {
    state.advance()
    return YamlValue::Object(result)
  }
  
  while true {
    // Parse key
    let key_value = parse_value(state)!
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
    let value = parse_value(state)!
    
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
fn parse_value(state : ParserState) -> YamlValue! {
  state.skip_whitespace()
  
  let ch = state.current_char()
  
  if ch == 0 {
    YamlValue::Null
  } else if ch == LEFT_SQUARE_BRACKET {
    parse_array(state)!
  } else if ch == LEFT_CURLY_BRACKET {
    parse_object(state)!
  } else {
    parse_scalar(state)!
  }
}

///|
/// Parse a YAML string and return the parsed value
pub fn parse(content : String, options~ : ParseOptions = ParseOptions::new()) -> YamlValue! {
  let state = ParserState::new(content, options)
  let result = parse_value(state)!
  
  // Skip any remaining whitespace
  state.skip_whitespace()
  
  // Check for additional content (multiple documents)
  if state.current_char() != 0 {
    if state.current_char() == MINUS && 
       state.peek_char(1) == MINUS && 
       state.peek_char(2) == MINUS {
      raise state.error("Found more than 1 document in the stream: expected a single document")
    }
  }
  
  result
}
