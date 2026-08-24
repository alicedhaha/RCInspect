///|
let tree_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*D_NET tree 3
  #|*CONN
  #|*P tree O
  #|*I u1:A I
  #|*I u2:A I
  #|*CAP
  #|1 tree 1
  #|2 u1:A 1
  #|3 u2:A 1
  #|*RES
  #|1 tree u1:A 10
  #|2 u1:A u2:A 20
  #|*END

///|
test "topology summarizes a connected RC tree" {
  let net = @parser.parse(tree_spef).network.nets[0]
  let summary = @graph.summarize(net)
  assert_eq(summary.node_count, 3)
  assert_eq(summary.connected_components, 1)
  assert_eq(summary.isolated_nodes, [])
  assert_false(summary.has_cycle)
  assert_eq(summary.driver_nodes, [0])
  assert_eq(summary.max_degree, 2)
  assert_eq(@graph.reachable_from(@graph.RCGraph::from_net(net), 0).length(), 3)
}

///|
test "topology detects cycles and isolated nodes" {
  let source = tree_spef.replace(
    old="*RES\n1 tree u1:A 10\n2 u1:A u2:A 20",
    new="*CONN\n*I loose I\n*RES\n1 tree u1:A 10\n2 u1:A u2:A 20\n3 u2:A tree 30",
  )
  let summary = @graph.summarize(@parser.parse(source).network.nets[0])
  assert_true(summary.has_cycle)
  assert_eq(summary.connected_components, 2)
  assert_eq(summary.isolated_nodes.length(), 1)
}
