///|
fn Char::is_break(self : Char) -> Bool {
  self == '\n' || self == '\r'
}

///|
fn Char::is_z(self : Char) -> Bool {
  self == '\u{0}'
}

///|
fn Char::is_breakz(self : Char) -> Bool {
  self.is_break() || self.is_z()
}

///|
fn Char::is_blank(self : Char) -> Bool {
  self == ' ' || self == '\t'
}

///|
fn Char::is_blank_or_breakz(self : Char) -> Bool {
  self.is_blank() || self.is_break() || self.is_z()
}
