///|
let analysis_spef =
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
fn near(actual : Double, expected : Double, tolerance : Double) -> Bool {
  let delta = actual - expected
  delta < tolerance && delta > -tolerance
}

///|
test "design analysis aggregates network metrics" {
  let network = @parser.parse(analysis_spef).network
  let metrics = @analyzer.analyze(network)
  assert_eq(metrics.net_count, 1)
  assert_eq(metrics.node_count, 3)
  assert_eq(metrics.resistor_count, 2)
  assert_eq(metrics.capacitor_count, 3)
  assert_eq(metrics.total_resistance, 30.0)
  assert_true(near(metrics.total_capacitance, 3.0e-15, 1.0e-30))
  assert_eq(metrics.max_resistance_net, Some("tree"))
  assert_eq(metrics.anomalous_net_count, 0)
  assert_eq(metrics.anomalous_nets, [])
  assert_eq(@analyzer.highest_complexity(metrics, limit=1).length(), 1)
}

///|
test "Elmore delay is exact for a single-driver RC tree" {
  let net = @parser.parse(analysis_spef).network.nets[0]
  let result = @analyzer.elmore_delay(net)
  assert_eq(result.status, @analyzer.ExactTree)
  assert_eq(result.root, Some(0))
  assert_true(near(result.node_delays[1].delay_seconds, 2.0e-14, 1.0e-29))
  assert_true(near(result.node_delays[2].delay_seconds, 4.0e-14, 1.0e-29))
  assert_true(near(result.max_delay_seconds, 4.0e-14, 1.0e-29))
}

///|
test "Elmore delay rejects multiple drivers" {
  let source = analysis_spef.replace(old="*I u1:A I", new="*I u1:A O")
  let net = @parser.parse(source).network.nets[0]
  assert_eq(@analyzer.elmore_delay(net).status, @analyzer.MultipleDrivers)
  let metrics = @analyzer.analyze_net(net)
  assert_true(metrics.anomalous)
  assert_true(metrics.anomaly_reasons.contains("driver count is not one"))
}
