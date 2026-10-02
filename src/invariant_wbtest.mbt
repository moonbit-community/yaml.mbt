///|
priv struct InvariantTestReceiver {}

///|
impl MarkedEventReceiver for InvariantTestReceiver with fn on_event(
  _self,
  _ev,
  _mark,
) {
  ()
}

///|
test "panic short document-end lookahead" {
  ignore(Lexer::new("").next_is_document_end())
}

///|
test "panic short document-indicator lookahead" {
  ignore(Lexer::new("").next_is_document_indicator())
}

///|
test "panic token insertion past end" {
  let lexer = Lexer::new("")
  let token = Token::{
    marker: Marker::{ index: 0, line: 1, col: 0 },
    token_type: TokenType::StreamStart,
  }
  lexer.insert_token(1, token)
}

///|
test "panic missing document-end event" {
  let parser = Parser::new("")
  let mark = Marker::{ index: 0, line: 1, col: 0 }
  parser.current = Some(
    (
      Event::Scalar(value="value", style=TScalarStyle::Plain, id=0, tag=None),
      mark,
    ),
  )
  parser.load_document(Event::DocumentStart, mark, InvariantTestReceiver::{  }) catch {
    error => fail("unexpected YAML error: \{error.to_repr()}")
  }
}

///|
test "panic mapping end without key stack" {
  let loader = YamlLoader::{
    docs: [],
    doc_stack: [],
    key_stack: [],
    anchor_map: @sorted_map.SortedMap([]),
    error: None,
  }
  let mark = Marker::{ index: 0, line: 1, col: 0 }
  loader.on_event_impl(Event::MappingEnd, mark) catch {
    error => fail("unexpected YAML error: \{error.to_repr()}")
  }
}
