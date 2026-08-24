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
