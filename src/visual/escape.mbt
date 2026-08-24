///|
pub fn json_escape(value : String) -> String {
  let out = StringBuilder()
  for ch in value {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ =>
        if ch.to_int() < 0x20 {
          out.write_string("?")
        } else {
          out.write_char(ch)
        }
    }
  }
  out.to_string()
}

///|
pub fn dot_escape(value : String) -> String {
  let out = StringBuilder()
  for ch in value {
    match ch {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => ()
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn json_string(value : String) -> String {
  "\"\{json_escape(value)}\""
}
