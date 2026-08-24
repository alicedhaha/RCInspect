///|
pub(all) enum Command {
  Parse
  Analyze
  Audit
  Visualize
  Report
  Path
  Coupling
  Reduce
  Matrix
} derive(Eq, Debug)

///|
pub(all) enum OutputFormat {
  Text
  Json
  Dot
  Markdown
  Csv
  Sarif
} derive(Eq, Debug)

///|
pub(all) enum PathMode {
  MinimumResistance
  MinimumHops
} derive(Eq, Debug)

///|
pub(all) struct CliConfig {
  command : Command
  input : String
  format : OutputFormat
  output : String?
  net : String?
  from_node : String?
  to_node : String?
  path_mode : PathMode
  strict : Bool
} derive(Debug)

///|
pub(all) struct CliOutcome {
  content : String
  failed : Bool
} derive(Debug)

///|
pub fn usage() -> String {
  let text =
    #|MoonRCInspect - SPEF parasitic RC analysis
    #|
    #|Usage:
    #|  moonrc parse <file.spef> [--format json] [-o FILE]
    #|  moonrc analyze <file.spef> [--format text|json] [-o FILE]
    #|  moonrc audit <file.spef> [--strict] [--format text|json] [-o FILE]
    #|  moonrc visualize <file.spef> [--net NAME] [--format dot|json] [-o FILE]
    #|  moonrc report <file.spef> [--format markdown|json] [-o FILE]
    #|  moonrc path <file.spef> --net NET --from NODE --to NODE [--mode resistance|hops] [--format text|json|csv]
    #|  moonrc coupling <file.spef> [--format text|json|csv] [-o FILE]
    #|  moonrc reduce <file.spef> [--format text|json|csv] [-o FILE]
    #|  moonrc matrix <file.spef> --net NET [--format text|json|csv] [-o FILE]
    #|
    #|Options:
    #|  -o, --output FILE   Write output to FILE instead of stdout
    #|  --net NAME          Select one network for visualization
    #|  --from NODE         Path source node name
    #|  --to NODE           Path target node name
    #|  --mode MODE         Path objective: resistance or hops
    #|  --strict            Promote audit warnings to errors
    #|  -h, --help          Show this help
  text
}

///|
fn parse_command(value : String) -> Command? {
  match value {
    "parse" => Some(Parse)
    "analyze" => Some(Analyze)
    "audit" => Some(Audit)
    "visualize" => Some(Visualize)
    "report" => Some(Report)
    "path" => Some(Path)
    "coupling" => Some(Coupling)
    "reduce" => Some(Reduce)
    "matrix" => Some(Matrix)
    _ => None
  }
}

///|
fn default_format(command : Command) -> OutputFormat {
  match command {
    Parse => Json
    Analyze => Text
    Audit => Text
    Visualize => Dot
    Report => Markdown
    Path | Coupling | Reduce | Matrix => Text
  }
}

///|
fn parse_format(value : String) -> OutputFormat? {
  match value {
    "text" => Some(Text)
    "json" => Some(Json)
    "dot" => Some(Dot)
    "markdown" | "md" => Some(Markdown)
    "csv" => Some(Csv)
    "sarif" => Some(Sarif)
    _ => None
  }
}

///|
fn format_allowed(command : Command, format : OutputFormat) -> Bool {
  match command {
    Parse => format == Json
    Analyze => format == Text || format == Json || format == Csv
    Audit => format == Text || format == Json || format == Sarif
    Visualize => format == Dot || format == Json
    Report => format == Markdown || format == Json
    Path | Coupling | Reduce | Matrix =>
      format == Text || format == Json || format == Csv
  }
}

///|
fn parse_path_mode(value : String) -> PathMode? {
  match value {
    "resistance" => Some(MinimumResistance)
    "hops" => Some(MinimumHops)
    _ => None
  }
}

///|
pub fn parse_config(args : Array[String]) -> Result[CliConfig, String] {
  guard args.length() >= 2 else { return Err(usage()) }
  if args[0] == "-h" || args[0] == "--help" || args[0] == "help" {
    return Err(usage())
  }
  guard parse_command(args[0]) is Some(command) else {
    return Err("unknown command '\{args[0]}'\n\n\{usage()}")
  }
  let input = args[1]
  let mut format = default_format(command)
  let mut output : String? = None
  let mut net : String? = None
  let mut from_node : String? = None
  let mut to_node : String? = None
  let mut path_mode = MinimumResistance
  let mut strict = false
  let mut index = 2
  while index < args.length() {
    match args[index] {
      "--strict" => {
        strict = true
        index += 1
      }
      "--format" =>
        if index + 1 < args.length() {
          match parse_format(args[index + 1]) {
            Some(value) => format = value
            None => return Err("unknown output format '\{args[index + 1]}'")
          }
          index += 2
        } else {
          return Err("--format requires a value")
        }
      "-o" | "--output" =>
        if index + 1 < args.length() {
          output = Some(args[index + 1])
          index += 2
        } else {
          return Err("\{args[index]} requires a path")
        }
      "--net" =>
        if index + 1 < args.length() {
          net = Some(args[index + 1])
          index += 2
        } else {
          return Err("--net requires a network name")
        }
      "--from" =>
        if index + 1 < args.length() {
          from_node = Some(args[index + 1])
          index += 2
        } else {
          return Err("--from requires a node name")
        }
      "--to" =>
        if index + 1 < args.length() {
          to_node = Some(args[index + 1])
          index += 2
        } else {
          return Err("--to requires a node name")
        }
      "--mode" =>
        if index + 1 < args.length() {
          match parse_path_mode(args[index + 1]) {
            Some(value) => path_mode = value
            None => return Err("unknown path mode '\{args[index + 1]}'")
          }
          index += 2
        } else {
          return Err("--mode requires resistance or hops")
        }
      option => return Err("unknown option '\{option}'")
    }
  }
  guard format_allowed(command, format) else {
    return Err("format is not supported by this command")
  }
  if strict && command != Audit {
    return Err("--strict is only valid with the audit command")
  }
  if net is Some(_) &&
    command != Visualize &&
    command != Path &&
    command != Matrix {
    return Err("--net is only valid with visualize, path, or matrix")
  }
  if (from_node is Some(_) || to_node is Some(_) || path_mode == MinimumHops) &&
    command != Path {
    return Err("--from, --to, and --mode are only valid with path")
  }
  if command == Path && (net is None || from_node is None || to_node is None) {
    return Err("path requires --net, --from, and --to")
  }
  if command == Matrix && net is None {
    return Err("matrix requires --net")
  }
  Ok({
    command,
    input,
    format,
    output,
    net,
    from_node,
    to_node,
    path_mode,
    strict,
  })
}

///|
fn find_net(network : @model.RCNetwork, name : String) -> @model.Net? {
  for net in network.nets {
    if net.name == name {
      return Some(net)
    }
  }
  None
}

///|
fn audit_config(strict : Bool) -> @audit.AuditConfig {
  { strict, capacitance_relative_tolerance: 0.05, complexity_threshold: 1000 }
}

///|
pub fn execute(config : CliConfig, source : String) -> CliOutcome {
  let parsed = @parser.parse(source, file=config.input)
  let network = parsed.network
  match config.command {
    Parse => {
      let audit_report = @audit.audit(network, config=audit_config(false))
      {
        content: @visual.network_to_json(network),
        failed: parsed.diagnostics.length() > 0 || audit_report.error_count > 0,
      }
    }
    Analyze => {
      let metrics = @analyzer.analyze(network)
      {
        content: match config.format {
          Json => @report.metrics_to_json(metrics)
          Csv => @report.metrics_to_csv(metrics)
          _ => @report.metrics_to_text(metrics)
        },
        failed: @parser.has_errors(parsed),
      }
    }
    Audit => {
      let audit_report = @audit.audit(
        network,
        config=audit_config(config.strict),
      )
      {
        content: match config.format {
          Json => @report.audit_to_json(audit_report)
          Sarif => @report.audit_to_sarif(audit_report)
          _ => @report.audit_to_text(audit_report)
        },
        failed: !audit_report.passed,
      }
    }
    Visualize => {
      let selected = match config.net {
        Some(name) => find_net(network, name)
        None => None
      }
      match (config.net, selected) {
        (Some(name), None) =>
          { content: "network '\{name}' was not found\n", failed: true }
        (_, Some(net)) =>
          {
            content: if config.format == Json {
              @visual.net_to_json(net)
            } else {
              @visual.net_to_dot(net)
            },
            failed: @parser.has_errors(parsed),
          }
        (None, None) =>
          {
            content: if config.format == Json {
              @visual.network_to_json(network)
            } else {
              @visual.network_to_dot(network)
            },
            failed: @parser.has_errors(parsed),
          }
      }
    }
    Report => {
      let metrics = @analyzer.analyze(network)
      let audit_report = @audit.audit(network)
      {
        content: if config.format == Json {
          "{\"network\":\{@visual.network_to_json(network)},\"analysis\":\{@report.metrics_to_json(metrics)},\"audit\":\{@report.audit_to_json(audit_report)}}"
        } else {
          @report.markdown_report(network, metrics, audit_report)
        },
        failed: !audit_report.passed,
      }
    }
    Path => {
      let net_name = config.net.unwrap()
      match find_net(network, net_name) {
        None =>
          { content: "network '\{net_name}' was not found\n", failed: true }
        Some(net) => {
          let source = config.from_node.unwrap()
          let target = config.to_node.unwrap()
          let result = if config.path_mode == MinimumHops {
            @path.minimum_hop_path(net, source, target)
          } else {
            @path.minimum_resistance_path(net, source, target)
          }
          {
            content: match config.format {
              Json => @report.path_to_json(result)
              Csv => @report.path_to_csv(result)
              _ => @report.path_to_text(result)
            },
            failed: result.status != @path.Found,
          }
        }
      }
    }
    Coupling => {
      let result = @coupling.analyze(network)
      {
        content: match config.format {
          Json => @report.coupling_to_json(result)
          Csv => @report.coupling_to_csv(result)
          _ => @report.coupling_to_text(result)
        },
        failed: @parser.has_errors(parsed),
      }
    }
    Reduce => {
      let result = @reduction.reduce_design(network)
      {
        content: match config.format {
          Json => @report.reduction_to_json(result)
          Csv => @report.reduction_to_csv(result)
          _ => @report.reduction_to_text(result)
        },
        failed: @parser.has_errors(parsed) || result.unavailable_count > 0,
      }
    }
    Matrix => {
      let net_name = config.net.unwrap()
      match find_net(network, net_name) {
        None =>
          { content: "network '\{net_name}' was not found\n", failed: true }
        Some(net) => {
          let matrix = @path.resistance_matrix(net)
          {
            content: match config.format {
              Json => @report.matrix_to_json(matrix)
              Csv => @report.matrix_to_csv(matrix)
              _ => @report.matrix_to_text(matrix)
            },
            failed: matrix.status != @path.Found,
          }
        }
      }
    }
  }
}
