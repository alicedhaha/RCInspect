# Changelog

All notable changes follow a simple versioned release log.

## 0.2.0 - 2026-08-24

- Added minimum-resistance and minimum-hop node path queries.
- Added all-pairs resistance matrices and electrical-diameter discovery.
- Added cross-network coupling-capacitance resolution, pair ranking and unresolved endpoint reporting.
- Added first-moment-preserving reduced RC models with sink and critical-path summaries.
- Added CSV output for analysis and new workflows, plus SARIF 2.1.0 audit output.
- Added `path`, `matrix`, `coupling` and `reduce` CLI subcommands.
- Expanded the public facade and increased the suite to 40 tests across all supported backends.

## 0.1.0 - 2026-08-24

- Added source-positioned SPEF Lexer, AST, stateful Parser and partial error recovery.
- Added Name Map expansion and SI-normalized RC network model.
- Added resistance topology, connectivity, isolated-node, cycle and driver analysis.
- Added design/network R/C statistics and complexity ranking.
- Added precondition-checked Elmore delay with documented coupling policy.
- Added composable data-quality audit rules with strict mode.
- Added deterministic network/analysis/audit JSON, Graphviz DOT and Markdown reports.
- Added native `moonrc` CLI with five subcommands.
- Added synthetic small, medium and invalid fixtures plus unit and integration tests.
