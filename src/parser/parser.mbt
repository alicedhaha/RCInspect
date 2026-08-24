///|
enum Section {
  HeaderSection
  NameMapSection
  PortsSection
  ConnSection
  CapSection
  ResSection
} derive(Eq, Debug)

///|
fn parse_int_text(text : String) -> Int? {
  try @string.parse_int(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_int_token(token : Token) -> Int? {
  parse_int_text(token.text)
}

///|
fn parse_double_token(token : Token) -> Double? {
  try @string.parse_double(token.text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_reference_index(text : String) -> Int? {
  guard text.length() > 1 && text.unsafe_get(0) == '*' else { return None }
  parse_int_text(text[1:].to_owned())
}

///|
fn line_error(
  diagnostics : Array[@diagnostic.Diagnostic],
  code : String,
  message : String,
  token : Token,
  suggestion? : String,
) -> Unit {
  diagnostics.push({
    code,
    severity: @diagnostic.Error,
    message,
    suggestion,
    span: Some(token.span),
    net: None,
  })
}

///|
fn parse_connection(
  tokens : Array[Token],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> AstConnection? {
  guard tokens.length() >= 3 else {
    if tokens.length() > 0 {
      line_error(
        diagnostics,
        "SPEF-P020",
        "connection requires kind, node name and direction",
        tokens[0],
      )
    }
    return None
  }
  let mut coordinate : (Double, Double)? = None
  let mut load : Double? = None
  let mut driving_cell : String? = None
  let mut index = 3
  while index < tokens.length() {
    match tokens[index].text {
      "*C" =>
        if index + 2 < tokens.length() {
          match
            (
              parse_double_token(tokens[index + 1]),
              parse_double_token(tokens[index + 2]),
            ) {
            (Some(x), Some(y)) => coordinate = Some((x, y))
            _ =>
              line_error(
                diagnostics,
                "SPEF-P021",
                "invalid connection coordinate",
                tokens[index],
              )
          }
          index += 3
        } else {
          line_error(
            diagnostics,
            "SPEF-P021",
            "connection coordinate requires x and y",
            tokens[index],
          )
          index = tokens.length()
        }
      "*L" =>
        if index + 1 < tokens.length() {
          load = parse_double_token(tokens[index + 1])
          if load is None {
            line_error(
              diagnostics,
              "SPEF-P022",
              "invalid connection load capacitance",
              tokens[index + 1],
            )
          }
          index += 2
        } else {
          index += 1
        }
      "*D" =>
        if index + 1 < tokens.length() {
          driving_cell = Some(tokens[index + 1].text)
          index += 2
        } else {
          index += 1
        }
      _ => index += 1
    }
  }
  Some({
    kind: tokens[0].text,
    name: tokens[1].text,
    direction: tokens[2].text,
    coordinate,
    load,
    driving_cell,
    span: tokens[0].span,
  })
}

///|
fn parse_port(
  tokens : Array[Token],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> AstPort? {
  guard tokens.length() >= 2 else {
    if tokens.length() > 0 {
      line_error(
        diagnostics,
        "SPEF-P015",
        "port requires a name and direction",
        tokens[0],
      )
    }
    return None
  }
  let mut coordinate : (Double, Double)? = None
  let mut index = 2
  while index < tokens.length() {
    if tokens[index].text == "*C" && index + 2 < tokens.length() {
      match
        (
          parse_double_token(tokens[index + 1]),
          parse_double_token(tokens[index + 2]),
        ) {
        (Some(x), Some(y)) => coordinate = Some((x, y))
        _ =>
          line_error(
            diagnostics,
            "SPEF-P016",
            "invalid port coordinate",
            tokens[index],
          )
      }
      index += 3
    } else {
      index += 1
    }
  }
  Some({
    name: tokens[0].text,
    direction: tokens[1].text,
    coordinate,
    span: tokens[0].span,
  })
}

///|
fn parse_capacitor(
  tokens : Array[Token],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> AstCapacitor? {
  guard tokens.length() == 3 || tokens.length() == 4 else {
    if tokens.length() > 0 {
      line_error(
        diagnostics,
        "SPEF-P030",
        "capacitor requires id, one or two nodes, and value",
        tokens[0],
      )
    }
    return None
  }
  guard parse_int_token(tokens[0]) is Some(id) else {
    line_error(diagnostics, "SPEF-P031", "invalid capacitor id", tokens[0])
    return None
  }
  let value_index = tokens.length() - 1
  guard parse_double_token(tokens[value_index]) is Some(value) else {
    line_error(
      diagnostics,
      "SPEF-P032",
      "invalid capacitance value",
      tokens[value_index],
    )
    return None
  }
  Some({
    id,
    first: tokens[1].text,
    second: if tokens.length() == 4 {
      Some(tokens[2].text)
    } else {
      None
    },
    value,
    span: tokens[0].span,
  })
}

///|
fn parse_resistor(
  tokens : Array[Token],
  diagnostics : Array[@diagnostic.Diagnostic],
) -> AstResistor? {
  guard tokens.length() == 4 else {
    if tokens.length() > 0 {
      line_error(
        diagnostics,
        "SPEF-P040",
        "resistor requires id, two nodes, and value",
        tokens[0],
      )
    }
    return None
  }
  guard parse_int_token(tokens[0]) is Some(id) else {
    line_error(diagnostics, "SPEF-P041", "invalid resistor id", tokens[0])
    return None
  }
  guard parse_double_token(tokens[3]) is Some(value) else {
    line_error(diagnostics, "SPEF-P042", "invalid resistance value", tokens[3])
    return None
  }
  Some({
    id,
    first: tokens[1].text,
    second: tokens[2].text,
    value,
    span: tokens[0].span,
  })
}

///|
fn parse_ast(lexed : LexResult) -> (SpefAst, Array[@diagnostic.Diagnostic]) {
  let headers : Array[AstHeader] = []
  let name_map : Array[AstNameMapEntry] = []
  let ports : Array[AstPort] = []
  let nets : Array[AstNet] = []
  let diagnostics = lexed.diagnostics.copy()
  let mut section = HeaderSection
  let mut current_name : String? = None
  let mut current_cap = 0.0
  let mut current_span : @diagnostic.SourceSpan? = None
  let mut connections : Array[AstConnection] = []
  let mut capacitors : Array[AstCapacitor] = []
  let mut resistors : Array[AstResistor] = []

  for line in lexed.lines {
    if line.tokens.length() == 0 {
      continue
    }
    let tokens = line.tokens
    let first = tokens[0]
    match first.text {
      "*R_NET" | "*R_PNET" | "*D_PNET" | "*INDUC" => {
        diagnostics.push(
          @diagnostic.Diagnostic::error(
            "SPEF-P060",
            "unsupported SPEF structural section \{first.text}",
            span=first.span,
            suggestion="convert the input to a *D_NET resistance/capacitance representation",
          ),
        )
        section = HeaderSection
        continue
      }
      "*NAME_MAP" => {
        section = NameMapSection
        continue
      }
      "*PORTS" => {
        section = PortsSection
        continue
      }
      "*D_NET" => {
        if current_name is Some(previous) {
          diagnostics.push(
            @diagnostic.Diagnostic::error(
              "SPEF-P010",
              "net \{previous} is missing *END",
              span=current_span.unwrap(),
              suggestion="terminate each *D_NET block with *END",
              net=previous,
            ),
          )
          nets.push({
            name: previous,
            declared_capacitance: current_cap,
            connections,
            capacitors,
            resistors,
            span: current_span.unwrap(),
          })
        }
        guard tokens.length() >= 3 else {
          line_error(
            diagnostics, "SPEF-P011", "*D_NET requires a name and total capacitance",
            first,
          )
          continue
        }
        current_name = Some(tokens[1].text)
        current_span = Some(first.span)
        current_cap = match parse_double_token(tokens[2]) {
          Some(value) => value
          None => {
            line_error(
              diagnostics,
              "SPEF-P012",
              "invalid *D_NET total capacitance",
              tokens[2],
            )
            0.0
          }
        }
        connections = []
        capacitors = []
        resistors = []
        section = ConnSection
        continue
      }
      "*CONN" => {
        section = ConnSection
        continue
      }
      "*CAP" => {
        section = CapSection
        continue
      }
      "*RES" => {
        section = ResSection
        continue
      }
      "*END" => {
        match current_name {
          Some(name) => {
            nets.push({
              name,
              declared_capacitance: current_cap,
              connections,
              capacitors,
              resistors,
              span: current_span.unwrap(),
            })
            current_name = None
            current_span = None
            connections = []
            capacitors = []
            resistors = []
            section = HeaderSection
          }
          None =>
            line_error(
              diagnostics, "SPEF-P013", "*END appears outside a net", first,
            )
        }
        continue
      }
      _ => ()
    }

    match section {
      HeaderSection => {
        let values : Array[String] = []
        for index in 1..<tokens.length() {
          values.push(tokens[index].text)
        }
        headers.push({ keyword: first.text, values, span: first.span })
      }
      NameMapSection =>
        match parse_reference_index(first.text) {
          Some(index) =>
            if tokens.length() >= 2 {
              name_map.push({ index, name: tokens[1].text, span: first.span })
            } else {
              line_error(
                diagnostics, "SPEF-P014", "name-map entry requires a mapped name",
                first,
              )
            }
          None => {
            let values : Array[String] = []
            for index in 1..<tokens.length() {
              values.push(tokens[index].text)
            }
            headers.push({ keyword: first.text, values, span: first.span })
          }
        }
      PortsSection =>
        if parse_port(tokens, diagnostics) is Some(port) {
          ports.push(port)
        }
      ConnSection =>
        if parse_connection(tokens, diagnostics) is Some(connection) {
          connections.push(connection)
        }
      CapSection =>
        if parse_capacitor(tokens, diagnostics) is Some(capacitor) {
          capacitors.push(capacitor)
        }
      ResSection =>
        if parse_resistor(tokens, diagnostics) is Some(resistor) {
          resistors.push(resistor)
        }
    }
  }
  if current_name is Some(name) {
    diagnostics.push(
      @diagnostic.Diagnostic::error(
        "SPEF-P010",
        "net \{name} is missing *END",
        span=current_span.unwrap(),
        suggestion="terminate each *D_NET block with *END",
        net=name,
      ),
    )
    nets.push({
      name,
      declared_capacitance: current_cap,
      connections,
      capacitors,
      resistors,
      span: current_span.unwrap(),
    })
  }
  ({ headers, name_map, ports, nets }, diagnostics)
}

///|
fn first_value(values : Array[String]) -> String? {
  if values.length() > 0 {
    Some(values[0])
  } else {
    None
  }
}

///|
fn parse_unit(
  header : AstHeader,
  quantity : @model.Quantity,
  fallback : @model.UnitScale,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> @model.UnitScale {
  guard header.values.length() >= 2 else {
    diagnostics.push(
      @diagnostic.Diagnostic::error(
        "SPEF-P050",
        "unit declaration requires magnitude and symbol",
        span=header.span,
      ),
    )
    return fallback
  }
  let magnitude = @string.parse_double(header.values[0]) catch {
    _ => {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "SPEF-P051",
          "invalid unit magnitude",
          span=header.span,
        ),
      )
      return fallback
    }
  }
  match @model.UnitScale::new(quantity, magnitude, header.values[1]) {
    Some(unit) => unit
    None => {
      diagnostics.push(
        @diagnostic.Diagnostic::error(
          "SPEF-P052",
          "unsupported unit symbol \{header.values[1]}",
          span=header.span,
        ),
      )
      fallback
    }
  }
}

///|
fn expand_name(
  raw : String,
  name_map : Array[AstNameMapEntry],
  delimiter : String,
) -> String {
  guard raw.length() > 1 && raw.unsafe_get(0) == '*' else { return raw }
  let mut split = raw.length()
  if delimiter.length() == 1 {
    let delimiter_char = delimiter.unsafe_get(0)
    for index in 1..<raw.length() {
      if raw.unsafe_get(index) == delimiter_char {
        split = index
        break
      }
    }
  }
  let reference = raw[1:split].to_owned()
  guard parse_int_text(reference) is Some(index) else { return raw }
  for entry in name_map {
    if entry.index == index {
      if split < raw.length() {
        return entry.name + raw[split:].to_owned()
      }
      return entry.name
    }
  }
  raw
}

///|
fn find_node_id(nodes : Array[@model.Node], name : String) -> Int? {
  for node in nodes {
    if node.name == name {
      return Some(node.id)
    }
  }
  None
}

///|
fn ensure_node(
  nodes : Array[@model.Node],
  name : String,
  kind : @model.NodeKind,
  span : @diagnostic.SourceSpan,
) -> Int {
  match find_node_id(nodes, name) {
    Some(id) => id
    None => {
      let id = nodes.length()
      nodes.push({ id, name, kind, span: Some(span) })
      id
    }
  }
}

///|
fn build_network(
  ast : SpefAst,
  diagnostics : Array[@diagnostic.Diagnostic],
) -> @model.RCNetwork {
  let mut spef_version : String? = None
  let mut design_name : String? = None
  let mut date : String? = None
  let mut vendor : String? = None
  let mut program : String? = None
  let mut program_version : String? = None
  let design_flow : Array[String] = []
  let mut divider = "/"
  let mut delimiter = ":"
  let mut bus_open = "["
  let mut bus_close = "]"
  let mut time_unit = @model.default_time_unit()
  let mut cap_unit = @model.default_capacitance_unit()
  let mut res_unit = @model.default_resistance_unit()
  let mut ind_unit = @model.default_inductance_unit()
  for header in ast.headers {
    match header.keyword {
      "*SPEF" => spef_version = first_value(header.values)
      "*DESIGN" => design_name = first_value(header.values)
      "*DATE" => date = first_value(header.values)
      "*VENDOR" => vendor = first_value(header.values)
      "*PROGRAM" => program = first_value(header.values)
      "*VERSION" => program_version = first_value(header.values)
      "*DESIGN_FLOW" =>
        for value in header.values {
          design_flow.push(value)
        }
      "*DIVIDER" =>
        if first_value(header.values) is Some(value) {
          divider = value
        }
      "*DELIMITER" =>
        if first_value(header.values) is Some(value) {
          delimiter = value
        }
      "*BUS_DELIMITER" => {
        if header.values.length() >= 1 {
          bus_open = header.values[0]
        }
        if header.values.length() >= 2 {
          bus_close = header.values[1]
        }
      }
      "*T_UNIT" =>
        time_unit = parse_unit(header, @model.Time, time_unit, diagnostics)
      "*C_UNIT" =>
        cap_unit = parse_unit(header, @model.Capacitance, cap_unit, diagnostics)
      "*R_UNIT" =>
        res_unit = parse_unit(header, @model.Resistance, res_unit, diagnostics)
      "*L_UNIT" =>
        ind_unit = parse_unit(header, @model.Inductance, ind_unit, diagnostics)
      _ => ()
    }
  }
  let header : @model.DesignHeader = {
    spef_version,
    design_name,
    date,
    vendor,
    program,
    program_version,
    design_flow,
    divider,
    delimiter,
    bus_delimiter_open: bus_open,
    bus_delimiter_close: bus_close,
    time_unit,
    capacitance_unit: cap_unit,
    resistance_unit: res_unit,
    inductance_unit: ind_unit,
  }
  let mapped : Array[@model.NameMapEntry] = []
  for entry in ast.name_map {
    mapped.push({ index: entry.index, name: entry.name, span: Some(entry.span) })
  }
  let ports : Array[@model.PortDecl] = []
  for port in ast.ports {
    let coordinate = match port.coordinate {
      Some((x, y)) => Some(@model.Point::{ x, y })
      None => None
    }
    ports.push({
      name: expand_name(port.name, ast.name_map, delimiter),
      direction: @model.Direction::from_spef(port.direction),
      coordinate,
      span: Some(port.span),
    })
  }
  let nets : Array[@model.Net] = []
  for ast_net in ast.nets {
    let nodes : Array[@model.Node] = []
    let connections : Array[@model.Connection] = []
    let capacitors : Array[@model.Capacitor] = []
    let resistors : Array[@model.Resistor] = []
    for connection in ast_net.connections {
      let name = expand_name(connection.name, ast.name_map, delimiter)
      let kind = if connection.kind == "*P" {
        @model.Port
      } else {
        @model.InstancePin
      }
      let node_id = ensure_node(nodes, name, kind, connection.span)
      let coordinate = match connection.coordinate {
        Some((x, y)) => Some(@model.Point::{ x, y })
        None => None
      }
      connections.push({
        node_id,
        direction: @model.Direction::from_spef(connection.direction),
        coordinate,
        load_capacitance: match connection.load {
          Some(value) => Some(cap_unit.to_si(value))
          None => None
        },
        driving_cell: connection.driving_cell,
        span: Some(connection.span),
      })
    }
    for capacitor in ast_net.capacitors {
      let first_name = expand_name(capacitor.first, ast.name_map, delimiter)
      let first_id = ensure_node(
        nodes,
        first_name,
        @model.Internal,
        capacitor.span,
      )
      let second_id = match capacitor.second {
        Some(raw) => {
          let name = expand_name(raw, ast.name_map, delimiter)
          Some(ensure_node(nodes, name, @model.External, capacitor.span))
        }
        None => None
      }
      capacitors.push({
        id: capacitor.id,
        from_node: first_id,
        to_node: second_id,
        capacitance: cap_unit.to_si(capacitor.value),
        span: Some(capacitor.span),
      })
    }
    for resistor in ast_net.resistors {
      let first_name = expand_name(resistor.first, ast.name_map, delimiter)
      let second_name = expand_name(resistor.second, ast.name_map, delimiter)
      let first_id = ensure_node(
        nodes,
        first_name,
        @model.Internal,
        resistor.span,
      )
      let second_id = ensure_node(
        nodes,
        second_name,
        @model.Internal,
        resistor.span,
      )
      resistors.push({
        id: resistor.id,
        from_node: first_id,
        to_node: second_id,
        resistance: res_unit.to_si(resistor.value),
        span: Some(resistor.span),
      })
    }
    nets.push({
      id: nets.length(),
      name: expand_name(ast_net.name, ast.name_map, delimiter),
      declared_capacitance: cap_unit.to_si(ast_net.declared_capacitance),
      nodes,
      connections,
      resistors,
      capacitors,
      span: Some(ast_net.span),
    })
  }
  { header, name_map: mapped, ports, nets, diagnostics }
}

///|
/// Parse SPEF text into both a syntax tree and normalized RC model.
pub fn parse(source : String, file? : String = "<memory>") -> ParseResult {
  let lexed = lex(source, file~)
  let (ast, diagnostics) = parse_ast(lexed)
  let network = build_network(ast, diagnostics)
  { ast, network, diagnostics }
}

///|
pub fn has_errors(result : ParseResult) -> Bool {
  result.diagnostics.iter().any(fn(diag) { diag.severity == @diagnostic.Error })
}
