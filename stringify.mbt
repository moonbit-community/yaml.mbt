///|
/// YAML Stringify implementation
/// Simplified version based on js-yaml v3.13.1

///|
fn StringifyOptions::new() -> StringifyOptions {
  {
    indent: 2,
    array_indent: true,
    skip_invalid: false,
    flow_level: -1,
    styles: Map::new(),
    schema: "default",
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
fn DumperState::new(options : StringifyOptions) -> DumperState {
  { options, indent_level: 0, output: "" }
}

///|
fn DumperState::write(self : DumperState, text : String) -> Unit {
  self.output = self.output + text
}

///|
fn DumperState::write_line(self : DumperState, text : String) -> Unit {
  self.output = self.output + text + "\n"
}

///|
fn DumperState::write_indent(self : DumperState) -> Unit {
  for i = 0; i < self.indent_level * self.options.indent; i = i + 1 {
    self.output = self.output + " "
  }
}

///|
fn DumperState::increase_indent(self : DumperState) -> Unit {
  self.indent_level = self.indent_level + 1
}

///|
fn DumperState::decrease_indent(self : DumperState) -> Unit {
  if self.indent_level > 0 {
    self.indent_level = self.indent_level - 1
  }
}

///|
fn DumperState::write_scalar(
  self : DumperState,
  value : String,
  needs_quotes : Bool,
) -> Unit {
  if needs_quotes {
    self.write_quoted_string(value)
  } else {
    self.write(value)
  }
}

///|
fn DumperState::write_quoted_string(self : DumperState, value : String) -> Unit {
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
fn DumperState::needs_quotes(self : DumperState, value : String) -> Bool {
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
fn DumperState::write_yaml_value(
  self : DumperState,
  value : YamlValue,
  in_flow : Bool,
) -> Unit {
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
fn DumperState::write_array(
  self : DumperState,
  arr : Array[YamlValue],
  in_flow : Bool,
) -> Unit {
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
fn DumperState::write_object(
  self : DumperState,
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
fn DumperState::dump(self : DumperState, value : YamlValue) -> String {
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
