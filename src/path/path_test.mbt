///|
let path_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*D_NET route 4
  #|*CONN
  #|*P route O
  #|*I sink I
  #|*CAP
  #|1 route 1
  #|2 a 1
  #|3 b 1
  #|4 sink 1
  #|*RES
  #|1 route a 2
  #|2 a sink 8
  #|3 route b 4
  #|4 b sink 1
  #|*END

///|
test "minimum resistance and minimum hop queries return stable routes" {
  let net = @parser.parse(path_spef).network.nets[0]
  let resistance = @path.minimum_resistance_path(net, "route", "sink")
  assert_eq(resistance.status, @path.Found)
  assert_eq(resistance.node_names(), ["route", "b", "sink"])
  assert_eq(resistance.resistor_ids(), [3, 4])
  assert_eq(resistance.total_resistance, 5.0)
  assert_eq(resistance.edge_count, 2)
  assert_true(resistance.contains_node("b"))
  let hops = @path.minimum_hop_path(net, "route", "sink")
  assert_eq(hops.status, @path.Found)
  assert_eq(hops.edge_count, 2)
}

///|
test "reachability and critical route report electrical distance" {
  let net = @parser.parse(path_spef).network.nets[0]
  let reachability = @path.resistance_reachability(net, "route")
  assert_eq(reachability.status, @path.Found)
  assert_eq(reachability.reachable.length(), 4)
  assert_eq(reachability.unreachable_nodes, [])
  assert_eq(reachability.farthest.unwrap().node_name, "sink")
  let critical = @path.critical_resistance_path(net)
  assert_eq(critical.status, @path.Found)
  assert_eq(critical.target, "sink")
  assert_eq(critical.total_resistance, 5.0)
}

///|
test "path queries expose invalid endpoints and disconnected nodes" {
  let net = @parser.parse(path_spef).network.nets[0]
  assert_eq(
    @path.minimum_resistance_path(net, "missing", "sink").status,
    @path.UnknownSource,
  )
  assert_eq(
    @path.minimum_resistance_path(net, "route", "missing").status,
    @path.UnknownTarget,
  )
  let disconnected_source = path_spef
    .replace(old="2 a sink 8", new="")
    .replace(old="4 b sink 1", new="")
  let disconnected = @parser.parse(disconnected_source).network.nets[0]
  assert_eq(
    @path.minimum_resistance_path(disconnected, "route", "sink").status,
    @path.Unreachable,
  )
}

///|
test "all-pairs matrix exposes network resistance diameter" {
  let net = @parser.parse(path_spef).network.nets[0]
  let matrix = @path.resistance_matrix(net)
  assert_eq(matrix.status, @path.Found)
  assert_eq(matrix.nodes.length(), 4)
  assert_eq(matrix.reachable_pair_count, 6)
  assert_eq(matrix.unreachable_pair_count, 0)
  assert_eq(matrix.find("route", "sink").unwrap().resistance, 5.0)
  assert_eq(matrix.find("sink", "route").unwrap().resistance, 5.0)
  assert_eq(matrix.find("route", "route").unwrap().resistance, 0.0)
  let diameter = @path.diameter_path(net)
  assert_eq(diameter.status, @path.Found)
  assert_true(diameter.total_resistance >= 5.0)
}
