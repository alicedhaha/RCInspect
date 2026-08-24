///|
/// Source position using one-based line and column numbers.
pub(all) struct SourcePos {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
/// Half-open source range `[start, end)`.
pub(all) struct SourceSpan {
  file : String
  start : SourcePos
  end : SourcePos
} derive(Eq, Debug)

///|
pub(all) enum Severity {
  Info
  Warning
  Error
} derive(Eq, Debug)

///|
/// Stable, machine-readable diagnostic emitted by parsing or auditing.
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  message : String
  suggestion : String?
  span : SourceSpan?
  net : String?
} derive(Eq, Debug)

///|
pub fn SourceSpan::synthetic(file : String) -> SourceSpan {
  let pos = SourcePos::{ offset: 0, line: 1, column: 1 }
  { file, start: pos, end: pos }
}

///|
pub fn Diagnostic::error(
  code : String,
  message : String,
  span? : SourceSpan,
  suggestion? : String,
  net? : String,
) -> Diagnostic {
  { code, severity: Error, message, suggestion, span, net }
}

///|
pub fn Diagnostic::warning(
  code : String,
  message : String,
  span? : SourceSpan,
  suggestion? : String,
  net? : String,
) -> Diagnostic {
  { code, severity: Warning, message, suggestion, span, net }
}

///|
pub fn Diagnostic::info(
  code : String,
  message : String,
  span? : SourceSpan,
  suggestion? : String,
  net? : String,
) -> Diagnostic {
  { code, severity: Info, message, suggestion, span, net }
}

///|
pub fn Severity::label(self : Severity) -> String {
  match self {
    Info => "info"
    Warning => "warning"
    Error => "error"
  }
}
