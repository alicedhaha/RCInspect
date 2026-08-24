// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "alicedhaha/moonrcinspect"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/alicedhaha/RCInspect"

license = "MIT"

keywords = [ "eda", "spef", "parasitics", "rc-network", "signal-integrity" ]

preferred_target = "native"

description = "MoonBit-native SPEF parasitic RC network parser, analyzer, auditor, and visualizer"

import {
  "moonbitlang/async@0.21.0",
}
