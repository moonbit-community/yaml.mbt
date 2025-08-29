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
        Some(_) => data // Style doesn't matter for strings in basic implementation
        None => data
      }
    }),
    default_style: None,
    resolve: fn(value) {
      match value {
        String(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => s
        _ => "" // Default to empty string for invalid values
      }
    },
  }
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
            "0b" + data.to_string() // TODO: implement binary conversion
          } else {
            "-0b" + (-data).to_string() // TODO: implement binary conversion
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
      match style {
        _ =>
          if data != data { // NaN check
            ".nan"
          } else if data == infinity() {
            ".inf"
          } else if data == -infinity() {
            "-.inf"
          } else {
            data.to_string()
          }
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
  if ch == '-' || ch == '+' {
    index = index + 1
    if index >= max {
      return false
    }
    ch = data[index]
  }

  // Handle zero prefix
  if ch == '0' {
    if index + 1 == max {
      return true
    } // Just "0"
    index = index + 1
    ch = data[index]

    // Binary prefix
    if ch == 'b' {
      index = index + 1
      for i = index; i < max; i = i + 1 {
        let c = data[i]
        if c == '_' {
          continue
        }
        if c != '0' && c != '1' {
          return false
        }
        has_digits = true
      }
      return has_digits
    }

    // Hex prefix
    if ch == 'x' {
      index = index + 1
      for i = index; i < max; i = i + 1 {
        let c = data[i]
        if c == '_' {
          continue
        }
        if !is_hex_char(Char::from_int(data[i])) {
          return false
        }
        has_digits = true
      }
      return has_digits
    }

    // Octal
    for i = index; i < max; i = i + 1 {
      let c = data[i]
      if c == '_' {
        continue
      }
      if !is_octal_char(Char::from_int(data[i])) {
        return false
      }
      has_digits = true
    }
    return has_digits
  }

  // Decimal
  if ch == '_' {
    return false
  } // Can't start with underscore
  for i = index; i < max; i = i + 1 {
    let c = data[i]
    if c == '_' {
      continue
    }
    if !is_decimal_char(Char::from_int(data[i])) {
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
  let mut ch = value[0]

  // Handle sign
  if ch == '-' || ch == '+' {
    if ch == '-' {
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
  if ch == '0' && value.length() > 1 {
    let prefix = value[1]
    if prefix == 'b' {
      // Binary - parse manually since MoonBit might not have built-in support
      let binary_str = value.substring(start=2)
      sign * parse_binary(binary_str)
    } else if prefix == 'x' {
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
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" => infinity()
    "-.inf" | "-.Inf" | "-.INF" => -infinity()
    _ => parse_double(data)
  }
}

// Helper functions

///|
/// Convert string to uppercase
fn to_uppercase(s : String) -> String {
  // TODO: Implement proper uppercase conversion
  s // Placeholder for now
}

///|
/// Get infinity value
fn infinity() -> Double {
  1.0 / 0.0
}

// Character validation helpers

///|
fn is_hex_char(c : Char) -> Bool {
  (c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')
}

///|
fn is_octal_char(c : Char) -> Bool {
  c >= '0' && c <= '7'
}

///|
fn is_decimal_char(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

// Number parsing helpers (simplified implementations)

///|
fn parse_binary(s : String) -> Int {
  // TODO: Implement binary parsing
  0 // Placeholder
}

///|
fn parse_hex(s : String) -> Int {
  // TODO: Implement hex parsing  
  0 // Placeholder
}

///|
fn parse_octal(s : String) -> Int {
  // TODO: Implement octal parsing
  0 // Placeholder
}

///|
fn to_base_string(n : Int, base : Int) -> String {
  // TODO: Implement base conversion
  n.to_string() // Placeholder - just return decimal for now
}

///|
fn parse_decimal(s : String) -> Int {
  // Simple decimal parsing - TODO: implement proper parsing
  let mut result = 0
  let mut i = 0
  while i < s.length() {
    let c_code = s[i]
    let c = Char::from_int(c_code)
    if is_decimal_char(c) {
      result = result * 10 + (c_code - 0x30)
    } else {
      break
    }
    i = i + 1
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
  if i < s.length() && (s[i] == '+' || s[i] == '-') {
    i = i + 1
  }
  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      has_digit = true
    } else if c == '.' && !has_dot {
      has_dot = true
    } else if c == 'e' || c == 'E' {
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
  // Simple double parsing - TODO: implement proper parsing
  // For now, just try basic patterns
  if s.contains(".") || s.contains("e") || s.contains("E") {
    1.0 // Placeholder - return 1.0 for now
  } else {
    parse_decimal(s).to_double()
  }
}
