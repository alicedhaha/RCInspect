///|
let reduction_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*D_NET tree 3
  #|*CONN
  #|*P tree O
  #|*I sink:A I *L 1
  #|*I sink:B I *L 2
  #|*CAP
  #|1 tree 1
  #|2 sink:A 1
  #|3 sink:B 1
  #|*RES
  #|1 tree sink:A 10
  #|2 sink:A sink:B 20
  #|*END

///|
test "tree reduction preserves total load and first moment" {
  let net = @parser.parse(reduction_spef).network.nets[0]
  let result = @reduction.reduce_net(net)
  assert_eq(result.status, @reduction.ExactTree)
  assert_eq(result.driver_node, Some("tree"))
  assert_eq(result.local_node_count, 3)
  assert_eq(result.reachable_node_count, 3)
  assert_eq(result.pi.near_capacitance, 1.0e-15)
  assert_true((result.pi.far_capacitance - 5.0e-15).abs() < 1.0e-29)
  assert_eq(result.sinks.length(), 2)
  assert_eq(result.worst_sink().unwrap().node_name, "sink:B")
  assert_eq(result.critical_path.unwrap().target, "sink:B")
}

///|
test "design reduction aggregates availability" {
  let network = @parser.parse(reduction_spef).network
  let result = @reduction.reduce_design(network)
  assert_eq(result.nets.length(), 1)
  assert_eq(result.exact_tree_count, 1)
  assert_eq(result.approximate_count, 0)
  assert_eq(result.unavailable_count, 0)
}

///|
test "reduction rejects missing and multiple drivers" {
  let no_driver = @parser.parse(
      reduction_spef.replace(old="*P tree O", new="*P tree I"),
    ).network.nets[0]
  assert_eq(@reduction.reduce_net(no_driver).status, @reduction.NoDriver)
  let multiple = @parser.parse(
      reduction_spef.replace(old="*I sink:A I", new="*I sink:A O"),
    ).network.nets[0]
  assert_eq(@reduction.reduce_net(multiple).status, @reduction.MultipleDrivers)
}
