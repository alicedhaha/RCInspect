///|
fn node_kind_label(kind : @model.NodeKind) -> String {
  match kind {
    @model.Port => "port"
    @model.InstancePin => "instance-pin"
    @model.Internal => "internal"
    @model.External => "external"
  }
}

///|
fn write_node_json(out : StringBuilder, node : @model.Node) -> Unit {
  out.write_string(
    "{\"id\":\{node.id},\"name\":\{json_string(node.name)},\"kind\":\{json_string(node_kind_label(node.kind))}}",
  )
}

///|
fn write_connection_json(
  out : StringBuilder,
  connection : @model.Connection,
) -> Unit {
  out.write_string(
    "{\"node_id\":\{connection.node_id},\"direction\":\{json_string(connection.direction.spef_code())}",
  )
  match connection.coordinate {
    Some(point) =>
      out.write_string(",\"coordinate\":{\"x\":\{point.x},\"y\":\{point.y}}")
    None => out.write_string(",\"coordinate\":null")
  }
  match connection.load_capacitance {
    Some(value) => out.write_string(",\"load_capacitance_f\":\{value}")
    None => out.write_string(",\"load_capacitance_f\":null")
  }
  match connection.driving_cell {
    Some(value) => out.write_string(",\"driving_cell\":\{json_string(value)}}")
    None => out.write_string(",\"driving_cell\":null}")
  }
}

///|
fn write_net_json(out : StringBuilder, net : @model.Net) -> Unit {
  out.write_string(
    "{\"id\":\{net.id},\"name\":\{json_string(net.name)},\"declared_capacitance_f\":\{net.declared_capacitance}",
  )
  out.write_string(",\"nodes\":[")
  for index in 0..<net.nodes.length() {
    if index > 0 {
      out.write_char(',')
    }
    write_node_json(out, net.nodes[index])
  }
  out.write_string("],\"connections\":[")
  for index in 0..<net.connections.length() {
    if index > 0 {
      out.write_char(',')
    }
    write_connection_json(out, net.connections[index])
  }
  out.write_string("],\"resistors\":[")
  for index in 0..<net.resistors.length() {
    if index > 0 {
      out.write_char(',')
    }
    let resistor = net.resistors[index]
    out.write_string(
      "{\"id\":\{resistor.id},\"from\":\{resistor.from_node},\"to\":\{resistor.to_node},\"resistance_ohm\":\{resistor.resistance}}",
    )
  }
  out.write_string("],\"capacitors\":[")
  for index in 0..<net.capacitors.length() {
    if index > 0 {
      out.write_char(',')
    }
    let capacitor = net.capacitors[index]
    out.write_string(
      "{\"id\":\{capacitor.id},\"from\":\{capacitor.from_node},\"to\":",
    )
    match capacitor.to_node {
      Some(node) => out.write_string("\{node}")
      None => out.write_string("null")
    }
    out.write_string(",\"capacitance_f\":\{capacitor.capacitance}}")
  }
  out.write_string("]}")
}

///|
pub fn net_to_json(net : @model.Net) -> String {
  let out = StringBuilder()
  write_net_json(out, net)
  out.to_string()
}

///|
pub fn network_to_json(network : @model.RCNetwork) -> String {
  let out = StringBuilder()
  out.write_string("{\"schema\":\"moonrcinspect.network.v1\",\"design\":")
  match network.header.design_name {
    Some(name) => out.write_string(json_string(name))
    None => out.write_string("null")
  }
  out.write_string(",\"spef_version\":")
  match network.header.spef_version {
    Some(version) => out.write_string(json_string(version))
    None => out.write_string("null")
  }
  out.write_string(",\"units\":{\"capacitance\":\"F\",\"resistance\":\"OHM\"}")
  out.write_string(",\"nets\":[")
  for index in 0..<network.nets.length() {
    if index > 0 {
      out.write_char(',')
    }
    write_net_json(out, network.nets[index])
  }
  out.write_string("]}")
  out.to_string()
}
