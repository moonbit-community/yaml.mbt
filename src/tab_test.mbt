///|
fn load_result(source : String) -> String {
  try {
    let docs = @yaml.Yaml::load_from_string(source)
    docs.map(d => d.to_json().stringify()).join("|")
  } catch {
    YamlError(info~, ..) => "error: \{info}"
  }
}

///|
/// Tabs may not indent block content (yaml-test-suite DK95/00): a line of
/// a block collection that starts with a tab is an error, as in yaml-rust2.
/// The check was inverted, so tab-indented mappings were accepted.
test "tabs as block indentation are an error" {
  assert_eq(
    load_result("foo:\n\tbar"),
    "error: tabs disallowed within this context (block indentation)",
  )
  assert_eq(
    load_result(
      "base:\n\tfont_family: Times-Roman\npage:\n\tbackground_color: fefefe\n",
    ),
    "error: tabs disallowed within this context (block indentation)",
  )
  // a line holding only tabs is fine
  assert_eq(load_result("foo:\n\t\nbar: 1"), "{\"foo\":null,\"bar\":1}")
  // tabs after the indentation, and in flow collections, are separation
  assert_eq(load_result(" \tfoo: 1"), "{\"foo\":1}")
  assert_eq(load_result("a: [1,\t2]"), "{\"a\":[1,2]}")
  assert_eq(load_result("- \tx"), "[\"x\"]")
}
