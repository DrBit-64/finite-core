# Debug 数值覆盖登记

本文档专门记录为了调试效率而临时调整的数值。这里的数值不代表正式平衡，进入试玩平衡或正式数值设计前需要逐项复查。

维护规则：

- 只要因为调试目的修改数值，就必须在本文档新增或更新记录。
- 每条记录至少写明：日期、配置位置、修改前数值、修改后数值、调试目的、正式化前处理建议。
- 如果数值已经迁移到外部配置，记录配置文件路径；如果仍在脚本中，记录脚本路径并优先安排迁移。

## 当前调试覆盖

| 日期 | 数值项 | 配置位置 | 修改前 | 修改后 | 调试目的 | 正式化前处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 暂无 | - | - | - | - | - | - |

## 已外部化的相关配置

- 单位蓝图与属性：`Resources/data/units/mvp_unit_blueprints.json`
- 正式开局库存：`Resources/data/balance/mvp_starting_inventory.json`
- 调试开局库存：`Resources/data/debug/mvp_debug_starting_inventory.json`

## 已撤销的调试覆盖

| 日期 | 数值项 | 配置位置 | 临时数值 | 恢复值 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 2026-06-05 | MVP 开局调试库存：建设质料 | `Scripts/mvp/mvp_game_manager.gd` 默认改读 `Resources/data/balance/mvp_starting_inventory.json` | `500` | `120` | 已恢复非 debug 开局库存；debug 配置文件保留但不再作为默认读取路径。 |
| 2026-06-05 | MVP 开局调试库存：铁板 | `Scripts/mvp/mvp_game_manager.gd` 默认改读 `Resources/data/balance/mvp_starting_inventory.json` | `500` | `20` | 已恢复非 debug 开局库存；debug 配置文件保留但不再作为默认读取路径。 |
| 2026-06-05 | MVP 开局调试库存：铜线 | `Scripts/mvp/mvp_game_manager.gd` 默认改读 `Resources/data/balance/mvp_starting_inventory.json` | `500` | `12` | 已恢复非 debug 开局库存；debug 配置文件保留但不再作为默认读取路径。 |
| 2026-06-05 | MVP 开局调试库存：铁矿 | `Scripts/mvp/mvp_game_manager.gd` 默认改读 `Resources/data/balance/mvp_starting_inventory.json` | `500` | `0` | 已恢复非 debug 开局库存；debug 配置文件保留但不再作为默认读取路径。 |
| 2026-06-05 | MVP 开局调试库存：铜矿 | `Scripts/mvp/mvp_game_manager.gd` 默认改读 `Resources/data/balance/mvp_starting_inventory.json` | `500` | `0` | 已恢复非 debug 开局库存；debug 配置文件保留但不再作为默认读取路径。 |
| 2026-06-01 | 基础步枪机器人寿命 `lifespan_seconds` | `Resources/data/units/mvp_unit_blueprints.json` | `20.0s` | `120.0s` | 已恢复 MVP 原始设计值；不再为了快速观察补位而缩短玩家机器人寿命。 |
