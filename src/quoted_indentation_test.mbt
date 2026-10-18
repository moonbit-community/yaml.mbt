///|
/// Load `source` with `lenient_quoted_scalar_indentation` (js-yaml
/// compatibility), as JSON, or the error.
fn load_lenient(source : String) -> String {
  try {
    let docs = @yaml.Yaml::load_from_string(
      source,
      lenient_quoted_scalar_indentation=true,
    )
    docs.map(d => d.to_json().stringify()).join("|")
  } catch {
    YamlError(info~, ..) => "error: \{info}"
  }
}

///|
/// The continuation lines of a quoted scalar in a block collection must be
/// indented (`s-flow-line-prefix(n)`, yaml-test-suite QB6E). This is the
/// default, strict behaviour.
test "strict: under-indented quoted scalars are an error (QB6E)" {
  // QB6E itself
  inspect(
    load_result("---\nquoted: \"a\nb\nc\""),
    content="error: invalid indentation in quoted scalar",
  )
  // continuation at the key's column, and at column 0
  inspect(
    load_result("config:\n  themeCSS: \"a\n  b\""),
    content="error: invalid indentation in quoted scalar",
  )
  inspect(
    load_result("config:\n  themeCSS: \"a\nb\""),
    content="error: invalid indentation in quoted scalar",
  )
  // closing quote alone on a less indented line
  inspect(
    load_result("k:\n  a: \"x\n      b\n  \""),
    content="error: invalid indentation in quoted scalar",
  )
  // single quotes
  inspect(
    load_result("k:\n  a: 'x\n  b'"),
    content="error: invalid indentation in quoted scalar",
  )
  // in a flow collection nested in a block mapping
  inspect(
    load_result("k:\n  a: [ \"x\ny\" ]"),
    content="error: invalid indentation in quoted scalar",
  )
  // a tab in the indentation of a continuation line
  inspect(
    load_result("k:\n  a: \"x\n\t b\""),
    content="error: tab cannot be used as indentation",
  )
  // correctly indented continuation lines are fine
  inspect(
    load_result("config:\n  themeCSS: \"a\n   b\""),
    content="{\"config\":{\"themeCSS\":\"a b\"}}",
  )
  // the explicit `false` is the default
  inspect(
    try {
      @yaml.Yaml::load_from_string(
        "k:\n  a: \"x\nb\"",
        lenient_quoted_scalar_indentation=false,
      )
      |> ignore
      "loaded"
    } catch {
      YamlError(info~, ..) => info
    },
    content="invalid indentation in quoted scalar",
  )
}

///|
test "lenient: under-indented continuation lines of quoted scalars" {
  // continuation at the key's column
  inspect(
    load_lenient(
      (
        #|config:
        #|  themeCSS: "a
        #|  b"
      ),
    ),
    content=(
      #|{"config":{"themeCSS":"a b"}}
    ),
  )
  // continuation at column 0
  inspect(
    load_lenient(
      (
        #|config:
        #|  themeCSS: "a
        #|b"
      ),
    ),
    content=(
      #|{"config":{"themeCSS":"a b"}}
    ),
  )
  // QB6E
  inspect(
    load_lenient(
      (
        #|---
        #|quoted: "a
        #|b
        #|c"
      ),
    ),
    content=(
      #|{"quoted":"a b c"}
    ),
  )
  // the closing quote alone on a less indented line: the line break before
  // it folds to a space
  inspect(
    load_lenient(
      (
        #|config:
        #|  k:
        #|    a: "x
        #|      b
        #|  "
      ),
    ),
    content=(
      #|{"config":{"k":{"a":"x b "}}}
    ),
  )
  // leading white space of a continuation line, tabs included, is not
  // content; neither is white space before a line break
  inspect(
    load_lenient("k:\n  a: \"x   \n\t b\""),
    content=(
      #|{"k":{"a":"x b"}}
    ),
  )
  // a `#` or a `---` not followed by a blank at the start of a line is
  // content
  inspect(
    load_lenient("k:\n  a: \"x\n# c\n---x\""),
    content=(
      #|{"k":{"a":"x # c ---x"}}
    ),
  )
}

///|
test "lenient: single-quoted scalars" {
  inspect(
    load_lenient(
      (
        #|config:
        #|  k: 'a
        #|  b'
        #|  l: 'it''s
        #|c'
      ),
    ),
    content=(
      #|{"config":{"k":"a b","l":"it's c"}}
    ),
  )
}

///|
test "lenient: escapes, escaped line breaks and empty lines" {
  // an escaped `\n` before a real line break, then an empty line: the
  // escape is kept, and the line break followed by one empty line folds to
  // one `\n`
  inspect(
    load_lenient("k:\n  a: \"a\\n\n\n  b\""),
    content=(
      #|{"k":{"a":"a\n\nb"}}
    ),
  )
  // an empty line folds to `\n`
  inspect(
    load_lenient("k:\n  a: \"a\n\nb\n\n\n  c\""),
    content=(
      #|{"k":{"a":"a\nb\n\nc"}}
    ),
  )
  // an escaped line break joins the lines without a space
  inspect(
    load_lenient("k:\n  a: \"a\\\nb\""),
    content=(
      #|{"k":{"a":"ab"}}
    ),
  )
}

///|
test "the line of the closing quote is checked however it is reached" {
  // An escaped line break followed directly by the closing quote, or by more
  // escaped line breaks, consumes the line break itself: the closing quote's
  // line is still checked against the indentation (strict) and recorded as
  // under-indented (lenient), so the `]` or `,` after it is accepted.
  inspect(
    load_result("k:\n  a: \"x\\\n\""),
    content="error: invalid indentation in quoted scalar",
  )
  inspect(
    load_result("k:\n    a: [ \"x\\\n\" ]"),
    content="error: invalid indentation in quoted scalar",
  )
  inspect(
    load_result("k:\n  a: \"x\\\n   \""),
    content=(
      #|{"k":{"a":"x"}}
    ),
  )
  inspect(
    load_lenient("k:\n  a: \"x\\\n\""),
    content=(
      #|{"k":{"a":"x"}}
    ),
  )
  inspect(
    load_lenient("k:\n    a: [ \"x\\\n\" ]"),
    content=(
      #|{"k":{"a":["x"]}}
    ),
  )
  inspect(
    load_lenient("k:\n    a: [ \"x\\\n\", y ]"),
    content=(
      #|{"k":{"a":["x","y"]}}
    ),
  )
  // several escaped line breaks, then the quote or content at column 0
  inspect(
    load_lenient("k:\n    a: [ \"x\\\n\\\n\" ]"),
    content=(
      #|{"k":{"a":["x"]}}
    ),
  )
  inspect(
    load_lenient("k:\n  a: \"x\\\n\\\ny\""),
    content=(
      #|{"k":{"a":"xy"}}
    ),
  )
  // an escape right after an escaped line break
  inspect(
    load_lenient("k:\n    a: [ \"x\\\n\\t\" ]"),
    content=(
      #|{"k":{"a":["x\t"]}}
    ),
  )
  // single quotes: the closing quote, and a `''` escape, at column 0
  inspect(
    load_lenient("k:\n    a: [ 'x\n' ]"),
    content=(
      #|{"k":{"a":["x "]}}
    ),
  )
  inspect(
    load_lenient("k:\n    a: [ 'x\n''' ]"),
    content=(
      #|{"k":{"a":["x '"]}}
    ),
  )
  inspect(
    load_lenient("k:\n    a: [ 'x\n''y' ]"),
    content=(
      #|{"k":{"a":["x 'y"]}}
    ),
  )
  // an empty line after an escaped line break is a line feed
  // (`l-empty(n,flow-in)*` in `s-double-escaped(n)`); js-yaml drops it
  inspect(
    load_lenient("k:\n    a: [ \"x\\\n\n\" ]"),
    content=(
      #|{"k":{"a":["x\n"]}}
    ),
  )
}

///|
test "lenient: the enclosing block structure is kept" {
  // a following sibling key
  inspect(
    load_lenient(
      (
        #|config:
        #|  a: "x
        #| b"
        #|  c: 1
      ),
    ),
    content=(
      #|{"config":{"a":"x b","c":1}}
    ),
  )
  // nested mappings, and a key of an outer mapping after the scalar
  inspect(
    load_lenient(
      (
        #|a:
        #|  b:
        #|    c: "x
        #|  y
        #|"
        #|    d: 1
        #|  e: 2
        #|f: 3
      ),
    ),
    content=(
      #|{"a":{"b":{"c":"x y ","d":1},"e":2},"f":3}
    ),
  )
  // sequence items, at the top level and nested
  inspect(
    load_lenient("- \"a\nb\""),
    content=(
      #|["a b"]
    ),
  )
  inspect(
    load_lenient(
      (
        #|k:
        #|  - "a
        #|b"
        #|  - 'c
        #|d'
        #|  - e
      ),
    ),
    content=(
      #|{"k":["a b","c d","e"]}
    ),
  )
  // a comment after the closing quote
  inspect(
    load_lenient("k:\n    a: \"x\n\" # c\n    b: 1"),
    content=(
      #|{"k":{"a":"x ","b":1}}
    ),
  )
}

///|
/// Flow collections nested in a block collection: js-yaml accepts the
/// under-indented continuation lines of quoted scalars there too, and so does
/// the option. A flow collection line that starts with a new token is still
/// checked.
test "lenient: quoted scalars in flow collections" {
  inspect(
    load_lenient("k:\n  a: [ \"x\ny\" ]"),
    content=(
      #|{"k":{"a":["x y"]}}
    ),
  )
  inspect(
    load_lenient("k:\n  a: { b: 'x\ny' }"),
    content=(
      #|{"k":{"a":{"b":"x y"}}}
    ),
  )
  // the tokens after the closing quote, on its line
  inspect(
    load_lenient("k:\n    a: [ \"x\n\", y, \"z\" ]"),
    content=(
      #|{"k":{"a":["x ","y","z"]}}
    ),
  )
  // a flow collection line starting with an entry is not a continuation line
  // of a quoted scalar
  inspect(
    load_lenient("k:\n    a: [ \"x\",\n\"y\" ]"),
    content="error: invalid indentation",
  )
  inspect(
    load_lenient("k:\n    a: [ \"x\n\",\ny ]"),
    content="error: invalid indentation",
  )
}

///|
test "lenient: what stays an error" {
  // a document marker at the start of a line inside the scalar
  inspect(
    load_lenient("k:\n  a: \"x\n---\n  b\""),
    content="error: while scanning a quoted scalar, found unexpected document indicator",
  )
  inspect(
    load_lenient("k:\n  a: 'x\n...\n  b'"),
    content="error: while scanning a quoted scalar, found unexpected document indicator",
  )
  // an unterminated scalar
  inspect(
    load_lenient("k:\n  a: \"x\nb"),
    content="error: while scanning a quoted scalar, found unexpected end of stream",
  )
  inspect(
    load_lenient("k:\n  a: 'x\n"),
    content="error: while scanning a quoted scalar, found unexpected end of stream",
  )
  // under-indented plain scalars are not continued (js-yaml rejects them
  // too): the line is a new key without `:`
  inspect(
    load_lenient("config:\n  k: a\n  b"),
    content="error: simple key expected",
  )
  inspect(
    load_lenient("config:\n  k: a\nb"),
    content="error: simple key expected",
  )
  // nor are block scalars
  inspect(
    load_lenient("config:\n  k: |\n    a\n  b"),
    content="error: simple key expected",
  )
  // content after the closing quote
  inspect(
    load_lenient("k:\n  a: \"x\n\" z"),
    content="error: invalid trailing content after double-quoted scalar",
  )
  // a multi-line implicit key
  inspect(
    load_lenient("k:\n  \"a\nb\": 1"),
    content="error: invalid trailing content after double-quoted scalar",
  )
}

///|
test "lenient: Parser::new(lenient_quoted_scalar_indentation=true)" {
  let parser = @yaml.Parser::new(
    "config:\n  themeCSS: \"a\nb\"",
    lenient_quoted_scalar_indentation=true,
  )
  json_inspect(@yaml.Yaml::load_from_parser(parser), content=[
    { "config": { "themeCSS": "a b" } },
  ])
}

///|
/// The frontmatter of the gantt example of the mermaid docs (with
/// `themeCSS`), which js-yaml loads. The expected `themeCSS` is the value
/// js-yaml 4 produces: each `\n` escape is kept and the real line break after
/// it folds to a space; the leading white space of each continuation line is
/// dropped; the line break followed by an empty line folds to one `\n` (so
/// `\n\n// Custom`); the line break before the closing quote folds to a
/// trailing space:
///
/// " // YAML supports multiline strings using a newline markers: \n #item36 { fill: CadetBlue }       \n\n// Custom marker workaround CSS from forum (below)    \n rect[id^=workaround] { height: calc(100% - 50px) ; transform: translate(9px, 25px); y: 0; width: 1.5px; stroke: none; fill: red; }   \n text[id^=workaround] { fill: red; y: 100%; font-size: 15px;} "
test "lenient: mermaid gantt frontmatter with themeCSS" {
  let source =
    #|    # Frontmatter config, YAML comments
    #|    title: Ignored if specified in chart
    #|    displayMode: compact     #gantt specific setting but works at this level too
    #|    config:
    #|#        theme: forest
    #|#        themeCSS: " #item36 { fill: CadetBlue } "
    #|        themeCSS: " // YAML supports multiline strings using a newline markers: \n
    #|            #item36 { fill: CadetBlue }       \n
    #|
    #|            // Custom marker workaround CSS from forum (below)    \n
    #|            rect[id^=workaround] { height: calc(100% - 50px) ; transform: translate(9px, 25px); y: 0; width: 1.5px; stroke: none; fill: red; }   \n
    #|            text[id^=workaround] { fill: red; y: 100%; font-size: 15px;}
    #|        "
    #|        gantt:
    #|            useWidth: 400
    #|            rightPadding: 0
    #|            topAxis: true  #false
    #|            numberSectionStyles: 2
  inspect(
    load_result(source),
    content="error: invalid indentation in quoted scalar",
  )
  let docs = @yaml.Yaml::load_from_string(
    source,
    lenient_quoted_scalar_indentation=true,
  )
  guard docs is [Map(doc)] && doc.get("config") is Some(Map(config)) else {
    fail("unexpected documents")
  }
  assert_eq(
    config.get("themeCSS"),
    Some(
      String(
        " // YAML supports multiline strings using a newline markers: \n #item36 { fill: CadetBlue }       \n\n// Custom marker workaround CSS from forum (below)    \n rect[id^=workaround] { height: calc(100% - 50px) ; transform: translate(9px, 25px); y: 0; width: 1.5px; stroke: none; fill: red; }   \n text[id^=workaround] { fill: red; y: 100%; font-size: 15px;} ",
      ),
    ),
  )
  json_inspect(docs, content=[
    {
      "title": "Ignored if specified in chart",
      "displayMode": "compact",
      "config": {
        "themeCSS": " // YAML supports multiline strings using a newline markers: \n #item36 { fill: CadetBlue }       \n\n// Custom marker workaround CSS from forum (below)    \n rect[id^=workaround] { height: calc(100% - 50px) ; transform: translate(9px, 25px); y: 0; width: 1.5px; stroke: none; fill: red; }   \n text[id^=workaround] { fill: red; y: 100%; font-size: 15px;} ",
        "gantt": {
          "useWidth": 400,
          "rightPadding": 0,
          "topAxis": true,
          "numberSectionStyles": 2,
        },
      },
    },
  ])
}
