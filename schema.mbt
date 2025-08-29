///| YAML Schema definitions
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// Schema type for different YAML standards
pub enum SchemaType {
  FailSafe // Generic mappings, sequences, strings
  Json // FailSafe + nulls, booleans, integers, floats  
  Core // Same as Json
  Default // Core + binary, omap, pairs, set
  Extended // Default + regexp, undefined
} derive(Eq, Show, Debug)

///|
/// Type map for organizing types by kind
pub struct TypeMap {
  pub fallback : Map[String, YamlType[YamlValue]]
  pub mapping : Map[String, YamlType[YamlValue]]
  pub scalar : Map[String, YamlType[YamlValue]]
  pub sequence : Map[String, YamlType[YamlValue]]
} derive(Show, Debug)

///|
/// YAML Schema containing implicit and explicit types
pub struct Schema {
  pub implicit_types : Array[YamlType[YamlValue]] // Types resolved implicitly
  pub explicit_types : Array[YamlType[YamlValue]] // Types requiring explicit tags  
  pub type_map : TypeMap
} derive(Show, Debug)

///|
/// Create a type map from implicit and explicit types
fn create_type_map(
  implicit_types : Array[YamlType[YamlValue]],
  explicit_types : Array[YamlType[YamlValue]],
) -> TypeMap {
  let fallback = Map::new()
  let mapping = Map::new()
  let scalar = Map::new()
  let sequence = Map::new()

  // Add all types to their respective maps
  for yaml_type in implicit_types {
    match yaml_type.kind {
      Scalar => scalar[yaml_type.tag] = yaml_type
      Mapping => mapping[yaml_type.tag] = yaml_type
      Sequence => sequence[yaml_type.tag] = yaml_type
    }
    fallback[yaml_type.tag] = yaml_type
  }
  for yaml_type in explicit_types {
    match yaml_type.kind {
      Scalar => scalar[yaml_type.tag] = yaml_type
      Mapping => mapping[yaml_type.tag] = yaml_type
      Sequence => sequence[yaml_type.tag] = yaml_type
    }
    fallback[yaml_type.tag] = yaml_type
  }
  { fallback, mapping, scalar, sequence }
}

///|
/// Create a schema from type arrays and optional parent schema
fn create_schema(
  implicit_types? : Array[YamlType[YamlValue]] = [],
  explicit_types? : Array[YamlType[YamlValue]] = [],
  include? : Schema? = None,
) -> Schema {
  let mut all_implicit = []
  let mut all_explicit = []

  // Include parent schema types if provided
  match include {
    Some(parent) => {
      all_implicit.append(parent.implicit_types)
      all_explicit.append(parent.explicit_types)
    }
    None => ()
  }

  // Add new types
  all_implicit.append(implicit_types)
  all_explicit.append(explicit_types)
  let type_map = create_type_map(all_implicit, all_explicit)
  { implicit_types: all_implicit, explicit_types: all_explicit, type_map }
}

// Convert builtin type functions to work with YamlValue

///|
/// Convert string type handler to work with YamlValue
fn str_yaml_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:str",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        String(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match data {
        String(s) => s
        _ => ""
      }
    }),
    default_style: None,
    resolve: fn(value) {
      true // Strings always resolve to themselves
    },
    construct: fn(value) {
      match value {
        String(s) => String(s)
        _ => String("")
      }
    },
  }
}

///|
/// Convert sequence type handler to work with YamlValue
fn seq_yaml_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:seq",
    kind: Sequence,
    predicate: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    represent: None,
    default_style: None,
    resolve: fn(value) {
      match value {
        Array(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Array(arr) => Array(arr)
        _ => Array([])
      }
    },
  }
}

///|
/// Convert mapping type handler to work with YamlValue
fn map_yaml_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:map",
    kind: Mapping,
    predicate: fn(value) {
      match value {
        Object(_) => true
        _ => false
      }
    },
    represent: None,
    default_style: None,
    resolve: fn(value) {
      match value {
        Object(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        Object(obj) => Object(obj)
        _ => Object(Map::new())
      }
    },
  }
}

///|
/// Null type handler for YamlValue
fn null_yaml_type() -> YamlType[YamlValue] {
  let yaml_null_values = ["null", "Null", "NULL", "~", ""]
  {
    tag: "tag:yaml.org,2002:null",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Null => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match style {
        Some(Uppercase) => "NULL"
        Some(Camelcase) => "Null"
        _ => "null"
      }
    }),
    default_style: Some(Lowercase),
    resolve: fn(value) {
      match value {
        String(s) => yaml_null_values.contains(s)
        Null => true
        _ => false
      }
    },
    construct: fn(value) { Null },
  }
}

///|
/// Boolean type handler for YamlValue
fn bool_yaml_type() -> YamlType[YamlValue] {
  let yaml_true_values = ["true", "True", "TRUE"]
  let yaml_false_values = ["false", "False", "FALSE"]
  {
    tag: "tag:yaml.org,2002:bool",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Bool(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match data {
        Bool(b) =>
          match style {
            Some(Uppercase) => if b { "TRUE" } else { "FALSE" }
            Some(Camelcase) => if b { "True" } else { "False" }
            _ => if b { "true" } else { "false" }
          }
        _ => "false"
      }
    }),
    default_style: Some(Lowercase),
    resolve: fn(value) {
      match value {
        String(s) =>
          yaml_true_values.contains(s) || yaml_false_values.contains(s)
        Bool(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => Bool(yaml_true_values.contains(s))
        Bool(b) => Bool(b)
        _ => Bool(false)
      }
    },
  }
}

///|
/// Integer type handler for YamlValue
fn int_yaml_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:int",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Int(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match data {
        Int(i) => i.to_string()
        _ => "0"
      }
    }),
    default_style: Some(Decimal),
    resolve: fn(value) {
      match value {
        String(s) => resolve_yaml_integer(s)
        Int(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => Int(construct_yaml_integer(s))
        Int(i) => Int(i)
        _ => Int(0)
      }
    },
  }
}

///|
/// Float type handler for YamlValue
fn float_yaml_type() -> YamlType[YamlValue] {
  {
    tag: "tag:yaml.org,2002:float",
    kind: Scalar,
    predicate: fn(value) {
      match value {
        Float(_) => true
        Int(_) => true
        _ => false
      }
    },
    represent: Some(fn(data, style) {
      match data {
        Float(f) =>
          if f != f { // NaN check
            ".nan"
          } else if f == infinity() {
            ".inf"
          } else if f == -infinity() {
            "-.inf"
          } else {
            f.to_string()
          }
        Int(i) => i.to_double().to_string()
        _ => "0.0"
      }
    }),
    default_style: None,
    resolve: fn(value) {
      match value {
        String(s) => resolve_yaml_float(s)
        Float(_) => true
        Int(_) => true
        _ => false
      }
    },
    construct: fn(value) {
      match value {
        String(s) => Float(construct_yaml_float(s))
        Float(f) => Float(f)
        Int(i) => Float(i.to_double())
        _ => Float(0.0)
      }
    },
  }
}

// Schema definitions

///|
/// Standard YAML's failsafe schema
/// Supports: generic mappings, generic sequences, generic strings
pub fn failsafe_schema() -> Schema {
  create_schema(explicit_types=[
    str_yaml_type(),
    seq_yaml_type(),
    map_yaml_type(),
  ])
}

///|
/// Standard YAML's JSON schema
/// Supports: failsafe + nulls, booleans, integers, floats
pub fn json_schema() -> Schema {
  create_schema(
    implicit_types=[
      null_yaml_type(),
      bool_yaml_type(),
      int_yaml_type(),
      float_yaml_type(),
    ],
    include=Some(failsafe_schema()),
  )
}

///|
/// Standard YAML's core schema
/// Functionally the same as JSON schema
pub fn core_schema() -> Schema {
  json_schema()
}

///|
/// Default YAML schema (not in YAML specification)
/// Supports: core + binary, omap, pairs, set
/// For now, same as core until we implement additional types
pub fn default_schema() -> Schema {
  core_schema()
}

///|
/// Extended YAML schema (not in YAML specification)
/// Supports: default + regexp, undefined  
/// For now, same as default until we implement additional types
pub fn extended_schema() -> Schema {
  default_schema()
}

///|
/// Get schema by name
pub fn get_schema(name : String) -> Schema {
  match name {
    "failsafe" => failsafe_schema()
    "json" => json_schema()
    "core" => core_schema()
    "default" => default_schema()
    "extended" => extended_schema()
    _ => default_schema() // Default fallback
  }
}

///|
/// Resolve a scalar value according to schema
pub fn resolve_scalar(data : String, schema : Schema) -> YamlValue {
  // Try implicit types first
  for yaml_type in schema.implicit_types {
    if yaml_type.resolve(String(data)) {
      return yaml_type.construct(String(data))
    }
  }

  // If no implicit type matches, return as string
  String(data)
}
