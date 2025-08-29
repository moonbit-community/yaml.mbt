///| MoonBit YAML Library
/// A YAML parsing and stringifying library for MoonBit
/// 
/// Ported from Deno std/yaml (js-yaml v3.13.1):
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.
/// 
/// This library supports:
/// - YAML 1.2.x (latest) and common YAML 1.1 features
/// - Parsing YAML strings to MoonBit values
/// - Stringifying MoonBit values to YAML
/// - Multiple schema types (failsafe, json, core, default)
/// - Flow and block styles
/// - Custom parsing options
/// 
/// # Example
/// 
/// ```moonbit
/// // Parse simple YAML
/// let data = parse("name: Alice\nage: 30")!
/// 
/// // Stringify to YAML
/// let yaml_obj = YamlValue::Object({
///   let map = Map::new()
///   map["name"] = YamlValue::String("Bob")
///   map["age"] = YamlValue::Int(25)
///   map
/// })
/// 
/// let yaml_text = stringify(yaml_obj)
/// ```

// Re-export core types from the converted modules

///|
/// Represents any YAML value
pub enum YamlValue {
  Null
  Bool(Bool)
  Int(Int)
  Float(Double)
  String(String)
  Array(Array[YamlValue])
  Object(Map[String, YamlValue])
} derive(Eq, Show)

// Utility functions

// JSON conversion functions are commented out due to constructor permission issues
// These are optional utility functions and not core to YAML functionality

// ///|
// /// Convert a simple JSON value to YamlValue
// /// This is a basic conversion for demonstration purposes
// pub fn from_json(json : Json) -> YamlValue {
//   match json {
//     Json::Null => Null
//     Json::True => Bool(true)
//     Json::False => Bool(false)
//     Json::Number(n) => {
//       // Try to convert to int if it's a whole number
//       let d = n
//       if d.floor() == d && d >= -2147483648.0 && d <= 2147483647.0 {
//         Int(d.to_int())
//       } else {
//         Float(d)
//       }
//     }
//     Json::String(s) => String(s)
//     Json::Array(arr) => {
//       let yaml_arr = []
//       for item in arr {
//         yaml_arr.push(from_json(item))
//       }
//       Array(yaml_arr)
//     }
//     Json::Object(obj) => {
//       let yaml_obj = Map::new()
//       obj.each(fn(k, v) { yaml_obj[k] = from_json(v) })
//       Object(yaml_obj)
//     }
//   }
// }

// ///|
// /// Convert YamlValue to JSON
// /// This is a basic conversion for demonstration purposes  
// pub fn to_json(yaml : YamlValue) -> Json {
//   match yaml {
//     Null => Json::Null
//     Bool(true) => Json::True
//     Bool(false) => Json::False
//     Int(i) => Json::Number(i.to_double())
//     Float(f) =>
//       if f != f || f == 1.0 / 0.0 || f == -1.0 / 0.0 {
//         Json::Null // JSON doesn't support NaN/Infinity
//       } else {
//         Json::Number(f)
//       }
//     String(s) => Json::String(s)
//     Array(arr) => {
//       let json_arr = []
//       for item in arr {
//         json_arr.push(to_json(item))
//       }
//       Json::Array(json_arr)
//     }
//     Object(obj) => {
//       let json_obj = {}
//       obj.each(fn(k, v) { json_obj[k] = to_json(v) })
//       Json::Object(json_obj)
//     }
//   }
// }

///|
/// Create a YAML object from key-value pairs
pub fn yaml_object(pairs : Array[(String, YamlValue)]) -> YamlValue {
  let obj = Map::new()
  for i = 0; i < pairs.length(); i = i + 1 {
    let (key, value) = pairs[i]
    obj[key] = value
  }
  Object(obj)
}

///|
/// Create a YAML array from values
pub fn yaml_array(values : Array[YamlValue]) -> YamlValue {
  Array(values)
}

// Directly export needed utility functions

///|
pub fn is_object(value : YamlValue) -> Bool {
  match value {
    Object(_) => true
    _ => false
  }
}

///|
pub fn is_plain_object(value : YamlValue) -> Bool {
  match value {
    Object(_) => true
    _ => false
  }
}

///|
pub fn is_negative_zero(f : Double) -> Bool {
  f == 0.0 && 1.0 / f < 0.0
}

// Character utilities are already declared in chars.mbt

// Schema functions are already declared in schema.mbt

// Type functions are already declared in builtin_types.mbt

// Main parsing functions are already declared in parser.mbt and stringify.mbt

// Helper string methods

///|
/// Repeat string n times
fn String::repeat(self : String, n : Int) -> String {
  if n <= 0 {
    ""
  } else {
    let mut result = ""
    for i = 0; i < n; i = i + 1 {
      result = result + self
    }
    result
  }
}

///|
/// Get minimum of two integers
fn Int::min(self : Int, other : Int) -> Int {
  if self < other {
    self
  } else {
    other
  }
}

///|
/// Array slice method
fn[T] Array::slice(
  self : Array[T],
  start? : Int = 0,
  end? : Int = -1,
) -> Array[T] {
  let actual_end = if end == -1 { self.length() } else { end }
  let result = []
  for i = start; i < actual_end && i < self.length(); i = i + 1 {
    result.push(self[i])
  }
  result
}

///|
/// Option or method
fn[T] Option::or(self : T?, default : T) -> T {
  match self {
    Some(value) => value
    None => default
  }
}

///|
/// Trim whitespace from both ends
fn String::trim(self : String) -> String {
  // Simple implementation - trim spaces and newlines
  let mut start = 0
  let mut end = self.length()
  while start < end &&
        (
          self[start] == ' ' ||
          self[start] == '\t' ||
          self[start] == '\n' ||
          self[start] == '\r'
        ) {
    start = start + 1
  }
  while end > start &&
        (
          self[end - 1] == ' ' ||
          self[end - 1] == '\t' ||
          self[end - 1] == '\n' ||
          self[end - 1] == '\r'
        ) {
    end = end - 1
  }
  if start == 0 && end == self.length() {
    self
  } else {
    self.substring(start~, end~)
  }
}

///|
/// Split string by delimiter
fn String::split(self : String, delimiter : String) -> Array[String] {
  let result = []
  let mut current = ""
  let mut i = 0
  while i < self.length() {
    if i + delimiter.length() <= self.length() {
      let substr = self.substring(start=i, end=i + delimiter.length())
      if substr == delimiter {
        result.push(current)
        current = ""
        i = i + delimiter.length()
        continue
      }
    }
    current = current + Char::from_int(self[i]).to_string()
    i = i + 1
  }
  result.push(current)
  result
}

///|
/// Check if string starts with prefix
fn String::starts_with(self : String, prefix : String) -> Bool {
  if prefix.length() > self.length() {
    false
  } else {
    self.substring(start=0, end=prefix.length()) == prefix
  }
}

///|
/// Check if string contains character
fn String::contains_char(self : String, ch : Char) -> Bool {
  let ch_code = Char::to_int(ch)
  for i = 0; i < self.length(); i = i + 1 {
    if self[i] == ch_code {
      return true
    }
  }
  false
}

///|
/// Join array elements with separator
fn join(self : Array[String], separator : String) -> String {
  if self.is_empty() {
    ""
  } else if self.length() == 1 {
    self[0]
  } else {
    let mut result = self[0]
    for i = 1; i < self.length(); i = i + 1 {
      result = result + separator + self[i]
    }
    result
  }
}
