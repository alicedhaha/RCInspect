///|
let coupling_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*D_NET left 3
  #|*CONN
  #|*P left O
  #|*CAP
  #|1 left 1
  #|2 left:1 right 2
  #|3 left:1 missing 3
  #|*RES
  #|1 left left:1 1
  #|*END
  #|*D_NET right 1
  #|*CONN
  #|*P right O
  #|*CAP
  #|1 right 1
  #|*END

///|
test "coupling analysis resolves cross-net and unknown endpoints" {
  let network = @parser.parse(coupling_spef).network
  let report = @coupling.analyze(network)
  assert_eq(report.link_count, 2)
  assert_eq(report.resolved_link_count, 1)
  assert_eq(report.unresolved_link_count, 1)
  assert_eq(report.resolved_capacitance, 2.0e-15)
  assert_true((report.unresolved_capacitance - 3.0e-15).abs() < 1.0e-29)
  assert_eq(report.pairs.length(), 1)
  assert_eq(report.pairs[0].first_net, "left")
  assert_eq(report.pairs[0].second_net, "right")
}

///|
test "per-net coupling stats rank partners" {
  let report = @coupling.analyze(@parser.parse(coupling_spef).network)
  let left = report.find_net("left").unwrap()
  assert_eq(left.outgoing_capacitance, 2.0e-15)
  assert_eq(left.unresolved_links, 1)
  assert_eq(left.partners, ["right"])
  assert_eq(left.strongest_partner, Some("right"))
  let right = report.find_net("right").unwrap()
  assert_eq(right.incoming_capacitance, 2.0e-15)
  assert_eq(report.strongest_pairs(limit=1).length(), 1)
}
