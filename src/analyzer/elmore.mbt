///|
pub(all) enum ElmoreStatus {
  ExactTree
  EmptyNetwork
  NoDriver
  MultipleDrivers
  Disconnected
  Cyclic
} derive(Eq, Debug)

///|
pub(all) struct NodeDelay {
  node_id : Int
  delay_seconds : Double
  downstream_capacitance : Double
} derive(Debug)

///|
pub(all) struct ElmoreResult {
  status : ElmoreStatus
  root : Int?
  node_delays : Array[NodeDelay]
  max_delay_seconds : Double
  coupling_policy : String
} derive(Debug)

///|
fn unavailable(status : ElmoreStatus, root? : Int) -> ElmoreResult {
  {
    status,
    root,
    node_delays: [],
    max_delay_seconds: 0.0,
    coupling_policy: "split coupling capacitance equally between endpoints",
  }
}

///|
fn node_capacitances(net : @model.Net) -> Array[Double] {
  let values = Array::make(net.nodes.length(), 0.0)
  for capacitor in net.capacitors {
    if capacitor.from_node >= 0 && capacitor.from_node < values.length() {
      match capacitor.to_node {
        None => values[capacitor.from_node] += capacitor.capacitance
        Some(other) => {
          values[capacitor.from_node] += capacitor.capacitance * 0.5
          if other >= 0 &&
            other < values.length() &&
            net.nodes[other].kind != @model.External {
            values[other] += capacitor.capacitance * 0.5
          }
        }
      }
    }
  }
  // Pin load is not part of D_NET's declared parasitic capacitance, but it is
  // electrical load seen by the resistance tree and therefore affects delay.
  for connection in net.connections {
    if connection.node_id >= 0 && connection.node_id < values.length() {
      if connection.load_capacitance is Some(load) {
        values[connection.node_id] += load
      }
    }
  }
  values
}

///|
/// Computes Elmore delay only when its mathematical preconditions hold.
///
/// The resistance topology must be a connected, single-driver tree. Coupling
/// capacitance is grounded by assigning half to each endpoint. Unsupported
/// topologies return an explicit status instead of a misleading number.
pub fn elmore_delay(net : @model.Net) -> ElmoreResult {
  if net.nodes.length() == 0 {
    return unavailable(EmptyNetwork)
  }
  let drivers = net.driver_nodes()
  if drivers.length() == 0 {
    return unavailable(NoDriver)
  }
  if drivers.length() > 1 {
    return unavailable(MultipleDrivers)
  }
  let root = drivers[0]
  let topology = @graph.summarize(net)
  if topology.connected_components > 1 {
    return unavailable(Disconnected, root~)
  }
  if topology.has_cycle {
    return unavailable(Cyclic, root~)
  }
  let graph = @graph.RCGraph::from_net(net)
  let parents = Array::make(net.nodes.length(), -2)
  let parent_resistance = Array::make(net.nodes.length(), 0.0)
  let order : Array[Int] = [root]
  let mut local_node_count = 0
  for node in net.nodes {
    if node.kind != @model.External {
      local_node_count += 1
    }
  }
  parents[root] = -1
  let mut cursor = 0
  while cursor < order.length() {
    let node = order[cursor]
    cursor += 1
    for edge in graph.adjacency[node] {
      if parents[edge.to] == -2 {
        parents[edge.to] = node
        parent_resistance[edge.to] = edge.resistance
        order.push(edge.to)
      }
    }
  }
  if order.length() != local_node_count {
    return unavailable(Disconnected, root~)
  }
  let downstream = node_capacitances(net)
  let mut reverse_index = order.length() - 1
  while reverse_index > 0 {
    let node = order[reverse_index]
    let parent = parents[node]
    downstream[parent] += downstream[node]
    reverse_index -= 1
  }
  let delays = Array::make(net.nodes.length(), 0.0)
  let mut max_delay = 0.0
  for index in 1..<order.length() {
    let node = order[index]
    let parent = parents[node]
    delays[node] = delays[parent] + parent_resistance[node] * downstream[node]
    if delays[node] > max_delay {
      max_delay = delays[node]
    }
  }
  let node_delays : Array[NodeDelay] = []
  for node in 0..<net.nodes.length() {
    if net.nodes[node].kind != @model.External {
      node_delays.push({
        node_id: node,
        delay_seconds: delays[node],
        downstream_capacitance: downstream[node],
      })
    }
  }
  {
    status: ExactTree,
    root: Some(root),
    node_delays,
    max_delay_seconds: max_delay,
    coupling_policy: "split coupling capacitance equally between endpoints",
  }
}

///|
pub fn ElmoreStatus::label(self : ElmoreStatus) -> String {
  match self {
    ExactTree => "exact-tree"
    EmptyNetwork => "empty-network"
    NoDriver => "no-driver"
    MultipleDrivers => "multiple-drivers"
    Disconnected => "disconnected"
    Cyclic => "cyclic"
  }
}
