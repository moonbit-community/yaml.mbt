///| Built-in YAML type handlers
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// String type handler
pub fn str_type() -> YamlType[String] {
  {
    tag: "tag:yaml.org,2002:str",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        String(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match style {
        Some(SingleQuoted) => "'" + escape_single_quotes(data) + "'"
        Some(DoubleQuoted) => "\"" + escape_double_quotes(data) + "\""
        Some(Literal) => "|\\n  " + data.replace(old="\n", new="\n  ")
        Some(Folded) => ">\\n  " + data.replace(old="\n", new="\n  ")
        _ => data // Plain style
      }
    }),
    default_style: Some(Plain),
    resolve: fn(value) {
      match value {
        String(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => s
        _ => yaml_value_to_debug_string(value)
      }
    },
  }
}

///|
/// Escape single quotes in string
fn escape_single_quotes(s : String) -> String {
  s.replace(old="'", new="''")
}

///|
/// Escape double quotes in string
fn escape_double_quotes(s : String) -> String {
  s
  .replace(old="\"", new="\\\"")
  .replace(old="\n", new="\\n")
  .replace(old="\t", new="\\t")
}

///|
/// Boolean type handler
pub fn bool_type() -> YamlType[Bool] {
  let yaml_true_values = ["true", "True", "TRUE"]
  let yaml_false_values = ["false", "False", "FALSE"]
  {
    tag: "tag:yaml.org,2002:bool",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Bool(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match style {
        Some(Uppercase) => if data { "TRUE" } else { "FALSE" }
        Some(Camelcase) => if data { "True" } else { "False" }
        _ => if data { "true" } else { "false" } // Default lowercase
      }
    }),
    default_style: Some(Lowercase),
    resolve: fn(value) {
      match value {
        String(s) =>
          yaml_true_values.contains(s) || yaml_false_values.contains(s)
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => yaml_true_values.contains(s)
        Bool(b) => b
        _ => false
      }
    },
  }
}

///|
/// Integer type handler  
pub fn int_type() -> YamlType[Int] {
  {
    tag: "tag:yaml.org,2002:int",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Int(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match style {
        Some(Binary) =>
          if data >= 0 {
            "0b" + to_base_string(data, 2)
          } else {
            "-0b" + to_base_string(-data, 2)
          }
        Some(Octal) =>
          if data >= 0 {
            "0" + to_base_string(data, 8)
          } else {
            "-0" + to_base_string(-data, 8)
          }
        Some(Hexadecimal) =>
          if data >= 0 {
            "0x" + to_uppercase(to_base_string(data, 16))
          } else {
            "-0x" + to_uppercase(to_base_string(-data, 16))
          }
        _ => data.to_string() // Default decimal
      }
    }),
    default_style: Some(Decimal),
    resolve: fn(value) {
      match value {
        String(s) => resolve_yaml_integer(s)
        Int(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => construct_yaml_integer(s)
        Int(i) => i
        _ => 0
      }
    },
  }
}

///|
/// Float type handler
pub fn float_type() -> YamlType[Double] {
  {
    tag: "tag:yaml.org,2002:float",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Float(_) => true
        Int(_) => true // Integers can be represented as floats
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      if data != data { // NaN check
        ".nan"
      } else if data.is_pos_inf() {
        ".inf"
      } else if data.is_neg_inf() {
        "-.inf"
      } else {
        data.to_string()
      }
    }),
    default_style: None,
    resolve: fn(value) {
      match value {
        String(s) => resolve_yaml_float(s)
        Float(_) => true
        Int(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => construct_yaml_float(s)
        Float(f) => f
        Int(i) => i.to_double()
        _ => 0.0
      }
    },
  }
}

///|
/// Null type handler
pub fn null_type() -> YamlType[Unit] {
  let yaml_null_values = ["null", "Null", "NULL", "~", ""]
  {
    tag: "tag:yaml.org,2002:null",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Null => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match style {
        Some(Uppercase) => "NULL"
        Some(Camelcase) => "Null"
        _ => "null" // Default lowercase
      }
    }),
    default_style: Some(Lowercase),
    resolve: fn(value) {
      match value {
        String(s) => yaml_null_values.contains(s)
        Null => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        _ => () // Always return unit/null
      }
    },
  }
}

///|
/// Sequence type handler
pub fn seq_type() -> YamlType[Array[YamlValue]] {
  {
    tag: "tag:yaml.org,2002:seq",
    kind: Sequence,
    predicate: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    represent: None, // Complex representation handled elsewhere
    default_style: None,
    resolve: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Array(arr) => arr
        _ => [] // Default to empty array
      }
    },
  }
}

///|
/// Mapping type handler
pub fn map_type() -> YamlType[Map[String, YamlValue]] {
  {
    tag: "tag:yaml.org,2002:map",
    kind: Mapping,
    predicate: fn(value) {
      match value {
        Object(_) => true
        _ => false
      }
    },
    represent: None, // Complex representation handled elsewhere
    default_style: None,
    resolve: fn(value) {
      match value {
        Object(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Object(obj) => obj
        _ => Map::new() // Default to empty map
      }
    },
  }
}

///|
/// Binary type handler
/// Represents binary data encoded in base64
pub fn binary_type() -> YamlType[String] {
  {
    tag: "tag:yaml.org,2002:binary",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        String(s) => is_base64_string(s)
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      // In a full implementation, this would encode to base64
      data
    }),
    default_style: Some(Literal),
    resolve: fn(value) {
      match value {
        String(s) => is_base64_string(s)
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => s // In a full implementation, this would decode base64
        _ => ""
      }
    },
  }
}

///|
/// Check if string looks like base64
fn is_base64_string(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }

  // Check if all characters are valid base64
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if !((ch >= 65 && ch <= 90) || // A-Z
      (ch >= 97 && ch <= 122) || // a-z
      (ch >= 48 && ch <= 57) || // 0-9
      ch == 43 ||
      ch == 47 || // + /
      ch == 61) { // =
      return false
    }
  }

  // Check padding
  let padding = s.length() % 4
  padding == 0 || padding == 2 || padding == 3
}

///|
/// Ordered map (omap) type handler
/// Represents an ordered mapping as an array of key-value pairs
pub fn omap_type() -> YamlType[Array[(String, YamlValue)]] {
  {
    tag: "tag:yaml.org,2002:omap",
    kind: Sequence,
    predicate: fn(value) {
      match value {
        Array(_) => true // TODO: Check if it's array of key-value pairs
        _ => false
      }
    },
    represent: None, // Complex representation handled elsewhere
    default_style: None,
    resolve: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Array(_) => [] // Simplified - should parse key-value pairs
        _ => []
      }
    },
  }
}

///|
/// Pairs type handler  
/// Similar to omap but allows duplicate keys
pub fn pairs_type() -> YamlType[Array[(String, YamlValue)]] {
  {
    tag: "tag:yaml.org,2002:pairs",
    kind: Sequence,
    predicate: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    represent: None,
    default_style: None,
    resolve: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Array(_) => []
        _ => []
      }
    },
  }
}

///|
/// Set type handler
/// Represents a set as a mapping with null values
pub fn set_type() -> YamlType[Array[String]] {
  {
    tag: "tag:yaml.org,2002:set",
    kind: Mapping,
    predicate: fn(value) {
      match value {
        Object(_) => true // TODO: Check if all values are null
        _ => false
      }
    },
    represent: None,
    default_style: None,
    resolve: fn(value) {
      match value {
        Object(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Object(_) => [] // Simplified - should extract keys
        _ => []
      }
    },
  }
}

///|
/// Timestamp type handler
/// Represents date/time values
pub fn timestamp_type() -> YamlType[String] {
  {
    tag: "tag:yaml.org,2002:timestamp",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        String(s) => is_timestamp_string(s)
        _ => false
      }
    },
    represent: Some(fn(data, style) { data }),
    default_style: None,
    resolve: fn(value) {
      match value {
        String(s) => is_timestamp_string(s)
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => s
        _ => ""
      }
    },
  }
}

///|
/// Check if string looks like a timestamp
fn is_timestamp_string(s : String) -> Bool {
  // Very basic check for ISO 8601-like format
  // Full implementation would use proper regex
  s.contains("-") && (s.contains(":") || s.length() == 10)
}

///|
/// Merge type handler
/// Handles YAML merge keys (<<)
pub fn merge_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:merge",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        String(s) => s == "<<"
        _ => false
      }
    },
    represent: Some(fn(value, style) { "<<" }),
    default_style: None,
    resolve: fn(value) {
      match value {
        String(s) => s == "<<"
        _ => false
      }
    },
    construct: fn(value) { YamlValue::String("<<MERGE>>") },
  }
}

// Helper functions for integer parsing

///|
/// Resolve YAML integer from string
fn resolve_yaml_integer(data : String) -> Bool {
  let max = data.length()
  if max == 0 {
    return false
  }
  let mut index = 0
  let mut has_digits = false
  let mut ch = data[index]

  // Handle sign
  if ch == 45 || ch == 43 { // '-' or '+'
    index = index + 1
    if index >= max {
      return false
    }
    ch = data[index]
  }

  // Handle zero prefix
  if ch == 48 { // '0'
    if index + 1 == max {
      return true
    } // Just "0"
    index = index + 1
    ch = data[index]

    // Binary prefix
    if ch == 98 { // 'b'
      index = index + 1
      for i = index; i < max; i = i + 1 {
        let c = data[i]
        if c == 95 { // '_'
          continue
        }
        if c != 48 && c != 49 { // '0' and '1'
          return false
        }
        has_digits = true
      }
      return has_digits
    }

    // Hex prefix
    if ch == 120 { // 'x'
      index = index + 1
      for i = index; i < max; i = i + 1 {
        let c = data[i]
        if c == 95 { // '_'
          continue
        }
        if !is_hex_digit(c) {
          return false
        }
        has_digits = true
      }
      return has_digits
    }

    // Octal
    for i = index; i < max; i = i + 1 {
      let c = data[i]
      if c == 95 { // '_'
        continue
      }
      if !is_octal_digit(c) {
        return false
      }
      has_digits = true
    }
    return has_digits
  }

  // Decimal
  if ch == 95 { // '_'
    return false
  } // Can't start with underscore
  for i = index; i < max; i = i + 1 {
    let c = data[i]
    if c == 95 { // '_'
      continue
    }
    if !is_decimal_digit(c) {
      return false
    }
    has_digits = true
  }
  has_digits
}

///|
/// Construct integer from YAML string
fn construct_yaml_integer(data : String) -> Int {
  let mut value = data

  // Remove underscores
  value = value.replace(old="_", new="")
  let mut sign = 1
  let mut ch = if value.length() > 0 { value[0] } else { 0 }

  // Handle sign
  if ch == 45 || ch == 43 { // '-' or '+'
    if ch == 45 { // '-'
      sign = -1
    }
    value = value.substring(start=1)
    if value.length() == 0 {
      return 0
    }
    ch = value[0]
  }
  if value == "0" {
    return 0
  }

  // Handle different bases
  if ch == 48 && value.length() > 1 { // '0'
    let prefix = value[1]
    if prefix == 98 { // 'b'
      // Binary - parse manually since MoonBit might not have built-in support
      let binary_str = value.substring(start=2)
      sign * parse_binary(binary_str)
    } else if prefix == 120 { // 'x'
      // Hexadecimal
      sign * parse_hex(value)
    } else {
      // Octal
      sign * parse_octal(value)
    }
  } else {
    // Decimal
    sign * parse_decimal(value)
  }
}

///|
/// Resolve YAML float from string
fn resolve_yaml_float(data : String) -> Bool {
  match data {
    ".nan" | ".NaN" | ".NAN" => true
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" => true
    "-.inf" | "-.Inf" | "-.INF" => true
    _ =>
      // Try to parse as regular float
      parse_double_check(data)
  }
}

///|
/// Construct float from YAML string
fn construct_yaml_float(data : String) -> Double {
  match data {
    ".nan" | ".NaN" | ".NAN" => 0.0 / 0.0 // NaN
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" => @double.infinity
    "-.inf" | "-.Inf" | "-.INF" => @double.neg_infinity
    _ => parse_double(data)
  }
}

// Helper functions

///|
/// Convert string to uppercase
fn to_uppercase(s : String) -> String {
  // Simplified implementation
  let mut result = ""
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch >= 97 && ch <= 122 { // 'a' to 'z'
      result += Char::from_int(ch - 32).to_string()
    } else {
      result += Char::from_int(ch).to_string()
    }
  }
  result
}

// Character validation helpers

///|
fn is_octal_digit(c : Int) -> Bool {
  c >= 48 && c <= 55 // '0' to '7'
}

// Number parsing helpers (simplified implementations)

///|
fn parse_binary(s : String) -> Int {
  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch == 48 { // '0'
      result = result * 2
    } else if ch == 49 { // '1'
      result = result * 2 + 1
    }
  }
  result
}

///|
fn parse_hex(s : String) -> Int {
  let mut result = 0
  let start = if s.starts_with("0x") || s.starts_with("0X") { 2 } else { 0 }
  for i = start; i < s.length(); i = i + 1 {
    let ch = s[i]
    result = result * 16
    if ch >= 48 && ch <= 57 { // '0' to '9'
      result += ch - 48
    } else if ch >= 65 && ch <= 70 { // 'A' to 'F'
      result += ch - 65 + 10
    } else if ch >= 97 && ch <= 102 { // 'a' to 'f'
      result += ch - 97 + 10
    }
  }
  result
}

///|
fn parse_octal(s : String) -> Int {
  let mut result = 0
  let start = if s.starts_with("0") { 1 } else { 0 }
  for i = start; i < s.length(); i = i + 1 {
    let ch = s[i]
    if ch >= 48 && ch <= 55 { // '0' to '7'
      result = result * 8 + (ch - 48)
    }
  }
  result
}

///|
fn to_base_string(n : Int, base : Int) -> String {
  if n == 0 {
    return "0"
  }
  let mut num = n
  let mut result = ""
  let digits = "0123456789abcdef"
  while num > 0 {
    let digit = num % base
    result = Int::unsafe_to_char(digits[digit]).to_string() + result
    num /= base
  }
  result
}

///|
fn parse_decimal(s : String) -> Int {
  let mut result = 0
  for i = 0; i < s.length(); i = i + 1 {
    let c = s[i]
    if c >= 48 && c <= 57 { // '0' to '9'
      result = result * 10 + (c - 48)
    }
  }
  result
}

///|
fn parse_double_check(s : String) -> Bool {
  // Simple check if string looks like a float
  let mut has_digit = false
  let mut has_dot = false
  let mut i = 0

  // Skip leading sign
  if i < s.length() && (s[i] == 43 || s[i] == 45) { // '+' or '-'
    i = i + 1
  }
  while i < s.length() {
    let c = s[i]
    if c >= 48 && c <= 57 { // '0' to '9'
      has_digit = true
    } else if c == 46 && !has_dot { // '.'
      has_dot = true
    } else if c == 101 || c == 69 { // 'e' or 'E'
      // Scientific notation - simplified check
      has_digit = true
      break
    } else {
      return false
    }
    i = i + 1
  }
  has_digit
}

///|
fn parse_double(s : String) -> Double {
  // Simple double parsing implementation
  let mut result = 0.0
  let mut decimal_part = 0.0
  let mut decimal_divisor = 1.0
  let mut in_decimal = false
  let mut i = 0
  let mut sign = 1.0

  // Handle sign
  if i < s.length() && s[i] == 45 { // '-'
    sign = -1.0
    i += 1
  } else if i < s.length() && s[i] == 43 { // '+'
    i += 1
  }
  while i < s.length() {
    let c = s[i]
    if c >= 48 && c <= 57 { // '0' to '9'
      let digit = (c - 48).to_double()
      if in_decimal {
        decimal_divisor *= 10.0
        decimal_part = decimal_part * 10.0 + digit
      } else {
        result = result * 10.0 + digit
      }
    } else if c == 46 { // '.'
      in_decimal = true
    } else if c == 101 || c == 69 { // 'e' or 'E'
      // Scientific notation - simplified handling
      break
    }
    i += 1
  }
  sign * (result + decimal_part / decimal_divisor)
}
