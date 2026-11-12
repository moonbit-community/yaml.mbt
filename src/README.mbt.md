# YAML

A simple YAML parsing and stringifying library for MoonBit, support a simplified YAML subset which can be convert to JSON.

This library is ported from yaml-rust2.

## Usage

### Basic Example

```mbt check
///|
test {
  let source =
    #|%YAML 1.2
    #|---
    #|YAML: YAML Ain't Markup Language™
    #|
    #|What It Is:
    #|  YAML is a human-friendly data serialization
    #|  language for all programming languages.
    #|
    #|YAML Resources:
    #|  YAML Specifications:
    #|  - YAML 1.2:
    #|    - Revision 1.2.2      # Oct 1, 2021 *New*
    #|    - Revision 1.2.1      # Oct 1, 2009
    #|    - Revision 1.2.0      # Jul 21, 2009
    #|  - YAML 1.1
    #|  - YAML 1.0
  json_inspect(@yaml.Yaml::load_from_string(source), content=[
    {
      "YAML": "YAML Ain't Markup Language™",
      "What It Is": "YAML is a human-friendly data serialization language for all programming languages.",
      "YAML Resources": {
        "YAML Specifications": [
          { "YAML 1.2": ["Revision 1.2.2", "Revision 1.2.1", "Revision 1.2.0"] },
          "YAML 1.1",
          "YAML 1.0",
        ],
      },
    },
  ])
}
```

### Event callbacks that can stop parsing

`Parser::load_with` accepts a callback that may raise `YamlError`. An error from
the callback stops loading immediately and preserves its marker and message;
no further events are delivered. This lets a caller enforce a depth or node
budget before the parser descends further into a collection. Limits are chosen
and enforced by the caller, rather than imposed by this API.

```mbt check
///|
test {
  let mut depth = 0
  try
    @yaml.Parser("- - - 0").load_with(
      (event, mark) => {
        match event {
          SequenceStart(..) | MappingStart(..) => {
            depth += 1
            if depth > 2 {
              raise @yaml.YamlError(mark~, info="nesting exceeds 2 levels")
            }
          }
          SequenceEnd | MappingEnd => depth -= 1
          _ => ()
        }
      },
      true,
    )
  catch {
    YamlError(mark~, info~) => {
      assert_eq(info, "nesting exceeds 2 levels")
      assert_eq(mark.line, 1)
      assert_eq(mark.col, 4)
    }
  } noraise {
    _ => fail("expected the nesting limit")
  }
}
```

The existing `Parser::load` and receiver traits remain available. Both loading
methods use the same event stream and `multi` setting: `false` stops after one
document, while `true` reads through the end of the stream. After a syntax or
callback error, discard the parser; resuming an interrupted document is not
supported.

### js-yaml compatibility: under-indented quoted scalars

By default the parser follows YAML 1.2, which requires the continuation lines
of a multi-line quoted scalar in a block collection to be indented
(`s-flow-line-prefix(n)` in `nb-double-multi-line(n)` and
`nb-single-multi-line(n)`; yaml-test-suite case QB6E is an error). js-yaml,
used by mermaid and many other tools, does not check that indentation. The
opt-in `lenient_quoted_scalar_indentation` setting accepts such documents as
js-yaml does: the continuation lines of single- and double-quoted scalars,
including the line of the closing quote, may be indented less than the
enclosing block, down to column 0, also inside a flow collection nested in a
block collection. Leading white space of those lines is still not content, and
line folding and escapes are unchanged. A document marker (`---`, `...`) at
the start of a line inside the scalar and an unterminated scalar remain
errors, and plain and block scalars are not affected.

```mbt check
///|
test {
  let source =
    #|config:
    #|  themeCSS: "a
    #|  b"
  // strict YAML 1.2
  let strict = try @yaml.Yaml::load_from_string(source) catch {
    YamlError(info~, ..) => info
  } noraise {
    _ => "loaded"
  }
  inspect(strict, content="invalid indentation in quoted scalar")
  // js-yaml compatible
  json_inspect(
    @yaml.Yaml::load_from_string(source, lenient_quoted_scalar_indentation=true),
    content=[{ "config": { "themeCSS": "a b" } }],
  )
  // or on a `Parser`, for event-level use
  let parser = @yaml.Parser(source, lenient_quoted_scalar_indentation=true)
  json_inspect(@yaml.Yaml::load_from_parser(parser), content=[
    { "config": { "themeCSS": "a b" } },
  ])
}
```
