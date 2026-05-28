# Debug 数值覆盖登记

本文档专门记录为了调试效率而临时调整的数值。这里的数值不代表正式平衡，进入试玩平衡或正式数值设计前需要逐项复查。

维护规则：

- 只要因为调试目的修改数值，就必须在本文档新增或更新记录。
- 每条记录至少写明：日期、配置位置、修改前数值、修改后数值、调试目的、正式化前处理建议。
- 如果数值已经迁移到外部配置，记录配置文件路径；如果仍在脚本中，记录脚本路径并优先安排迁移。

## 当前调试覆盖

| 日期 | 数值项 | 配置位置 | 修改前 | 修改后 | 调试目的 | 正式化前处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-05-28 | 基础步枪机器人寿命 `lifespan_seconds` | `Resources/data/units/mvp_unit_blueprints.json` | `120.0s` | `20.0s` | 缩短等待时间，方便验证机器人死亡、锻造厂自动补位和复盘事件。 | 正式平衡前恢复或重新按战斗节奏设定。 |
| 2026-05-28 | MVP 开局调试库存：建设质料 | `Resources/data/debug/mvp_debug_starting_inventory.json` | `120` | `500` | 减少手动测试建造等待。 | 正式平衡前关闭 debug 配置或替换为正式开局配置。 |
| 2026-05-28 | MVP 开局调试库存：铁板 | `Resources/data/debug/mvp_debug_starting_inventory.json` | `20` | `500` | 减少手动测试加工等待。 | 正式平衡前关闭 debug 配置或替换为正式开局配置。 |
| 2026-05-28 | MVP 开局调试库存：铜线 | `Resources/data/debug/mvp_debug_starting_inventory.json` | `12` | `500` | 减少手动测试加工等待。 | 正式平衡前关闭 debug 配置或替换为正式开局配置。 |
| 2026-05-28 | MVP 开局调试库存：铁矿 | `Resources/data/debug/mvp_debug_starting_inventory.json` | `0` | `500` | 减少手动测试采矿等待。 | 正式平衡前关闭 debug 配置或替换为正式开局配置。 |
| 2026-05-28 | MVP 开局调试库存：铜矿 | `Resources/data/debug/mvp_debug_starting_inventory.json` | `0` | `500` | 减少手动测试采矿等待。 | 正式平衡前关闭 debug 配置或替换为正式开局配置。 |

## 已外部化的相关配置

- 单位蓝图与属性：`Resources/data/units/mvp_unit_blueprints.json`
- 调试开局库存：`Resources/data/debug/mvp_debug_starting_inventory.json`
