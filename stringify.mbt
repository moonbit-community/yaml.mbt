///|
/// YAML Stringify implementation
/// Simplified version based on js-yaml v3.13.1

// Stringify options
pub struct StringifyOptions {
  pub indent : Int
  pub array_indent : Bool
  pub skip_invalid : Bool
  pub flow_level : Int
  pub styles : Map[String, StyleVariant]
  pub schema : SchemaType
  pub sort_keys : Bool
  pub line_width : Int
  pub use_anchors : Bool
  pub compat_mode : Bool
  pub condense_flow : Bool
} derive(Show, Debug)

///|
impl StringifyOptions with new() -> StringifyOptions {
  {
    indent: 2,
    array_indent: true,
    skip_invalid: false,
    flow_level: -1,
    styles: Map::new(),
    schema: SchemaType::Default,
    sort_keys: false,
    line_width: 80,
    use_anchors: true,
    compat_mode: true,
    condense_flow: false,
  }
}

// Dumper state

///|
struct DumperState {
  options : StringifyOptions
  mut indent_level : Int
  mut output : String
}

///|
impl DumperState with new(options : StringifyOptions) -> DumperState {
  { options, indent_level: 0, output: "" }
}

///|
impl DumperState with write(self, text : String) -> Unit {
  self.output += text
}

///|
impl DumperState with write_line(self, text : String) -> Unit {
  self.output += text + "\n"
}

///|
impl DumperState with write_indent(self) -> Unit {
  for i = 0; i < self.indent_level * self.options.indent; i = i + 1 {
    self.output += " "
  }
}

///|
impl DumperState with increase_indent(self) -> Unit {
  self.indent_level += 1
}

///|
impl DumperState with decrease_indent(self) -> Unit {
  if self.indent_level > 0 {
    self.indent_level -= 1
  }
}

///|
impl DumperState with write_scalar(self, value : String, needs_quotes : Bool) -> Unit {
  if needs_quotes {
    self.write_quoted_string(value)
  } else {
    self.write(value)
  }
}

///|
impl DumperState with write_quoted_string(self, value : String) -> Unit {
  self.write("\"")
  for i = 0; i < value.length(); i = i + 1 {
    let ch = value[i]
    match ch {
      '"' => self.write("\\\"")
      '\\' => self.write("\\\\")
      '\n' => self.write("\\n")
      '\t' => self.write("\\t")
      '\r' => self.write("\\r")
      _ => self.write(ch.to_string())
    }
  }
  self.write("\"")
}

///|
impl DumperState with needs_quotes(self, value : String) -> Bool {
  if value.is_empty() {
    return true
  }

  // Check if it looks like a number
  match parse_number(value) {
    Some(_) => return true
    None => ()
  }

  // Check if it looks like a boolean or null
  match value.to_lower() {
    "true" | "false" | "yes" | "no" | "on" | "off" | "null" | "~" => return true
    _ => ()
  }

  // Check for special characters
  let special_chars = "[]{}|>*&!%#`@,"
  for i = 0; i < value.length(); i = i + 1 {
    let ch = value[i]
    if special_chars.contains(ch.to_string()) {
      return true
    }
  }

  // Check if starts with whitespace or contains colon
  let first_char = value[0]
  if first_char == ' ' || first_char == '\t' || value.contains(":") {
    return true
  }
  false
}

///|
impl DumperState with write_yaml_value(self, value : YamlValue, in_flow : Bool) -> Unit {
  match value {
    Null => self.write("null")
    Bool(b) => self.write(if b { "true" } else { "false" })
    Int(i) => self.write(i.to_string())
    Float(f) => self.write(f.to_string())
    String(s) => self.write_scalar(s, self.needs_quotes(s))
    Array(arr) => self.write_array(arr, in_flow)
    Object(obj) => self.write_object(obj, in_flow)
  }
}

///|
impl DumperState with write_array(self, arr : Array[YamlValue], in_flow : Bool) -> Unit {
  if arr.is_empty() {
    self.write("[]")
    return
  }
  let use_flow = in_flow ||
    (
      self.options.flow_level >= 0 &&
      self.indent_level >= self.options.flow_level
    )
  if use_flow {
    self.write("[")
    for i = 0; i < arr.length(); i = i + 1 {
      if i > 0 {
        if self.options.condense_flow {
          self.write(",")
        } else {
          self.write(", ")
        }
      }
      self.write_yaml_value(arr[i], true)
    }
    self.write("]")
  } else {
    for i = 0; i < arr.length(); i = i + 1 {
      if i > 0 {
        self.write("\n")
      }
      self.write_indent()
      self.write("- ")
      if self.options.array_indent {
        self.increase_indent()
        self.write_yaml_value(arr[i], false)
        self.decrease_indent()
      } else {
        self.write_yaml_value(arr[i], false)
      }
    }
  }
}

///|
impl DumperState with write_object(
  self,
  obj : Map[String, YamlValue],
  in_flow : Bool,
) -> Unit {
  if obj.size() == 0 {
    self.write("{}")
    return
  }
  let use_flow = in_flow ||
    (
      self.options.flow_level >= 0 &&
      self.indent_level >= self.options.flow_level
    )
  let keys = []
  obj
  .iter()
  .each(fn(entry) {
    let (key, _) = entry
    keys.push(key)
  })
  if self.options.sort_keys {
    keys.sort()
  }
  if use_flow {
    self.write("{")
    for i = 0; i < keys.length(); i = i + 1 {
      if i > 0 {
        if self.options.condense_flow {
          self.write(",")
        } else {
          self.write(", ")
        }
      }
      let key = keys[i]
      let value = obj.get(key).unwrap()
      self.write_scalar(key, self.needs_quotes(key))
      if self.options.condense_flow {
        self.write(":")
      } else {
        self.write(": ")
      }
      self.write_yaml_value(value, true)
    }
    self.write("}")
  } else {
    for i = 0; i < keys.length(); i = i + 1 {
      if i > 0 {
        self.write("\n")
      }
      self.write_indent()
      let key = keys[i]
      let value = obj.get(key).unwrap()
      self.write_scalar(key, self.needs_quotes(key))
      self.write(": ")

      // Check if value needs multiline formatting
      match value {
        Array(_) | Object(_) => {
          self.write("\n")
          self.increase_indent()
          self.write_indent()
          self.write_yaml_value(value, false)
          self.decrease_indent()
        }
        _ => self.write_yaml_value(value, false)
      }
    }
  }
}

///|
impl DumperState with dump(self, value : YamlValue) -> String {
  self.write_yaml_value(value, false)
  self.output
}

///|
/// Convert a value to YAML string
pub fn stringify(
  data : YamlValue,
  options? : StringifyOptions = StringifyOptions::new(),
) -> String {
  let state = DumperState::new(options)
  let result = state.dump(data)
  if result.is_empty() {
    "null\n"
  } else {
    result + "\n"
  }
}
