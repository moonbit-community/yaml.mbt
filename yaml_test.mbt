///|
/// Tests for MoonBit YAML Library
/// Demonstrating the converted functionality from Deno std/yaml
test "parse simple key-value pairs" {
  let yaml = "name: Alice\nage: 30\nactive: true"
  let result = parse(yaml)
  match result {
    Object(obj) => {
      inspect(obj["name"], content="Some(String(\"Alice\"))")
      inspect(obj["age"], content="Some(Int(30))")
      inspect(obj["active"], content="Some(Bool(true))")
    }
    _ => fail("Expected object result")
  }
}

///|
test "parse single scalar values" {
  inspect(parse("42"), content="Int(42)")
  inspect(parse("true"), content="Bool(true)")
  inspect(parse("null"), content="Null")
  inspect(parse("3.14"), content="Float(3.14)")
}

///|
test "stringify yaml values" {
  let obj = yaml_object([
    ("name", String("Bob")),
    ("age", Int(25)),
    ("active", Bool(false)),
  ])
  let yaml_str = stringify(obj)
  inspect(yaml_str.contains_char(':'), content="true")
  inspect(yaml_str.contains_char('\n'), content="true")
}

///|
test "yaml array creation and stringification" {
  let arr = yaml_array([String("apple"), String("banana"), String("cherry")])
  let yaml_str = stringify(arr)
  inspect(yaml_str.starts_with("\n-"), content="true")
}

///|
test "json conversion roundtrip" {
  let json_data = Json::Object(
    {
      let obj = {}
      obj["name"] = Json::String("Charlie")
      obj["score"] = Json::Number(95.5)
      obj["passed"] = Json::True
      obj
    },
  )
  let yaml_data = from_json(json_data)
  let back_to_json = to_json(yaml_data)
  match back_to_json {
    Json::Object(obj) => {
      inspect(obj["name"], content="Some(String(\"Charlie\"))")
      inspect(obj["passed"], content="Some(True)")
    }
    _ => fail("Expected JSON object")
  }
}

///|
test "schema types functionality" {
  let default_schema = get_schema("default")
  let json_schema = get_schema("json")
  let failsafe_schema = get_schema("failsafe")

  // Test scalar resolution with different schemas
  let resolved_true = resolve_scalar("true", default_schema)
  inspect(resolved_true, content="Bool(true)")
  let resolved_null = resolve_scalar("null", json_schema)
  inspect(resolved_null, content="Null")
  let resolved_str = resolve_scalar("hello", failsafe_schema)
  inspect(resolved_str, content="String(\"hello\")")
}

///|
test "special float values" {
  let nan_yaml = Float(0.0 / 0.0)
  let inf_yaml = Float(1.0 / 0.0)
  let neg_inf_yaml = Float(-1.0 / 0.0)
  let nan_str = stringify(nan_yaml)
  let inf_str = stringify(inf_yaml)
  let neg_inf_str = stringify(neg_inf_yaml)
  inspect(nan_str, content="\".nan\"")
  inspect(inf_str, content="\".inf\"")
  inspect(neg_inf_str, content="\"-.inf\"")
}

///|
test "string utility functions" {
  // Test string repeat
  inspect("abc".repeat(3), content="\"abcabcabc\"")
  inspect("x".repeat(0), content="\"\"")

  // Test string trim
  inspect("  hello  ".trim(), content="\"hello\"")
  inspect("\nhello\n".trim(), content="\"hello\"")

  // Test string split
  let parts = "a,b,c".split(",")
  inspect(parts.length(), content="3")
  inspect(parts[0], content="\"a\"")
  inspect(parts[2], content="\"c\"")

  // Test starts_with
  inspect("hello world".starts_with("hello"), content="true")
  inspect("hello world".starts_with("world"), content="false")

  // Test contains_char
  inspect("hello".contains_char('l'), content="true")
  inspect("hello".contains_char('z'), content="false")
}

///|
test "array join utility" {
  let strings = ["apple", "banana", "cherry"]
  let joined = join(strings, ", ")
  inspect(joined, content="\"apple, banana, cherry\"")
  let empty : Array[String] = []
  let empty_joined = join(empty, ",")
  inspect(empty_joined, content="\"\"")
  let single = ["solo"]
  let single_joined = join(single, ",")
  inspect(single_joined, content="\"solo\"")
}

///|
test "character constants availability" {
  // Test that character constants from chars.mbt are accessible
  inspect(SPACE, content="32")
  inspect(TAB, content="9")
  inspect(LINE_FEED, content="10")
  inspect(COLON, content="58")

  // Test character utility functions
  inspect(is_whitespace_or_eol(' '), content="true")
  inspect(is_whitespace_or_eol('\n'), content="true")
  inspect(is_whitespace_or_eol('a'), content="false")
  inspect(is_flow_indicator(','), content="true")
  inspect(is_flow_indicator('['), content="true")
  inspect(is_flow_indicator('a'), content="false")
}

///|
test "builtin type handlers" {
  // Test type construction and resolution
  let str_type = str_yaml_type()
  let bool_type = bool_yaml_type()
  let int_type = int_yaml_type()

  // Test string type
  inspect(str_type.tag, content="\"tag:yaml.org,2002:str\"")
  inspect(str_type.kind, content="Scalar")

  // Test boolean type resolution
  inspect(bool_type.resolve(String("true")), content="true")
  inspect(bool_type.resolve(String("false")), content="true")
  inspect(bool_type.resolve(String("maybe")), content="false")

  // Test integer type construction
  let int_result = int_type.construct(String("42"))
  inspect(int_result, content="Int(42)")
}

///|
test "yaml error types" {
  let parse_error = ParseError("Invalid syntax", 5, 10)
  let type_error = TypeError("Type mismatch")
  let syntax_error = SyntaxError("Missing colon")

  // Test error creation (errors are values, not exceptions in this demo)
  match parse_error {
    ParseError(msg, line, col) => {
      inspect(msg, content="\"Invalid syntax\"")
      inspect(line, content="5")
      inspect(col, content="10")
    }
    _ => fail("Expected ParseError")
  }
}

///|
test "parse options and defaults" {
  let default_opts = ParseOptions::default()
  inspect(default_opts.schema, content="\"default\"")
  inspect(default_opts.allow_duplicate_keys, content="false")
  let stringify_opts = StringifyOptions::default()
  inspect(stringify_opts.indent, content="2")
  inspect(stringify_opts.array_indent, content="true")
  inspect(stringify_opts.sort_keys, content="false")
}

///|
test "demonstrate full yaml conversion workflow" {
  // Create complex YAML data structure
  let complex_data = yaml_object([
    ("title", String("MoonBit YAML Demo")),
    ("version", String("1.0.0")),
    (
      "features",
      yaml_array([
        String("Parsing"),
        String("Stringifying"),
        String("Schema support"),
      ]),
    ),
    (
      "config",
      yaml_object([
        ("debug", Bool(true)),
        ("max_depth", Int(10)),
        ("timeout", Float(30.5)),
      ]),
    ),
  ])

  // Convert to YAML string
  let yaml_output = stringify(complex_data)

  // Verify the output contains expected elements
  inspect(yaml_output.contains_char(':'), content="true")
  inspect(yaml_output.contains_char('-'), content="true")
  inspect(yaml_output.contains_char('\n'), content="true")

  // Test that we can parse simple structures back
  let simple_yaml = "title: Test\ncount: 5"
  let parsed = parse(simple_yaml)
  match parsed {
    Object(obj) => {
      inspect(obj.size(), content="2")
      inspect(obj.contains("title"), content="true")
      inspect(obj.contains("count"), content="true")
    }
    _ => fail("Expected object from parse")
  }
}
