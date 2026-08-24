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

///|
/// Find the minimum-resistance route between two expanded SPEF node names.
pub fn minimum_resistance_path(
  net : @model.Net,
  source : String,
  target : String,
) -> @path.PathResult {
  @path.minimum_resistance_path(net, source, target)
}

///|
/// Build an all-pairs resistance matrix and identify the electrical diameter.
pub fn resistance_matrix(net : @model.Net) -> @path.PathMatrix {
  @path.resistance_matrix(net)
}

///|
/// Resolve and aggregate coupling capacitance relationships across D_NETs.
pub fn analyze_coupling(network : @model.RCNetwork) -> @coupling.CouplingReport {
  @coupling.analyze(network)
}

///|
/// Produce first-moment-preserving reduced RC models for every network.
pub fn reduce(network : @model.RCNetwork) -> @reduction.DesignReduction {
  @reduction.reduce_design(network)
}
