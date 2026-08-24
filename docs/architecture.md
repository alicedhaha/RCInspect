# Architecture

MoonRCInspect separates syntax fidelity, electrical semantics and presentation so each layer can
be reused independently.

## Parse pipeline

1. `src/parser/lexer.mbt` scans characters, quoted strings, escapes and comments. Every token owns
   a one-based line/column span.
2. `src/parser/parser.mbt` uses explicit SPEF section states. It emits diagnostics and a partial AST
   instead of stopping at the first recoverable error.
3. The model builder expands Name Map references, interns stable node IDs and converts declared
   units to F, ohm, s and H.
4. `src/model` stores the normalized design. Original spans remain attached to declarations and
   elements for audit output.

## RC graph semantics

Resistance elements form an undirected adjacency list. Ground capacitors attach to one local node;
coupling capacitors preserve the second endpoint as an external reference. External coupling-only
nodes are excluded from resistance connectivity and Elmore tree preconditions.

Topology analysis is linear in local nodes plus resistance edges. It computes components, isolated
nodes, cycles, maximum degree and output-direction drivers.

## Elmore model

Elmore delay is produced only for a connected, acyclic, single-driver resistance tree. Ground
capacitance is attached in full. Coupling capacitance is split equally between endpoints; an
endpoint outside the current net contributes only the local half. Pin `*L` load is included in
delay but not in SPEF parasitic-capacitance reconciliation.

For tree edge `e`, the downstream capacitance is accumulated in reverse BFS order. Node delay is:

```text
delay(child) = delay(parent) + R(e) * C_downstream(e)
```

## Audit architecture

`src/audit` exposes a list of `AuditRule` values and a rule runner. Each finding has a stable code,
severity, optional source span, optional network name, message and repair suggestion. Strict mode
promotes warnings after all rules run, keeping rule behavior deterministic.

## Boundary design

The root package offers parse, analyze, audit and Elmore facade functions. Package-level APIs are
available for advanced consumers. `src/cli` is pure and testable; only `cmd/moonrc` imports async
filesystem and stdio packages.
