///|
fn node_shape(kind : @model.NodeKind) -> String {
  match kind {
    @model.Port => "box"
    @model.InstancePin => "ellipse"
    @model.Internal => "circle"
    @model.External => "diamond"
  }
}

///|
/// Generates a deterministic Graphviz DOT representation of one RC network.
pub fn net_to_dot(net : @model.Net) -> String {
  let out = StringBuilder()
  out.write_string("graph \"\{dot_escape(net.name)}\" {\n")
  out.write_string("  graph [label=\"\{dot_escape(net.name)}\", labelloc=t];\n")
  out.write_string("  node [fontname=\"Arial\"];\n")
  for node in net.nodes {
    out.write_string(
      "  n\{node.id} [label=\"\{dot_escape(node.name)}\", shape=\{node_shape(node.kind)}];\n",
    )
  }
  for resistor in net.resistors {
    out.write_string(
      "  n\{resistor.from_node} -- n\{resistor.to_node} [label=\"R\{resistor.id} \{resistor.resistance} ohm\", color=\"#b54b4b\"];\n",
    )
  }
  for capacitor in net.capacitors {
    match capacitor.to_node {
      None => {
        out.write_string(
          "  g\{capacitor.id} [label=\"GND\", shape=ground, fontsize=9];\n",
        )
        out.write_string(
          "  n\{capacitor.from_node} -- g\{capacitor.id} [label=\"C\{capacitor.id} \{capacitor.capacitance} F\", color=\"#3d6fb4\", style=dashed];\n",
        )
      }
      Some(other) =>
        out.write_string(
          "  n\{capacitor.from_node} -- n\{other} [label=\"Cc\{capacitor.id} \{capacitor.capacitance} F\", color=\"#3d6fb4\", style=dotted, constraint=false];\n",
        )
    }
  }
  out.write_string("}\n")
  out.to_string()
}

///|
pub fn network_to_dot(network : @model.RCNetwork) -> String {
  let out = StringBuilder()
  out.write_string("graph moonrcinspect {\n")
  out.write_string("  compound=true;\n")
  for net in network.nets {
    out.write_string("  subgraph cluster_\{net.id} {\n")
    out.write_string("    label=\"\{dot_escape(net.name)}\";\n")
    for node in net.nodes {
      out.write_string(
        "    n\{net.id}_\{node.id} [label=\"\{dot_escape(node.name)}\", shape=\{node_shape(node.kind)}];\n",
      )
    }
    for resistor in net.resistors {
      out.write_string(
        "    n\{net.id}_\{resistor.from_node} -- n\{net.id}_\{resistor.to_node} [label=\"R=\{resistor.resistance}\"];\n",
      )
    }
    for capacitor in net.capacitors {
      match capacitor.to_node {
        None => {
          out.write_string(
            "    g\{net.id}_\{capacitor.id} [label=\"GND\", shape=ground, fontsize=9];\n",
          )
          out.write_string(
            "    n\{net.id}_\{capacitor.from_node} -- g\{net.id}_\{capacitor.id} [label=\"C=\{capacitor.capacitance}\", style=dashed];\n",
          )
        }
        Some(other) =>
          out.write_string(
            "    n\{net.id}_\{capacitor.from_node} -- n\{net.id}_\{other} [label=\"Cc=\{capacitor.capacitance}\", style=dotted, constraint=false];\n",
          )
      }
    }
    out.write_string("  }\n")
  }
  out.write_string("}\n")
  out.to_string()
}
