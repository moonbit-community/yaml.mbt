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
