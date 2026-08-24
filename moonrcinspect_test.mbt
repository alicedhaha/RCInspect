///|
test "root facade supports parse analyze audit workflow" {
  let source =
    #|*SPEF "IEEE 1481-1998"
    #|*DESIGN "facade"
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
  let parsed = @moonrcinspect.parse(source)
  assert_eq(@moonrcinspect.analyze(parsed.network).net_count, 1)
  assert_true(@moonrcinspect.audit(parsed.network).passed)
  assert_eq(
    @moonrcinspect.elmore_delay(parsed.network.nets[0]).max_delay_seconds,
    0.0,
  )
}
