///|
fn quoted(value : String) -> String {
  "\"\{@visual.json_escape(value)}\""
}

///|
fn csv_cell(value : String) -> String {
  "\"\{value.replace(old="\"", new="\"\"")}\""
}

///|
pub fn metrics_to_text(metrics : @analyzer.DesignMetrics) -> String {
  let out = StringBuilder()
  out.write_string("MoonRCInspect analysis\n")
  out.write_string("nets: \{metrics.net_count}\n")
  out.write_string("nodes: \{metrics.node_count}\n")
  out.write_string("connections: \{metrics.connection_count}\n")
  out.write_string("resistors: \{metrics.resistor_count}\n")
  out.write_string("capacitors: \{metrics.capacitor_count}\n")
  out.write_string("total resistance: \{metrics.total_resistance} ohm\n")
  out.write_string("total capacitance: \{metrics.total_capacitance} F\n")
  out.write_string(
    "average net resistance: \{metrics.average_net_resistance} ohm\n",
  )
  out.write_string(
    "average net capacitance: \{metrics.average_net_capacitance} F\n",
  )
  out.write_string("anomalous networks: \{metrics.anomalous_net_count}\n")
  out.write_string("\nPer-net metrics:\n")
  for net in metrics.nets {
    out.write_string(
      "- \{net.name}: nodes=\{net.node_count}, R=\{net.total_resistance} ohm, C=\{net.detailed_capacitance} F, components=\{net.connected_components}, complexity=\{net.complexity_score}, anomalous=\{net.anomalous}\n",
    )
  }
  out.to_string()
}

///|
pub fn metrics_to_json(metrics : @analyzer.DesignMetrics) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.analysis.v1\",\"net_count\":\{metrics.net_count},\"node_count\":\{metrics.node_count},\"connection_count\":\{metrics.connection_count},\"resistor_count\":\{metrics.resistor_count},\"capacitor_count\":\{metrics.capacitor_count},\"total_resistance_ohm\":\{metrics.total_resistance},\"total_capacitance_f\":\{metrics.total_capacitance},\"anomalous_net_count\":\{metrics.anomalous_net_count},\"anomalous_nets\":[",
  )
  for index in 0..<metrics.anomalous_nets.length() {
    if index > 0 {
      out.write_char(',')
    }
    out.write_string(quoted(metrics.anomalous_nets[index]))
  }
  out.write_string("],\"nets\":[")
  for index in 0..<metrics.nets.length() {
    if index > 0 {
      out.write_char(',')
    }
    let net = metrics.nets[index]
    out.write_string(
      "{\"name\":\{quoted(net.name)},\"nodes\":\{net.node_count},\"resistors\":\{net.resistor_count},\"capacitors\":\{net.capacitor_count},\"resistance_ohm\":\{net.total_resistance},\"capacitance_f\":\{net.detailed_capacitance},\"declared_capacitance_f\":\{net.declared_capacitance},\"components\":\{net.connected_components},\"isolated_nodes\":\{net.isolated_node_count},\"has_cycle\":\{net.has_cycle},\"complexity\":\{net.complexity_score},\"anomalous\":\{net.anomalous},\"anomaly_reasons\":[",
    )
    for reason_index in 0..<net.anomaly_reasons.length() {
      if reason_index > 0 {
        out.write_char(',')
      }
      out.write_string(quoted(net.anomaly_reasons[reason_index]))
    }
    out.write_string("]}")
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn metrics_to_csv(metrics : @analyzer.DesignMetrics) -> String {
  let out = StringBuilder()
  out.write_string(
    "net,nodes,connections,resistors,capacitors,resistance_ohm,capacitance_f,components,isolated_nodes,has_cycle,complexity,anomalous\n",
  )
  for net in metrics.nets {
    out.write_string(
      "\{csv_cell(net.name)},\{net.node_count},\{net.connection_count},\{net.resistor_count},\{net.capacitor_count},\{net.total_resistance},\{net.detailed_capacitance},\{net.connected_components},\{net.isolated_node_count},\{net.has_cycle},\{net.complexity_score},\{net.anomalous}\n",
    )
  }
  out.to_string()
}

///|
fn location_text(span : @diagnostic.SourceSpan?) -> String {
  match span {
    Some(value) => "\{value.file}:\{value.start.line}:\{value.start.column}"
    None => "<unknown>"
  }
}

///|
pub fn audit_to_text(report : @audit.AuditReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "MoonRCInspect audit: errors=\{report.error_count}, warnings=\{report.warning_count}, info=\{report.info_count}\n",
  )
  for issue in report.diagnostics {
    out.write_string(
      "[\{issue.severity.label()}] \{issue.code} \{location_text(issue.span)}: \{issue.message}",
    )
    match issue.net {
      Some(net) => out.write_string(" (net: \{net})")
      None => ()
    }
    out.write_char('\n')
    match issue.suggestion {
      Some(suggestion) => out.write_string("  suggestion: \{suggestion}\n")
      None => ()
    }
  }
  out.to_string()
}

///|
pub fn audit_to_json(report : @audit.AuditReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.audit.v1\",\"passed\":\{report.passed},\"errors\":\{report.error_count},\"warnings\":\{report.warning_count},\"info\":\{report.info_count},\"diagnostics\":[",
  )
  for index in 0..<report.diagnostics.length() {
    if index > 0 {
      out.write_char(',')
    }
    let issue = report.diagnostics[index]
    out.write_string(
      "{\"code\":\{quoted(issue.code)},\"severity\":\{quoted(issue.severity.label())},\"message\":\{quoted(issue.message)},\"location\":\{quoted(location_text(issue.span))},\"net\":",
    )
    match issue.net {
      Some(net) => out.write_string(quoted(net))
      None => out.write_string("null")
    }
    out.write_string(",\"suggestion\":")
    match issue.suggestion {
      Some(suggestion) => out.write_string(quoted(suggestion))
      None => out.write_string("null")
    }
    out.write_char('}')
  }
  out.write_string("]}")
  out.to_string()
}

///|
fn sarif_level(severity : @diagnostic.Severity) -> String {
  match severity {
    @diagnostic.Error => "error"
    @diagnostic.Warning => "warning"
    @diagnostic.Info => "note"
  }
}

///|
fn sarif_rule_codes(report : @audit.AuditReport) -> Array[String] {
  let codes : Array[String] = []
  for issue in report.diagnostics {
    if !codes.contains(issue.code) {
      codes.push(issue.code)
    }
  }
  codes
}

///|
fn sarif_rule_message(report : @audit.AuditReport, code : String) -> String {
  for issue in report.diagnostics {
    if issue.code == code {
      return issue.message
    }
  }
  code
}

///|
/// Serializes audit diagnostics as SARIF 2.1.0 for code-scanning systems.
pub fn audit_to_sarif(report : @audit.AuditReport) -> String {
  let out = StringBuilder()
  let rule_codes = sarif_rule_codes(report)
  out.write_string(
    "{\"version\":\"2.1.0\",\"$schema\":\"https://json.schemastore.org/sarif-2.1.0.json\",\"runs\":[{\"tool\":{\"driver\":{\"name\":\"MoonRCInspect\",\"informationUri\":\"https://github.com/alicedhaha/RCInspect\",\"rules\":[",
  )
  for index in 0..<rule_codes.length() {
    if index > 0 {
      out.write_char(',')
    }
    let code = rule_codes[index]
    out.write_string(
      "{\"id\":\{quoted(code)},\"shortDescription\":{\"text\":\{quoted(sarif_rule_message(report, code))}}}",
    )
  }
  out.write_string("]}},\"results\":[")
  for index in 0..<report.diagnostics.length() {
    if index > 0 {
      out.write_char(',')
    }
    let issue = report.diagnostics[index]
    out.write_string(
      "{\"ruleId\":\{quoted(issue.code)},\"level\":\{quoted(sarif_level(issue.severity))},\"message\":{\"text\":\{quoted(issue.message)}}",
    )
    match issue.span {
      Some(span) =>
        out.write_string(
          ",\"locations\":[{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\{quoted(span.file)}},\"region\":{\"startLine\":\{span.start.line},\"startColumn\":\{span.start.column},\"endLine\":\{span.end.line},\"endColumn\":\{span.end.column}}}}]",
        )
      None => ()
    }
    match issue.suggestion {
      Some(suggestion) =>
        out.write_string(",\"help\":{\"text\":\{quoted(suggestion)}}")
      None => ()
    }
    out.write_char('}')
  }
  out.write_string("]}]}")
  out.to_string()
}

///|
pub fn path_to_text(path : @path.PathResult) -> String {
  let out = StringBuilder()
  out.write_string("MoonRCInspect path\n")
  out.write_string("net: \{path.net_name}\n")
  out.write_string("status: \{path.status.label()}\n")
  out.write_string("source: \{path.source}\n")
  out.write_string("target: \{path.target}\n")
  if path.status == @path.Found {
    out.write_string("edges: \{path.edge_count}\n")
    out.write_string("total resistance: \{path.total_resistance} ohm\n")
    out.write_string("route:\n")
    for hop in path.hops {
      out.write_string(
        "- \{hop.node_name}: edge=\{hop.edge_resistance} ohm, cumulative=\{hop.cumulative_resistance} ohm",
      )
      match hop.via_resistor_id {
        Some(id) => out.write_string(", resistor=\{id}")
        None => ()
      }
      out.write_char('\n')
    }
  }
  out.to_string()
}

///|
pub fn path_to_json(path : @path.PathResult) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.path.v1\",\"status\":\{quoted(path.status.label())},\"net\":\{quoted(path.net_name)},\"source\":\{quoted(path.source)},\"target\":\{quoted(path.target)},\"edge_count\":\{path.edge_count},\"total_resistance_ohm\":\{path.total_resistance},\"hops\":[",
  )
  for index in 0..<path.hops.length() {
    if index > 0 {
      out.write_char(',')
    }
    let hop = path.hops[index]
    out.write_string(
      "{\"node_id\":\{hop.node_id},\"node\":\{quoted(hop.node_name)},\"resistor_id\":",
    )
    match hop.via_resistor_id {
      Some(id) => out.write_string("\{id}")
      None => out.write_string("null")
    }
    out.write_string(
      ",\"edge_resistance_ohm\":\{hop.edge_resistance},\"cumulative_resistance_ohm\":\{hop.cumulative_resistance}}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn path_to_csv(path : @path.PathResult) -> String {
  let out = StringBuilder()
  out.write_string(
    "net,source,target,status,sequence,node,resistor_id,edge_resistance_ohm,cumulative_resistance_ohm\n",
  )
  for index in 0..<path.hops.length() {
    let hop = path.hops[index]
    let resistor = match hop.via_resistor_id {
      Some(id) => "\{id}"
      None => ""
    }
    out.write_string(
      "\{csv_cell(path.net_name)},\{csv_cell(path.source)},\{csv_cell(path.target)},\{csv_cell(path.status.label())},\{index},\{csv_cell(hop.node_name)},\{resistor},\{hop.edge_resistance},\{hop.cumulative_resistance}\n",
    )
  }
  out.to_string()
}

///|
pub fn matrix_to_text(matrix : @path.PathMatrix) -> String {
  let out = StringBuilder()
  out.write_string("MoonRCInspect resistance matrix\n")
  out.write_string("net: \{matrix.net_name}\n")
  out.write_string("status: \{matrix.status.label()}\n")
  out.write_string("nodes: \{matrix.nodes.length()}\n")
  out.write_string("reachable pairs: \{matrix.reachable_pair_count}\n")
  out.write_string("unreachable pairs: \{matrix.unreachable_pair_count}\n")
  match matrix.diameter {
    Some(value) =>
      out.write_string(
        "resistance diameter: \{value.source} -> \{value.target}, \{value.resistance} ohm, \{value.edge_count} edge(s)\n",
      )
    None => out.write_string("resistance diameter: unavailable\n")
  }
  out.to_string()
}

///|
pub fn matrix_to_json(matrix : @path.PathMatrix) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.path-matrix.v1\",\"net\":\{quoted(matrix.net_name)},\"status\":\{quoted(matrix.status.label())},\"reachable_pair_count\":\{matrix.reachable_pair_count},\"unreachable_pair_count\":\{matrix.unreachable_pair_count},\"distances\":[",
  )
  for index in 0..<matrix.distances.length() {
    if index > 0 {
      out.write_char(',')
    }
    let distance = matrix.distances[index]
    out.write_string(
      "{\"source\":\{quoted(distance.source)},\"target\":\{quoted(distance.target)},\"reachable\":\{distance.reachable},\"resistance_ohm\":\{distance.resistance},\"edge_count\":\{distance.edge_count}}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn matrix_to_csv(matrix : @path.PathMatrix) -> String {
  let out = StringBuilder()
  out.write_string("net,source,target,reachable,resistance_ohm,edge_count\n")
  for distance in matrix.distances {
    out.write_string(
      "\{csv_cell(matrix.net_name)},\{csv_cell(distance.source)},\{csv_cell(distance.target)},\{distance.reachable},\{distance.resistance},\{distance.edge_count}\n",
    )
  }
  out.to_string()
}

///|
pub fn coupling_to_text(report : @coupling.CouplingReport) -> String {
  let out = StringBuilder()
  out.write_string("MoonRCInspect coupling analysis\n")
  out.write_string("links: \{report.link_count}\n")
  out.write_string("resolved links: \{report.resolved_link_count}\n")
  out.write_string("unresolved links: \{report.unresolved_link_count}\n")
  out.write_string(
    "total coupling capacitance: \{report.total_coupling_capacitance} F\n",
  )
  out.write_string("\nCoupling pairs:\n")
  for pair in report.pairs {
    out.write_string(
      "- \{pair.first_net} <-> \{pair.second_net}: \{pair.capacitance} F (\{pair.element_count} element(s))\n",
    )
  }
  out.write_string("\nPer-net coupling:\n")
  for net in report.nets {
    out.write_string(
      "- \{net.net_name}: outgoing=\{net.outgoing_capacitance} F, incoming=\{net.incoming_capacitance} F, unresolved=\{net.unresolved_capacitance} F, partners=\{net.partners.length()}\n",
    )
  }
  out.to_string()
}

///|
pub fn coupling_to_json(report : @coupling.CouplingReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.coupling.v1\",\"link_count\":\{report.link_count},\"resolved_link_count\":\{report.resolved_link_count},\"unresolved_link_count\":\{report.unresolved_link_count},\"total_coupling_capacitance_f\":\{report.total_coupling_capacitance},\"resolved_capacitance_f\":\{report.resolved_capacitance},\"unresolved_capacitance_f\":\{report.unresolved_capacitance},\"pairs\":[",
  )
  for index in 0..<report.pairs.length() {
    if index > 0 {
      out.write_char(',')
    }
    let pair = report.pairs[index]
    out.write_string(
      "{\"first_net\":\{quoted(pair.first_net)},\"second_net\":\{quoted(pair.second_net)},\"capacitance_f\":\{pair.capacitance},\"element_count\":\{pair.element_count}}",
    )
  }
  out.write_string("],\"links\":[")
  for index in 0..<report.links.length() {
    if index > 0 {
      out.write_char(',')
    }
    let link = report.links[index]
    out.write_string(
      "{\"source_net\":\{quoted(link.source_net)},\"source_node\":\{quoted(link.source_node)},\"target_node\":\{quoted(link.target_node)},\"target_net\":",
    )
    match link.target_net {
      Some(value) => out.write_string(quoted(value))
      None => out.write_string("null")
    }
    out.write_string(
      ",\"capacitance_f\":\{link.capacitance},\"resolved\":\{link.resolved}}",
    )
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn coupling_to_csv(report : @coupling.CouplingReport) -> String {
  let out = StringBuilder()
  out.write_string(
    "source_net,source_node,target_net,target_node,capacitor_id,capacitance_f,resolved\n",
  )
  for link in report.links {
    let target_net = match link.target_net {
      Some(value) => value
      None => ""
    }
    out.write_string(
      "\{csv_cell(link.source_net)},\{csv_cell(link.source_node)},\{csv_cell(target_net)},\{csv_cell(link.target_node)},\{link.capacitor_id},\{link.capacitance},\{link.resolved}\n",
    )
  }
  out.to_string()
}

///|
pub fn reduction_to_text(reduction : @reduction.DesignReduction) -> String {
  let out = StringBuilder()
  out.write_string("MoonRCInspect RC reduction\n")
  out.write_string("exact trees: \{reduction.exact_tree_count}\n")
  out.write_string("approximate graphs: \{reduction.approximate_count}\n")
  out.write_string("unavailable: \{reduction.unavailable_count}\n")
  out.write_string("\nPer-net reduced models:\n")
  for net in reduction.nets {
    out.write_string(
      "- \{net.net_name}: status=\{net.status.label()}, Cnear=\{net.pi.near_capacitance} F, Cfar=\{net.pi.far_capacitance} F, Rseries=\{net.pi.series_resistance} ohm, sinks=\{net.sinks.length()}\n",
    )
  }
  out.to_string()
}

///|
pub fn reduction_to_json(reduction : @reduction.DesignReduction) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\"schema\":\"moonrcinspect.reduction.v1\",\"exact_tree_count\":\{reduction.exact_tree_count},\"approximate_count\":\{reduction.approximate_count},\"unavailable_count\":\{reduction.unavailable_count},\"nets\":[",
  )
  for index in 0..<reduction.nets.length() {
    if index > 0 {
      out.write_char(',')
    }
    let net = reduction.nets[index]
    out.write_string(
      "{\"net\":\{quoted(net.net_name)},\"status\":\{quoted(net.status.label())},\"driver\":",
    )
    match net.driver_node {
      Some(value) => out.write_string(quoted(value))
      None => out.write_string("null")
    }
    out.write_string(
      ",\"near_capacitance_f\":\{net.pi.near_capacitance},\"far_capacitance_f\":\{net.pi.far_capacitance},\"series_resistance_ohm\":\{net.pi.series_resistance},\"first_moment_s\":\{net.pi.first_moment},\"sinks\":[",
    )
    for sink_index in 0..<net.sinks.length() {
      if sink_index > 0 {
        out.write_char(',')
      }
      let sink = net.sinks[sink_index]
      out.write_string(
        "{\"node\":\{quoted(sink.node_name)},\"path_resistance_ohm\":\{sink.path_resistance},\"pin_load_capacitance_f\":\{sink.pin_load_capacitance},\"reachable\":\{sink.reachable}}",
      )
    }
    out.write_string("]}")
  }
  out.write_string("]}")
  out.to_string()
}

///|
pub fn reduction_to_csv(reduction : @reduction.DesignReduction) -> String {
  let out = StringBuilder()
  out.write_string(
    "net,status,driver,near_capacitance_f,far_capacitance_f,series_resistance_ohm,total_capacitance_f,first_moment_s,sink_count\n",
  )
  for net in reduction.nets {
    let driver = match net.driver_node {
      Some(value) => value
      None => ""
    }
    out.write_string(
      "\{csv_cell(net.net_name)},\{csv_cell(net.status.label())},\{csv_cell(driver)},\{net.pi.near_capacitance},\{net.pi.far_capacitance},\{net.pi.series_resistance},\{net.pi.total_capacitance},\{net.pi.first_moment},\{net.sinks.length()}\n",
    )
  }
  out.to_string()
}

///|
pub fn markdown_report(
  network : @model.RCNetwork,
  metrics : @analyzer.DesignMetrics,
  audit_report : @audit.AuditReport,
) -> String {
  let out = StringBuilder()
  let design = match network.header.design_name {
    Some(value) => value
    None => "<unnamed>"
  }
  out.write_string("# MoonRCInspect Report\n\n")
  out.write_string("- Design: `\{design}`\n")
  out.write_string("- Networks: \{metrics.net_count}\n")
  out.write_string("- Nodes: \{metrics.node_count}\n")
  out.write_string("- Resistors: \{metrics.resistor_count}\n")
  out.write_string("- Capacitors: \{metrics.capacitor_count}\n")
  out.write_string(
    "- Audit: \{if audit_report.passed { "PASS" } else { "FAIL" }}",
  )
  out.write_string(
    " (\{audit_report.error_count} errors, \{audit_report.warning_count} warnings)\n\n",
  )
  out.write_string("## Network Analysis\n\n")
  for net in network.nets {
    let net_metrics = @analyzer.analyze_net(net)
    let delay = @analyzer.elmore_delay(net)
    out.write_string("### `\{net.name}`\n\n")
    out.write_string(
      "- Scale: \{net_metrics.node_count} nodes, \{net_metrics.resistor_count} resistors, \{net_metrics.capacitor_count} capacitors\n",
    )
    out.write_string(
      "- Total R/C: \{net_metrics.total_resistance} ohm / \{net_metrics.detailed_capacitance} F\n",
    )
    out.write_string(
      "- Topology: \{net_metrics.connected_components} component(s)",
    )
    if net_metrics.has_cycle {
      out.write_string(", cyclic")
    }
    out.write_char('\n')
    out.write_string("- Anomaly status: ")
    if net_metrics.anomalous {
      out.write_string("anomalous (")
      for index in 0..<net_metrics.anomaly_reasons.length() {
        if index > 0 {
          out.write_string(", ")
        }
        out.write_string(net_metrics.anomaly_reasons[index])
      }
      out.write_string(")\n")
    } else {
      out.write_string("normal\n")
    }
    out.write_string("- Elmore status: `\{delay.status.label()}`")
    if delay.status == @analyzer.ExactTree {
      out.write_string(", max delay \{delay.max_delay_seconds} s")
    }
    out.write_string("\n\n")
  }
  out.write_string("## Audit Findings\n\n")
  if audit_report.diagnostics.length() == 0 {
    out.write_string("No issues found.\n")
  } else {
    for issue in audit_report.diagnostics {
      out.write_string(
        "- **\{issue.severity.label()} \{issue.code}**: \{issue.message}",
      )
      match issue.suggestion {
        Some(suggestion) => out.write_string(" Suggested fix: \{suggestion}.")
        None => ()
      }
      out.write_char('\n')
    }
  }
  out.to_string()
}
