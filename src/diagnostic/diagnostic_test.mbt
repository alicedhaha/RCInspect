///|
test "synthetic spans use one-based coordinates" {
  let span = @diagnostic.SourceSpan::synthetic("fixture.spef")
  inspect(span.start.line, content="1")
  inspect(span.start.column, content="1")
  inspect(span.file, content="fixture.spef")
}

///|
test "diagnostics expose stable severity labels" {
  let diag = @diagnostic.Diagnostic::warning(
    "SPEF-W001",
    "unknown header",
    suggestion="preserve it for forward compatibility",
  )
  inspect(diag.severity.label(), content="warning")
  inspect(diag.code, content="SPEF-W001")
}
