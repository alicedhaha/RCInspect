///|
fn sample_net() -> @model.Net {
  {
    id: 0,
    name: "clk",
    declared_capacitance: 3.0e-15,
    nodes: [
      { id: 0, name: "clk", kind: @model.Port, span: None },
      { id: 1, name: "u1:A", kind: @model.InstancePin, span: None },
    ],
    connections: [
      {
        node_id: 0,
        direction: @model.Output,
        coordinate: None,
        load_capacitance: None,
        driving_cell: None,
        span: None,
      },
      {
        node_id: 1,
        direction: @model.Input,
        coordinate: None,
        load_capacitance: None,
        driving_cell: None,
        span: None,
      },
    ],
    resistors: [
      { id: 1, from_node: 0, to_node: 1, resistance: 125.0, span: None },
    ],
    capacitors: [
      { id: 1, from_node: 0, to_node: None, capacitance: 1.0e-15, span: None },
      {
        id: 2,
        from_node: 0,
        to_node: Some(1),
        capacitance: 2.0e-15,
        span: None,
      },
    ],
    span: None,
  }
}

///|
test "SPEF units normalize to SI" {
  let scale = @model.UnitScale::new(@model.Capacitance, 1.0, "PF").unwrap()
  assert_eq(scale.to_si(2.5), 2.5e-12)
  assert_eq(@model.UnitScale::new(@model.Resistance, 1.0, "BOGUS"), None)
}

///|
test "net aggregates RC values and drivers" {
  let net = sample_net()
  assert_eq(net.total_resistance(), 125.0)
  let cap_error = net.effective_capacitance() - 3.0e-15
  assert_true(cap_error < 1.0e-30 && cap_error > -1.0e-30)
  assert_eq(net.ground_capacitance(), 1.0e-15)
  assert_eq(net.coupling_capacitance(), 2.0e-15)
  assert_eq(net.driver_nodes(), [0])
  let pins = net.pins()
  assert_eq(pins.length(), 2)
  assert_eq(pins[0].name, "clk")
  assert_eq(pins[1].direction, @model.Input)
}

///|
test "RCNetwork exposes an explicit design view" {
  let network = @model.RCNetwork::empty()
  let design = network.design()
  assert_eq(design.nets.length(), 0)
  assert_eq(design.ports.length(), 0)
}
