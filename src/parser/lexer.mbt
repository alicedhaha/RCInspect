///|
pub(all) struct Token {
  text : String
  quoted : Bool
  span : @diagnostic.SourceSpan
} derive(Eq, Debug)

///|
pub(all) struct TokenLine {
  number : Int
  tokens : Array[Token]
} derive(Eq, Debug)

///|
pub(all) struct LexResult {
  lines : Array[TokenLine]
  diagnostics : Array[@diagnostic.Diagnostic]
} derive(Debug)

///|
fn is_space(ch : UInt16) -> Bool {
  ch == ' ' || ch == '\t' || ch == '\r'
}

///|
fn position(offset : Int, line : Int, column : Int) -> @diagnostic.SourcePos {
  { offset, line, column }
}

///|
fn token_span(
  file : String,
  base_offset : Int,
  line_number : Int,
  start : Int,
  end : Int,
) -> @diagnostic.SourceSpan {
  {
    file,
    start: position(base_offset + start, line_number, start + 1),
    end: position(base_offset + end, line_number, end + 1),
  }
}

///|
/// Tokenizes SPEF text while preserving physical lines and source ranges.
///
/// SPEF is line-oriented, but token boundaries are not obtained with a simple
/// whitespace split: quoted strings, escapes, comments and exact columns are
/// handled explicitly.
pub fn lex(source : String, file? : String = "<memory>") -> LexResult {
  let lines : Array[TokenLine] = []
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  let mut line_number = 1
  let mut base_offset = 0
  for line_view in source.split("\n") {
    let line = line_view.to_owned()
    let tokens : Array[Token] = []
    let mut index = 0
    while index < line.length() {
      let ch = line.unsafe_get(index)
      if is_space(ch) {
        index += 1
        continue
      }
      if ch == '/' &&
        index + 1 < line.length() &&
        line.unsafe_get(index + 1) == '/' {
        break
      }
      if ch == '"' {
        let start = index
        index += 1
        let builder = StringBuilder()
        let mut closed = false
        while index < line.length() {
          let current = line.unsafe_get(index)
          if current == '\\' && index + 1 < line.length() {
            let escaped = line.unsafe_get(index + 1)
            if escaped == '"' || escaped == '\\' {
              builder.write_char(escaped.to_int().unsafe_to_char())
              index += 2
              continue
            }
          }
          if current == '"' {
            index += 1
            closed = true
            break
          }
          builder.write_char(current.to_int().unsafe_to_char())
          index += 1
        }
        let span = token_span(file, base_offset, line_number, start, index)
        tokens.push({ text: builder.to_string(), quoted: true, span })
        if !closed {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              "SPEF-P001",
              "unterminated quoted string",
              span~,
              suggestion="add a closing double quote",
            ),
          )
        }
        continue
      }
      let start = index
      while index < line.length() {
        let current = line.unsafe_get(index)
        if is_space(current) {
          break
        }
        index += 1
      }
      if index > start {
        let span = token_span(file, base_offset, line_number, start, index)
        tokens.push({ text: line[start:index].to_owned(), quoted: false, span })
      }
    }
    lines.push({ number: line_number, tokens })
    base_offset += line.length() + 1
    line_number += 1
  }
  { lines, diagnostics }
}
