///|
let valid_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "audit"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*NAME_MAP
  #|*1 net
  #|*2 u1
  #|*D_NET *1 2
  #|*CONN
  #|*P *1 O
  #|*I *2:A I
  #|*CAP
  #|1 *1 1
  #|2 *2:A 1
  #|*RES
  #|1 *1 *2:A 10
  #|*END

///|
test "valid RC tree passes default audit" {
  let report = @audit.audit(@parser.parse(valid_spef).network)
  assert_true(report.passed)
  assert_eq(report.error_count, 0)
  assert_eq(report.warning_count, 0)
}

///|
test "audit reports malformed RC values and disconnected topology" {
  let invalid = valid_spef.replace(
    old="1 *1 *2:A 10",
    new="1 *1 loose -10\n1 loose *2:A 5",
  )
  let report = @audit.audit(@parser.parse(invalid).network)
  assert_false(report.passed)
  assert_true(report.error_count >= 2)
  let mut saw_negative = false
  let mut saw_duplicate = false
  for issue in report.diagnostics {
    if issue.code == "SPEF-A201" {
      saw_negative = true
    }
    if issue.code == "SPEF-A203" {
      saw_duplicate = true
    }
  }
  assert_true(saw_negative)
  assert_true(saw_duplicate)
}

///|
test "strict mode promotes warnings to errors" {
  let no_name_map = valid_spef.replace(old="*NAME_MAP\n*1 net\n*2 u1\n", new="")
  let parsed = @parser.parse(
    no_name_map.replace(old="*1", new="net").replace(old="*2", new="u1"),
  )
  let normal = @audit.audit(parsed.network)
  assert_true(normal.warning_count > 0)
  let strict = @audit.audit(parsed.network, config={
    strict: true,
    capacitance_relative_tolerance: 0.05,
    complexity_threshold: 1000,
  })
  assert_false(strict.passed)
  assert_eq(strict.warning_count, 0)
}

///|
test "empty network is rejected and has no Elmore estimate" {
  let source =
    #|*SPEF "IEEE 1481-1998"
    #|*DESIGN "empty"
    #|*NAME_MAP
    #|*1 empty_net
    #|*D_NET *1 0
    #|*END
  let network = @parser.parse(source).network
  let report = @audit.audit(network)
  assert_false(report.passed)
  assert_true(
    report.diagnostics.iter().any(fn(issue) { issue.code == "SPEF-A100" }),
  )
  assert_true(
    report.diagnostics.iter().any(fn(issue) { issue.code == "SPEF-A101" }),
  )
  assert_eq(
    @analyzer.elmore_delay(network.nets[0]).status,
    @analyzer.EmptyNetwork,
  )
}

///|
test "audit detects dangling resistor and capacitor node ids" {
  let network = @parser.parse(valid_spef).network
  let resistor = network.nets[0].resistors[0]
  network.nets[0].resistors[0] = {
    id: resistor.id,
    from_node: resistor.from_node,
    to_node: 99,
    resistance: resistor.resistance,
    span: resistor.span,
  }
  let capacitor = network.nets[0].capacitors[0]
  network.nets[0].capacitors[0] = {
    id: capacitor.id,
    from_node: 98,
    to_node: capacitor.to_node,
    capacitance: capacitor.capacitance,
    span: capacitor.span,
  }
  let report = @audit.audit(network)
  assert_true(
    report.diagnostics.iter().any(fn(issue) { issue.code == "SPEF-A103" }),
  )
  assert_true(
    report.diagnostics.iter().any(fn(issue) { issue.code == "SPEF-A104" }),
  )
}
