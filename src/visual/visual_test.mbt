///|
let visual_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "visual"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*D_NET "clock net" 2
  #|*CONN
  #|*P "clock net" O
  #|*I "u1:A" I
  #|*CAP
  #|1 "clock net" 1
  #|2 "u1:A" 1
  #|*RES
  #|1 "clock net" "u1:A" 10
  #|*END

///|
test "network JSON is valid and contains normalized data" {
  let network = @parser.parse(visual_spef).network
  let encoded = @visual.network_to_json(network)
  ignore(@json.parse(encoded))
  assert_true(encoded.contains("\"schema\":\"moonrcinspect.network.v1\""))
  assert_true(encoded.contains("\"resistance_ohm\":10"))
}

///|
test "DOT output escapes labels and renders RC elements" {
  let net = @parser.parse(visual_spef).network.nets[0]
  let dot = @visual.net_to_dot(net)
  assert_true(dot.contains("graph"))
  assert_true(dot.contains("R1 10 ohm"))
  assert_true(dot.contains("GND"))
  assert_true(dot.contains("clock net"))
}
