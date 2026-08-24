///|
pub(all) struct CouplingLink {
  source_net : String
  source_node : String
  target_node : String
  target_net : String?
  capacitance : Double
  capacitor_id : Int
  resolved : Bool
} derive(Debug)

///|
pub(all) struct CouplingPair {
  first_net : String
  second_net : String
  capacitance : Double
  element_count : Int
} derive(Debug)

///|
pub(all) struct NetCouplingStats {
  net_name : String
  outgoing_capacitance : Double
  incoming_capacitance : Double
  internal_capacitance : Double
  unresolved_capacitance : Double
  resolved_links : Int
  unresolved_links : Int
  partners : Array[String]
  strongest_partner : String?
  strongest_partner_capacitance : Double
} derive(Debug)

///|
pub(all) struct CouplingReport {
  total_coupling_capacitance : Double
  resolved_capacitance : Double
  unresolved_capacitance : Double
  link_count : Int
  resolved_link_count : Int
  unresolved_link_count : Int
  links : Array[CouplingLink]
  pairs : Array[CouplingPair]
  nets : Array[NetCouplingStats]
} derive(Debug)

///|
fn node_name(net : @model.Net, node_id : Int) -> String? {
  match net.find_node(node_id) {
    Some(node) => Some(node.name)
    None => None
  }
}

///|
fn local_owner(network : @model.RCNetwork, name : String) -> String? {
  for net in network.nets {
    for node in net.nodes {
      if node.kind != @model.External && node.name == name {
        return Some(net.name)
      }
    }
  }
  None
}

///|
fn target_owner(
  network : @model.RCNetwork,
  source_net : String,
  target_name : String,
) -> String? {
  for net in network.nets {
    if net.name != source_net {
      for node in net.nodes {
        if node.kind != @model.External && node.name == target_name {
          return Some(net.name)
        }
      }
    }
  }
  local_owner(network, target_name)
}

///|
fn collect_links(network : @model.RCNetwork) -> Array[CouplingLink] {
  let links : Array[CouplingLink] = []
  for net in network.nets {
    for capacitor in net.capacitors {
      match capacitor.to_node {
        None => ()
        Some(target_id) => {
          let source_name = match node_name(net, capacitor.from_node) {
            Some(value) => value
            None => "<invalid:{capacitor.from_node}>"
          }
          let target_name = match node_name(net, target_id) {
            Some(value) => value
            None => "<invalid:{target_id}>"
          }
          let owner = match net.find_node(target_id) {
            Some(node) =>
              if node.kind == @model.External {
                target_owner(network, net.name, target_name)
              } else {
                Some(net.name)
              }
            None => None
          }
          links.push({
            source_net: net.name,
            source_node: source_name,
            target_node: target_name,
            target_net: owner,
            capacitance: capacitor.capacitance,
            capacitor_id: capacitor.id,
            resolved: owner is Some(_),
          })
        }
      }
    }
  }
  links
}

///|
fn canonical_pair(first : String, second : String) -> (String, String) {
  if first.compare(second) <= 0 {
    (first, second)
  } else {
    (second, first)
  }
}

///|
fn find_pair(
  pairs : Array[CouplingPair],
  first : String,
  second : String,
) -> Int {
  for index in 0..<pairs.length() {
    if pairs[index].first_net == first && pairs[index].second_net == second {
      return index
    }
  }
  -1
}

///|
fn aggregate_pairs(links : Array[CouplingLink]) -> Array[CouplingPair] {
  let pairs : Array[CouplingPair] = []
  for link in links {
    match link.target_net {
      Some(target) => {
        let (first, second) = canonical_pair(link.source_net, target)
        let index = find_pair(pairs, first, second)
        if index == -1 {
          pairs.push({
            first_net: first,
            second_net: second,
            capacitance: link.capacitance,
            element_count: 1,
          })
        } else {
          let current = pairs[index]
          pairs[index] = {
            first_net: current.first_net,
            second_net: current.second_net,
            capacitance: current.capacitance + link.capacitance,
            element_count: current.element_count + 1,
          }
        }
      }
      None => ()
    }
  }
  pairs.sort_by(fn(left, right) {
    let capacitance_order = right.capacitance.compare(left.capacitance)
    if capacitance_order == 0 {
      let first_order = left.first_net.compare(right.first_net)
      if first_order == 0 {
        left.second_net.compare(right.second_net)
      } else {
        first_order
      }
    } else {
      capacitance_order
    }
  })
  pairs
}

///|
fn add_unique(values : Array[String], value : String) -> Unit {
  if !values.contains(value) {
    values.push(value)
  }
}

///|
fn partner_totals(
  pairs : Array[CouplingPair],
  net_name : String,
) -> Array[(String, Double)] {
  let totals : Array[(String, Double)] = []
  for pair in pairs {
    if pair.first_net == net_name && pair.second_net != net_name {
      totals.push((pair.second_net, pair.capacitance))
    } else if pair.second_net == net_name && pair.first_net != net_name {
      totals.push((pair.first_net, pair.capacitance))
    }
  }
  totals.sort_by(fn(left, right) {
    let value_order = right.1.compare(left.1)
    if value_order == 0 {
      left.0.compare(right.0)
    } else {
      value_order
    }
  })
  totals
}

///|
fn stats_for_net(
  net : @model.Net,
  links : Array[CouplingLink],
  pairs : Array[CouplingPair],
) -> NetCouplingStats {
  let mut outgoing = 0.0
  let mut incoming = 0.0
  let mut internal = 0.0
  let mut unresolved = 0.0
  let mut resolved_links = 0
  let mut unresolved_links = 0
  let partners : Array[String] = []
  for link in links {
    if link.source_net == net.name {
      match link.target_net {
        Some(target) => {
          resolved_links += 1
          if target == net.name {
            internal += link.capacitance
          } else {
            outgoing += link.capacitance
            add_unique(partners, target)
          }
        }
        None => {
          unresolved += link.capacitance
          unresolved_links += 1
        }
      }
    }
    match link.target_net {
      Some(target) =>
        if target == net.name && link.source_net != net.name {
          incoming += link.capacitance
          add_unique(partners, link.source_net)
        }
      None => ()
    }
  }
  partners.sort()
  let ranked = partner_totals(pairs, net.name)
  let strongest_partner = if ranked.length() == 0 {
    None
  } else {
    Some(ranked[0].0)
  }
  {
    net_name: net.name,
    outgoing_capacitance: outgoing,
    incoming_capacitance: incoming,
    internal_capacitance: internal,
    unresolved_capacitance: unresolved,
    resolved_links,
    unresolved_links,
    partners,
    strongest_partner,
    strongest_partner_capacitance: if ranked.length() == 0 {
      0.0
    } else {
      ranked[0].1
    },
  }
}

///|
/// Builds a design-level coupling index from the endpoint names retained by
/// the parser. Coupling to nodes in another D_NET is resolved by exact expanded
/// SPEF name; unknown external endpoints remain explicit in the report.
pub fn analyze(network : @model.RCNetwork) -> CouplingReport {
  let links = collect_links(network)
  let pairs = aggregate_pairs(links)
  let nets : Array[NetCouplingStats] = []
  let mut total = 0.0
  let mut resolved_capacitance = 0.0
  let mut unresolved_capacitance = 0.0
  let mut resolved_link_count = 0
  let mut unresolved_link_count = 0
  for link in links {
    total += link.capacitance
    if link.resolved {
      resolved_capacitance += link.capacitance
      resolved_link_count += 1
    } else {
      unresolved_capacitance += link.capacitance
      unresolved_link_count += 1
    }
  }
  for net in network.nets {
    nets.push(stats_for_net(net, links, pairs))
  }
  {
    total_coupling_capacitance: total,
    resolved_capacitance,
    unresolved_capacitance,
    link_count: links.length(),
    resolved_link_count,
    unresolved_link_count,
    links,
    pairs,
    nets,
  }
}

///|
pub fn CouplingReport::strongest_pairs(
  self : CouplingReport,
  limit? : Int = 10,
) -> Array[CouplingPair] {
  if limit <= 0 {
    return []
  }
  if self.pairs.length() <= limit {
    return self.pairs.copy()
  }
  let result : Array[CouplingPair] = []
  for index in 0..<limit {
    result.push(self.pairs[index])
  }
  result
}

///|
pub fn CouplingReport::find_net(
  self : CouplingReport,
  name : String,
) -> NetCouplingStats? {
  self.nets.iter().find_first(fn(net) { net.net_name == name })
}
