///|
let cli_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "cli"
  #|*C_UNIT 1 FF
  #|*R_UNIT 1 OHM
  #|*NAME_MAP
  #|*1 n
  #|*D_NET *1 1
  #|*CONN
  #|*P *1 O
  #|*CAP
  #|1 *1 1
  #|*END

///|
test "CLI parser handles subcommands and options" {
  let config = @cli.parse_config([
    "visualize", "input.spef", "--net", "n", "--format", "json", "-o", "n.json",
  ]).unwrap()
  assert_eq(config.command, @cli.Visualize)
  assert_eq(config.format, @cli.Json)
  assert_eq(config.net, Some("n"))
  assert_eq(config.output, Some("n.json"))
}

///|
test "CLI executes analyze and audit workflows" {
  let analyze = @cli.execute(
    @cli.parse_config(["analyze", "input.spef"]).unwrap(),
    cli_spef,
  )
  assert_false(analyze.failed)
  assert_true(analyze.content.contains("MoonRCInspect analysis"))
  let audit = @cli.execute(
    @cli.parse_config(["audit", "input.spef", "--format", "json"]).unwrap(),
    cli_spef,
  )
  assert_false(audit.failed)
  assert_true(audit.content.contains("\"passed\":true"))
}

///|
test "CLI rejects command-specific option misuse" {
  assert_true(@cli.parse_config(["parse", "input.spef", "--strict"]) is Err(_))
  assert_true(
    @cli.parse_config(["audit", "input.spef", "--format", "dot"]) is Err(_),
  )
}

///|
test "CLI parses and executes path, coupling, and reduction workflows" {
  let source =
    #|*SPEF "IEEE 1481-1998"
    #|*C_UNIT 1 FF
    #|*R_UNIT 1 OHM
    #|*D_NET n 2
    #|*CONN
    #|*P n O
    #|*I sink I
    #|*CAP
    #|1 n 1
    #|2 sink 1
    #|*RES
    #|1 n sink 5
    #|*END
  let path = @cli.execute(
    @cli.parse_config([
      "path", "input.spef", "--net", "n", "--from", "n", "--to", "sink", "--format",
      "json",
    ]).unwrap(),
    source,
  )
  assert_false(path.failed)
  assert_true(path.content.contains("\"total_resistance_ohm\":5"))
  let coupling = @cli.execute(
    @cli.parse_config(["coupling", "input.spef", "--format", "csv"]).unwrap(),
    source,
  )
  assert_false(coupling.failed)
  assert_true(coupling.content.contains("source_net,source_node"))
  let reduction = @cli.execute(
    @cli.parse_config(["reduce", "input.spef", "--format", "json"]).unwrap(),
    source,
  )
  assert_false(reduction.failed)
  assert_true(reduction.content.contains("moonrcinspect.reduction.v1"))
  let matrix = @cli.execute(
    @cli.parse_config(["matrix", "input.spef", "--net", "n", "--format", "json"]).unwrap(),
    source,
  )
  assert_false(matrix.failed)
  assert_true(matrix.content.contains("moonrcinspect.path-matrix.v1"))
}
