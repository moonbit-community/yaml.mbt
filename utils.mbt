///| Utility functions for YAML processing
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// Check if a value is an object (mapping)
pub fn is_object(value : YamlValue) -> Bool {
  match value {
    Object(_) => true
    _ => false
  }
}

///|
/// Check if a value is a plain object (not array, null, etc.)
pub fn is_plain_object(value : YamlValue) -> Bool {
  match value {
    Object(_) => true
    _ => false
  }
}

///|
/// Check if a number is negative zero
pub fn is_negative_zero(f : Double) -> Bool {
  f == 0.0 && 1.0 / f < 0.0 // Check for -0.0
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
      obj.each(fn(k, v) { new_obj[k] = clone_yaml_value(v) })
      Object(new_obj)
    }
  }
}
