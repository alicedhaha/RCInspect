///|
pub(all) struct Edge {
  to : Int
  resistor_id : Int
  resistance : Double
} derive(Debug)

///|
pub(all) struct RCGraph {
  adjacency : Array[Array[Edge]]
  resistor_count : Int
} derive(Debug)

///|
pub(all) struct TopologySummary {
  node_count : Int
  resistor_count : Int
  connected_components : Int
  isolated_nodes : Array[Int]
  has_cycle : Bool
  driver_nodes : Array[Int]
  max_degree : Int
} derive(Debug)

///|
pub fn RCGraph::from_net(net : @model.Net) -> RCGraph {
  let adjacency : Array[Array[Edge]] = []
  for _ in 0..<net.nodes.length() {
    adjacency.push([])
  }
  let mut accepted = 0
  for resistor in net.resistors {
    if resistor.from_node >= 0 &&
      resistor.from_node < adjacency.length() &&
      resistor.to_node >= 0 &&
      resistor.to_node < adjacency.length() {
      adjacency[resistor.from_node].push({
        to: resistor.to_node,
        resistor_id: resistor.id,
        resistance: resistor.resistance,
      })
      adjacency[resistor.to_node].push({
        to: resistor.from_node,
        resistor_id: resistor.id,
        resistance: resistor.resistance,
      })
      accepted += 1
    }
  }
  { adjacency, resistor_count: accepted }
}

///|
pub fn RCGraph::node_count(self : RCGraph) -> Int {
  self.adjacency.length()
}

///|
pub fn RCGraph::degree(self : RCGraph, node : Int) -> Int {
  if node < 0 || node >= self.adjacency.length() {
    0
  } else {
    self.adjacency[node].length()
  }
}

///|
pub fn RCGraph::neighbors(self : RCGraph, node : Int) -> Array[Edge] {
  if node < 0 || node >= self.adjacency.length() {
    []
  } else {
    self.adjacency[node].copy()
  }
}

///|
fn inspect_component(
  graph : RCGraph,
  start : Int,
  visited : Array[Bool],
) -> Bool {
  let nodes : Array[Int] = [start]
  let parents : Array[Int] = [-1]
  visited[start] = true
  let mut cursor = 0
  let mut cyclic = false
  while cursor < nodes.length() {
    let node = nodes[cursor]
    let parent = parents[cursor]
    cursor += 1
    for edge in graph.adjacency[node] {
      if edge.to == node {
        cyclic = true
      } else if !visited[edge.to] {
        visited[edge.to] = true
        nodes.push(edge.to)
        parents.push(node)
      } else if edge.to != parent {
        cyclic = true
      }
    }
  }
  cyclic
}

///|
pub fn summarize(net : @model.Net) -> TopologySummary {
  let graph = RCGraph::from_net(net)
  let visited = Array::make(graph.node_count(), false)
  let isolated_nodes : Array[Int] = []
  let mut connected_components = 0
  let mut has_cycle = false
  let mut max_degree = 0
  for node in 0..<graph.node_count() {
    if net.nodes[node].kind == @model.External {
      visited[node] = true
      continue
    }
    let degree = graph.degree(node)
    if degree == 0 {
      isolated_nodes.push(node)
    }
    if degree > max_degree {
      max_degree = degree
    }
    if !visited[node] {
      connected_components += 1
      if inspect_component(graph, node, visited) {
        has_cycle = true
      }
    }
  }
  {
    node_count: graph.node_count(),
    resistor_count: graph.resistor_count,
    connected_components,
    isolated_nodes,
    has_cycle,
    driver_nodes: net.driver_nodes(),
    max_degree,
  }
}

///|
pub fn reachable_from(graph : RCGraph, start : Int) -> Array[Int] {
  guard start >= 0 && start < graph.node_count() else { return [] }
  let visited = Array::make(graph.node_count(), false)
  let queue : Array[Int] = [start]
  let result : Array[Int] = []
  let mut cursor = 0
  visited[start] = true
  while cursor < queue.length() {
    let node = queue[cursor]
    cursor += 1
    result.push(node)
    for edge in graph.adjacency[node] {
      if !visited[edge.to] {
        visited[edge.to] = true
        queue.push(edge.to)
      }
    }
  }
  result
}
