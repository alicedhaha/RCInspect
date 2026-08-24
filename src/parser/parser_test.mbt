///|
let small_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "tiny design"
  #|*DIVIDER /
  #|*DELIMITER :
  #|*BUS_DELIMITER [ ]
  #|*T_UNIT 1 PS
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*L_UNIT 1 UH
  #|*NAME_MAP
  #|*1 clk
  #|*2 u1
  #|*PORTS
  #|*1 O *C 0 0
  #|*D_NET *1 3.0
  #|*CONN
  #|*P *1 O
  #|*I *2:A I *C 10 20 *L 0.2
  #|*CAP
  #|1 *1 1.0
  #|2 *2:A 2.0
  #|*RES
  #|1 *1 *2:A 125
  #|*END

///|
test "lexer preserves quoted header values and source positions" {
  let result = @parser.lex("*DESIGN \"tiny design\"\n", file="tiny.spef")
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(result.lines[0].tokens.length(), 2)
  assert_eq(result.lines[0].tokens[1].text, "tiny design")
  assert_true(result.lines[0].tokens[1].quoted)
  assert_eq(result.lines[0].tokens[1].span.start.column, 9)
}

///|
test "lexer recognizes comments only at token boundaries" {
  let result = @parser.lex(
    "1 U//A 2.0 // trailing comment\n*DESIGN \"name // preserved\"\n",
  )
  assert_eq(result.lines[0].tokens.length(), 3)
  assert_eq(result.lines[0].tokens[1].text, "U//A")
  assert_eq(result.lines[1].tokens[1].text, "name // preserved")
}

///|
test "parser expands names and normalizes RC units" {
  let result = @parser.parse(small_spef, file="small.spef")
  assert_false(@parser.has_errors(result))
  assert_eq(result.network.header.design_name, Some("tiny design"))
  assert_eq(result.network.nets.length(), 1)
  let net = result.network.nets[0]
  assert_eq(net.name, "clk")
  assert_eq(net.nodes.length(), 2)
  assert_eq(net.nodes[1].name, "u1:A")
  assert_eq(net.resistors[0].resistance, 125.0)
  let cap_error = net.declared_capacitance - 3.0e-15
  assert_true(cap_error < 1.0e-30 && cap_error > -1.0e-30)
  assert_eq(net.driver_nodes(), [0])
}

///|
test "parser reports malformed numeric fields and missing END" {
  let result = @parser.parse(
    "*D_NET bad not-a-number\n*CAP\nx node 1.0\n",
    file="invalid.spef",
  )
  assert_true(@parser.has_errors(result))
  assert_true(result.diagnostics.length() >= 3)
  assert_eq(result.network.nets.length(), 1)
}

///|
test "parser rejects unsupported reduced-net structures explicitly" {
  let result = @parser.parse("*R_NET reduced 1.0\n*END\n")
  assert_true(@parser.has_errors(result))
  assert_true(
    result.diagnostics.iter().any(fn(issue) { issue.code == "SPEF-P060" }),
  )
}
