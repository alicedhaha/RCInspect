///|
pub(all) enum ReductionStatus {
  ExactTree
  ApproximateGraph
  EmptyNetwork
  NoDriver
  MultipleDrivers
  Disconnected
  InvalidElectricalValue
} derive(Eq, Debug)

///|
pub(all) struct SinkEstimate {
  node_id : Int
  node_name : String
  direction : @model.Direction
  pin_load_capacitance : Double
  local_parasitic_capacitance : Double
  path_resistance : Double
  elmore_delay : Double?
  reachable : Bool
} derive(Debug)

///|
pub(all) struct PiModel {
  near_capacitance : Double
  far_capacitance : Double
  series_resistance : Double
  total_capacitance : Double
  first_moment : Double
} derive(Debug)

///|
pub(all) struct NetReduction {
  status : ReductionStatus
  net_name : String
  driver_node : String?
  pi : PiModel
  critical_path : @path.PathResult?
  sinks : Array[SinkEstimate]
  local_node_count : Int
  reachable_node_count : Int
  coupling_policy : String
} derive(Debug)

///|
pub(all) struct DesignReduction {
  nets : Array[NetReduction]
  exact_tree_count : Int
  approximate_count : Int
  unavailable_count : Int
  total_near_capacitance : Double
  total_far_capacitance : Double
} derive(Debug)

///|
fn empty_pi() -> PiModel {
  {
    near_capacitance: 0.0,
    far_capacitance: 0.0,
    series_resistance: 0.0,
    total_capacitance: 0.0,
    first_moment: 0.0,
  }
}

///|
fn local_node_count(net : @model.Net) -> Int {
  let mut count = 0
  for node in net.nodes {
    if node.kind != @model.External {
      count += 1
    }
  }
  count
}

///|
fn unavailable(status : ReductionStatus, net : @model.Net) -> NetReduction {
  {
    status,
    net_name: net.name,
    driver_node: None,
    pi: empty_pi(),
    critical_path: None,
    sinks: [],
    local_node_count: local_node_count(net),
    reachable_node_count: 0,
    coupling_policy: "split coupling capacitance equally between endpoints",
  }
}

///|
fn valid_value(value : Double) -> Bool {
  value >= 0.0 && !value.is_nan() && !value.is_inf()
}

///|
fn electrical_values_valid(net : @model.Net) -> Bool {
  for resistor in net.resistors {
    if !valid_value(resistor.resistance) {
      return false
    }
  }
  for capacitor in net.capacitors {
    if !valid_value(capacitor.capacitance) {
      return false
    }
  }
  for connection in net.connections {
    if connection.load_capacitance is Some(value) && !valid_value(value) {
      return false
    }
  }
  true
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
  values
}

///|
fn pin_loads(net : @model.Net) -> Array[Double] {
  let values = Array::make(net.nodes.length(), 0.0)
  for connection in net.connections {
    if connection.node_id >= 0 && connection.node_id < values.length() {
      if connection.load_capacitance is Some(value) {
        values[connection.node_id] += value
      }
    }
  }
  values
}

///|
fn delay_for_node(result : @analyzer.ElmoreResult, node_id : Int) -> Double? {
  for delay in result.node_delays {
    if delay.node_id == node_id {
      return Some(delay.delay_seconds)
    }
  }
  None
}

///|
fn sink_estimates(
  net : @model.Net,
  driver_name : String,
  parasitics : Array[Double],
  loads : Array[Double],
  delay : @analyzer.ElmoreResult,
) -> Array[SinkEstimate] {
  let sinks : Array[SinkEstimate] = []
  for connection in net.connections {
    if connection.direction == @model.Input ||
      connection.direction == @model.Inout {
      match net.find_node(connection.node_id) {
        Some(node) => {
          let path = @path.minimum_resistance_path(net, driver_name, node.name)
          sinks.push({
            node_id: node.id,
            node_name: node.name,
            direction: connection.direction,
            pin_load_capacitance: loads[node.id],
            local_parasitic_capacitance: parasitics[node.id],
            path_resistance: path.total_resistance,
            elmore_delay: delay_for_node(delay, node.id),
            reachable: path.status == @path.Found,
          })
        }
        None => ()
      }
    }
  }
  sinks.sort_by(fn(left, right) {
    let delay_order = right.path_resistance.compare(left.path_resistance)
    if delay_order == 0 {
      left.node_name.compare(right.node_name)
    } else {
      delay_order
    }
  })
  sinks
}

///|
fn build_pi(
  net : @model.Net,
  driver_name : String,
  driver_id : Int,
  parasitics : Array[Double],
  loads : Array[Double],
) -> (PiModel, Int) {
  let mut near_capacitance = parasitics[driver_id] + loads[driver_id]
  let mut far_capacitance = 0.0
  let mut first_moment = 0.0
  let mut reachable_count = 0
  for node in net.nodes {
    if node.kind != @model.External {
      let local_capacitance = parasitics[node.id] + loads[node.id]
      let path = @path.minimum_resistance_path(net, driver_name, node.name)
      if path.status == @path.Found {
        reachable_count += 1
        if node.id != driver_id {
          far_capacitance += local_capacitance
          first_moment += local_capacitance * path.total_resistance
        }
      }
    }
  }
  if near_capacitance < 0.0 {
    near_capacitance = 0.0
  }
  let series_resistance = if far_capacitance > 0.0 {
    first_moment / far_capacitance
  } else {
    0.0
  }
  (
    {
      near_capacitance,
      far_capacitance,
      series_resistance,
      total_capacitance: near_capacitance + far_capacitance,
      first_moment,
    },
    reachable_count,
  )
}

///|
/// Produces a first-moment-preserving two-capacitance RC approximation.
///
/// For a tree, shortest resistance paths are unique and the model is marked
/// exact-tree. Cyclic graphs are accepted as a screening approximation using
/// minimum-resistance paths. Disconnected and invalid networks are explicit.
pub fn reduce_net(net : @model.Net) -> NetReduction {
  if net.nodes.length() == 0 {
    return unavailable(EmptyNetwork, net)
  }
  if !electrical_values_valid(net) {
    return unavailable(InvalidElectricalValue, net)
  }
  let drivers = net.driver_nodes()
  if drivers.length() == 0 {
    return unavailable(NoDriver, net)
  }
  if drivers.length() > 1 {
    return unavailable(MultipleDrivers, net)
  }
  let topology = @graph.summarize(net)
  if topology.connected_components > 1 {
    return unavailable(Disconnected, net)
  }
  let driver_id = drivers[0]
  let driver_name = net.nodes[driver_id].name
  let parasitics = node_capacitances(net)
  let loads = pin_loads(net)
  let (pi, reachable_count) = build_pi(
    net, driver_name, driver_id, parasitics, loads,
  )
  let delay = @analyzer.elmore_delay(net)
  {
    status: if topology.has_cycle {
      ApproximateGraph
    } else {
      ExactTree
    },
    net_name: net.name,
    driver_node: Some(driver_name),
    pi,
    critical_path: Some(@path.critical_resistance_path(net)),
    sinks: sink_estimates(net, driver_name, parasitics, loads, delay),
    local_node_count: local_node_count(net),
    reachable_node_count: reachable_count,
    coupling_policy: "split coupling capacitance equally between endpoints",
  }
}

///|
pub fn reduce_design(network : @model.RCNetwork) -> DesignReduction {
  let nets : Array[NetReduction] = []
  let mut exact_tree_count = 0
  let mut approximate_count = 0
  let mut unavailable_count = 0
  let mut total_near_capacitance = 0.0
  let mut total_far_capacitance = 0.0
  for net in network.nets {
    let reduction = reduce_net(net)
    match reduction.status {
      ExactTree => exact_tree_count += 1
      ApproximateGraph => approximate_count += 1
      _ => unavailable_count += 1
    }
    total_near_capacitance += reduction.pi.near_capacitance
    total_far_capacitance += reduction.pi.far_capacitance
    nets.push(reduction)
  }
  {
    nets,
    exact_tree_count,
    approximate_count,
    unavailable_count,
    total_near_capacitance,
    total_far_capacitance,
  }
}

///|
pub fn ReductionStatus::label(self : ReductionStatus) -> String {
  match self {
    ExactTree => "exact-tree"
    ApproximateGraph => "approximate-graph"
    EmptyNetwork => "empty-network"
    NoDriver => "no-driver"
    MultipleDrivers => "multiple-drivers"
    Disconnected => "disconnected"
    InvalidElectricalValue => "invalid-electrical-value"
  }
}

///|
pub fn NetReduction::worst_sink(self : NetReduction) -> SinkEstimate? {
  if self.sinks.length() == 0 {
    None
  } else {
    Some(self.sinks[0])
  }
}
