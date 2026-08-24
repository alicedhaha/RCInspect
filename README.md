# MoonRCInspect

[![CI](https://github.com/alicedhaha/RCInspect/actions/workflows/ci.yml/badge.svg)](https://github.com/alicedhaha/RCInspect/actions/workflows/ci.yml)

项目链接：[GitHub](https://github.com/alicedhaha/RCInspect) · [GitLink](https://gitlink.org.cn/alicedhh/RCInspect) · [Mooncakes](https://mooncakes.io/docs/alicedhaha/moonrcinspect) · [项目申报书](项目申报书.md)

MoonRCInspect 是一个使用 MoonBit 原生实现的 SPEF（Standard Parasitic Exchange
Format）寄生 RC 网络解析、分析、审计与可视化工具。它面向布局布线后的寄生参数检查、
EDA 数据流水线、教学和轻量级自动化，不只是一个文本解析 Demo。

项目把 SPEF 文本转换为带物理单位和拓扑语义的 RC 模型，并提供网络统计、连通性检查、
孤立节点/环检测、Elmore delay、数据质量规则、Graphviz DOT、JSON 和命令行工作流。

## 为什么做这个项目

商业 EDA 工具和现有 C/C++ 工具链通常可以读取 SPEF，但 MoonBit 生态此前缺少针对物理
设计寄生网络的原生基础组件。MoonRCInspect 探索 MoonBit 在以下工程场景中的适用性：

- 芯片互连寄生参数的可重复解析和归一化；
- 签核前 SPEF 数据质量预检查；
- RC 网络规模、拓扑和简单延迟指标分析；
- 面向 CI、Web 或后续 EDA 工具的机器可读数据交换。

公开检索到的相邻 MoonBit 项目主要覆盖 Verilog RTL、VCD、拥塞布线、通用电路求解和
Graphviz 布局。MoonRCInspect 聚焦 SPEF 与提取后寄生 RC 审计，不重复实现这些项目。

## 功能

- 带行列位置的逐字符 Lexer、状态化 Parser 和独立 AST；
- SPEF Header、单位、`*NAME_MAP`、`*PORTS`、`*D_NET`、`*CONN`、
  接地/耦合 `*CAP`、`*RES`、`*END`；
- 名称映射展开，以及电容、阻抗到 F/ohm 的 SI 归一化；
- 显式 `Design`、`RCNetwork`、`Net`、`Pin`、`Node`、`Resistor` 和
  `Capacitor` 公共数据模型；
- RC 邻接图、连通分量、孤立节点、环、最大度数和驱动节点分析；
- 网络/设计级 R、C、规模、均值、极值、电容偏差、异常网络与复杂度统计；
- 满足单驱动连通 RC 树前提时的 Elmore delay；
- 稳定规则 ID、严重度、源码位置和修复建议组成的数据审计报告；
- 确定性 JSON、Graphviz DOT、文本和 Markdown 输出；
- `parse`、`analyze`、`audit`、`visualize`、`report` CLI 子命令。

## 支持边界

当前版本面向 IEEE 1481-1998 中最常见的 distributed net 工作流。它有意不宣称完整
STA 或完整 IEEE SPEF 覆盖：

- 支持 `*D_NET`，暂不支持 reduced `*R_NET`；
- 支持电阻和电容，暂不分析电感段；
- 耦合电容在 Elmore 计算中按两端各 0.5 接地化；
- Elmore 只对单驱动、连通、无环电阻树给出数值；
- 环、多驱动、无驱动或断连网络返回明确状态，而不是伪造“精确”延迟。

详见 [SPEF 支持矩阵](docs/spef-support.md)。

## 架构

```text
SPEF text
  -> source-positioned lexer
  -> section-aware parser
  -> syntax AST
  -> name/unit model builder
  -> RCNetwork
       -> topology + RC + Elmore analysis
       -> rule-based audit
       -> JSON / DOT / Markdown
       -> moonrc CLI
```

主要包：

- `src/diagnostic`：源码位置、严重度和稳定诊断；
- `src/model`：物理单位、节点、连接、R/C 元件和设计模型；
- `src/parser`：Lexer、AST、Parser 和模型构建；
- `src/graph`：面向电阻拓扑的图算法；
- `src/analyzer`：统计、复杂度和 Elmore delay；
- `src/audit`：可组合审计规则；
- `src/visual`：JSON 与 DOT；
- `src/report`：文本、JSON 和 Markdown 报告；
- `src/cli`：纯命令配置与执行逻辑；
- `cmd/moonrc`：native IO 入口。

更详细的设计见 [架构文档](docs/architecture.md)。

## 环境与安装

需要近期 MoonBit 工具链和 native 后端。开发版本使用：

```text
moon 0.1.20260819
moonc v0.10.9
```

克隆后检查、测试和构建：

```bash
moon check --deny-warn
moon test --deny-warn
moon build cmd/moonrc --target native
```

开发时可直接运行：

```bash
moon run cmd/moonrc -- --help
```

项目只依赖官方 `moonbitlang/async` 来完成 native 文件 IO。解析、模型、图算法、分析、
审计和序列化逻辑均在本仓库中用 MoonBit 实现。

## 快速开始

分析示例：

```bash
moon run cmd/moonrc -- analyze examples/small.spef
```

典型输出：

```text
MoonRCInspect analysis
nets: 1
nodes: 4
resistors: 3
capacitors: 4
total resistance: 60 ohm
total capacitance: 4e-15 F
```

执行质量审计：

```bash
moon run cmd/moonrc -- audit examples/medium.spef
moon run cmd/moonrc -- audit examples/invalid.spef --strict
```

生成单个网络的 DOT：

```bash
moon run cmd/moonrc -- visualize examples/small.spef \
  --net clk --output clk.dot
dot -Tpng clk.dot -o clk.png
```

导出完整 JSON 或 Markdown 报告：

```bash
moon run cmd/moonrc -- parse examples/small.spef -o small.json
moon run cmd/moonrc -- report examples/small.spef -o report.md
```

## CLI

```text
moonrc parse <file.spef> [--format json] [-o FILE]
moonrc analyze <file.spef> [--format text|json] [-o FILE]
moonrc audit <file.spef> [--strict] [--format text|json] [-o FILE]
moonrc visualize <file.spef> [--net NAME] [--format dot|json] [-o FILE]
moonrc report <file.spef> [--format markdown|json] [-o FILE]
```

`audit --strict` 会把所有 warning 提升为 error，适合 CI 门禁。JSON schema 使用带版本的
标识，例如 `moonrcinspect.network.v1` 和 `moonrcinspect.audit.v1`。

## 审计规则示例

- `SPEF-A001`：缺少 `*SPEF`；
- `SPEF-A100`：网络没有连接声明；
- `SPEF-A103` / `SPEF-A104`：R/C 元件引用不存在节点；
- `SPEF-A201` / `SPEF-A202`：负值或非有限 R/C 参数；
- `SPEF-A205`：声明电容和 `*CAP` 明细和偏差过大；
- `SPEF-A300`：电阻网络断连；
- `SPEF-A301`：孤立节点；
- `SPEF-A302`：电阻环；
- `SPEF-A303` / `SPEF-A304`：无驱动或多驱动；
- `SPEF-A400`：网络复杂度超过阈值。

## 测试

```bash
moon test
moon test --deny-warn
```

测试覆盖模型单位、Lexer、Parser、错误恢复、Name Map、拓扑、Elmore、审计规则、
空网络、悬空 R/C 节点、JSON/DOT/Markdown、CLI 参数和完整多网络工作流。样例包括：

- `examples/small.spef`：单个分支 RC 树；
- `examples/medium.spef`：三个网络与耦合电容；
- `examples/invalid.spef`：缺失头部/结尾、重复 ID 和负参数。

全部样例由本项目原创编写，不包含商业 EDA 输出或受限设计数据。

## 技术亮点

- Parser 与模型分离，语法问题不会破坏已成功解析的部分数据；
- 所有 R/C 值先归一化到 SI，避免跨文件单位误判；
- Elmore 前置条件显式建模，错误拓扑不会静默产生数值；
- 审计问题有稳定 ID 和修复建议，可用于 CI 与后续 SARIF 适配；
- 输出顺序确定，便于快照、版本对比和可重复构建；
- 核心 API 是纯函数，native IO 只存在于极薄的 executable 包。

## 路线图

- `*R_NET` 和更多 IEEE 1481 可选段；
- 大文件流式 Lexer/Parser 与内存上限；
- 耦合电容策略配置和跨网络索引；
- RC tree reduction、路径查询和更丰富的延迟统计；
- SARIF、CSV 和 HTML 报告；
- 与 Verilog 网表、布局坐标和时序约束的交叉检查；
- 性能基准和真实但可再分发的公开 SPEF corpus。

## 开源与来源

本项目为原创 MoonBit 实现，未移植 OpenTimer 或商业 EDA 代码。公开资料只用于理解
SPEF 结构和验证术语，详见 [来源与合规说明](docs/sources.md)。

许可证：[MIT](LICENSE)。欢迎阅读 [贡献指南](CONTRIBUTING.md) 后提交问题和改进。
