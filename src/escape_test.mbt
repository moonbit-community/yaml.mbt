///|
/// The escapes of double-quoted scalars (YAML 1.2 §5.7). `\v`, `\f`, `\r`,
/// `\e` and `\ ` were mapped to the characters whose *decimal* codes are
/// their hex codes (U+0011, U+0012, U+0013, U+0027 `'`, U+0032 `2`).
test "double-quoted escapes" {
  let docs = @yaml.Yaml::load_from_string(
    "- \"\\0\\a\\b\\t\\n\\v\\f\\r\\e\\ \\\"\\/\\\\\"\n- \"\\N\\_\\L\\P\\x41\\u00e9\\U0001F600\"",
  )
  guard docs[0] is Array([String(controls), String(unicode)]) else {
    fail("unexpected document")
  }
  assert_eq(controls.iter().map(c => c.to_int()).collect(), [
    0, 7, 8, 9, 10, 11, 12, 13, 27, 32, 34, 47, 92,
  ])
  assert_eq(unicode.iter().map(c => c.to_int()).collect(), [
    0x85, 0xA0, 0x2028, 0x2029, 0x41, 0xE9, 0x1F600,
  ])
}
