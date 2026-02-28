///|
/// YAML data structure representation
pub(all) enum Yaml {
  /// Float types
  Real(Double, repr~ : String)
  /// YAML int is stored as Int64.
  Integer(Int64)
  /// YAML scalar.
  String(String)
  /// YAML bool, e.g. `true` or `false`.
  Boolean(Bool)
  /// YAML array, can be accessed as an `Array`.
  Array(Array[Yaml])
  /// YAML map, can be accessed as a `Map`.
  /// 
  /// Insertion order will match the order of insertion into the map.
  ///
  /// Note that YAML keys can be of any type, but restrict them to String here for simplicity.
  Map(Map[String, Yaml])
  /// YAML null, e.g. `null` or `~`.
  Null
  /// Accessing a nonexistent node via indexing returns `BadValue`. This
  /// simplifies error handling in the calling code. Invalid type conversion also
  /// returns `BadValue`.
  BadValue
} derive(Eq, Show)

///|
pub impl ToJson for Yaml with to_json(self) {
  // assume input not contain complicate yaml feature
  match self {
    Null => Json::null()
    Map(yaml_map) => Json::object(yaml_map.map((_, yaml) => yaml.to_json()))
    Array(yaml_array) => Json::array(yaml_array.map(yaml => yaml.to_json()))
    Boolean(bool) => Json::boolean(bool)
    String(str) => Json::string(str)
    Integer(i64) => Json::number(i64.to_double())
    Real(f64, repr~) => Json::number(f64, repr~)
    BadValue => panic()
  }
}

///|
fn Yaml::from_str(v : String) -> Yaml {
  match v {
    ['0', 'x', .. number] if (try? @strconv.parse_int64(number, base=16))
      is Ok(i) => Yaml::Integer(i)
    ['0', 'o', .. number] if (try? @strconv.parse_int64(number, base=8))
      is Ok(i) => Yaml::Integer(i)
    ['+', .. number] if (try? @strconv.parse_int64(number)) is Ok(i) =>
      Yaml::Integer(i)
    "" | "~" | "null" => Yaml::Null
    "true" | "True" | "TRUE" => Yaml::Boolean(true)
    "false" | "False" | "FALSE" => Yaml::Boolean(false)
    v =>
      if (try? @strconv.parse_int64(v)) is Ok(integer) {
        Yaml::Integer(integer)
      } else if parse_double(v) is Some(d) {
        Yaml::Real(d, repr=v)
      } else {
        Yaml::String(v)
      }
  }
}

///|
test "simple string to yaml" {
  inspect(Yaml::from_str("42"), content="Integer(42)")
  inspect(Yaml::from_str("0x2A"), content="Integer(42)")
  inspect(Yaml::from_str("0o52"), content="Integer(42)")
  inspect(Yaml::from_str("~"), content="Null")
  inspect(Yaml::from_str("true"), content="Boolean(true)")
  inspect(Yaml::from_str("True"), content="Boolean(true)")
  inspect(Yaml::from_str("TRUE"), content="Boolean(true)")
  inspect(Yaml::from_str("false"), content="Boolean(false)")
  inspect(Yaml::from_str("False"), content="Boolean(false)")
  inspect(Yaml::from_str("FALSE"), content="Boolean(false)")
  assert_true(Yaml::from_str("3.14") is Yaml::Real(_))
  assert_true(Yaml::from_str("hello") is Yaml::String(_))
}

///|
fn parse_double(v : StringView) -> Double? {
  match v {
    ".inf" | ".Inf" | ".INF" | "+.inf" | "+.Inf" | "+.INF" =>
      Some(@double.infinity)
    "-.inf" | "-.Inf" | "-.INF" => Some(@double.neg_infinity)
    ".nan" | ".NaN" | ".NAN" => Some(@double.not_a_number)
    v if v.iter().any(ch => ch.is_ascii_digit()) =>
      Some(@strconv.parse_double(v)) catch {
        @strconv.StrConvError(_) => None
      }
    _ => None
  }
}

///|
priv struct YamlLoader {
  /// The different YAML documents that are loaded.
  docs : Array[Yaml]
  /// stack of (current node, anchor_id)
  doc_stack : Array[(Yaml, Int)]
  key_stack : Array[String]
  anchor_map : @sorted_map.SortedMap[Int, Yaml]
  mut error : YamlError?
}

///|
pub fn Yaml::load_from_parser(parser : Parser) -> Array[Yaml] raise YamlError {
  let loader = YamlLoader::{
    docs: [],
    doc_stack: [],
    key_stack: [],
    anchor_map: @sorted_map.new(),
    error: None,
  }
  parser.load(loader, true)
  if loader.error is Some(err) {
    raise err
  } else {
    loader.docs
  }
}

///|
pub fn Yaml::load_from_string(
  source : StringView,
) -> Array[Yaml] raise YamlError {
  let parser = Parser::new(source)
  Yaml::load_from_parser(parser)
}

///|
impl MarkedEventReceiver for YamlLoader with on_event(self, ev, mark) {
  if self.error is Some(_) {
    return
  }
  self.on_event_impl(ev, mark) catch {
    YamlError(_) as e => self.error = Some(e)
  }
}

///|
fn YamlLoader::on_event_impl(
  self : YamlLoader,
  ev : Event,
  mark : Marker,
) -> Unit raise YamlError {
  match ev {
    Event::DocumentStart | Event::StreamStart | Event::StreamEnd => () // do nothing
    Event::DocumentEnd =>
      match self.doc_stack.length() {
        // empty document
        0 => self.docs.push(Yaml::BadValue)
        1 => self.docs.push(self.doc_stack.pop().unwrap().0)
        _ => panic()
      }
    Event::SequenceStart(id~, ..) => self.doc_stack.push((Yaml::Array([]), id))
    Event::SequenceEnd => {
      let node = self.doc_stack.pop().unwrap()
      self.insert_new_node(node, mark)
    }
    Event::MappingStart(id~, ..) => {
      self.doc_stack.push((Yaml::Map({}), id))
      self.key_stack.push("") // place holder
    }
    Event::MappingEnd => {
      guard self.key_stack.pop() is Some(_)
      let node = self.doc_stack.pop().unwrap()
      self.insert_new_node(node, mark)
    }
    Event::Scalar(value~, style~, id~, tag~) => {
      let node = if style != TScalarStyle::Plain {
        Yaml::String(value)
      } else if tag is Some({ handle, suffix }) {
        if handle == "tag:yaml.org,2002:" {
          match suffix {
            "bool" =>
              match value {
                "true" | "True" | "TRUE" => Yaml::Boolean(true)
                "false" | "False" | "FALSE" => Yaml::Boolean(false)
                _ => Yaml::BadValue
              }
            "int" =>
              Yaml::Integer(@strconv.parse_int64(value)) catch {
                @strconv.StrConvError(_) => Yaml::BadValue
              }
            "float" =>
              match parse_double(value) {
                Some(d) => Yaml::Real(d, repr=value)
                None => Yaml::BadValue
              }
            "null" =>
              match value {
                "~" | "null" => Yaml::Null
                _ => Yaml::BadValue
              }
            _ => Yaml::String(value)
          }
        } else {
          Yaml::String(value)
        }
      } else {
        // Datatype is not specified, or unrecognized
        Yaml::from_str(value)
      }
      self.insert_new_node((node, id), mark)
    }
    Event::Alias(id~) => {
      let n = match self.anchor_map.get(id) {
        Some(v) => v
        None => Yaml::BadValue
      }
      self.insert_new_node((n, 0), mark)
    }
  }
}

///|
fn YamlLoader::insert_new_node(
  self : YamlLoader,
  node : (Yaml, Int),
  mark : Marker,
) -> Unit raise YamlError {
  // valid anchor id starts from 1
  if node.1 > 0 {
    self.anchor_map[node.1] = node.0
  }
  if self.doc_stack.is_empty() {
    self.doc_stack.push(node)
  } else {
    let parent = self.doc_stack.last().unwrap()
    match parent {
      (Array(v), _) => v.push(node.0)
      (Map(m), _) => {
        let cur_key = self.key_stack.last().unwrap()
        if cur_key.is_empty() {
          // current node is a key
          if node.0 is String(key) {
            self.key_stack[self.key_stack.length() - 1] = key
          } else {
            raise YamlError::YamlError(
              mark~,
              info="yaml.mbt doesn't support non-string key",
            )
          }
        } else {
          // current node is a value
          let new_key = cur_key
          self.key_stack[self.key_stack.length() - 1] = ""
          if m.contains(new_key) {
            raise YamlError::YamlError(
              mark~,
              info="\{new_key}: duplicated key in mapping",
            )
          } else {
            m[new_key] = node.0
          }
        }
      }
      _ => panic()
    }
  }
}

///|
/// The YAML serializer.
///
/// This is a simplified emitter that matches the parser features supported by
/// this package.
///
/// # Example
/// ```mbt nocheck
/// let input = "a: b\nc: d"
/// let docs = Yaml::load_from_string(input)
/// let emitter = YamlEmitter::new()
/// emitter.dump(docs[0])
/// let output = emitter.to_string()
/// // output == "---\na: b\nc: d"
/// ```
struct YamlEmitter {
  writer : StringBuilder
  best_indent : Int
  mut compact : Bool
  mut level : Int
  mut multiline_strings : Bool
}

///|
/// Create a new emitter serializing into `writer`.
pub fn YamlEmitter::new(
  writer? : StringBuilder = StringBuilder::new(),
) -> YamlEmitter {
  YamlEmitter::{
    writer,
    best_indent: 2,
    compact: true,
    level: -1,
    multiline_strings: false,
  }
}

///|
/// Set "compact inline notation" on or off for block sequences and mappings.
///
/// In this form, blocks cannot have any properties (such as anchors or tags),
/// which should be OK, because this emitter doesn't emit those anyways.
pub fn YamlEmitter::compact(self : YamlEmitter, compact : Bool) -> Unit {
  self.compact = compact
}

///|
/// Render strings containing multiple lines in literal block style.
///
/// # Example
/// ```mbt nocheck
/// let input = "{foo: \"bar!\\nbar!\", baz: 42}"
/// let parsed = Yaml::load_from_string(input)
/// let emitter = YamlEmitter::new()
/// emitter.multiline_strings(true)
/// emitter.dump(parsed[0])
/// let output = emitter.to_string()
/// // output is:
/// // ---
/// // foo: |-
/// //   bar!
/// //   bar!
/// // baz: 42
/// ```
pub fn YamlEmitter::multiline_strings(
  self : YamlEmitter,
  multiline_strings : Bool,
) -> Unit {
  self.multiline_strings = multiline_strings
}

///|
/// Dump a YAML document into the internal buffer.
pub fn YamlEmitter::dump(self : YamlEmitter, doc : Yaml) -> Unit {
  self.writer.write_string("---")
  self.writer.write_char('\n')
  self.level = -1
  self.emit_node(doc)
}

///|
/// Get the current emitted output as a string.
pub fn YamlEmitter::to_string(self : YamlEmitter) -> String {
  self.writer.to_string()
}

///|
/// Convenience helper to dump a `Yaml` value into a string using default settings.
pub fn Yaml::dump(self : Yaml) -> String {
  let emitter = YamlEmitter::new()
  emitter.dump(self)
  emitter.to_string()
}

///|
fn YamlEmitter::write_indent(self : YamlEmitter) -> Unit {
  if self.level <= 0 {
    return
  }
  for _ in 0..<self.level {
    for _ in 0..<self.best_indent {
      self.writer.write_char(' ')
    }
  }
}

///|
fn YamlEmitter::emit_node(self : YamlEmitter, node : Yaml) -> Unit {
  match node {
    Array(values) => self.emit_array(values)
    Map(values) => self.emit_map(values)
    String(value) =>
      if self.multiline_strings &&
        value.contains_char('\n') &&
        is_valid_literal_block_scalar(value) {
        self.emit_literal_block(value)
      } else if need_quotes(value) {
        escape_str(self.writer, value)
      } else {
        self.writer.write_string(value)
      }
    Boolean(value) =>
      if value {
        self.writer.write_string("true")
      } else {
        self.writer.write_string("false")
      }
    Integer(value) => self.writer.write_string(value.to_string())
    Real(value, repr~) =>
      if repr.is_empty() {
        self.writer.write_string(value.to_string())
      } else {
        self.writer.write_string(repr)
      }
    Null | BadValue => self.writer.write_char('~')
  }
}

///|
fn YamlEmitter::emit_literal_block(self : YamlEmitter, value : String) -> Unit {
  let len = value.length()
  let ends_with_newline = len > 0 && value[len - 1] == ('\n' : UInt16)
  if ends_with_newline {
    self.writer.write_char('|')
  } else {
    self.writer.write_string("|-")
  }
  self.level += 1
  let lines = value.split("\n").to_array()
  if ends_with_newline && !lines.is_empty() && lines.last().unwrap().is_empty() {
    ignore(lines.pop())
  }
  for line in lines {
    self.writer.write_char('\n')
    self.write_indent()
    self.writer.write_view(line)
  }
  self.level -= 1
}

///|
fn YamlEmitter::emit_array(self : YamlEmitter, values : Array[Yaml]) -> Unit {
  if values.is_empty() {
    self.writer.write_string("[]")
  } else {
    self.level += 1
    for index, value in values {
      if index > 0 {
        self.writer.write_char('\n')
        self.write_indent()
      }
      self.writer.write_char('-')
      self.emit_val(true, value)
    }
    self.level -= 1
  }
}

///|
fn YamlEmitter::emit_map(
  self : YamlEmitter,
  values : Map[String, Yaml],
) -> Unit {
  if values.is_empty() {
    self.writer.write_string("{}")
  } else {
    self.level += 1
    values.eachi((index, key, value) => {
      if index > 0 {
        self.writer.write_char('\n')
        self.write_indent()
      }
      self.emit_node(Yaml::String(key))
      self.writer.write_char(':')
      self.emit_val(false, value)
    })
    self.level -= 1
  }
}

///|
/// Emit a YAML as a mapping or sequence value, following ':' or '-'.
///
/// If `inline` is true, the preceding characters are distinct and short
/// enough to respect the compact flag.
fn YamlEmitter::emit_val(
  self : YamlEmitter,
  inline : Bool,
  value : Yaml,
) -> Unit {
  match value {
    Array(values) => {
      if (inline && self.compact) || values.is_empty() {
        self.writer.write_char(' ')
      } else {
        self.writer.write_char('\n')
        self.level += 1
        self.write_indent()
        self.level -= 1
      }
      self.emit_array(values)
    }
    Map(values) => {
      if (inline && self.compact) || values.is_empty() {
        self.writer.write_char(' ')
      } else {
        self.writer.write_char('\n')
        self.level += 1
        self.write_indent()
        self.level -= 1
      }
      self.emit_map(values)
    }
    _ => {
      self.writer.write_char(' ')
      self.emit_node(value)
    }
  }
}

///|
fn escape_str(writer : StringBuilder, value : String) -> Unit {
  writer.write_char('"')
  for ch in value {
    match ch {
      '"' => writer.write_string("\\\"")
      '\\' => writer.write_string("\\\\")
      '\u{0008}' => writer.write_string("\\b")
      '\t' => writer.write_string("\\t")
      '\n' => writer.write_string("\\n")
      '\u{000c}' => writer.write_string("\\f")
      '\r' => writer.write_string("\\r")
      _ => {
        let code = ch.to_int()
        if code <= 0x1f || code == 0x7f {
          write_hex_escape(writer, code)
        } else {
          writer.write_char(ch)
        }
      }
    }
  }
  writer.write_char('"')
}

///|
fn write_hex_escape(writer : StringBuilder, value : Int) -> Unit {
  writer.write_string("\\u")
  writer.write_char(hex_digit((value >> 12) & 0xf))
  writer.write_char(hex_digit((value >> 8) & 0xf))
  writer.write_char(hex_digit((value >> 4) & 0xf))
  writer.write_char(hex_digit(value & 0xf))
}

///|
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    15 => 'f'
    _ => panic()
  }
}

///|
fn is_valid_literal_block_scalar(value : String) -> Bool {
  value
  .iter()
  .all(ch => {
    ch == '\t' ||
    ch == '\n' ||
    ch is ('\u{0020}'..='\u{007e}') ||
    ch == '\u{0085}' ||
    ch is ('\u{00a0}'..='\u{d7ff}')
  })
}

///|
fn need_quotes_spaces(value : String) -> Bool {
  let len = value.length()
  value.trim_start(chars=" ").length() != len ||
  value.trim_end(chars=" ").length() != len
}

///|
/// Check if the string requires quoting.
///
/// Strings starting with any of the following characters must be quoted:
/// `:`, `&`, `*`, `?`, `|`, `-`, `<`, `>`, `=`, `!`, `%`, `@`.
///
/// Strings containing any of the following characters must be quoted:
/// `{`, `}`, `[`, `]`, `,`, `#`, `` ` ``.
///
/// If the string contains any of the following control characters, it must be
/// escaped with double quotes:
/// `\0`, `\x01`, `\x02`, `\x03`, `\x04`, `\x05`, `\x06`, `\a`, `\b`, `\t`,
/// `\n`, `\v`, `\f`, `\r`, `\x0e`, `\x0f`, `\x10`, `\x11`, `\x12`, `\x13`,
/// `\x14`, `\x15`, `\x16`, `\x17`, `\x18`, `\x19`, `\x1a`, `\e`, `\x1c`,
/// `\x1d`, `\x1e`, `\x1f`, `\N`, `\_`, `\L`, `\P`.
///
/// Finally, there are other cases when the strings must be quoted:
/// - When the string is true or false.
/// - When the string is null or "~".
/// - When the string looks like a number, such as integers, floats, and
///   exponential numbers.
/// - When the string looks like a date (e.g. 2014-12-31).
fn need_quotes(value : String) -> Bool {
  if value.is_empty() || need_quotes_spaces(value) {
    return true
  }
  match value.get_char(0) {
    Some(ch) if ch
      is ('&' | '*' | '?' | '|' | '-' | '<' | '>' | '=' | '!' | '%' | '@') =>
      return true
    _ => ()
  }
  if value
    .iter()
    .any(ch => {
      ch is (':' | '{' | '}' | '[' | ']' | ',' | '#' | '`' | '"' | '\'' | '\\') ||
      ch.to_int() <= 0x06 ||
      ch == '\t' ||
      ch == '\n' ||
      ch == '\r' ||
      (ch.to_int() >= 0x0e && ch.to_int() <= 0x1a) ||
      (ch.to_int() >= 0x1c && ch.to_int() <= 0x1f)
    }) {
    return true
  }
  if [
      "true", "false", "True", "False", "TRUE", "FALSE", "null", "Null", "NULL",
      "~", "y", "Y", "n", "N", "yes", "Yes", "YES", "no", "No", "NO", "True", "TRUE",
      "False", "FALSE", "on", "On", "ON", "off", "Off", "OFF",
    ].contains(value) {
    return true
  }
  match value.get_char(0) {
    Some('.') => return true
    _ => ()
  }
  if value is ['0', 'x', ..] {
    return true
  }
  (try? @strconv.parse_int64(value)) is Ok(_) ||
  (try? @strconv.parse_double(value)) is Ok(_)
}
