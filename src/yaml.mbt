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
