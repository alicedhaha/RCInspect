///|
let complete_design =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "integration"
  #|*DIVIDER /
  #|*DELIMITER :
  #|*BUS_DELIMITER [ ]
  #|*T_UNIT 1 PS
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*L_UNIT 1 UH
  #|*NAME_MAP
  #|*1 clk
  #|*2 data
  #|*3 u1
  #|*PORTS
  #|*1 O
  #|*2 O
  #|*D_NET *1 2
  #|*CONN
  #|*P *1 O
  #|*I *3:CLK I
  #|*CAP
  #|1 *1 1
  #|2 *3:CLK 1
  #|*RES
  #|1 *1 *3:CLK 12
  #|*END
  #|*D_NET *2 3
  #|*CONN
  #|*P *2 O
  #|*I *3:D I
  #|*CAP
  #|1 *2 1
  #|2 *2:1 1
  #|3 *3:D 1
  #|*RES
  #|1 *2 *2:1 5
  #|2 *2:1 *3:D 7
  #|*END

///|
fn run(command : Array[String]) -> @cli.CliOutcome {
  @cli.execute(@cli.parse_config(command).unwrap(), complete_design)
}

///|
test "complete SPEF passes all machine-readable workflows" {
  let parsed = run(["parse", "integration.spef"])
  assert_false(parsed.failed)
  ignore(@json.parse(parsed.content))
  let analyzed = run(["analyze", "integration.spef", "--format", "json"])
  assert_false(analyzed.failed)
  ignore(@json.parse(analyzed.content))
  assert_true(analyzed.content.contains("\"net_count\":2"))
  let audited = run(["audit", "integration.spef", "--format", "json"])
  assert_false(audited.failed)
  ignore(@json.parse(audited.content))
  let report = run(["report", "integration.spef"])
  assert_false(report.failed)
  assert_true(report.content.contains("## Network Analysis"))
  let json_report = run(["report", "integration.spef", "--format", "json"])
  assert_false(json_report.failed)
  ignore(@json.parse(json_report.content))
}

///|
test "visualization can select a mapped network name" {
  let output = run(["visualize", "integration.spef", "--net", "data"])
  assert_false(output.failed)
  assert_true(output.content.contains("graph \"data\""))
  assert_false(output.content.contains("clk"))
}

///|
test "invalid SPEF produces failing audit and actionable codes" {
  let invalid =
    #|*DESIGN "invalid"
    #|*C_UNIT 1 FF
    #|*R_UNIT 1 OHM
    #|*D_NET bad 1
    #|*CONN
    #|*I sink:A I
    #|*CAP
    #|1 sink:A -1
  let outcome = @cli.execute(
    @cli.parse_config(["audit", "invalid.spef"]).unwrap(),
    invalid,
  )
  assert_true(outcome.failed)
  assert_true(outcome.content.contains("SPEF-P010"))
  assert_true(outcome.content.contains("SPEF-A001"))
  assert_true(outcome.content.contains("SPEF-A202"))
}
