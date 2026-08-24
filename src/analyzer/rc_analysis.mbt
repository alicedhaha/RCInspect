///|
pub(all) struct NetMetrics {
  net_id : Int
  name : String
  node_count : Int
  connection_count : Int
  resistor_count : Int
  capacitor_count : Int
  total_resistance : Double
  detailed_capacitance : Double
  declared_capacitance : Double
  capacitance_delta : Double
  connected_components : Int
  isolated_node_count : Int
  has_cycle : Bool
  max_degree : Int
  complexity_score : Int
  anomalous : Bool
  anomaly_reasons : Array[String]
} derive(Debug)

///|
pub(all) struct DesignMetrics {
  net_count : Int
  node_count : Int
  connection_count : Int
  resistor_count : Int
  capacitor_count : Int
  total_resistance : Double
  total_capacitance : Double
  average_net_resistance : Double
  average_net_capacitance : Double
  max_resistance_net : String?
  max_capacitance_net : String?
  anomalous_net_count : Int
  anomalous_nets : Array[String]
  nets : Array[NetMetrics]
} derive(Debug)

///|
pub fn analyze_net(net : @model.Net) -> NetMetrics {
  let topology = @graph.summarize(net)
  let detailed_capacitance = net.effective_capacitance()
  let anomaly_reasons : Array[String] = []
  if net.nodes.length() == 0 {
    anomaly_reasons.push("empty network")
  }
  if net.connections.length() == 0 {
    anomaly_reasons.push("no connections")
  }
  if topology.connected_components > 1 {
    anomaly_reasons.push("disconnected resistance topology")
  }
  if topology.isolated_nodes.length() > 0 {
    anomaly_reasons.push("isolated nodes")
  }
  if topology.has_cycle {
    anomaly_reasons.push("resistance cycle")
  }
  if topology.driver_nodes.length() != 1 {
    anomaly_reasons.push("driver count is not one")
  }
  for resistor in net.resistors {
    if resistor.resistance < 0.0 ||
      resistor.resistance.is_nan() ||
      resistor.resistance.is_inf() {
      anomaly_reasons.push("invalid resistance")
      break
    }
  }
  for capacitor in net.capacitors {
    if capacitor.capacitance < 0.0 ||
      capacitor.capacitance.is_nan() ||
      capacitor.capacitance.is_inf() {
      anomaly_reasons.push("invalid capacitance")
      break
    }
  }
  let cap_scale = if detailed_capacitance > net.declared_capacitance {
    detailed_capacitance
  } else {
    net.declared_capacitance
  }
  if cap_scale > 0.0 &&
    (detailed_capacitance - net.declared_capacitance).abs() / cap_scale > 0.05 {
    anomaly_reasons.push("declared capacitance mismatch")
  }
  {
    net_id: net.id,
    name: net.name,
    node_count: net.nodes.length(),
    connection_count: net.connections.length(),
    resistor_count: net.resistors.length(),
    capacitor_count: net.capacitors.length(),
    total_resistance: net.total_resistance(),
    detailed_capacitance,
    declared_capacitance: net.declared_capacitance,
    capacitance_delta: detailed_capacitance - net.declared_capacitance,
    connected_components: topology.connected_components,
    isolated_node_count: topology.isolated_nodes.length(),
    has_cycle: topology.has_cycle,
    max_degree: topology.max_degree,
    complexity_score: net.nodes.length() +
    net.resistors.length() +
    net.capacitors.length() +
    topology.max_degree * 2,
    anomalous: anomaly_reasons.length() > 0,
    anomaly_reasons,
  }
}

///|
pub fn analyze(network : @model.RCNetwork) -> DesignMetrics {
  let nets : Array[NetMetrics] = []
  let mut node_count = 0
  let mut connection_count = 0
  let mut resistor_count = 0
  let mut capacitor_count = 0
  let mut total_resistance = 0.0
  let mut total_capacitance = 0.0
  let mut max_resistance = -1.0
  let mut max_capacitance = -1.0
  let mut max_resistance_net : String? = None
  let mut max_capacitance_net : String? = None
  let anomalous_nets : Array[String] = []
  for net in network.nets {
    let metrics = analyze_net(net)
    node_count += metrics.node_count
    connection_count += metrics.connection_count
    resistor_count += metrics.resistor_count
    capacitor_count += metrics.capacitor_count
    total_resistance += metrics.total_resistance
    total_capacitance += metrics.detailed_capacitance
    if metrics.total_resistance > max_resistance {
      max_resistance = metrics.total_resistance
      max_resistance_net = Some(metrics.name)
    }
    if metrics.detailed_capacitance > max_capacitance {
      max_capacitance = metrics.detailed_capacitance
      max_capacitance_net = Some(metrics.name)
    }
    if metrics.anomalous {
      anomalous_nets.push(metrics.name)
    }
    nets.push(metrics)
  }
  let count = network.nets.length()
  {
    net_count: count,
    node_count,
    connection_count,
    resistor_count,
    capacitor_count,
    total_resistance,
    total_capacitance,
    average_net_resistance: if count == 0 {
      0.0
    } else {
      total_resistance / count.to_double()
    },
    average_net_capacitance: if count == 0 {
      0.0
    } else {
      total_capacitance / count.to_double()
    },
    max_resistance_net,
    max_capacitance_net,
    anomalous_net_count: anomalous_nets.length(),
    anomalous_nets,
    nets,
  }
}

///|
pub fn highest_complexity(
  metrics : DesignMetrics,
  limit? : Int = 10,
) -> Array[NetMetrics] {
  let result = metrics.nets.copy()
  result.sort_by(fn(left, right) {
    right.complexity_score.compare(left.complexity_score)
  })
  if result.length() <= limit {
    result
  } else {
    let trimmed : Array[NetMetrics] = []
    for index in 0..<limit {
      trimmed.push(result[index])
    }
    trimmed
  }
}
