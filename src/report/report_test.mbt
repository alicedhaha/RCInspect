///|
let report_spef =
  #|*SPEF "IEEE 1481-1998"
  #|*DESIGN "report"
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
test "reports include analysis, audit, and delay status" {
  let network = @parser.parse(report_spef).network
  let metrics = @analyzer.analyze(network)
  let audit_report = @audit.audit(network)
  let markdown = @report.markdown_report(network, metrics, audit_report)
  assert_true(markdown.contains("# MoonRCInspect Report"))
  assert_true(markdown.contains("Elmore status"))
  assert_true(@report.metrics_to_json(metrics).contains("\"net_count\":1"))
  assert_true(@report.audit_to_json(audit_report).contains("\"passed\":true"))
}
