///|
fn Lexer::next_t(self : Lexer) -> TokenType {
  self.next().unwrap().token_type
}

///|
test "empty" {
  let p = Lexer::new("")
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "scalar" {
  let p = Lexer::new("a scalar")
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a scalar")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "explicit scalar" {
  let s =
    #|---
    #|'a scalar'
    #|...
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  debug_inspect(p.next_t(), content="DocumentEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "multiple documents" {
  let s =
    #|'a scalar'
    #|---
    #|'a scalar'
    #|---
    #|'a scalar'
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "flow sequence" {
  let s = "[item 1, item 2, item 3]"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="FlowSequenceStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3")
    ),
  )
  debug_inspect(p.next_t(), content="FlowSequenceEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "flow mapping" {
  let s =
    #|{
    #|    a simple key: a value, # Note that the KEY token is produced.
    #|    ? a complex key: another value,
    #|}
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="FlowMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a simple key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a value")
    ),
  )
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a complex key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "another value")
    ),
  )
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(p.next_t(), content="FlowMappingEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "block sequences" {
  let s =
    #|- item 1
    #|- item 2
    #|-
    #|  - item 3.1
    #|  - item 3.2
    #|-
    #|  key 1: value 1
    #|  key 2: value 2
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3.1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3.2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "block mappings" {
  let s =
    #|a simple key: a value   # The KEY token is produced here.
    #|? a complex key
    #|: another value
    #|a mapping:
    #|  key 1: value 1
    #|  key 2: value 2
    #|a sequence:
    #|  - item 1
    #|  - item 2
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a simple key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a value")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a complex key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "another value")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a mapping")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a sequence")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "no block sequence start" {
  let s =
    #|key:
    #|- item 1
    #|- item 2
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "collections in sequence" {
  let s =
    #|- - item 1
    #|  - item 2
    #|- key 1: value 1
    #|  key 2: value 2
    #|- ? complex key
    #|  : complex value
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "complex key")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "complex value")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "collections in mapping" {
  let s =
    #|? a sequence
    #|: - item 1
    #|  - item 2
    #|? a mapping
    #|: key 1: value 1
    #|  key 2: value 2
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a sequence")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a mapping")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "spec ex7_3" {
  let s =
    #|{
    #|    ? foo :,
    #|    : bar,
    #|}
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="FlowMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "foo")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "bar")
    ),
  )
  debug_inspect(p.next_t(), content="FlowEntry")
  debug_inspect(p.next_t(), content="FlowMappingEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "plain scalar starting with indicators in flow" {
  // "Plain scalars must not begin with most indicators, as this would cause ambiguity with
  // other YAML constructs. However, the “:”, “?” and “-” indicators may be used as the first
  // character if followed by a non-space “safe” character, as this causes no ambiguity."
  let s = "{a: :b}"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="FlowMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":b")
    ),
  )
  debug_inspect(p.next_t(), content="FlowMappingEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
  let s = "{a: ?b}"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="FlowMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "?b")
    ),
  )
  debug_inspect(p.next_t(), content="FlowMappingEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "plain scalar starting with indicators in block" {
  let s = ":a"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":a")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
  let s = "?a"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "?a")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "plain scalar containing indicators in block" {
  let s = "a:,b"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a:,b")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
  let s = ":,b"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":,b")
    ),
  )
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "lexer cr" {
  let s = "---\r\n- tok1\r\n- tok2"
  let p = Lexer::new(s)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "tok1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "tok2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "keep tags across multiple documents" {
  let source =
    #|%YAML 1.1
    #|%TAG !t! tag:test,2024:
    #|--- !t!1 &1
    #|foo: "bar"
    #|--- !t!2 &2
    #|baz: "qux"
  let p = Lexer::new(source)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="VersionDirective(major=1, minor=1)")
  debug_inspect(
    p.next_t(),
    content=(
      #|TagDirective(handle="!t!", prefix="tag:test,2024:")
    ),
  )
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!t!", suffix="1")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Anchor("1")
    ),
  )
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "foo")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(DoubleQuoted, "bar")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="DocumentStart")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!t!", suffix="2")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Anchor("2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "baz")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(DoubleQuoted, "qux")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "large block scalar indent" {
  let source =
    #|a: |-
    #|                  a
    #|                      b
  let p = Lexer::new(source)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Literal, "a\n    b")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "tag directives" {
  let source =
    #|- !!str 0
    #|- !!int 100
    #|- !!float 2
    #|- !!null ~
    #|- !!bool true
    #|- !!bool false
  let p = Lexer::new(source)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="str")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "0")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="int")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "100")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="float")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "2")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="null")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "~")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="bool")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "true")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Tag(handle="!!", suffix="bool")
    ),
  )
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "false")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "looks like float but actually string" {
  let buf = StringBuilder::new(size_hint=400)
  let bases = ["nan", "NAN", "NaN", "inf", "infinity", "Infinity"]
  for base in bases {
    buf.write_string("- +\{base}\n")
    buf.write_string("- -\{base}\n")
    buf.write_string("- \{base}\n")
  }
  let source = buf.to_string()
  let p = Lexer::new(source)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockSequenceStart")
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+nan")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-nan")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "nan")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+NAN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-NAN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "NAN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+NaN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-NaN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "NaN")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+inf")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-inf")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "inf")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "+Infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "-Infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEntry")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "Infinity")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}

///|
test "testcase from OpenAI OpenAPI" {
  let source =
    #|example: '[''This is a test.'']'
  let p = Lexer::new(source)
  debug_inspect(p.next_t(), content="StreamStart")
  debug_inspect(p.next_t(), content="BlockMappingStart")
  debug_inspect(p.next_t(), content="Key")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "example")
    ),
  )
  debug_inspect(p.next_t(), content="Value")
  debug_inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "['This is a test.']")
    ),
  )
  debug_inspect(p.next_t(), content="BlockEnd")
  debug_inspect(p.next_t(), content="StreamEnd")
  debug_inspect(p.next(), content="None")
}
