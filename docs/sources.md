# Sources and Compliance

MoonRCInspect is an original MoonBit implementation. No source code was copied or translated from
the projects below.

Public references used to understand terminology and practical SPEF structure:

- IEEE 1481-1998 SPEF format name and commonly documented section semantics;
- OpenTimer SPEF documentation:
  <https://github.com/OpenTimer/OpenTimer/blob/master/wiki/io/spef.md>;
- OpenTimer Parser-SPEF project for ecosystem comparison:
  <https://github.com/OpenTimer/Parser-SPEF> (MIT);
- General SPEF explanations linked from the project research notes.

The Lexer, AST, state machine, RC model, graph algorithms, Elmore implementation, audit rules,
serializers and CLI were designed and written specifically for this repository.

All files under `examples/` and all inline test fixtures are synthetic and authored for this
project. They do not contain proprietary net names, commercial tool output, foundry data or
third-party benchmark content.

The only package dependency is the official `moonbitlang/async` module, used for native file IO.
MoonRCInspect is distributed under the MIT License.
