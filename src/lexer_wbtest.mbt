///|
fn Lexer::next_t(self : Lexer) -> TokenType {
  self.next().unwrap().token_type
}

///|
test "empty" {
  let p = Lexer::new("")
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "scalar" {
  let p = Lexer::new("a scalar")
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a scalar")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "explicit scalar" {
  let s =
    #|---
    #|'a scalar'
    #|...
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="DocumentStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  inspect(p.next_t(), content="DocumentEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
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
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  inspect(p.next_t(), content="DocumentStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  inspect(p.next_t(), content="DocumentStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(SingleQuoted, "a scalar")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "flow sequence" {
  let s = "[item 1, item 2, item 3]"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="FlowSequenceStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="FlowEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="FlowEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3")
    ),
  )
  inspect(p.next_t(), content="FlowSequenceEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "flow mapping" {
  let s =
    #|{
    #|    a simple key: a value, # Note that the KEY token is produced.
    #|    ? a complex key: another value,
    #|}
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="FlowMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a simple key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a value")
    ),
  )
  inspect(p.next_t(), content="FlowEntry")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a complex key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "another value")
    ),
  )
  inspect(p.next_t(), content="FlowEntry")
  inspect(p.next_t(), content="FlowMappingEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
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
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3.1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 3.2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEntry")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
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
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a simple key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a value")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a complex key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "another value")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a mapping")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a sequence")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "no block sequence start" {
  let s =
    #|key:
    #|- item 1
    #|- item 2
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
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
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEntry")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEntry")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "complex key")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "complex value")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
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
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a sequence")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "item 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a mapping")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="BlockMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 1")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 1")
    ),
  )
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "key 2")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "value 2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "spec ex7_3" {
  let s =
    #|{
    #|    ? foo :,
    #|    : bar,
    #|}
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="FlowMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "foo")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(p.next_t(), content="FlowEntry")
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "bar")
    ),
  )
  inspect(p.next_t(), content="FlowEntry")
  inspect(p.next_t(), content="FlowMappingEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "plain scalar starting with indicators in flow" {
  // "Plain scalars must not begin with most indicators, as this would cause ambiguity with
  // other YAML constructs. However, the “:”, “?” and “-” indicators may be used as the first
  // character if followed by a non-space “safe” character, as this causes no ambiguity."
  let s = "{a: :b}"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="FlowMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":b")
    ),
  )
  inspect(p.next_t(), content="FlowMappingEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
  let s = "{a: ?b}"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="FlowMappingStart")
  inspect(p.next_t(), content="Key")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a")
    ),
  )
  inspect(p.next_t(), content="Value")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "?b")
    ),
  )
  inspect(p.next_t(), content="FlowMappingEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "plain scalar starting with indicators in block" {
  let s = ":a"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":a")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
  let s = "?a"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "?a")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "plain scalar containing indicators in block" {
  let s = "a:,b"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "a:,b")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
  let s = ":,b"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, ":,b")
    ),
  )
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}

///|
test "lexer cr" {
  let s = "---\r\n- tok1\r\n- tok2"
  let p = Lexer::new(s)
  inspect(p.next_t(), content="StreamStart")
  inspect(p.next_t(), content="DocumentStart")
  inspect(p.next_t(), content="BlockSequenceStart")
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "tok1")
    ),
  )
  inspect(p.next_t(), content="BlockEntry")
  inspect(
    p.next_t(),
    content=(
      #|Scalar(Plain, "tok2")
    ),
  )
  inspect(p.next_t(), content="BlockEnd")
  inspect(p.next_t(), content="StreamEnd")
  inspect(p.next(), content="None")
}
