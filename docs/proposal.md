# MoonRCInspect 项目申报书
- GitHub：https://github.com/alicedhaha/RCInspect
- Gitlink：https://gitlink.org.cn/alicedhh/RCInspect
- 项目方向：MoonBit 原生 EDA 数据工具 / SPEF 寄生 RC 基础设施
- 项目性质：原创实现；未移植既有 MoonBit 或其他语言项目

MoonRCInspect 面向芯片布局布线后的 SPEF 数据，提供解析、RC 网络建模、拓扑与参数分析、
Elmore delay、路径/耦合/降阶分析、数据质量审计和多格式 CLI。它解决 MoonBit 生态缺少物理设计
寄生参数工具的问题，并为 CI、教学和后续时序/信号完整性工具提供可复用模型。

核心交付包括：带源码位置的 Lexer/Parser/AST；单位归一化 RC 模型；连通性、孤立点、
环和复杂度分析；条件明确的 Elmore 估算；带稳定规则 ID 和修复建议的审计；九个 CLI
子命令；原创 SPEF 样例、单元/集成/异常测试、CI、架构和合规文档。

实现分为模型、解析、拓扑、分析、审计、导出/CLI、工程交付七阶段。核心逻辑全部使用
MoonBit，官方 async 包仅负责 native 文件 IO。首版聚焦 IEEE 1481-1998 常见 `*D_NET`
工作流，明确不宣称完整 STA、`*R_NET` 或电感分析。

预期成果是可发布到 mooncakes.io、可在 GitHub/Gitlink 复现、具备真实工程边界的
MoonBit EDA 基础工具，而非简单格式 Parser。
