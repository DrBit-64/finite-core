# llm-docs 目录说明

本文档目录分成两类：

| 目录 | 内容 |
| --- | --- |
| `design-docs/` | 玩法、系统、流程、敌人、生产、科技树、复盘等设计文档 |
| `mvp-dev-docs/` | MVP 开发范围、阶段开发任务、技术实现细节与工程拆分 |

重要索引：

- `mvp-dev-docs/project-memory.md`：项目长期记忆，记录已经验证过的工程经验、坑点和推荐实现方案。后续遇到类似问题时优先检索这里。
- `mvp-dev-docs/debug-balance-overrides.md`：调试数值覆盖登记，记录所有为了调试效率而临时修改的数值、修改前后值和正式化前处理建议。
- `mvp-dev-docs/post-mvp-development-roadmap.md`：MVP 完成后的开发路线与工程指导，按战役阶段拆分后续系统、验收标准和范围控制。
- `mvp-dev-docs/svg-art-direction-and-asset-guide.md`：基于现有 `Resources/art/` SVG 图标的美术规范、阶段视觉预算、生成模板和验收流程。
- `mvp-dev-docs/svg-art-asset-manifest.md`：完整战役 SVG 素材登记表，记录稳定 ID、建议路径、生成状态、优先级和候选设计。

建议后续新增文档时按用途放置：

- 如果文档回答“游戏应该是什么体验”，放入 `design-docs/`。
- 如果文档回答“下一步代码应该怎么实现”，放入 `mvp-dev-docs/`。
