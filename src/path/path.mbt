///|
pub(all) enum PathStatus {
  Found
  EmptyNetwork
  UnknownSource
  UnknownTarget
  Unreachable
  InvalidResistance
  NoDriver
  MultipleDrivers
} derive(Eq, Debug)

///|
pub(all) struct PathHop {
  node_id : Int
  node_name : String
  via_resistor_id : Int?
  edge_resistance : Double
  cumulative_resistance : Double
} derive(Debug)

///|
pub(all) struct PathResult {
  status : PathStatus
  net_name : String
  source : String
  target : String
  hops : Array[PathHop]
  total_resistance : Double
  edge_count : Int
} derive(Debug)

///|
pub(all) struct ReachableNode {
  node_id : Int
  node_name : String
  resistance : Double
  edge_count : Int
} derive(Debug)

///|
pub(all) struct ReachabilityResult {
  status : PathStatus
  net_name : String
  source : String
  reachable : Array[ReachableNode]
  unreachable_nodes : Array[String]
  farthest : ReachableNode?
} derive(Debug)

///|
pub(all) struct PathDistance {
  source : String
  target : String
  reachable : Bool
  resistance : Double
  edge_count : Int
} derive(Debug)

///|
pub(all) struct PathMatrix {
  status : PathStatus
  net_name : String
  nodes : Array[String]
  distances : Array[PathDistance]
  reachable_pair_count : Int
  unreachable_pair_count : Int
  diameter : PathDistance?
} derive(Debug)

///|
struct SearchState {
  source_id : Int
  distances : Array[Double]
  edge_counts : Array[Int]
  parents : Array[Int]
  parent_resistors : Array[Int]
  parent_resistances : Array[Double]
} derive(Debug)

///|
fn empty_path(
  status : PathStatus,
  net : @model.Net,
  source : String,
  target : String,
) -> PathResult {
  {
    status,
    net_name: net.name,
    source,
    target,
    hops: [],
    total_resistance: 0.0,
    edge_count: 0,
  }
}

///|
fn find_node_id(net : @model.Net, name : String) -> Int? {
  for node in net.nodes {
    if node.name == name {
      return Some(node.id)
    }
  }
  None
}

///|
fn valid_local_node(net : @model.Net, node_id : Int) -> Bool {
  node_id >= 0 &&
  node_id < net.nodes.length() &&
  net.nodes[node_id].kind != @model.External
}

///|
fn resistance_is_valid(value : Double) -> Bool {
  value >= 0.0 && !value.is_nan() && !value.is_inf()
}

///|
fn network_resistances_valid(net : @model.Net) -> Bool {
  for resistor in net.resistors {
    if !resistance_is_valid(resistor.resistance) {
      return false
    }
  }
  true
}

///|
fn minimum_unsettled(distances : Array[Double], settled : Array[Bool]) -> Int {
  let mut selected = -1
  let mut selected_distance = 0.0
  for node in 0..<distances.length() {
    if !settled[node] && distances[node] >= 0.0 {
      if selected == -1 || distances[node] < selected_distance {
        selected = node
        selected_distance = distances[node]
      }
    }
  }
  selected
}

///|
fn minimum_resistance_search(net : @model.Net, source_id : Int) -> SearchState {
  let graph = @graph.RCGraph::from_net(net)
  let distances = Array::make(net.nodes.length(), -1.0)
  let edge_counts = Array::make(net.nodes.length(), -1)
  let parents = Array::make(net.nodes.length(), -1)
  let parent_resistors = Array::make(net.nodes.length(), -1)
  let parent_resistances = Array::make(net.nodes.length(), 0.0)
  let settled = Array::make(net.nodes.length(), false)
  distances[source_id] = 0.0
  edge_counts[source_id] = 0
  while true {
    let current = minimum_unsettled(distances, settled)
    if current == -1 {
      break
    }
    settled[current] = true
    for edge in graph.neighbors(current) {
      if valid_local_node(net, edge.to) && !settled[edge.to] {
        let candidate = distances[current] + edge.resistance
        let candidate_edges = edge_counts[current] + 1
        if distances[edge.to] < 0.0 ||
          candidate < distances[edge.to] ||
          (
            candidate == distances[edge.to] &&
            candidate_edges < edge_counts[edge.to]
          ) {
          distances[edge.to] = candidate
          edge_counts[edge.to] = candidate_edges
          parents[edge.to] = current
          parent_resistors[edge.to] = edge.resistor_id
          parent_resistances[edge.to] = edge.resistance
        }
      }
    }
  }
  {
    source_id,
    distances,
    edge_counts,
    parents,
    parent_resistors,
    parent_resistances,
  }
}

///|
fn minimum_hop_search(net : @model.Net, source_id : Int) -> SearchState {
  let graph = @graph.RCGraph::from_net(net)
  let distances = Array::make(net.nodes.length(), -1.0)
  let edge_counts = Array::make(net.nodes.length(), -1)
  let parents = Array::make(net.nodes.length(), -1)
  let parent_resistors = Array::make(net.nodes.length(), -1)
  let parent_resistances = Array::make(net.nodes.length(), 0.0)
  let queue : Array[Int] = [source_id]
  distances[source_id] = 0.0
  edge_counts[source_id] = 0
  let mut cursor = 0
  while cursor < queue.length() {
    let current = queue[cursor]
    cursor += 1
    for edge in graph.neighbors(current) {
      if valid_local_node(net, edge.to) && edge_counts[edge.to] == -1 {
        edge_counts[edge.to] = edge_counts[current] + 1
        distances[edge.to] = distances[current] + edge.resistance
        parents[edge.to] = current
        parent_resistors[edge.to] = edge.resistor_id
        parent_resistances[edge.to] = edge.resistance
        queue.push(edge.to)
      }
    }
  }
  {
    source_id,
    distances,
    edge_counts,
    parents,
    parent_resistors,
    parent_resistances,
  }
}

///|
fn build_path(
  net : @model.Net,
  source : String,
  target : String,
  target_id : Int,
  state : SearchState,
) -> PathResult {
  if state.distances[target_id] < 0.0 {
    return empty_path(Unreachable, net, source, target)
  }
  let reverse_nodes : Array[Int] = []
  let mut current = target_id
  while current != -1 {
    reverse_nodes.push(current)
    if current == state.source_id {
      break
    }
    current = state.parents[current]
  }
  if reverse_nodes[reverse_nodes.length() - 1] != state.source_id {
    return empty_path(Unreachable, net, source, target)
  }
  let hops : Array[PathHop] = []
  for index in 0..<reverse_nodes.length() {
    let node_id = reverse_nodes[reverse_nodes.length() - 1 - index]
    let resistor_id = if node_id == state.source_id {
      None
    } else {
      Some(state.parent_resistors[node_id])
    }
    hops.push({
      node_id,
      node_name: net.nodes[node_id].name,
      via_resistor_id: resistor_id,
      edge_resistance: state.parent_resistances[node_id],
      cumulative_resistance: state.distances[node_id],
    })
  }
  {
    status: Found,
    net_name: net.name,
    source,
    target,
    hops,
    total_resistance: state.distances[target_id],
    edge_count: state.edge_counts[target_id],
  }
}

///|
/// Finds the lowest-resistance path using Dijkstra's algorithm.
///
/// Resistance values must be finite and non-negative. Ties are resolved by
/// preferring fewer edges, then by the stable SPEF resistor order.
pub fn minimum_resistance_path(
  net : @model.Net,
  source : String,
  target : String,
) -> PathResult {
  if net.nodes.length() == 0 {
    return empty_path(EmptyNetwork, net, source, target)
  }
  let source_id = match find_node_id(net, source) {
    Some(value) => value
    None => return empty_path(UnknownSource, net, source, target)
  }
  let target_id = match find_node_id(net, target) {
    Some(value) => value
    None => return empty_path(UnknownTarget, net, source, target)
  }
  if !valid_local_node(net, source_id) {
    return empty_path(UnknownSource, net, source, target)
  }
  if !valid_local_node(net, target_id) {
    return empty_path(UnknownTarget, net, source, target)
  }
  if !network_resistances_valid(net) {
    return empty_path(InvalidResistance, net, source, target)
  }
  build_path(
    net,
    source,
    target,
    target_id,
    minimum_resistance_search(net, source_id),
  )
}

///|
/// Finds the path with the fewest resistor edges using breadth-first search.
pub fn minimum_hop_path(
  net : @model.Net,
  source : String,
  target : String,
) -> PathResult {
  if net.nodes.length() == 0 {
    return empty_path(EmptyNetwork, net, source, target)
  }
  let source_id = match find_node_id(net, source) {
    Some(value) => value
    None => return empty_path(UnknownSource, net, source, target)
  }
  let target_id = match find_node_id(net, target) {
    Some(value) => value
    None => return empty_path(UnknownTarget, net, source, target)
  }
  if !valid_local_node(net, source_id) {
    return empty_path(UnknownSource, net, source, target)
  }
  if !valid_local_node(net, target_id) {
    return empty_path(UnknownTarget, net, source, target)
  }
  if !network_resistances_valid(net) {
    return empty_path(InvalidResistance, net, source, target)
  }
  build_path(net, source, target, target_id, minimum_hop_search(net, source_id))
}

///|
fn unreachable_names(net : @model.Net, state : SearchState) -> Array[String] {
  let result : Array[String] = []
  for node in net.nodes {
    if node.kind != @model.External && state.distances[node.id] < 0.0 {
      result.push(node.name)
    }
  }
  result
}

///|
/// Returns minimum resistance and hop count from one source to every local
/// node. Results are sorted by resistance and then by node name.
pub fn resistance_reachability(
  net : @model.Net,
  source : String,
) -> ReachabilityResult {
  if net.nodes.length() == 0 {
    return {
      status: EmptyNetwork,
      net_name: net.name,
      source,
      reachable: [],
      unreachable_nodes: [],
      farthest: None,
    }
  }
  let source_id = match find_node_id(net, source) {
    Some(value) => value
    None =>
      return {
        status: UnknownSource,
        net_name: net.name,
        source,
        reachable: [],
        unreachable_nodes: [],
        farthest: None,
      }
  }
  if !network_resistances_valid(net) {
    return {
      status: InvalidResistance,
      net_name: net.name,
      source,
      reachable: [],
      unreachable_nodes: [],
      farthest: None,
    }
  }
  let state = minimum_resistance_search(net, source_id)
  let reachable : Array[ReachableNode] = []
  let mut farthest : ReachableNode? = None
  for node in net.nodes {
    if node.kind != @model.External && state.distances[node.id] >= 0.0 {
      let entry : ReachableNode = {
        node_id: node.id,
        node_name: node.name,
        resistance: state.distances[node.id],
        edge_count: state.edge_counts[node.id],
      }
      match farthest {
        None => farthest = Some(entry)
        Some(current) =>
          if entry.resistance > current.resistance {
            farthest = Some(entry)
          }
      }
      reachable.push(entry)
    }
  }
  reachable.sort_by(fn(left, right) {
    let resistance_order = left.resistance.compare(right.resistance)
    if resistance_order == 0 {
      left.node_name.compare(right.node_name)
    } else {
      resistance_order
    }
  })
  {
    status: Found,
    net_name: net.name,
    source,
    reachable,
    unreachable_nodes: unreachable_names(net, state),
    farthest,
  }
}

///|
/// Finds the minimum-resistance route from the sole driver to the electrically
/// farthest reachable local node.
pub fn critical_resistance_path(net : @model.Net) -> PathResult {
  if net.nodes.length() == 0 {
    return empty_path(EmptyNetwork, net, "", "")
  }
  let drivers = net.driver_nodes()
  if drivers.length() == 0 {
    return empty_path(NoDriver, net, "", "")
  }
  if drivers.length() > 1 {
    return empty_path(MultipleDrivers, net, "", "")
  }
  if !network_resistances_valid(net) {
    return empty_path(InvalidResistance, net, "", "")
  }
  let source_id = drivers[0]
  let source = net.nodes[source_id].name
  let state = minimum_resistance_search(net, source_id)
  let mut target_id = source_id
  let mut max_resistance = 0.0
  for node in net.nodes {
    if node.kind != @model.External && state.distances[node.id] > max_resistance {
      max_resistance = state.distances[node.id]
      target_id = node.id
    }
  }
  build_path(net, source, net.nodes[target_id].name, target_id, state)
}

///|
pub fn PathStatus::label(self : PathStatus) -> String {
  match self {
    Found => "found"
    EmptyNetwork => "empty-network"
    UnknownSource => "unknown-source"
    UnknownTarget => "unknown-target"
    Unreachable => "unreachable"
    InvalidResistance => "invalid-resistance"
    NoDriver => "no-driver"
    MultipleDrivers => "multiple-drivers"
  }
}

///|
pub fn PathResult::node_names(self : PathResult) -> Array[String] {
  self.hops.map(fn(hop) { hop.node_name })
}

///|
pub fn PathResult::resistor_ids(self : PathResult) -> Array[Int] {
  let result : Array[Int] = []
  for hop in self.hops {
    if hop.via_resistor_id is Some(id) {
      result.push(id)
    }
  }
  result
}

///|
pub fn PathResult::contains_node(self : PathResult, name : String) -> Bool {
  self.hops.any(fn(hop) { hop.node_name == name })
}

///|
/// Computes unordered all-pairs minimum-resistance distances for local nodes.
/// This uses one Dijkstra search per source and is intended for inspection and
/// moderate-sized extracted nets rather than full-chip timing signoff.
pub fn resistance_matrix(net : @model.Net) -> PathMatrix {
  let names : Array[String] = []
  for node in net.nodes {
    if node.kind != @model.External {
      names.push(node.name)
    }
  }
  if names.length() == 0 {
    return {
      status: EmptyNetwork,
      net_name: net.name,
      nodes: names,
      distances: [],
      reachable_pair_count: 0,
      unreachable_pair_count: 0,
      diameter: None,
    }
  }
  if !network_resistances_valid(net) {
    return {
      status: InvalidResistance,
      net_name: net.name,
      nodes: names,
      distances: [],
      reachable_pair_count: 0,
      unreachable_pair_count: 0,
      diameter: None,
    }
  }
  let distances : Array[PathDistance] = []
  let mut reachable_pair_count = 0
  let mut unreachable_pair_count = 0
  let mut diameter : PathDistance? = None
  for source_index in 0..<net.nodes.length() {
    if net.nodes[source_index].kind == @model.External {
      continue
    }
    let state = minimum_resistance_search(net, source_index)
    for target_index in (source_index + 1)..<net.nodes.length() {
      if net.nodes[target_index].kind == @model.External {
        continue
      }
      let reachable = state.distances[target_index] >= 0.0
      let entry : PathDistance = {
        source: net.nodes[source_index].name,
        target: net.nodes[target_index].name,
        reachable,
        resistance: if reachable {
          state.distances[target_index]
        } else {
          0.0
        },
        edge_count: if reachable {
          state.edge_counts[target_index]
        } else {
          0
        },
      }
      if reachable {
        reachable_pair_count += 1
        match diameter {
          None => diameter = Some(entry)
          Some(current) =>
            if entry.resistance > current.resistance {
              diameter = Some(entry)
            }
        }
      } else {
        unreachable_pair_count += 1
      }
      distances.push(entry)
    }
  }
  {
    status: Found,
    net_name: net.name,
    nodes: names,
    distances,
    reachable_pair_count,
    unreachable_pair_count,
    diameter,
  }
}

///|
pub fn PathMatrix::find(
  self : PathMatrix,
  first : String,
  second : String,
) -> PathDistance? {
  if first == second && self.nodes.contains(first) {
    return Some({
      source: first,
      target: second,
      reachable: true,
      resistance: 0.0,
      edge_count: 0,
    })
  }
  for distance in self.distances {
    if (distance.source == first && distance.target == second) ||
      (distance.source == second && distance.target == first) {
      return Some(distance)
    }
  }
  None
}

///|
pub fn diameter_path(net : @model.Net) -> PathResult {
  let matrix = resistance_matrix(net)
  match matrix.diameter {
    Some(distance) =>
      minimum_resistance_path(net, distance.source, distance.target)
    None => empty_path(matrix.status, net, "", "")
  }
}
