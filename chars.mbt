///| Character constants and utility functions
/// Ported from js-yaml v3.13.1:
/// https://github.com/nodeca/js-yaml/commit/665aadda42349dcae869f12040d9b10ef18d12da
/// Copyright 2011-2015 by Vitaly Puzrin. All rights reserved. MIT license.
/// Copyright 2018-2025 the Deno authors. MIT license.

///|
/// Character code constants
pub const BOM = 0xfeff // BOM

///|
pub const TAB = 0x09 // Tab

///|
pub const LINE_FEED = 0x0a // LF

///|
pub const CARRIAGE_RETURN = 0x0d // CR

///|
pub const SPACE = 0x20 // Space

///|
pub const EXCLAMATION = 0x21 // !

///|
pub const DOUBLE_QUOTE = 0x22 // "

///|
pub const SHARP = 0x23 // #

///|
pub const PERCENT = 0x25 // %

///|
pub const AMPERSAND = 0x26 // &

///|
pub const SINGLE_QUOTE = 0x27 // '

///|
pub const ASTERISK = 0x2a // *

///|
pub const PLUS = 0x2b // +

///|
pub const COMMA = 0x2c // ,

///|
pub const MINUS = 0x2d // -

///|
pub const DOT = 0x2e // .

///|
pub const COLON = 0x3a // :

///|
pub const SMALLER_THAN = 0x3c // <

///|
pub const GREATER_THAN = 0x3e // >

///|
pub const QUESTION = 0x3f // ?

///|
pub const COMMERCIAL_AT = 0x40 // @

///|
pub const LEFT_SQUARE_BRACKET = 0x5b // [

///|
pub const BACKSLASH = 0x5c // \

///|
pub const RIGHT_SQUARE_BRACKET = 0x5d // ]

///|
pub const GRAVE_ACCENT = 0x60 // `

///|
pub const LEFT_CURLY_BRACKET = 0x7b // {

///|
pub const VERTICAL_LINE = 0x7c // |

///|
pub const RIGHT_CURLY_BRACKET = 0x7d // }

///|
/// Check if character is end-of-line (internal)
fn is_eol_internal(c : Int) -> Bool {
  c == LINE_FEED || c == CARRIAGE_RETURN
}

///|
/// Check if character is whitespace (internal)
fn is_whitespace_internal(c : Int) -> Bool {
  c == TAB || c == SPACE
}

///|
/// Check if character is whitespace or end-of-line
pub fn is_whitespace_or_eol(c : Int) -> Bool {
  is_whitespace_internal(c) || is_eol_internal(c)
}

///|
/// Check if character is a flow indicator
pub fn is_flow_indicator(c : Int) -> Bool {
  c == COMMA ||
  c == LEFT_SQUARE_BRACKET ||
  c == RIGHT_SQUARE_BRACKET ||
  c == LEFT_CURLY_BRACKET ||
  c == RIGHT_CURLY_BRACKET
}

///|
/// Check if character is printable
pub fn is_printable(c : Int) -> Bool {
  (0x20 <= c && c <= 0x7E) ||
  0x85 == // ASCII printable
  c ||
  (
    0xA0 <= // NEL
    c &&
    c <= 0xD7FF
  ) || // Unicode printable range 1
  (0xE000 <= c && c <= 0xFFFD) || // Unicode printable range 2
  (0x10000 <= c && c <= 0x10FFFF) // Unicode printable range 3
}

///|
/// Check if character is a valid hexadecimal digit
pub fn is_hex_digit(c : Int) -> Bool {
  (0x30 <= c && c <= 0x39) || // 0-9
  (0x41 <= c && c <= 0x46) || // A-F
  (0x61 <= c && c <= 0x66) // a-f
}

///|
/// Check if character is a valid decimal digit
pub fn is_decimal_digit(c : Int) -> Bool {
  0x30 <= c && c <= 0x39 // 0-9
}

///|
/// Convert hex character to number
pub fn hex_char_to_number(c : Int) -> Int {
  if 0x30 <= c && c <= 0x39 {
    c - 0x30 // 0-9
  } else if 0x41 <= c && c <= 0x46 {
    c - 0x41 + 10 // A-F
  } else if 0x61 <= c && c <= 0x66 {
    c - 0x61 + 10 // a-f
  } else {
    -1 // Invalid hex digit
  }
}

///|
/// Convert decimal character to number
pub fn decimal_char_to_number(c : Int) -> Int {
  if 0x30 <= c && c <= 0x39 {
    c - 0x30 // 0-9
  } else {
    -1 // Invalid decimal digit
  }
}

///|
/// Convert Unicode code point to string
pub fn codepoint_to_string(codepoint : Int) -> String {
  if codepoint <= 0xFFFF {
    // Basic Multilingual Plane
    Char::from_int(codepoint).to_string()
  } else {
    // Surrogate pairs for code points beyond BMP
    let high = (codepoint - 0x010000) / 1024 + 0xD800
    let low = (codepoint - 0x010000) % 1024 + 0xDC00
    Char::from_int(high).to_string() + Char::from_int(low).to_string()
  }
}
