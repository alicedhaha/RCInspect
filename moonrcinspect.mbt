///|
/// Parse SPEF text into a source-positioned AST and normalized RC model.
pub fn parse(
  source : String,
  file? : String = "<memory>",
) -> @parser.ParseResult {
  @parser.parse(source, file~)
}

///|
/// Compute aggregate physical and topology metrics for a parsed design.
pub fn analyze(network : @model.RCNetwork) -> @analyzer.DesignMetrics {
  @analyzer.analyze(network)
}

///|
/// Run the default data-quality rule set.
pub fn audit(
  network : @model.RCNetwork,
  config? : @audit.AuditConfig = @audit.AuditConfig::default(),
) -> @audit.AuditReport {
  @audit.audit(network, config~)
}

///|
/// Compute Elmore delay when the selected net is a connected RC tree.
pub fn elmore_delay(net : @model.Net) -> @analyzer.ElmoreResult {
  @analyzer.elmore_delay(net)
}
