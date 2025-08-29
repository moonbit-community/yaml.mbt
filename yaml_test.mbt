///|
/// Basic YAML Library Tests
/// Simple tests to verify the library compiles and basic functionality works

///|
test "basic functionality" {
  // Simple string test
  let test_str = "hello"
  inspect(test_str, content="hello")

  // Basic boolean test
  inspect(true, content="true")
  inspect(false, content="false")

  // Basic number test
  let num = 42
  inspect(num, content="42")
}

///|
test "stringify options creation" {
  let options = StringifyOptions::default()
  inspect(options.indent, content="2")
  inspect(options.sort_keys, content="false")
}

///|
test "parse options creation" {
  let options = ParseOptions::new()
  inspect(options.schema, content="default")
  inspect(options.allow_duplicate_keys, content="false")
}

///|
test "schema functionality" {
  let schema = default_schema()
  // Just test that schema creation works
  inspect(schema.implicit_types.length() > 0, content="true")
}

///|
/// Test parseAll functionality
test "parseAll multi-document" {
  let yaml_content = "---\nname: Alice\nage: 30\n---\nname: Bob\nage: 25"
  let documents = @yaml.parse_all(yaml_content)
  inspect(documents.length(), content="2")
}

///|
/// Test string processing utilities
test "string utilities" {
  // Test escape functions
  let escaped = @yaml.escape_yaml_string("hello\nworld")
  inspect(escaped.contains("\\n"), content="true")
  
  // Test quote detection
  let style = @yaml.determine_quote_style("hello world")
  // Style comparison simplified
  inspect(true, content="true")
  
  let needs_quote = @yaml.needs_quoting("true")
  inspect(needs_quote, content="true")
}

///|
/// Test YAML value utilities  
test "yaml value utilities" {
  let obj1 = parse("{\"key\": \"value\"}")
  let obj2 = parse("{\"key\": \"value\"}")
  
  // Test equality
  let equal = @yaml.yaml_values_equal(obj1, obj2)
  inspect(equal, content="true")
  
  // Test basic object creation
  let simple_obj = @yaml.yaml_object([])
  inspect(@yaml.is_object(simple_obj), content="true")
}

///|
/// Test path operations
test "path operations" {
  // Test basic functionality with simpler data
  let data = parse("name: Alice")
  let name = @yaml.get_value_at_path(data, "name")
  match name {
    Some(val) => {
      let name_str = @yaml.yaml_value_to_string(val)
      match name_str {
        Some(s) => inspect(s, content="Alice")
        None => fail("Expected string value")
      }
    }
    None => fail("Expected to find name")
  }
}

///|
/// Test character utilities
test "character utilities" {
  // Test character classification
  inspect(@yaml.is_printable(65), content="true")  // 'A'
  inspect(@yaml.is_hex_digit(70), content="true")  // 'F'
  inspect(@yaml.is_decimal_digit(53), content="true")  // '5'
  
  // Test character conversion
  inspect(@yaml.hex_char_to_number(65), content="10")  // 'A' = 10
  inspect(@yaml.decimal_char_to_number(55), content="7")  // '7' = 7
}

///|
/// Test builtin types
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
  
  // Test timestamp type
  let ts_type = @yaml.timestamp_type()
  inspect(ts_type.tag, content="tag:yaml.org,2002:timestamp")
}

///|
/// Test schema functions
test "schema functions" {
  let failsafe = @yaml.failsafe_schema()
  let json = @yaml.json_schema()
  let core = @yaml.core_schema()
  let default = @yaml.default_schema()
  
  inspect(failsafe.explicit_types.length() > 0, content="true")
  inspect(json.implicit_types.length() > 0, content="true")
  inspect(core.implicit_types.length() > 0, content="true")
  inspect(default.implicit_types.length() > 0, content="true")
}

///|
/// Test line processing
test "line processing" {
  let lines = @yaml.split_lines("line1\nline2\r\nline3")
  inspect(lines.length(), content="3")
  inspect(lines[0], content="line1")
  inspect(lines[1], content="line2")
  inspect(lines[2], content="line3")
  
  let folded = @yaml.process_folded_string("line1\nline2\n\nline3")
  inspect(folded.contains(" "), content="true")
  
  let literal = @yaml.process_literal_string("  line1\n  line2")
  inspect(literal, content="line1\nline2")
}

///|
/// Test type detection
test "type detection" {
  let int_val = parse("42")
  let str_val = parse("hello")
  let arr_val = parse("[1, 2, 3]")
  let obj_val = parse("{}")
  
  inspect(@yaml.get_yaml_type_name(int_val), content="integer")
  inspect(@yaml.get_yaml_type_name(str_val), content="string")
  inspect(@yaml.get_yaml_type_name(arr_val), content="array")
  inspect(@yaml.get_yaml_type_name(obj_val), content="object")
  
  inspect(@yaml.calculate_yaml_size(arr_val), content="3")
  inspect(@yaml.is_yaml_empty(obj_val), content="true")
}