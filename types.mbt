///| Type definitions for YAML processing
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// Kind of YAML node
pub enum KindType {
  Sequence // Array-like structures  
  Scalar // Primitive values
  Mapping // Object-like structures
} derive(Eq, Show, Debug)

///|
/// Style variations for stringify
pub enum StyleVariant {
  Lowercase
  Uppercase
  Camelcase
  Decimal
  Binary
  Octal
  Hexadecimal
} derive(Eq, Show, Debug)

///|
/// Type alias for represent function
pub typealias (T, StyleVariant?) -> String as RepresentFn[T]

///|
/// Represents any YAML value during parsing
pub enum YamlValue {
  Null
  Bool(Bool)
  Int(Int)
  Float(Double)
  String(String)
  Array(Array[YamlValue])
  Object(Map[String, YamlValue])
} derive(Eq, Show, Debug)

///|
/// YAML type definition structure
/// Generic type T represents the actual MoonBit type this YAML type handles
pub struct YamlType[T] {
  pub tag : String // YAML tag (e.g., "tag:yaml.org,2002:str")
  pub kind : KindType // Kind of YAML structure
  pub predicate : (YamlValue) -> Bool // Check if a value matches this type
  pub represent : RepresentFn[T]? // How to serialize this type
  pub default_style : StyleVariant? // Default serialization style
  pub resolve : (YamlValue) -> Bool // Check if value can be resolved to this type
  pub construct : (YamlValue) -> T // Construct value from YAML
} derive(Show, Debug)

///|
/// Error types for YAML processing
pub enum YamlError {
  ParseError(String, Int, Int) // message, line, column
  TypeError(String)
  SyntaxError(String)
  ResolveError(String) // For type resolution errors
  ConstructError(String) // For value construction errors
} derive(Eq, Show, Debug)

///|
impl Show for YamlError with output(self, logger) {
  match self {
    ParseError(msg, line, col) =>
      logger.write_string("Parse error at line \{line}, column \{col}: \{msg}")
    TypeError(msg) => logger.write_string("Type error: \{msg}")
    SyntaxError(msg) => logger.write_string("Syntax error: \{msg}")
    ResolveError(msg) => logger.write_string("Resolve error: \{msg}")
    ConstructError(msg) => logger.write_string("Construct error: \{msg}")
  }
}

///|
/// Position tracking in input
pub struct Position {
  pub line : Int
  pub column : Int
  pub index : Int
} derive(Eq, Show, Debug)

///|
/// Parse options for YAML parsing
pub struct ParseOptions {
  pub schema : String // Schema name to use ("default", "json", etc.)
  pub allow_duplicate_keys : Bool // Allow duplicate keys in mappings
  pub on_warning : ((YamlError) -> Unit)? // Warning handler
} derive(Show, Debug)

///|
/// Default parse options
pub fn ParseOptions::default() -> ParseOptions {
  { schema: "default", allow_duplicate_keys: false, on_warning: None }
}

///|
/// Stringify options for YAML serialization
pub struct StringifyOptions {
  pub indent : Int // Indentation width (default: 2)
  pub array_indent : Bool // Add indent to array elements (default: true)
  pub skip_invalid : Bool // Skip invalid types (default: false)
  pub flow_level : Int // Flow vs block style level (-1 = block everywhere)
  pub styles : Map[String, StyleVariant] // Tag-specific styles
  pub schema : String // Schema name
  pub sort_keys : Bool // Sort object keys
  pub line_width : Int // Max line width (default: 80)
  pub use_anchors : Bool // Use anchors for duplicate objects
  pub compat_mode : Bool // YAML 1.1 compatibility mode
  pub condense_flow : Bool // Condense flow sequences
} derive(Show, Debug)

///|
/// Default stringify options
pub fn StringifyOptions::default() -> StringifyOptions {
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
