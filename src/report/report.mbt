///|
fn quoted(value : String) -> String {
  "\"\{@visual.json_escape(value)}\""
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
