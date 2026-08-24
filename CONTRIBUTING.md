# Contributing

Thanks for improving MoonRCInspect.

## Development

1. Use a recent MoonBit toolchain.
2. Keep parsing, electrical semantics, analysis and presentation in separate packages.
3. Add focused tests for every behavior change.
4. Run:

```bash
moon fmt
moon info
moon check --deny-warn
moon test --deny-warn
moon build cmd/moonrc --target native
```

## SPEF fixtures

Do not commit proprietary chip data, commercial-tool output without redistribution permission,
foundry information or private netlists. Prefer small synthetic fixtures. If a public third-party
fixture is necessary, document its URL, exact license and modification scope in `docs/sources.md`.

## Diagnostics

Parser and audit diagnostics are public contracts. New diagnostics need a stable `SPEF-Pxxx` or
`SPEF-Axxx` code, severity, actionable message, source span when available and repair suggestion.
Avoid silently accepting unsupported structural syntax.

## Pull requests

Keep changes focused and describe the user-visible reason. Include test commands and output format
compatibility notes. Changes to JSON fields or Elmore policy require documentation and a schema
version decision.
