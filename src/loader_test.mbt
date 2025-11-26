///|
test "keep tags across multiple documents" {
  let source =
    #|%YAML 1.1
    #|%TAG !t! tag:test,2024:
    #|--- !t!1 &1
    #|foo: "bar"
    #|--- !t!2 &2
    #|baz: "qux"
  let parser = Parser::new(source)
  parser.keep_tags(true)
  let docs = Yaml::load_from_parser(parser)
  @json.inspect(docs, content=[{ "foo": "bar" }, { "baz": "qux" }])
}

///|
test "empty doc" {
  let source = "---"
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  let yaml = docs[0]
  assert_true(yaml is Yaml::Null)
  let source = ""
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 0)
  let source = "&a"
  let docs = Yaml::load_from_string(source)
  let doc = docs[0]
  assert_true(doc is Yaml::Null)
}

///|
test "basic" {
  let source =
    #|# comment
    #|a0 bb: val
    #|a1:
    #|    b1: 4
    #|    b2: d
    #|a2: 4 # i'm comment
    #|a3: [1, 2, 3]
    #|a4:
    #|    - - a1
    #|      - a2
    #|    - 2
    #|a5: 'single_quoted'
    #|a6: "double_quoted"
    #|a7: 你好
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  let doc = docs[0]
  @json.inspect(doc, content={
    "a0 bb": "val",
    "a1": { "b1": 4, "b2": "d" },
    "a2": 4,
    "a3": [1, 2, 3],
    "a4": [["a1", "a2"], 2],
    "a5": "single_quoted",
    "a6": "double_quoted",
    "a7": "你好",
  })
  let source =
    #|# from yaml-cpp example
    #|- name: Ogre
    #|  position: [0, 5, 0]
    #|  powers:
    #|    - name: Club
    #|      damage: 10
    #|    - name: Fist
    #|      damage: 8
    #|- name: Dragon
    #|  position: [1, 0, 10]
    #|  powers:
    #|    - name: Fire Breath
    #|      damage: 25
    #|    - name: Claws
    #|      damage: 15
    #|- name: Wizard
    #|  position: [5, -3, 0]
    #|  powers:
    #|    - name: Acid Rain
    #|      damage: 50
    #|    - name: Staff
    #|      damage: 3
  let docs = Yaml::load_from_string(source)
  @json.inspect(docs, content=[
    [
      {
        "name": "Ogre",
        "position": [0, 5, 0],
        "powers": [
          { "name": "Club", "damage": 10 },
          { "name": "Fist", "damage": 8 },
        ],
      },
      {
        "name": "Dragon",
        "position": [1, 0, 10],
        "powers": [
          { "name": "Fire Breath", "damage": 25 },
          { "name": "Claws", "damage": 15 },
        ],
      },
      {
        "name": "Wizard",
        "position": [5, -3, 0],
        "powers": [
          { "name": "Acid Rain", "damage": 50 },
          { "name": "Staff", "damage": 3 },
        ],
      },
    ],
  ])
}

///|
test "multi doc" {
  let source =
    #|'a scalar'
    #|---
    #|'a scalar'
    #|---
    #|'a scalar'
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 3)
}

///|
test "anchor" {
  let source =
    #|a1: &DEFAULT
    #|    b1: 4
    #|    b2: d
    #|a2: *DEFAULT
  let docs = Yaml::load_from_string(source)
  let doc = docs[0]
  @json.inspect(doc, content={
    "a1": { "b1": 4, "b2": "d" },
    "a2": { "b1": 4, "b2": "d" },
  })
}

///|
test "bad anchor" {
  let source =
    #|a1: &DEFAULT
    #|    b1: 4
    #|    b2: *DEFAULT
  let docs = Yaml::load_from_string(source)
  let doc = docs[0]
  guard doc is Yaml::Map(yaml_map) && yaml_map["a1"] is Yaml::Map(yaml_map) else {
    fail("\{doc}")
  }
  inspect(yaml_map["b2"], content="BadValue")
}

///|
test "should throw error" {
  // bad hyphen
  let source = "{-"
  assert_true((try? Yaml::load_from_string(source)) is Err(_))

  // invalid trailing content after a double quoted string
  let source =
    #|"foo" l"
  assert_true((try? Yaml::load_from_string(source)) is Err(_))
}

///|
test "comment after tag" {
  let source =
    #|%YAML 1.2
    #|# This is a comment
    #|--- #-------
    #|foobar
  let docs = Yaml::load_from_string(source)
  @json.inspect(docs, content=["foobar"])
}

///|
test "large block scalar indent" {
  let source =
    #|a: |-
    #|                  a
    #|                      b
  let docs = Yaml::load_from_string(source)
  @json.inspect(docs, content=[{ "a": "a\n    b" }])
}

///|
test "bad docstart" {
  @json.inspect(
    Yaml::load_from_string("---This used to cause an infinite loop"),
    content=["---This used to cause an infinite loop"],
  )
  @json.inspect(Yaml::load_from_string("----"), content=["----"])
  @json.inspect(Yaml::load_from_string("--- #here goes a comment"), content=[
    null,
  ])
  @json.inspect(Yaml::load_from_string("---- #here goes a comment"), content=[
    "----",
  ])
}

///|
test "plain datatype" {
  let source =
    #|- 'string'
    #|- "string"
    #|- string
    #|- 123
    #|- -321
    #|- 1.23
    #|- -1e4
    #|- ~
    #|- null
    #|- true
    #|- false
    #|- !!str 0
    #|- !!int 100
    #|- !!float 2
    #|- !!null ~
    #|- !!bool true
    #|- !!bool false
    #|- 0xFF
    #|# bad values
    #|- !!int string
    #|- !!float string
    #|- !!bool null
    #|- !!null val
    #|- 0o77
    #|- [ 0xF, 0xF ]
    #|- +12345
    #|- [ true, false ]
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  guard docs[0] is Yaml::Array(yaml_array) else {
    fail("expect yaml array but got \{docs[0]}")
  }
  inspect(
    yaml_array[0],
    content=(
      #|String("string")
    ),
  )
  inspect(
    yaml_array[1],
    content=(
      #|String("string")
    ),
  )
  inspect(
    yaml_array[2],
    content=(
      #|String("string")
    ),
  )
  inspect(yaml_array[3], content="Integer(123)")
  inspect(yaml_array[4], content="Integer(-321)")
  inspect(
    yaml_array[5],
    content=(
      #|Real(1.23, repr="1.23")
    ),
  )
  inspect(
    yaml_array[6],
    content=(
      #|Real(-10000, repr="-1e4")
    ),
  )
  inspect(yaml_array[7], content="Null")
  inspect(yaml_array[8], content="Null")
  inspect(yaml_array[9], content="Boolean(true)")
  inspect(yaml_array[10], content="Boolean(false)")
  inspect(
    yaml_array[11],
    content=(
      #|String("0")
    ),
  )
  inspect(yaml_array[12], content="Integer(100)")
  inspect(
    yaml_array[13],
    content=(
      #|Real(2, repr="2")
    ),
  )
  inspect(yaml_array[14], content="Null")
  inspect(yaml_array[15], content="Boolean(true)")
  inspect(yaml_array[16], content="Boolean(false)")
  inspect(yaml_array[17], content="Integer(255)")
  inspect(yaml_array[18], content="BadValue")
  inspect(yaml_array[19], content="BadValue")
  inspect(yaml_array[20], content="BadValue")
  inspect(yaml_array[21], content="BadValue")
  inspect(yaml_array[22], content="Integer(63)")
  inspect(yaml_array[23], content="Array([Integer(15), Integer(15)])")
  inspect(yaml_array[24], content="Integer(12345)")
  inspect(yaml_array[25], content="Array([Boolean(true), Boolean(false)])")
}

///|
test "map order" {
  let source =
    #|---
    #|b: ~
    #|a: ~
    #|c: ~
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  guard docs[0] is Yaml::Map(map) else {
    fail("expect yaml map but got \{docs[0]}")
  }
  @json.inspect(map.iter().collect(), content=[
    ["b", null],
    ["a", null],
    ["c", null],
  ])
}

///|
test "integer key" {
  // always fail by design
  let source =
    #|0:
    #|    important: true
    #|1:
    #|    important: false
  guard (try? Yaml::load_from_string(source)) is Err(YamlError(info~, ..))
  inspect(info, content="yaml.mbt doesn't support non-string key")
}

///|
test "indentation equality" {
  let four_spaces =
    #|hash:
    #|    with:
    #|        indentations
  let four_spaces = Yaml::load_from_string(four_spaces)
  let two_spaces =
    #|hash:
    #|  with:
    #|    indentations
  let two_spaces = Yaml::load_from_string(two_spaces)
  let one_space =
    #|hash:
    #| with:
    #|  indentations
  let one_space = Yaml::load_from_string(one_space)
  let mixed_spaces =
    #|hash:
    #|     with:
    #|               indentations
  let mixed_spaces = Yaml::load_from_string(mixed_spaces)
  assert_eq(four_spaces, two_spaces)
  assert_eq(two_spaces, one_space)
  assert_eq(four_spaces, mixed_spaces)
}

///|
test "two space indentations" {
  let source =
    #|subcommands:
    #|  - server:
    #|    about: server related commands
    #|subcommands2:
    #|  - server:
    #|      about: server related commands
    #|subcommands3:
    #| - server:
    #|    about: server related commands
  let docs = Yaml::load_from_string(source)
  @json.inspect(docs, content=[
    {
      "subcommands": [{ "server": null, "about": "server related commands" }],
      "subcommands2": [{ "server": { "about": "server related commands" } }],
      "subcommands3": [{ "server": { "about": "server related commands" } }],
    },
  ])
}

///|
test "recursion depth check objects" {
  let buf = StringBuilder::new(size_hint=4 * 2 * 10_000)
  for _ in 0..<10_000 {
    buf.write_string("{a:")
  }
  for _ in 0..<10_000 {
    buf.write_string("}")
  }
  let source = buf.to_string()
  assert_true((try? Yaml::load_from_string(source)) is Err(_))
}

///|
test "recursion depth check arrays" {
  let buf = StringBuilder::new(size_hint=2 * 2 * 10_000)
  for _ in 0..<10_000 {
    buf.write_char('[')
  }
  for _ in 0..<10_000 {
    buf.write_char(']')
  }
  let source = buf.to_string()
  assert_true((try? Yaml::load_from_string(source)) is Err(_))
}

///|
test "mapping duplicates" {
  let source =
    #|a: foo
    #|a: bar
  assert_true((try? Yaml::load_from_string(source)) is Err(_))
}

///|
test "nominal float parse" {
  // Generates a document that looks like so:
  // ```yaml
  // - +nan
  // - -nan
  // - nan
  // - +NAN
  // ```
  // Every single one of these values should be parsed as a string in yaml,
  let buf = StringBuilder::new(size_hint=400)
  let bases = ["nan", "NAN", "NaN", "inf", "infinity", "Infinity"]
  for base in bases {
    buf.write_string("- +\{base}\n")
    buf.write_string("- -\{base}\n")
    buf.write_string("- \{base}\n")
  }
  let source = buf.to_string()
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  guard docs[0] is Yaml::Array(yaml_array) else {
    fail("expect yaml array but got \{docs[0]}")
  }
  for yaml in yaml_array {
    guard yaml is Yaml::String(_) else {
      fail("expect a yaml string but got \{yaml}")
    }
  }
}

///|
test "OpenAI OpenAPI" (t : @test.Test) {
  let source = @fs.read_file_to_string("misc/openai_openapi.yml")
  let docs = Yaml::load_from_string(source)
  assert_eq(docs.length(), 1)
  guard docs[0] is Yaml::Map(yaml_map) else {
    fail("\{t.name()}: expect a YAML map")
  }
  @json.inspect(yaml_map.keys().collect(), content=[
    "openapi", "info", "servers", "security", "tags", "paths", "webhooks", "components",
    "x-oaiMeta",
  ])
  @json.inspect(yaml_map["servers"], content=[
    { "url": "https://api.openai.com/v1" },
  ])
  @json.inspect(yaml_map["info"], content={
    "title": "OpenAI API",
    "description": "The OpenAI REST API. Please see https://platform.openai.com/docs/api-reference for more details.",
    "version": "2.3.0",
    "termsOfService": "https://openai.com/policies/terms-of-use",
    "contact": { "name": "OpenAI Support", "url": "https://help.openai.com/" },
    "license": {
      "name": "MIT",
      "url": "https://github.com/openai/openai-openapi/blob/master/LICENSE",
    },
  })
}
