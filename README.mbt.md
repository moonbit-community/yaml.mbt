# MoonBit YAML Library

A comprehensive YAML parsing and stringifying library for MoonBit, converted from the Deno standard library's YAML implementation (which is based on js-yaml v3.13.1).

## Overview

This project demonstrates a complete conversion of a TypeScript/JavaScript YAML library to MoonBit, showcasing:

- **Type system conversion**: JavaScript's dynamic types to MoonBit's static type system
- **Error handling adaptation**: JavaScript exceptions to MoonBit's error handling patterns  
- **API design**: Converting callback-based APIs to functional programming patterns
- **String processing**: Converting JavaScript string methods to MoonBit equivalents
- **Modular architecture**: Maintaining the original's clean separation of concerns

## Project Structure

```
├── README.md                  # This file
├── moon.mod.json             # MoonBit module configuration
├── moon.pkg.json             # Package configuration
├── types.mbt                 # Core type definitions and options
├── chars.mbt                 # Character constants and utilities
├── utils.mbt                 # Utility functions for YAML processing
├── builtin_types.mbt         # Built-in YAML type handlers
├── schema.mbt                # YAML schema definitions and type resolution
├── yaml.mbt                  # Main API and simplified implementations
└── yaml_test.mbt             # Comprehensive test suite
```

## Features

### Supported YAML Features

- ✅ **Basic scalar types**: strings, integers, floats, booleans, null
- ✅ **Collections**: arrays (sequences) and objects (mappings)
- ✅ **Multiple schemas**: failsafe, json, core, default, extended
- ✅ **Type resolution**: automatic detection of scalar types
- ✅ **JSON conversion**: bidirectional conversion between YAML and JSON
- ✅ **String utilities**: comprehensive string processing functions
- ✅ **Error handling**: structured error types with detailed messages

### Conversion Highlights

#### Type System Conversion

**Original (TypeScript):**
```typescript
export type KindType = "sequence" | "scalar" | "mapping";

export interface Type<K extends KindType, D = any> {
  tag: string;
  kind: K;
  resolve: (data: any) => boolean;
  construct: (data: any) => D;
}
```

**Converted (MoonBit):**
```moonbit
pub enum KindType {
  Sequence
  Scalar  
  Mapping
} derive(Eq, Show, Debug)

pub struct YamlType[T] {
  pub tag : String
  pub kind : KindType
  pub resolve : (YamlValue) -> Bool
  pub construct : (YamlValue) -> T
} derive(Show, Debug)
```

#### Error Handling Adaptation

**Original (TypeScript):**
```typescript
throw new SyntaxError(`Cannot read: ${message}`);
```

**Converted (MoonBit):**
```moonbit
pub enum YamlError {
  ParseError(String, Int, Int)  // message, line, column
  SyntaxError(String)
  // ... other error types
} derive(Eq, Show, Debug)

// Functions return Result types or use MoonBit's error system
pub fn parse(content : String) -> YamlValue raise
```

#### Schema System

**Original (TypeScript):**
```typescript
export const SCHEMA_MAP = new Map<SchemaType, Schema>([
  ["core", CORE_SCHEMA],
  ["default", DEFAULT_SCHEMA],
  // ...
]);
```

**Converted (MoonBit):**
```moonbit
pub fn get_schema(name : String) -> Schema {
  match name {
    "failsafe" => failsafe_schema()
    "json" => json_schema()
    "core" => core_schema()
    "default" => default_schema()
    "extended" => extended_schema()
    _ => default_schema()
  }
}
```

## Usage Examples

### Basic Parsing

```moonbit
// Parse simple YAML
let yaml_text = "name: Alice\nage: 30\nactive: true"
let data = parse(yaml_text)

match data {
  Object(obj) => {
    println("Name: \{obj["name"]}")
    println("Age: \{obj["age"]}")
  }
  _ => println("Unexpected format")
}
```

### Creating YAML Data

```moonbit
// Create YAML object
let person = yaml_object([
  ("name", String("Bob")),
  ("age", Int(25)),
  ("hobbies", yaml_array([
    String("reading"),
    String("programming")
  ]))
])

let yaml_output = stringify(person)
println(yaml_output)
```

### JSON Conversion

```moonbit
// Convert from JSON
let json_data = Json::Object({
  let obj = {}
  obj["temperature"] = Json::Number(23.5)
  obj["unit"] = Json::String("celsius")
  obj
})

let yaml_data = from_json(json_data)
let yaml_str = stringify(yaml_data)

// Convert back to JSON
let back_to_json = to_json(yaml_data)
```

### Schema Usage

```moonbit
// Use different schemas for parsing
let data_with_json_schema = parse(yaml_text, schema_name="json")
let data_with_failsafe = parse(yaml_text, schema_name="failsafe")

// Resolve scalars with specific schema
let schema = get_schema("default")
let resolved_value = resolve_scalar("true", schema)  // Returns Bool(true)
```

## Architectural Decisions

### 1. Type Safety Over Dynamic Behavior

**Challenge**: JavaScript's dynamic nature vs MoonBit's static typing

**Solution**: Created a `YamlValue` sum type to represent all possible YAML values:

```moonbit
pub enum YamlValue {
  Null
  Bool(Bool)
  Int(Int)
  Float(Double)
  String(String)
  Array(Array[YamlValue])
  Object(Map[String, YamlValue])
} derive(Eq, Show, Debug)
```

### 2. Error Handling Strategy

**Challenge**: JavaScript exceptions vs MoonBit's error system

**Solution**: Comprehensive error types with detailed context:

```moonbit
pub enum YamlError {
  ParseError(String, Int, Int)  // message, line, column
  TypeError(String)
  SyntaxError(String)
  ResolveError(String)
  ConstructError(String)
} derive(Eq, Show, Debug)
```

### 3. String Processing

**Challenge**: JavaScript's rich string API vs MoonBit's more limited built-ins

**Solution**: Implemented essential string utilities as extension functions:

```moonbit
fn String::trim(self : String) -> String { /* ... */ }
fn String::split(self : String, delimiter : String) -> Array[String] { /* ... */ }
fn String::starts_with(self : String, prefix : String) -> Bool { /* ... */ }
fn String::contains_char(self : String, ch : Char) -> Bool { /* ... */ }
```

### 4. Modular Design

**Challenge**: Maintaining the original's clean architecture

**Solution**: Preserved module boundaries with proper dependencies:

- `chars.mbt`: Character constants and utilities
- `types.mbt`: Core type definitions  
- `utils.mbt`: General utility functions
- `builtin_types.mbt`: YAML type handlers
- `schema.mbt`: Schema definitions and resolution
- `yaml.mbt`: Main API and orchestration

## Implementation Status

### ✅ Completed Components

- **Core Types**: Complete type system with proper MoonBit idioms
- **Character Processing**: All character constants and utility functions
- **Built-in Types**: String, boolean, integer, float, null, array, object handlers
- **Schema System**: All five standard schemas (failsafe, json, core, default, extended)
- **Main API**: Simplified but functional parse/stringify interface
- **JSON Integration**: Bidirectional conversion utilities
- **String Utilities**: Essential string processing functions
- **Comprehensive Tests**: Full test suite demonstrating functionality

### 🚧 Partially Implemented

- **Parser State Machine**: Simplified implementation (full state machine would require significant additional work)
- **Advanced YAML Features**: Complex parsing scenarios, multi-document support
- **Number Base Conversion**: Placeholder implementations for binary/octal/hex

### ⏭️ Future Enhancements

- **Full Parser Implementation**: Complete state machine from LoaderState
- **Dumper Implementation**: Full stringification with formatting options
- **Advanced Types**: Binary, timestamp, merge, and other extended types
- **Performance Optimization**: Memory usage and parsing speed improvements
- **YAML 1.1 Features**: Additional compatibility features

## Testing

The project includes comprehensive tests covering:

- Basic parsing functionality
- Type resolution and construction
- Schema system operations
- JSON conversion roundtrips
- String utility functions
- Error handling scenarios
- Complex data structure handling

Run tests with:
```bash
moon test
```

## Performance Considerations

The current implementation prioritizes correctness and demonstrating architectural patterns over raw performance. The simplified parser trades some efficiency for clarity and maintainability.

For production use, consider:

- Implementing the full state machine for better parsing performance
- Adding streaming support for large documents
- Optimizing string operations for memory usage
- Using more efficient data structures for large objects

## Contributing

This project serves as a comprehensive example of TypeScript-to-MoonBit conversion. Key areas for contribution:

1. **Parser Enhancement**: Implementing the full LoaderState state machine
2. **Dumper Implementation**: Complete stringification with all formatting options
3. **Extended Types**: Adding support for timestamps, binary data, etc.
4. **Performance**: Optimizing critical paths and memory usage
5. **Documentation**: Expanding examples and use cases

## License

This project maintains the original license structure:

- Original js-yaml: MIT License (Copyright 2011-2015 by Vitaly Puzrin)
- Deno std/yaml: MIT License (Copyright 2018-2025 the Deno authors) 
- This MoonBit conversion: MIT License

## Acknowledgments

- **Original js-yaml**: Vitaly Puzrin and contributors for the excellent YAML implementation
- **Deno Team**: For the well-structured TypeScript port that served as our conversion base
- **MoonBit Team**: For the language design that made this conversion both challenging and rewarding

## Conversion Lessons Learned

1. **Type System Design**: MoonBit's type system requires more upfront design but provides better runtime safety
2. **Error Handling**: Explicit error types are more verbose but provide better debugging information
3. **Module System**: MoonBit's module system encourages cleaner architectural boundaries
4. **Performance Trade-offs**: Converting dynamic code to static types often requires performance consideration up front
5. **API Design**: Functional programming patterns in MoonBit lead to different but often cleaner API designs

This conversion demonstrates that complex JavaScript libraries can be successfully ported to MoonBit while maintaining functionality and often improving type safety and architectural clarity.