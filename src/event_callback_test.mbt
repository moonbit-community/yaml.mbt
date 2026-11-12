///|
test "fallible callback preserves receiver events and source markers" {
  let source =
    #|a: &x 1
    #|b: 'q'
    #|c: *x
    #|---
    #|d: [2, {nested: 3}]
  for multi in [false, true] {
    let expected : Recorder = { events: [], }
    @yaml.Parser(source).load(expected, multi)
    let actual : Recorder = { events: [], }
    @yaml.Parser(source).load_with(
      (event, mark) => @yaml.MarkedEventReceiver::on_event(actual, event, mark),
      multi,
    )
    assert_eq(actual.events, expected.events)
  }
}

///|
test "fallible callback propagates errors at every event boundary" {
  let source = "key: [a, {inner: b}]\nanchor: &x c\ncopy: *x\n"
  let events : Array[(@yaml.Event, @yaml.Marker)] = []
  @yaml.Parser(source).load_with(
    (event, mark) => events.push((event, mark)),
    true,
  )
  for stop in 0..<events.length() {
    let mut calls = 0
    try
      @yaml.Parser(source).load_with(
        (_, mark) => {
          calls += 1
          if calls == stop + 1 {
            raise @yaml.YamlError(mark~, info="callback rejected event")
          }
        },
        true,
      )
    catch {
      YamlError(mark~, info~) => {
        assert_eq(mark, events[stop].1)
        assert_eq(info, "callback rejected event")
        assert_eq(calls, stop + 1)
      }
    } noraise {
      _ => fail("callback error was swallowed")
    }
  }
}

///|
test "fallible callback stops deep block sequences at the caller limit" {
  let mut depth = 0
  let mut calls = 0
  try
    @yaml.Parser("- ".repeat(32760) + "0").load_with(
      (event, mark) => {
        calls += 1
        match event {
          SequenceStart(..) | MappingStart(..) => {
            depth += 1
            if depth > 32 {
              raise @yaml.YamlError(mark~, info="caller nesting limit")
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
      assert_eq(mark.line, 1)
      assert_eq(mark.col, 64)
      assert_eq(info, "caller nesting limit")
      assert_eq(depth, 33)
      assert_eq(calls, 35)
    }
  } noraise {
    _ => fail("expected the caller nesting limit")
  }
}

///|
test "fallible callback rejects wide documents without further callbacks" {
  let mut nodes = 0
  try
    @yaml.Parser("[" + "0,".repeat(8192) + "0]").load_with(
      (event, mark) => {
        match event {
          Scalar(..) | SequenceStart(..) | MappingStart(..) => {
            nodes += 1
            if nodes > 64 {
              raise @yaml.YamlError(mark~, info="caller node limit")
            }
          }
          _ => ()
        }
      },
      true,
    )
  catch {
    YamlError(info~, ..) => {
      assert_eq(info, "caller node limit")
      assert_eq(nodes, 65)
    }
  } noraise {
    _ => fail("expected the caller node limit")
  }
}

///|
test "fallible callback errors precede malformed trailing YAML" {
  try
    @yaml.Parser("value: [stop]\nbroken: [").load_with(
      (event, mark) => {
        if event is Scalar(value~, ..) && value == "stop" {
          raise @yaml.YamlError(mark~, info="caller rejected scalar")
        }
      },
      true,
    )
  catch {
    YamlError(mark~, info~) => {
      assert_eq(info, "caller rejected scalar")
      assert_eq(mark.line, 1)
      assert_eq(mark.col, 8)
    }
  } noraise {
    _ => fail("expected the caller error")
  }
}

///|
test "fallible callback preserves parser syntax errors" {
  try @yaml.Parser("value: [1, 2").load_with((_, _) => (), true) catch {
    YamlError(mark~, info~) => {
      assert_true(!info.is_empty())
      assert_true(mark.line >= 1)
      assert_true(mark.col >= 0)
    }
  } noraise {
    _ => fail("accepted malformed YAML")
  }
}

///|
test "fallible callback can read successive documents from the same parser" {
  let parser = @yaml.Parser("first: 1\n---\nsecond: 2\n")
  let scalars : Array[String] = []
  let mut starts = 0
  let mut ends = 0
  let callback : (@yaml.Event, @yaml.Marker) -> Unit raise @yaml.YamlError = fn(
    event,
    _,
  ) {
    match event {
      Scalar(value~, ..) => scalars.push(value)
      StreamStart => starts += 1
      StreamEnd => ends += 1
      _ => ()
    }
  }
  parser.load_with(callback, false)
  assert_eq(scalars, ["first", "1"])
  assert_eq(starts, 1)
  assert_eq(ends, 0)
  parser.load_with(callback, false)
  assert_eq(scalars, ["first", "1", "second", "2"])
  assert_eq(starts, 1)
  assert_eq(ends, 0)
  parser.load_with(callback, true)
  assert_eq(starts, 1)
  assert_eq(ends, 1)
}
