///|
/// A receiver defined outside the package: the receiver traits are open,
/// so a client can build its own representation from the events (keeping
/// scalar styles, tags and anchors that `Yaml` drops).
struct Recorder {
  events : Array[String]
}

///|
impl MarkedEventReceiver for Recorder with fn on_event(self, event, mark) {
  let text = match event {
    Scalar(value~, style~, id~, ..) => {
      let style = match style {
        Plain => "Plain"
        SingleQuoted => "SingleQuoted"
        DoubleQuoted => "DoubleQuoted"
        Literal => "Literal"
        Folded => "Folded"
      }
      "Scalar(\{value}, \{style}, id=\{id}) at \{mark.line}:\{mark.col}"
    }
    Alias(id~) => "Alias(\{id})"
    MappingStart(id~, ..) => "MappingStart(id=\{id})"
    SequenceStart(id~, ..) => "SequenceStart(id=\{id})"
    MappingEnd => "MappingEnd"
    SequenceEnd => "SequenceEnd"
    StreamStart => "StreamStart"
    StreamEnd => "StreamEnd"
    DocumentStart => "DocumentStart"
    DocumentEnd => "DocumentEnd"
  }
  self.events.push(text)
}

///|
test "external event receiver" {
  let recorder = { events: [], }
  let source =
    #|a: &x 1
    #|b: 'q'
    #|c: *x
  Parser::new(source).load(recorder, false)
  debug_inspect(
    recorder.events,
    content=(
      #|[
      #|  "StreamStart",
      #|  "DocumentStart",
      #|  "MappingStart(id=0)",
      #|  "Scalar(a, Plain, id=0) at 1:0",
      #|  "Scalar(1, Plain, id=1) at 1:6",
      #|  "Scalar(b, Plain, id=0) at 2:0",
      #|  "Scalar(q, SingleQuoted, id=0) at 2:3",
      #|  "Scalar(c, Plain, id=0) at 3:0",
      #|  "Alias(1)",
      #|  "MappingEnd",
      #|  "DocumentEnd",
      #|]
    ),
  )
}

///|
/// A receiver outside the package that only wants events, not markers.
struct Counter {
  mut scalars : Int
}

///|
impl EventReceiver for Counter with fn on_event(self, event) {
  if event is Scalar(..) {
    self.scalars += 1
  }
}

///|
/// `Parser::load` takes a `MarkedEventReceiver`: an `EventReceiver` is used
/// through a wrapper that forwards events and drops the markers.
struct Unmarked {
  inner : Counter
}

///|
impl MarkedEventReceiver for Unmarked with fn on_event(self, event, _mark) {
  EventReceiver::on_event(self.inner, event)
}

///|
test "external unmarked event receiver" {
  let counter = { scalars: 0, }
  let parser = Parser::new("a: 1\nb: [2, 3]\n")
  parser.load({ inner: counter, }, false)
  inspect(counter.scalars, content="5")
}
