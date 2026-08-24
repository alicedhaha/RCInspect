///|
pub(all) enum NodeKind {
  Port
  InstancePin
  Internal
  External
} derive(Eq, Debug)

///|
pub(all) enum Direction {
  Input
  Output
  Inout
  Unknown
} derive(Eq, Debug)

///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Debug)

///|
pub(all) struct Node {
  id : Int
  name : String
  kind : NodeKind
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
pub(all) struct Connection {
  node_id : Int
  direction : Direction
  coordinate : Point?
  load_capacitance : Double?
  driving_cell : String?
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
/// Semantic pin view resolved from a connection and its backing node.
pub(all) struct Pin {
  node_id : Int
  name : String
  kind : NodeKind
  direction : Direction
  coordinate : Point?
  load_capacitance : Double?
  driving_cell : String?
} derive(Debug)

///|
pub(all) struct Resistor {
  id : Int
  from_node : Int
  to_node : Int
  resistance : Double
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
/// `to_node = None` represents a capacitance to ground.
pub(all) struct Capacitor {
  id : Int
  from_node : Int
  to_node : Int?
  capacitance : Double
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
pub(all) struct Net {
  id : Int
  name : String
  declared_capacitance : Double
  nodes : Array[Node]
  connections : Array[Connection]
  resistors : Array[Resistor]
  capacitors : Array[Capacitor]
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
pub(all) struct NameMapEntry {
  index : Int
  name : String
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
pub(all) struct PortDecl {
  name : String
  direction : Direction
  coordinate : Point?
  span : @diagnostic.SourceSpan?
} derive(Debug)

///|
pub(all) struct DesignHeader {
  spef_version : String?
  design_name : String?
  date : String?
  vendor : String?
  program : String?
  program_version : String?
  design_flow : Array[String]
  divider : String
  delimiter : String
  bus_delimiter_open : String
  bus_delimiter_close : String
  time_unit : UnitScale
  capacitance_unit : UnitScale
  resistance_unit : UnitScale
  inductance_unit : UnitScale
} derive(Debug)

///|
pub(all) struct RCNetwork {
  header : DesignHeader
  name_map : Array[NameMapEntry]
  ports : Array[PortDecl]
  nets : Array[Net]
  diagnostics : Array[@diagnostic.Diagnostic]
} derive(Debug)

///|
/// Design-level view exposed to library consumers.
pub(all) struct Design {
  header : DesignHeader
  name_map : Array[NameMapEntry]
  ports : Array[PortDecl]
  nets : Array[Net]
} derive(Debug)

///|
pub fn DesignHeader::default() -> DesignHeader {
  {
    spef_version: None,
    design_name: None,
    date: None,
    vendor: None,
    program: None,
    program_version: None,
    design_flow: [],
    divider: "/",
    delimiter: ":",
    bus_delimiter_open: "[",
    bus_delimiter_close: "]",
    time_unit: default_time_unit(),
    capacitance_unit: default_capacitance_unit(),
    resistance_unit: default_resistance_unit(),
    inductance_unit: default_inductance_unit(),
  }
}

///|
pub fn RCNetwork::empty() -> RCNetwork {
  {
    header: DesignHeader::default(),
    name_map: [],
    ports: [],
    nets: [],
    diagnostics: [],
  }
}

///|
pub fn RCNetwork::design(self : RCNetwork) -> Design {
  {
    header: self.header,
    name_map: self.name_map,
    ports: self.ports,
    nets: self.nets,
  }
}

///|
pub fn Net::pins(self : Net) -> Array[Pin] {
  let pins : Array[Pin] = []
  for connection in self.connections {
    match self.find_node(connection.node_id) {
      Some(node) =>
        pins.push({
          node_id: node.id,
          name: node.name,
          kind: node.kind,
          direction: connection.direction,
          coordinate: connection.coordinate,
          load_capacitance: connection.load_capacitance,
          driving_cell: connection.driving_cell,
        })
      None => ()
    }
  }
  pins
}

///|
pub fn Net::total_resistance(self : Net) -> Double {
  let mut total = 0.0
  for resistor in self.resistors {
    total += resistor.resistance
  }
  total
}

///|
/// Effective grounded capacitance using a 0.5 split for coupling capacitors.
pub fn Net::effective_capacitance(self : Net) -> Double {
  let mut total = 0.0
  for capacitor in self.capacitors {
    total += capacitor.capacitance
  }
  total
}

///|
pub fn Net::ground_capacitance(self : Net) -> Double {
  let mut total = 0.0
  for capacitor in self.capacitors {
    if capacitor.to_node is None {
      total += capacitor.capacitance
    }
  }
  total
}

///|
pub fn Net::coupling_capacitance(self : Net) -> Double {
  let mut total = 0.0
  for capacitor in self.capacitors {
    if capacitor.to_node is Some(_) {
      total += capacitor.capacitance
    }
  }
  total
}

///|
pub fn Net::find_node(self : Net, node_id : Int) -> Node? {
  self.nodes.iter().find_first(fn(node) { node.id == node_id })
}

///|
pub fn Net::driver_nodes(self : Net) -> Array[Int] {
  let result : Array[Int] = []
  for connection in self.connections {
    if connection.direction == Output {
      result.push(connection.node_id)
    }
  }
  result
}

///|
pub fn Direction::from_spef(value : String) -> Direction {
  match value {
    "I" => Input
    "O" => Output
    "B" => Inout
    _ => Unknown
  }
}

///|
pub fn Direction::spef_code(self : Direction) -> String {
  match self {
    Input => "I"
    Output => "O"
    Inout => "B"
    Unknown => "?"
  }
}
