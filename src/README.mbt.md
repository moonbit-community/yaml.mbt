# YAML

A simple YAML parsing and stringifying library for MoonBit, support a simplified YAML subset which can be convert to JSON.

This library is ported from yaml-rust2.

## Usage

### Basic Example

```mbt
///|
test {
  let source =
    #|%YAML 1.2
    #|---
    #|YAML: YAML Ain't Markup Language™
    #|
    #|What It Is:
    #|  YAML is a human-friendly data serialization
    #|  language for all programming languages.
    #|
    #|YAML Resources:
    #|  YAML Specifications:
    #|  - YAML 1.2:
    #|    - Revision 1.2.2      # Oct 1, 2021 *New*
    #|    - Revision 1.2.1      # Oct 1, 2009
    #|    - Revision 1.2.0      # Jul 21, 2009
    #|  - YAML 1.1
    #|  - YAML 1.0
  @json.inspect(@yaml.Yaml::load_from_string(source), content=[
    {
      "YAML": "YAML Ain't Markup Language™",
      "What It Is": "YAML is a human-friendly data serialization language for all programming languages.",
      "YAML Resources": {
        "YAML Specifications": [
          { "YAML 1.2": ["Revision 1.2.2", "Revision 1.2.1", "Revision 1.2.0"] },
          "YAML 1.1",
          "YAML 1.0",
        ],
      },
    },
  ])
}
```
