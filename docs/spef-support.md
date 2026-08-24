# SPEF Support Matrix

## Supported

- Common IEEE 1481-1998 header fields: `*SPEF`, `*DESIGN`, `*DATE`, `*VENDOR`,
  `*PROGRAM`, `*VERSION`, `*DESIGN_FLOW`;
- Name syntax controls: `*DIVIDER`, `*DELIMITER`, `*BUS_DELIMITER`;
- `*T_UNIT`, `*C_UNIT`, `*R_UNIT`, `*L_UNIT` parsing and SI normalization;
- `*NAME_MAP` and references with internal-node suffixes;
- `*PORTS` with direction and optional coordinates;
- Distributed networks using `*D_NET`;
- `*CONN` entries `*P` and `*I`, directions `I`, `O`, `B`, plus common `*C`,
  `*L` and `*D` attributes;
- Ground and coupling entries in `*CAP`;
- Two-terminal entries in `*RES`;
- `*END`, blank lines, quoted values, escaped quotes and `//` comments;
- Partial AST/model plus source-positioned diagnostics for recoverable malformed input.

## Explicitly unsupported in 0.1

- Reduced networks (`*R_NET`);
- Power/ground net sections as first-class electrical models;
- Inductance element sections and mutual inductance;
- Variation tuples, triplets and advanced corner-specific syntax;
- Streaming input and compressed files;
- Full static timing analysis, crosstalk switching-window analysis or SPICE simulation.

Unknown top-level headers are preserved in the AST. Unsupported structural sections should be
treated as diagnostics rather than silently interpreted.

## Numerical policy

Internal resistance is ohm and capacitance is farad. Reports include explicit unit suffixes.
Floating-point comparisons in tests and capacitance reconciliation use tolerances; exact textual
round-tripping is not a goal.
