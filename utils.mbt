///| Utility functions for YAML processing
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// Clone a YamlValue
pub fn clone_yaml_value(value : YamlValue) -> YamlValue {
  match value {
    Null => Null
    Bool(b) => Bool(b)
    Int(i) => Int(i)
    Float(f) => Float(f)
    String(s) => String(s)
    Array(arr) => {
      let new_arr = []
      for i = 0; i < arr.length(); i = i + 1 {
        new_arr.push(clone_yaml_value(arr[i]))
      }
      Array(new_arr)
    }
    Object(obj) => {
      let new_obj = Map::new()
      obj.each(fn(key, value) { new_obj.set(key, clone_yaml_value(value)) })
      Object(new_obj)
    }
  }
}

///|
/// Sanitize input string for parsing
/// Handles BOM, line endings, and ensures proper termination
pub fn sanitize_input(input : String) -> String {
  let mut result = input
  
  // Convert input to string if it isn't already
  result = result.to_string()
  
  if result.length() > 0 {
    // Add trailing newline if not exists
    let last_char = result[result.length() - 1]
    if !is_eol(last_char) {
      result = result + "\n"
    }
    
    // Strip BOM (Byte Order Mark)
    if result[0] == BOM {
      result = result.substring(start=1)
    }
  }
  
  // Use 0 as string terminator for easier bounds checking
  result + "\u{0000}"
}

///|
/// Normalize line endings to LF
pub fn normalize_line_endings(input : String) -> String {
  let mut result = ""
  let mut i = 0
  while i < input.length() {
    let ch = input[i]
    if ch == CARRIAGE_RETURN {
      if i + 1 < input.length() && input[i + 1] == LINE_FEED {
        // CRLF -> LF
        result += "\n"
        i += 2
      } else {
        // CR -> LF
        result += "\n"
        i += 1
      }
    } else {
      result += Char::from_int(ch).to_string()
      i += 1
    }
  }
  result
}

///|
/// Check if string is a valid YAML document start (---)
pub fn is_document_start(line : String) -> Bool {
  let trimmed = trim_whitespace(line)
  trimmed == "---" || trimmed.starts_with("--- ")
}

///|
/// Check if string is a YAML document end (...)
pub fn is_document_end(line : String) -> Bool {
  let trimmed = trim_whitespace(line)
  trimmed == "..." || trimmed.starts_with("... ")
}

///|
/// Trim leading and trailing whitespace
pub fn trim_whitespace(s : String) -> String {
  let mut start = 0
  let mut end = s.length()
  
  // Find first non-whitespace character
  while start < end && is_whitespace_or_eol(s[start]) {
    start += 1
  }
  
  // Find last non-whitespace character
  while end > start && is_whitespace_or_eol(s[end - 1]) {
    end -= 1
  }
  
  if start >= end {
    ""
  } else {
    s.substring(start~, end~)
  }
}

///|
/// Count leading whitespace characters
pub fn count_leading_whitespace(s : String) -> Int {
  let mut count = 0
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch == SPACE {
      count += 1
    } else if ch == TAB {
      count += 8 // Treat tab as 8 spaces
    } else {
      break
    }
  }
  count
}

///|
/// Check if a line is empty or contains only whitespace
pub fn is_empty_line(line : String) -> Bool {
  for i = 0; i < line.length(); i = i + 1 {
    if !is_whitespace_or_eol(line[i]) {
      return false
    }
  }
  true
}

///|
/// Split string into lines, preserving line ending information
pub fn split_lines(input : String) -> Array[String] {
  let lines = []
  let mut current = ""
  
  let mut i = 0
  while i < input.length() {
    let ch = input[i]
    if ch == LINE_FEED {
      lines.push(current)
      current = ""
      i += 1
    } else if ch == CARRIAGE_RETURN {
      lines.push(current)
      current = ""
      i += 1
      // Skip following LF if present
      if i < input.length() && input[i] == LINE_FEED {
        i += 1
      }
    } else {
      current += Char::from_int(ch).to_string()
      i += 1
    }
  }
  
  // Add last line if not empty
  if current.length() > 0 {
    lines.push(current)
  }
  
  lines
}

///|
/// Escape special characters for YAML output
pub fn escape_yaml_string(s : String) -> String {
  let mut result = ""
  
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    match ch {
      DOUBLE_QUOTE => result += "\\\""
      BACKSLASH => result += "\\\\"
      LINE_FEED => result += "\\n"
      CARRIAGE_RETURN => result += "\\r"
      TAB => result += "\\t"
      0x08 => result += "\\b" // backspace
      0x0c => result += "\\f" // form feed
      0x07 => result += "\\a" // bell
      0x0b => result += "\\v" // vertical tab
      0x00 => result += "\\0" // null
      0x1b => result += "\\e" // escape
      _ => 
        if ch < 32 || ch == 0x7f {
          // Non-printable ASCII characters
          result += "\\x" + format_hex_byte(ch)
        } else if ch > 0x7f && ch < 0xa0 {
          // Control characters in Latin-1 supplement
          result += "\\x" + format_hex_byte(ch)
        } else if ch > 0xffff {
          // Characters beyond BMP need \U notation
          result += "\\U" + format_hex_unicode(ch)
        } else if ch > 0x7f {
          // Unicode characters in BMP can use \u notation
          result += "\\u" + format_hex_unicode_short(ch)
        } else {
          result += Char::from_int(ch).to_string()
        }
    }
  }
  
  result
}

///|
/// Format byte as 2-digit hex
fn format_hex_byte(byte : Int) -> String {
  let hex_digits = "0123456789abcdef"
  let high = (byte / 16) % 16
  let low = byte % 16
  Char::from_int(hex_digits[high]).to_string() + 
  Char::from_int(hex_digits[low]).to_string()
}

///|
/// Format Unicode code point as 8-digit hex (for \U)
fn format_hex_unicode(codepoint : Int) -> String {
  let hex_digits = "0123456789abcdef"
  let mut result = ""
  let mut val = codepoint
  
  for i = 0; i < 8; i = i + 1 {
    let digit = val % 16
    result = Char::from_int(hex_digits[digit]).to_string() + result
    val /= 16
  }
  
  result
}

///|
/// Format Unicode code point as 4-digit hex (for \u)
fn format_hex_unicode_short(codepoint : Int) -> String {
  let hex_digits = "0123456789abcdef"
  let mut result = ""
  let mut val = codepoint
  
  for i = 0; i < 4; i = i + 1 {
    let digit = val % 16
    result = Char::from_int(hex_digits[digit]).to_string() + result
    val /= 16
  }
  
  result
}

///|
/// Unescape YAML string (decode escape sequences)
pub fn unescape_yaml_string(s : String) -> String {
  let mut result = ""
  let mut i = 0
  
  while i < s.length() {
    let ch = s[i]
    if ch == BACKSLASH && i + 1 < s.length() {
      let next_ch = s[i + 1]
      match next_ch {
        0x22 => { // \"
          result += "\""
          i += 2
        }
        0x5c => { // \\
          result += "\\"
          i += 2
        }
        0x6e => { // \n
          result += "\n"
          i += 2
        }
        0x72 => { // \r
          result += "\r"
          i += 2
        }
        0x74 => { // \t
          result += "\t"
          i += 2
        }
        0x62 => { // \b
          result += "\u{08}"
          i += 2
        }
        0x66 => { // \f
          result += "\u{0c}"
          i += 2
        }
        0x61 => { // \a
          result += "\u{07}"
          i += 2
        }
        0x76 => { // \v
          result += "\u{0b}"
          i += 2
        }
        0x30 => { // \0
          result += "\u{00}"
          i += 2
        }
        0x65 => { // \e
          result += "\u{1b}"
          i += 2
        }
        0x78 => { // \x (hex escape)
          if i + 3 < s.length() {
            let hex_str = s.substring(start=i + 2, end=i + 4)
            match parse_hex_byte(hex_str) {
              Some(byte_val) => {
                result += Char::from_int(byte_val).to_string()
                i += 4
              }
              None => {
                result += Char::from_int(ch).to_string()
                i += 1
              }
            }
          } else {
            result += Char::from_int(ch).to_string()
            i += 1
          }
        }
        0x75 => { // \u (unicode escape)
          if i + 5 < s.length() {
            let hex_str = s.substring(start=i + 2, end=i + 6)
            match parse_hex_unicode(hex_str) {
              Some(unicode_val) => {
                result += Char::from_int(unicode_val).to_string()
                i += 6
              }
              None => {
                result += Char::from_int(ch).to_string()
                i += 1
              }
            }
          } else {
            result += Char::from_int(ch).to_string()
            i += 1
          }
        }
        0x55 => { // \U (long unicode escape)
          if i + 9 < s.length() {
            let hex_str = s.substring(start=i + 2, end=i + 10)
            match parse_hex_unicode(hex_str) {
              Some(unicode_val) => {
                result += codepoint_to_string(unicode_val)
                i += 10
              }
              None => {
                result += Char::from_int(ch).to_string()
                i += 1
              }
            }
          } else {
            result += Char::from_int(ch).to_string()
            i += 1
          }
        }
        _ => {
          result += Char::from_int(ch).to_string()
          i += 1
        }
      }
    } else {
      result += Char::from_int(ch).to_string()
      i += 1
    }
  }
  
  result
}

///|
/// Parse hex byte string to integer
fn parse_hex_byte(hex_str : String) -> Int? {
  if hex_str.length() != 2 {
    return None
  }
  
  let mut result = 0
  for i = 0; i < hex_str.length(); i = i + 1 {
    let ch = hex_str[i]
    let digit = if ch >= 48 && ch <= 57 { // 0-9
      ch - 48
    } else if ch >= 65 && ch <= 70 { // A-F
      ch - 65 + 10
    } else if ch >= 97 && ch <= 102 { // a-f
      ch - 97 + 10
    } else {
      return None
    }
    result = result * 16 + digit
  }
  
  Some(result)
}

///|
/// Parse hex unicode string to integer
fn parse_hex_unicode(hex_str : String) -> Int? {
  if hex_str.length() != 4 && hex_str.length() != 8 {
    return None
  }
  
  let mut result = 0
  for i = 0; i < hex_str.length(); i = i + 1 {
    let ch = hex_str[i]
    let digit = if ch >= 48 && ch <= 57 { // 0-9
      ch - 48
    } else if ch >= 65 && ch <= 70 { // A-F
      ch - 65 + 10
    } else if ch >= 97 && ch <= 102 { // a-f
      ch - 97 + 10
    } else {
      return None
    }
    result = result * 16 + digit
  }
  
  Some(result)
}

///|
/// Check if string needs quoting in YAML
pub fn needs_quoting(s : String) -> Bool {
  if s.length() == 0 {
    return true
  }
  
  // Check for special YAML values
  let lower = s.to_lower()
  if lower == "true" || lower == "false" || lower == "null" || 
     lower == "yes" || lower == "no" || lower == "on" || lower == "off" ||
     lower == "~" {
    return true
  }
  
  // Check if it looks like a number
  if is_numeric_string(s) {
    return true
  }
  
  // Check for special characters
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if is_flow_indicator(ch) || ch == COLON || ch == SHARP || 
       ch == ASTERISK || ch == AMPERSAND || ch == EXCLAMATION ||
       ch == VERTICAL_LINE || ch == GREATER_THAN || ch == SMALLER_THAN ||
       ch == QUESTION || ch == COMMERCIAL_AT || ch == GRAVE_ACCENT ||
       ch == PERCENT {
      return true
    }
  }
  
  false
}

///|
/// Check if string looks like a number
pub fn is_numeric_string(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  
  let mut has_digit = false
  let mut has_dot = false
  let mut start = 0
  
  // Check for sign
  if s[0] == PLUS || s[0] == MINUS {
    start = 1
  }
  
  for i = start; i < s.length(); i = i + 1 {
    let ch = s[i]
    if is_decimal_digit(ch) {
      has_digit = true
    } else if ch == DOT && !has_dot {
      has_dot = true
    } else {
      return false
    }
  }
  
  has_digit
}

///|
/// Process folded string (YAML >)
/// Folds newlines into spaces while preserving paragraph breaks
pub fn process_folded_string(s : String) -> String {
  let lines = split_lines(s)
  let mut result = ""
  let mut i = 0
  
  while i < lines.length() {
    let line = lines[i]
    let trimmed = trim_whitespace(line)
    
    if trimmed.length() == 0 {
      // Empty line - preserve as paragraph break
      result += "\n"
    } else {
      // Non-empty line
      if result.length() > 0 && !string_ends_with(result, "\n") {
        result += " " // Fold previous line ending into space
      }
      result += trimmed
    }
    
    i += 1
  }
  
  result
}

///|
/// Process literal string (YAML |)
/// Preserves line breaks exactly as written
pub fn process_literal_string(s : String) -> String {
  // Remove common leading indentation
  let lines = split_lines(s)
  if lines.length() == 0 {
    return ""
  }
  
  // Find minimum indentation (excluding empty lines)
  let mut min_indent = -1
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if !is_empty_line(line) {
      let indent = count_leading_whitespace(line)
      if min_indent == -1 || indent < min_indent {
        min_indent = indent
      }
    }
  }
  
  if min_indent <= 0 {
    return join(lines, "\n")
  }
  
  // Remove common indentation
  let processed_lines = []
  for i = 0; i < lines.length(); i = i + 1 {
    let line = lines[i]
    if is_empty_line(line) {
      processed_lines.push("")
    } else {
      let spaces_to_remove = min_indent.min(count_leading_whitespace(line))
      processed_lines.push(line.substring(start=spaces_to_remove))
    }
  }
  
  join(processed_lines, "\n")
}

///|
/// Determine if string should use literal (|) or folded (>) style
pub fn suggest_block_style(s : String) -> StyleVariant {
  if s.contains("\n\n") {
    // Has paragraph breaks - literal style preserves them better
    Literal
  } else if s.contains("\n") {
    // Has line breaks but no paragraphs - folded might be better
    Folded
  } else {
    // Single line - use plain style
    Plain
  }
}

///|
/// Smart quote detection for strings
pub fn determine_quote_style(s : String) -> StyleVariant {
  // Check if string needs quoting at all
  if !needs_quoting(s) {
    return Plain
  }
  
  // Count quote types to choose the best one
  let mut double_quotes = 0
  let mut single_quotes = 0
  let mut has_escapes = false
  
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    match ch {
      DOUBLE_QUOTE => double_quotes += 1
      SINGLE_QUOTE => single_quotes += 1
      BACKSLASH | LINE_FEED | CARRIAGE_RETURN | TAB => has_escapes = true
      _ => 
        if ch < 32 || ch == 0x7f {
          has_escapes = true
        }
    }
  }
  
  if has_escapes {
    // Need escape sequences - must use double quotes
    DoubleQuoted
  } else if double_quotes > 0 && single_quotes == 0 {
    // Has double quotes but no single quotes
    SingleQuoted
  } else if single_quotes > 0 && double_quotes == 0 {
    // Has single quotes but no double quotes
    DoubleQuoted
  } else if single_quotes <= double_quotes {
    // Equal or fewer single quotes
    SingleQuoted
  } else {
    // Fewer double quotes
    DoubleQuoted
  }
}

///|
/// Check if string ends with suffix
pub fn string_ends_with(s : String, suffix : String) -> Bool {
  if suffix.length() > s.length() {
    false
  } else {
    let start = s.length() - suffix.length()
    s.substring(start~) == suffix
  }
}

///|
/// Pad string to specified width with spaces
pub fn pad_string(s : String, width : Int) -> String {
  let padding_needed = width - s.length()
  if padding_needed <= 0 {
    s
  } else {
    s + " ".repeat(padding_needed)
  }
}

///|
/// Wrap text to specified line width
pub fn wrap_text(text : String, width : Int) -> Array[String] {
  if width <= 0 {
    return [text]
  }
  
  let words = text.split(" ")
  let lines = []
  let mut current_line = ""
  
  for i = 0; i < words.length(); i = i + 1 {
    let word = words[i]
    let potential_line = if current_line.length() == 0 {
      word
    } else {
      current_line + " " + word
    }
    
    if potential_line.length() <= width {
      current_line = potential_line
    } else {
      if current_line.length() > 0 {
        lines.push(current_line)
      }
      current_line = word
    }
  }
  
  if current_line.length() > 0 {
    lines.push(current_line)
  }
  
  lines
}

///|
/// Get string representation of a YAML value for debugging
pub fn yaml_value_to_debug_string(value : YamlValue) -> String {
  match value {
    Null => "null"
    Bool(b) => b.to_string()
    Int(i) => i.to_string()
    Float(f) => f.to_string()
    String(s) => "\"" + s + "\""
    Array(arr) => {
      let items = []
      for i = 0; i < arr.length(); i = i + 1 {
        items.push(yaml_value_to_debug_string(arr[i]))
      }
      "[" + items.join(", ") + "]"
    }
    Object(obj) => {
      let items = []
      obj.each(fn(k, v) {
        items.push("\"" + k + "\": " + yaml_value_to_debug_string(v))
      })
      "{" + items.join(", ") + "}"
    }
  }
}

///|
/// Convert YamlValue to String if possible
pub fn yaml_value_to_string(value : YamlValue) -> String? {
  match value {
    String(s) => Some(s)
    _ => None
  }
}

///|
/// Convert YamlValue to Int if possible
pub fn yaml_value_to_int(value : YamlValue) -> Int? {
  match value {
    Int(i) => Some(i)
    _ => None
  }
}

///|
/// Convert YamlValue to Bool if possible  
pub fn yaml_value_to_bool(value : YamlValue) -> Bool? {
  match value {
    Bool(b) => Some(b)
    _ => None
  }
}

///|
/// Convert YamlValue to Double if possible
pub fn yaml_value_to_double(value : YamlValue) -> Double? {
  match value {
    Float(f) => Some(f)
    Int(i) => Some(i.to_double())
    _ => None
  }
}

///|
/// Convert YamlValue to Array if possible
pub fn yaml_value_to_array(value : YamlValue) -> Array[YamlValue]? {
  match value {
    Array(arr) => Some(arr)
    _ => None
  }
}

///|
/// Convert YamlValue to Object if possible
pub fn yaml_value_to_object(value : YamlValue) -> Map[String, YamlValue]? {
  match value {
    Object(obj) => Some(obj)
    _ => None
  }
}

///|
/// Check if YamlValue is null
pub fn yaml_value_is_null(value : YamlValue) -> Bool {
  match value {
    Null => true
    _ => false
  }
}



///|
/// Deep equality check for YAML values
pub fn yaml_values_equal(a : YamlValue, b : YamlValue) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (Bool(a_val), Bool(b_val)) => a_val == b_val
    (Int(a_val), Int(b_val)) => a_val == b_val
    (Float(a_val), Float(b_val)) => a_val == b_val
    (String(a_val), String(b_val)) => a_val == b_val
    (Array(a_arr), Array(b_arr)) => {
      if a_arr.length() != b_arr.length() {
        false
      } else {
        let mut equal = true
        for i = 0; i < a_arr.length(); i = i + 1 {
          if !yaml_values_equal(a_arr[i], b_arr[i]) {
            equal = false
            break
          }
        }
        equal
      }
    }
    (Object(a_obj), Object(b_obj)) => {
      if a_obj.size() != b_obj.size() {
        false
      } else {
        let mut equal = true
        a_obj.each(fn(key, a_val) {
          match b_obj.get(key) {
            Some(b_val) => {
              if !yaml_values_equal(a_val, b_val) {
                equal = false
              }
            }
            None => equal = false
          }
        })
        equal
      }
    }
    _ => false
  }
}

///|
/// Convert YAML value to JSON-like string representation
pub fn yaml_value_to_json_string(value : YamlValue) -> String {
  match value {
    Null => "null"
    Bool(b) => b.to_string()
    Int(i) => i.to_string()
    Float(f) => {
      if f != f { // NaN
        "null"
      } else if f == infinity() || f == -infinity() {
        "null"
      } else {
        f.to_string()
      }
    }
    String(s) => "\"" + escape_json_string(s) + "\""
    Array(arr) => {
      let items = []
      for i = 0; i < arr.length(); i = i + 1 {
        items.push(yaml_value_to_json_string(arr[i]))
      }
      "[" + join(items, ", ") + "]"
    }
    Object(obj) => {
      let items = []
      obj.each(fn(k, v) {
        items.push("\"" + escape_json_string(k) + "\": " + yaml_value_to_json_string(v))
      })
      "{" + join(items, ", ") + "}"
    }
  }
}

///|
/// Escape string for JSON output
fn escape_json_string(s : String) -> String {
  let mut result = ""
  
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    match ch {
      DOUBLE_QUOTE => result += "\\\""
      BACKSLASH => result += "\\\\"
      LINE_FEED => result += "\\n"
      CARRIAGE_RETURN => result += "\\r"
      TAB => result += "\\t"
      0x08 => result += "\\b" // backspace
      0x0c => result += "\\f" // form feed
      _ => 
        if ch < 32 {
          result += "\\u" + format_hex_unicode_short(ch)
        } else {
          result += Char::from_int(ch).to_string()
        }
    }
  }
  
  result
}

///|
/// Merge two YAML objects (deep merge)
pub fn merge_yaml_objects(target : YamlValue, source : YamlValue) -> YamlValue {
  match (target, source) {
    (Object(target_obj), Object(source_obj)) => {
      let result = Map::new()
      
      // Copy all target properties
      target_obj.each(fn(k, v) { result[k] = v })
      
      // Merge source properties
      source_obj.each(fn(k, v) {
        match target_obj.get(k) {
          Some(existing) => {
            // Deep merge if both are objects
            match (existing, v) {
              (Object(_), Object(_)) => result[k] = merge_yaml_objects(existing, v)
              _ => result[k] = v // Override with source value
            }
          }
          None => result[k] = v // Add new property
        }
      })
      
      Object(result)
    }
    (_, source) => source // Non-object target, just return source
  }
}

///|
/// Get all keys from a YAML object (including nested)
pub fn get_all_keys(value : YamlValue, prefix? : String = "") -> Array[String] {
  let keys = []
  
  match value {
    Object(obj) => {
      obj.each(fn(k, v) {
        let full_key = if prefix.length() == 0 { k } else { prefix + "." + k }
        keys.push(full_key)
        let nested_keys = get_all_keys(v, prefix=full_key)
        for i = 0; i < nested_keys.length(); i = i + 1 {
          keys.push(nested_keys[i])
        }
      })
    }
    Array(arr) => {
      for i = 0; i < arr.length(); i = i + 1 {
        let index_key = if prefix.length() == 0 { i.to_string() } else { prefix + "[" + i.to_string() + "]" }
        keys.push(index_key)
        let nested_keys = get_all_keys(arr[i], prefix=index_key)
        for j = 0; j < nested_keys.length(); j = j + 1 {
          keys.push(nested_keys[j])
        }
      }
    }
    _ => () // Scalar values have no nested keys
  }
  
  keys
}

///|
/// Get value at path (dot notation)
pub fn get_value_at_path(value : YamlValue, path : String) -> YamlValue? {
  if path.length() == 0 {
    return Some(value)
  }
  
  let parts = path.split(".")
  let mut current = value
  
  for i = 0; i < parts.length(); i = i + 1 {
    let part = parts[i]
    match current {
      Object(obj) => {
        match obj.get(part) {
          Some(next_value) => current = next_value
          None => return None
        }
      }
      Array(arr) => {
        // Try to parse part as array index
        match parse_array_index(part) {
          Some(index) => {
            if index >= 0 && index < arr.length() {
              current = arr[index]
            } else {
              return None
            }
          }
          None => return None
        }
      }
      _ => return None // Can't traverse into scalar values
    }
  }
  
  Some(current)
}

///|
/// Parse string as array index
fn parse_array_index(s : String) -> Int? {
  if s.length() == 0 {
    return None
  }
  
  // Check if all characters are digits
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch < 48 || ch > 57 { // Not 0-9
      return None
    }
  }
  
  Some(parse_decimal(s))
}

///|
/// Set value at path (dot notation)
pub fn set_value_at_path(value : YamlValue, path : String, new_value : YamlValue) -> YamlValue {
  if path.length() == 0 {
    return new_value
  }
  
  let parts = path.split(".")
  
  match value {
    Object(obj) => {
      let result = Map::new()
      obj.each(fn(k, v) { result[k] = v }) // Copy existing properties
      
      if parts.length() == 1 {
        result[parts[0]] = new_value
      } else {
        let first_part = parts[0]
        let remaining_path = join(parts.slice(start=1), ".")
        let existing = obj.get(first_part).or(Object(Map::new()))
        result[first_part] = set_value_at_path(existing, remaining_path, new_value)
      }
      
      Object(result)
    }
    _ => {
      // For non-objects, create new object with the path
      let result = Map::new()
      if parts.length() == 1 {
        result[parts[0]] = new_value
      } else {
        let first_part = parts[0]
        let remaining_path = join(parts.slice(start=1), ".")
        result[first_part] = set_value_at_path(Object(Map::new()), remaining_path, new_value)
      }
      Object(result)
    }
  }
}

///|
/// Get the type name of a YAML value
pub fn get_yaml_type_name(value : YamlValue) -> String {
  match value {
    Null => "null"
    Bool(_) => "boolean"
    Int(_) => "integer"
    Float(_) => "float"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
  }
}

///|
/// Flatten nested YAML object to dot notation
pub fn flatten_yaml_object(value : YamlValue, prefix? : String = "") -> Map[String, YamlValue] {
  let result = Map::new()
  
  match value {
    Object(obj) => {
      obj.each(fn(k, v) {
        let key = if prefix.length() == 0 { k } else { prefix + "." + k }
        match v {
          Object(_) => {
            let nested = flatten_yaml_object(v, prefix=key)
            nested.each(fn(nested_k, nested_v) { result[nested_k] = nested_v })
          }
          _ => result[key] = v
        }
      })
    }
    _ => {
      let key = if prefix.length() == 0 { "value" } else { prefix }
      result[key] = value
    }
  }
  
  result
}

///|
/// Unflatten dot notation back to nested YAML object
pub fn unflatten_yaml_object(flat : Map[String, YamlValue]) -> YamlValue {
  let result = Map::new()
  
  flat.each(fn(path, value) {
    let mut current = result
    let parts = path.split(".")
    
    for i = 0; i < parts.length() - 1; i = i + 1 {
      let part = parts[i]
      match current.get(part) {
        Some(Object(nested)) => {
          // Continue with existing nested object
          current = nested
        }
        _ => {
          // Create new nested object
          let new_nested = Map::new()
          current[part] = Object(new_nested)
          current = new_nested
        }
      }
    }
    
    // Set the final value
    if parts.length() > 0 {
      current[parts[parts.length() - 1]] = value
    }
  })
  
  Object(result)
}

///|
/// Calculate size (number of elements) in YAML value
pub fn calculate_yaml_size(value : YamlValue) -> Int {
  match value {
    Array(arr) => arr.length()
    Object(obj) => obj.size()
    _ => 1 // Scalar values have size 1
  }
}

///|
/// Check if YAML value is empty
pub fn is_yaml_empty(value : YamlValue) -> Bool {
  match value {
    Null => true
    String(s) => s.length() == 0
    Array(arr) => arr.length() == 0
    Object(obj) => obj.size() == 0
    _ => false
  }
}

///|
/// Create a simple helper for infinity detection
fn infinity() -> Double {
  1.0 / 0.0
}