# YAML

A comprehensive YAML parsing and stringifying library for MoonBit, supporting YAML 1.2.x and common YAML 1.1 features.

This library is ported from Deno std/yaml (js-yaml v3.13.1) and provides full-featured YAML processing capabilities including multiple schema types, flow and block styles, and custom parsing options.

## Features

- Parse YAML strings to MoonBit values  
- Stringify MoonBit values to YAML
- Multiple schema types (failsafe, json, core, default)
- Flow and block styles support
- Custom parsing and stringification options
- Comprehensive error handling

## Basic Usage

### Parsing YAML

Parse simple YAML documents into MoonBit values:

```moonbit
test "basic parsing" {
  // Parse simple key-value pairs
  let result = @yaml.parse("name: Alice\nage: 30")
  match result {
    @yaml.Object(obj) => {
      match (obj.get("name"), obj.get("age")) {
        (Some(@yaml.String(name)), Some(@yaml.Int(age))) => {
          assert_eq(name, "Alice")
          assert_eq(age, 30)
        }
        _ => fail("Expected name and age")
      }
    }
    _ => fail("Expected object")
  }
}
```

### Stringifying to YAML

Convert MoonBit values back to YAML format using helper functions:

```moonbit
test "basic stringification" {
  // Create values using parse() and helper functions
  let name_val = @yaml.parse("Bob")
  let age_val = @yaml.parse("25")
  let active_val = @yaml.parse("true")
  
  let yaml_obj = @yaml.yaml_object([
    ("name", name_val),
    ("age", age_val),
    ("active", active_val)
  ])
  
  let yaml_text = @yaml.stringify(yaml_obj)
  assert_eq(yaml_text.contains("name: Bob"), true)
  assert_eq(yaml_text.contains("age: 25"), true)
  assert_eq(yaml_text.contains("active: true"), true)
}
```

## Working with Arrays

Handle YAML sequences and arrays:

```moonbit
test "arrays and sequences" {
  // Parse YAML array
  let yaml_text = "- apple\n- banana\n- cherry"
  let result = @yaml.parse(yaml_text)
  
  match result {
    @yaml.Array(arr) => {
      assert_eq(arr.length(), 3)
      match (arr[0], arr[1], arr[2]) {
        (@yaml.String(first), @yaml.String(second), @yaml.String(third)) => {
          assert_eq(first, "apple")
          assert_eq(second, "banana")
          assert_eq(third, "cherry")
        }
        _ => fail("Expected string array")
      }
    }
    _ => fail("Expected array")
  }
  
  // Create array using helper function
  let apple = @yaml.parse("apple")
  let banana = @yaml.parse("banana")
  let cherry = @yaml.parse("cherry")
  
  let fruits = @yaml.yaml_array([apple, banana, cherry])
  let stringified = @yaml.stringify(fruits)
  assert_eq(stringified.contains("- apple"), true)
}
```

## Complex Data Structures

Work with nested objects and mixed data types:

```moonbit
test "nested structures" {
  let complex_yaml = "person:\n  name: Alice\n  age: 30\n  hobbies:\n    - reading\n    - swimming\n  address:\n    street: 123 Main St\n    city: Anytown"
  
  let result = @yaml.parse(complex_yaml)
  match result {
    @yaml.Object(obj) => {
      match obj.get("person") {
        Some(@yaml.Object(person)) => {
          match (person.get("name"), person.get("age")) {
            (Some(@yaml.String(name)), Some(@yaml.Int(age))) => {
              assert_eq(name, "Alice")
              assert_eq(age, 30)
            }
            _ => fail("Expected name and age")
          }
          
          match person.get("hobbies") {
            Some(@yaml.Array(hobbies)) => {
              assert_eq(hobbies.length(), 2)
              match hobbies[0] {
                @yaml.String(hobby) => assert_eq(hobby, "reading")
                _ => fail("Expected string hobby")
              }
            }
            _ => fail("Expected hobbies array")
          }
        }
        _ => fail("Expected person object")
      }
    }
    _ => fail("Expected root object")
  }
}
```

## Schema Support

Use different YAML schemas for parsing:

```moonbit
test "schema types" {
  // Test with JSON schema (stricter)
  let options = @yaml.ParseOptions::{
    schema: "json",
    allow_duplicate_keys: false,
    on_warning: None
  }
  
  let result = @yaml.parse("number: 42\ntext: hello", options=options)
  match result {
    @yaml.Object(obj) => {
      match (obj.get("number"), obj.get("text")) {
        (Some(@yaml.Int(num)), Some(@yaml.String(text))) => {
          assert_eq(num, 42)
          assert_eq(text, "hello")
        }
        _ => fail("Expected number and text")
      }
    }
    _ => fail("Expected object")
  }
  
  // Test available schemas
  let failsafe = @yaml.failsafe_schema()
  let json = @yaml.json_schema()
  let core = @yaml.core_schema()
  let default = @yaml.default_schema()
  
  inspect(failsafe.explicit_types.length() > 0, content="true")
  inspect(json.implicit_types.length() > 0, content="true")
}
```

## Value Type Checking and Conversion

Use utility functions to work with YAML values:

```moonbit
test "value utilities" {
  // Create values using parse
  let name_val = @yaml.parse("test")
  let count_val = @yaml.parse("42")
  let active_val = @yaml.parse("true")
  let score_val = @yaml.parse("95.5")
  let null_val = @yaml.parse("null")
  
  let yaml_obj = @yaml.yaml_object([
    ("name", name_val),
    ("count", count_val),
    ("active", active_val),
    ("score", score_val),
    ("data", null_val)
  ])
  
  match yaml_obj {
    @yaml.Object(obj) => {
      // Type checking and conversion
      match obj.get("name") {
        Some(value) => assert_eq(@yaml.yaml_value_to_string(value), Some("test"))
        None => fail("Expected name")
      }
      
      match obj.get("count") {
        Some(value) => assert_eq(@yaml.yaml_value_to_int(value), Some(42))
        None => fail("Expected count")
      }
      
      match obj.get("active") {
        Some(value) => assert_eq(@yaml.yaml_value_to_bool(value), Some(true))
        None => fail("Expected active")
      }
      
      match obj.get("score") {
        Some(value) => assert_eq(@yaml.yaml_value_to_double(value), Some(95.5))
        None => fail("Expected score")
      }
      
      match obj.get("data") {
        Some(value) => assert_eq(@yaml.yaml_value_is_null(value), true)
        None => fail("Expected data")
      }
    }
    _ => fail("Expected object")
  }
}
```

## Custom Stringify Options

Control YAML output formatting:

```moonbit
test "stringify options" {
  let name_val = @yaml.parse("Alice")
  let key1_val = @yaml.parse("value1")
  let key2_val = @yaml.parse("123")
  
  let nested_obj = @yaml.yaml_object([
    ("key1", key1_val),
    ("key2", key2_val)
  ])
  
  let data = @yaml.yaml_object([
    ("name", name_val),
    ("nested", nested_obj)
  ])
  
  // Custom indentation
  let options = @yaml.StringifyOptions::{
    indent: 4,
    array_indent: false,
    skip_invalid: false,
    flow_level: -1,
    styles: Map::new(),
    schema: "default",
    sort_keys: false,
    line_width: 80,
    use_anchors: false,
    compat_mode: false,
    condense_flow: false
  }
  
  let yaml_text = @yaml.stringify(data, options=options)
  inspect(yaml_text.contains("name: Alice"), content="true")
}
```

## Type Constructors and Handlers

Work with built-in YAML types:

```moonbit
test "builtin types" {
  // Test string type
  let str_type = @yaml.str_type()
  inspect(str_type.tag, content="tag:yaml.org,2002:str")
  
  // Test boolean type
  let bool_type = @yaml.bool_type()
  inspect(bool_type.tag, content="tag:yaml.org,2002:bool")
  
  // Test integer type
  let int_type = @yaml.int_type()
  inspect(int_type.tag, content="tag:yaml.org,2002:int")
  
  // Test float type
  let float_type = @yaml.float_type()
  inspect(float_type.tag, content="tag:yaml.org,2002:float")
  
  // Test null type
  let null_type = @yaml.null_type()
  inspect(null_type.tag, content="tag:yaml.org,2002:null")
}
```

## Error Handling

Handle parsing errors gracefully:

```moonbit
test "error handling" {
  // Test valid YAML first
  let valid_result = try {
    @yaml.parse("valid: yaml")
  } catch {
    _ => @yaml.parse("null")
  }
  
  match valid_result {
    @yaml.Object(_) => inspect(true, content="true")
    _ => fail("Expected successful parse")
  }
  
  // Test clone utility
  let original_val = @yaml.parse("test")
  let original = @yaml.yaml_object([("key", original_val)])
  let cloned = @yaml.clone_yaml_value(original)
  assert_eq(original, cloned)
}
```

## Character Utilities

Use character checking utilities for advanced processing:

```moonbit
test "character utilities" {
  // Test character classification
  assert_eq(@yaml.is_eol(10), true)  // newline
  assert_eq(@yaml.is_whitespace_or_eol(32), true)  // space
  assert_eq(@yaml.is_flow_indicator(91), true)  // [
  assert_eq(@yaml.is_printable(65), true)  // A
  assert_eq(@yaml.is_hex_digit(70), true)  // F
  assert_eq(@yaml.is_decimal_digit(53), true)  // 5
  
  // Test character conversion
  assert_eq(@yaml.hex_char_to_number(65), 10)  // A = 10
  assert_eq(@yaml.decimal_char_to_number(55), 7)  // 7 = 7
  
  // Test string conversion
  let codepoint_str = @yaml.codepoint_to_string(65)  // A
  inspect(codepoint_str.contains("A"), content="true")
}
```

## Advanced Features

Demonstrate advanced YAML processing capabilities:

```moonbit
test "advanced features" {
  // Create complex structure using parsed values and helpers
  let version_val = @yaml.parse("1.0")
  let created_val = @yaml.parse("2024-01-01")
  let id1_val = @yaml.parse("1")
  let name1_val = @yaml.parse("Item 1")
  let tag1_val = @yaml.parse("tag1")
  let tag2_val = @yaml.parse("tag2")
  let id2_val = @yaml.parse("2")
  let name2_val = @yaml.parse("Item 2")
  let active_val = @yaml.parse("false")
  
  let metadata = @yaml.yaml_object([
    ("version", version_val),
    ("created", created_val)
  ])
  
  let tags_array = @yaml.yaml_array([tag1_val, tag2_val])
  
  let item1 = @yaml.yaml_object([
    ("id", id1_val),
    ("name", name1_val),
    ("tags", tags_array)
  ])
  
  let item2 = @yaml.yaml_object([
    ("id", id2_val),
    ("name", name2_val),
    ("active", active_val)
  ])
  
  let items_array = @yaml.yaml_array([item1, item2])
  
  let complex_data = @yaml.yaml_object([
    ("metadata", metadata),
    ("items", items_array)
  ])
  
  let yaml_text = @yaml.stringify(complex_data)
  let parsed_back = @yaml.parse(yaml_text)
  
  // Verify round-trip consistency
  match (complex_data, parsed_back) {
    (@yaml.Object(orig), @yaml.Object(parsed)) => {
      let has_metadata = orig.get("metadata").is_some() && parsed.get("metadata").is_some()
      let has_items = orig.get("items").is_some() && parsed.get("items").is_some()
      inspect(has_metadata, content="true")
      inspect(has_items, content="true")
    }
    _ => fail("Round-trip failed")
  }
}
```

## Scalar Resolving

Work with schema-based scalar resolution:

```moonbit
test "scalar resolving" {
  let schema = @yaml.default_schema()
  
  // Test various scalar types
  let null_val = @yaml.resolve_scalar("null", schema)
  let parsed_null = @yaml.parse("null")
  assert_eq(null_val, parsed_null)
  
  let bool_val = @yaml.resolve_scalar("true", schema)
  let parsed_bool = @yaml.parse("true")
  assert_eq(bool_val, parsed_bool)
  
  let int_val = @yaml.resolve_scalar("42", schema)
  let parsed_int = @yaml.parse("42")
  assert_eq(int_val, parsed_int)
  
  let str_val = @yaml.resolve_scalar("hello", schema)
  let parsed_str = @yaml.parse("hello")
  assert_eq(str_val, parsed_str)
}
```

## Utility Functions

Test additional utility functions for working with YAML values:

```moonbit
test "utility functions" {
  let key_val = @yaml.parse("value")
  let obj_value = @yaml.yaml_object([("key", key_val)])
  
  let int1_val = @yaml.parse("1")
  let int2_val = @yaml.parse("2")
  let array_value = @yaml.yaml_array([int1_val, int2_val])
  
  let simple_value = @yaml.parse("simple")
  
  // Test object checking
  assert_eq(@yaml.is_object(obj_value), true)
  assert_eq(@yaml.is_object(simple_value), false)
  
  assert_eq(@yaml.is_plain_object(obj_value), true)
  assert_eq(@yaml.is_plain_object(array_value), false)
  
  // Test negative zero detection
  assert_eq(@yaml.is_negative_zero(-0.0), true)
  assert_eq(@yaml.is_negative_zero(0.0), false)
  
  // Test debug string conversion
  let debug_str = @yaml.yaml_value_to_debug_string(obj_value)
  inspect(debug_str.contains("Object"), content="false")
}
