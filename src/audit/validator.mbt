///|
pub(all) enum AuditRule {
  HeaderRule
  NameMapRule
  NetIntegrityRule
  RcValueRule
  TopologyRule
  ComplexityRule
} derive(Eq, Debug)

///|
pub(all) struct AuditConfig {
  strict : Bool
  capacitance_relative_tolerance : Double
  complexity_threshold : Int
} derive(Debug)

///|
pub(all) struct AuditReport {
  diagnostics : Array[@diagnostic.Diagnostic]
  error_count : Int
  warning_count : Int
  info_count : Int
  passed : Bool
} derive(Debug)

///|
pub fn AuditConfig::default() -> AuditConfig {
  {
    strict: false,
    capacitance_relative_tolerance: 0.05,
    complexity_threshold: 1000,
  }
}

///|
pub fn default_rules() -> Array[AuditRule] {
  [
    HeaderRule,
    NameMapRule,
    NetIntegrityRule,
    RcValueRule,
    TopologyRule,
    ComplexityRule,
  ]
}

///|
fn magnitude(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
fn invalid_number(value : Double) -> Bool {
  value.is_nan() || value.is_inf()
}

///|
fn add_issue(
  issues : Array[@diagnostic.Diagnostic],
  code : String,
  severity : @diagnostic.Severity,
  message : String,
  suggestion : String,
  span : @diagnostic.SourceSpan?,
  net? : String,
) -> Unit {
  issues.push({
    code,
    severity,
    message,
    suggestion: Some(suggestion),
    span,
    net,
  })
}

///|
fn valid_node(net : @model.Net, id : Int) -> Bool {
  id >= 0 && id < net.nodes.length()
}

///|
fn check_headers(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
) -> Unit {
  if network.header.spef_version is None {
    add_issue(
      issues,
      "SPEF-A001",
      @diagnostic.Error,
      "missing *SPEF standard declaration",
      "add *SPEF \"IEEE 1481-1998\" near the beginning of the file",
      None,
    )
  }
  if network.header.design_name is None {
    add_issue(
      issues,
      "SPEF-A002",
      @diagnostic.Warning,
      "missing *DESIGN declaration",
      "add the design name to make reports traceable",
      None,
    )
  }
}

///|
fn check_name_map(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
) -> Unit {
  if network.name_map.length() == 0 {
    add_issue(
      issues,
      "SPEF-A010",
      @diagnostic.Warning,
      "no *NAME_MAP section was found",
      "add a name map for large designs; literal-only SPEF remains valid",
      None,
    )
  }
  for left in 0..<network.name_map.length() {
    for right in (left + 1)..<network.name_map.length() {
      if network.name_map[left].index == network.name_map[right].index {
        add_issue(
          issues,
          "SPEF-A011",
          @diagnostic.Error,
          "duplicate name-map index *\{network.name_map[left].index}",
          "assign each name-map entry a unique integer index",
          network.name_map[right].span,
        )
      }
    }
  }
}

///|
fn check_net_integrity(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
) -> Unit {
  for net in network.nets {
    if net.connections.length() == 0 {
      add_issue(
        issues,
        "SPEF-A100",
        @diagnostic.Error,
        "network \{net.name} has no connection declarations",
        "add *P or *I entries under *CONN",
        net.span,
        net=net.name,
      )
    }
    if net.nodes.length() == 0 {
      add_issue(
        issues,
        "SPEF-A101",
        @diagnostic.Error,
        "network \{net.name} contains no nodes",
        "add connection and parasitic entries or remove the empty net",
        net.span,
        net=net.name,
      )
    }
    for connection in net.connections {
      if !valid_node(net, connection.node_id) {
        add_issue(
          issues,
          "SPEF-A102",
          @diagnostic.Error,
          "connection references missing node id \{connection.node_id}",
          "ensure the connection node is interned in the same network",
          connection.span,
          net=net.name,
        )
      }
    }
    for resistor in net.resistors {
      if !valid_node(net, resistor.from_node) ||
        !valid_node(net, resistor.to_node) {
        add_issue(
          issues,
          "SPEF-A103",
          @diagnostic.Error,
          "resistor \{resistor.id} references a missing node",
          "correct both resistor endpoints",
          resistor.span,
          net=net.name,
        )
      }
    }
    for capacitor in net.capacitors {
      let missing_second = match capacitor.to_node {
        Some(id) => !valid_node(net, id)
        None => false
      }
      if !valid_node(net, capacitor.from_node) || missing_second {
        add_issue(
          issues,
          "SPEF-A104",
          @diagnostic.Error,
          "capacitor \{capacitor.id} references a missing node",
          "correct the capacitor endpoint reference",
          capacitor.span,
          net=net.name,
        )
      }
    }
  }
}

///|
fn check_rc_values(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
  tolerance : Double,
) -> Unit {
  for net in network.nets {
    if invalid_number(net.declared_capacitance) ||
      net.declared_capacitance < 0.0 {
      add_issue(
        issues,
        "SPEF-A200",
        @diagnostic.Error,
        "network \{net.name} has invalid declared capacitance",
        "use a finite, non-negative total capacitance",
        net.span,
        net=net.name,
      )
    }
    for resistor in net.resistors {
      if invalid_number(resistor.resistance) || resistor.resistance < 0.0 {
        add_issue(
          issues,
          "SPEF-A201",
          @diagnostic.Error,
          "resistor \{resistor.id} has invalid resistance",
          "use a finite, non-negative resistance",
          resistor.span,
          net=net.name,
        )
      }
    }
    for capacitor in net.capacitors {
      if invalid_number(capacitor.capacitance) || capacitor.capacitance < 0.0 {
        add_issue(
          issues,
          "SPEF-A202",
          @diagnostic.Error,
          "capacitor \{capacitor.id} has invalid capacitance",
          "use a finite, non-negative capacitance",
          capacitor.span,
          net=net.name,
        )
      }
    }
    for left in 0..<net.resistors.length() {
      for right in (left + 1)..<net.resistors.length() {
        if net.resistors[left].id == net.resistors[right].id {
          add_issue(
            issues,
            "SPEF-A203",
            @diagnostic.Error,
            "duplicate resistor id \{net.resistors[left].id}",
            "assign unique resistor ids within the network",
            net.resistors[right].span,
            net=net.name,
          )
        }
      }
    }
    for left in 0..<net.capacitors.length() {
      for right in (left + 1)..<net.capacitors.length() {
        if net.capacitors[left].id == net.capacitors[right].id {
          add_issue(
            issues,
            "SPEF-A204",
            @diagnostic.Error,
            "duplicate capacitor id \{net.capacitors[left].id}",
            "assign unique capacitor ids within the network",
            net.capacitors[right].span,
            net=net.name,
          )
        }
      }
    }
    let detailed = net.effective_capacitance()
    let denominator = if magnitude(net.declared_capacitance) >
      magnitude(detailed) {
      magnitude(net.declared_capacitance)
    } else {
      magnitude(detailed)
    }
    let relative_error = if denominator == 0.0 {
      0.0
    } else {
      magnitude(detailed - net.declared_capacitance) / denominator
    }
    if relative_error > tolerance {
      add_issue(
        issues,
        "SPEF-A205",
        @diagnostic.Warning,
        "network \{net.name} declared capacitance differs from *CAP sum",
        "verify extraction units and coupling-capacitance accounting",
        net.span,
        net=net.name,
      )
    }
  }
}

///|
fn check_topology(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
) -> Unit {
  for net in network.nets {
    let topology = @graph.summarize(net)
    if topology.connected_components > 1 {
      add_issue(
        issues,
        "SPEF-A300",
        @diagnostic.Error,
        "network \{net.name} has \{topology.connected_components} disconnected components",
        "connect the resistance components or verify node naming",
        net.span,
        net=net.name,
      )
    }
    if topology.isolated_nodes.length() > 0 {
      add_issue(
        issues,
        "SPEF-A301",
        @diagnostic.Warning,
        "network \{net.name} has \{topology.isolated_nodes.length()} isolated nodes",
        "add missing resistance paths or remove unused nodes",
        net.span,
        net=net.name,
      )
    }
    if topology.has_cycle {
      add_issue(
        issues,
        "SPEF-A302",
        @diagnostic.Warning,
        "network \{net.name} contains a resistance cycle",
        "Elmore tree delay is unavailable; inspect extraction topology",
        net.span,
        net=net.name,
      )
    }
    if topology.driver_nodes.length() == 0 {
      add_issue(
        issues,
        "SPEF-A303",
        @diagnostic.Warning,
        "network \{net.name} has no output-direction driver",
        "mark one *CONN entry as output when appropriate",
        net.span,
        net=net.name,
      )
    } else if topology.driver_nodes.length() > 1 {
      add_issue(
        issues,
        "SPEF-A304",
        @diagnostic.Warning,
        "network \{net.name} has multiple output-direction drivers",
        "verify direction metadata before delay estimation",
        net.span,
        net=net.name,
      )
    }
  }
}

///|
fn check_complexity(
  network : @model.RCNetwork,
  issues : Array[@diagnostic.Diagnostic],
  threshold : Int,
) -> Unit {
  for net in network.nets {
    let metrics = @analyzer.analyze_net(net)
    if metrics.complexity_score > threshold {
      add_issue(
        issues,
        "SPEF-A400",
        @diagnostic.Warning,
        "network \{net.name} complexity score \{metrics.complexity_score} exceeds \{threshold}",
        "inspect this net separately or raise the configured threshold",
        net.span,
        net=net.name,
      )
    }
  }
}

///|
fn run_rule(
  rule : AuditRule,
  network : @model.RCNetwork,
  config : AuditConfig,
  issues : Array[@diagnostic.Diagnostic],
) -> Unit {
  match rule {
    HeaderRule => check_headers(network, issues)
    NameMapRule => check_name_map(network, issues)
    NetIntegrityRule => check_net_integrity(network, issues)
    RcValueRule =>
      check_rc_values(network, issues, config.capacitance_relative_tolerance)
    TopologyRule => check_topology(network, issues)
    ComplexityRule =>
      check_complexity(network, issues, config.complexity_threshold)
  }
}

///|
pub fn audit_with_rules(
  network : @model.RCNetwork,
  rules : Array[AuditRule],
  config? : AuditConfig = AuditConfig::default(),
) -> AuditReport {
  let issues = network.diagnostics.copy()
  for rule in rules {
    run_rule(rule, network, config, issues)
  }
  let mut errors = 0
  let mut warnings = 0
  let mut infos = 0
  for index in 0..<issues.length() {
    if config.strict && issues[index].severity == @diagnostic.Warning {
      let issue = issues[index]
      issues[index] = {
        code: issue.code,
        severity: @diagnostic.Error,
        message: issue.message,
        suggestion: issue.suggestion,
        span: issue.span,
        net: issue.net,
      }
    }
    match issues[index].severity {
      @diagnostic.Error => errors += 1
      @diagnostic.Warning => warnings += 1
      @diagnostic.Info => infos += 1
    }
  }
  {
    diagnostics: issues,
    error_count: errors,
    warning_count: warnings,
    info_count: infos,
    passed: errors == 0,
  }
}

///|
pub fn audit(
  network : @model.RCNetwork,
  config? : AuditConfig = AuditConfig::default(),
) -> AuditReport {
  audit_with_rules(network, default_rules(), config~)
}
