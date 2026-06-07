# Project Memory

本文件记录项目开发中已经验证过的工程经验、坑点和推荐方案。后续遇到相似问题时，优先检索本文件，再决定是否重新设计实现。

## UI 弹出面板尺寸自适应

**记录时间**：2026-05-27  
**适用范围**：建筑费用提示、建筑操作面板、状态浮窗、右键菜单、配方选择浮窗等由内容驱动尺寸的临时 UI。

### 背景

在 MVP 阶段 3 的建筑放置费用提示和加工厂操作面板中，连续出现过两类问题：

- 面板越点越长，或第一次打开就出现大量无意义空白。
- 手动计算面板高度后，最后一行文字溢出到面板外。

这些问题的共同原因是：弹出面板尺寸由内容决定，但实现时混用了手动估算尺寸、容器自动布局和旧的 `custom_minimum_size` / `size` 状态。

### 推荐结构

内容自适应弹窗优先使用 Godot 容器布局，而不是手动估算字体高度：

```text
PanelContainer
└── MarginContainer
    └── VBoxContainer / HBoxContainer
        ├── Label
        ├── Button / HBoxContainer
        ├── ProgressBar
        └── Label
```

推荐流程：

1. 创建 `PanelContainer`，添加 `StyleBoxFlat`。
2. 内部添加 `MarginContainer`，用 margin 控制边距。
3. 内容放进 `VBoxContainer` 或组合容器。
4. 重建内容前，删除并 `queue_free()` 旧子节点。
5. 重建内容时先把面板 `size = Vector2.ZERO`。
6. 添加完所有内容后，调用：

```gdscript
panel.size = panel.get_combined_minimum_size()
```

7. 定位时也使用：

```gdscript
var panel_size := panel.get_combined_minimum_size()
```

### 不推荐做法

除非弹窗是完全自绘 UI，否则不要用以下方式处理内容自适应面板：

- 不要用普通 `Panel` 加手动 `size` 估算来包裹文本、按钮和进度条。
- 不要用字符串长度乘固定像素宽度估算真实 UI 尺寸。
- 不要手动猜 `Label`、`Button`、`ProgressBar` 的高度。
- 不要在没有固定宽度约束时开启 `Label` 自动换行，否则 `get_combined_minimum_size()` 可能不稳定。
- 不要只隐藏面板但持续追加子节点；这会造成尺寸和内容状态积累。

### 交互规则

- 纯展示提示，例如建筑材料费用提示：
  - `PanelContainer.mouse_filter = Control.MOUSE_FILTER_IGNORE`
  - 子节点也尽量 `MOUSE_FILTER_IGNORE`
- 可点击操作面板，例如加工厂配方选择：
  - `PanelContainer.mouse_filter = Control.MOUSE_FILTER_STOP`
  - 只有 `Label` 等非交互子节点设为 `MOUSE_FILTER_IGNORE`
  - `Button` 保持默认可交互状态

### 当前项目参考

当前可参考实现位于：

- `Scripts/ui/hud.gd` 的建筑费用提示：
  - `_ensure_cost_panel()`
  - `_rebuild_cost_panel()`
  - `_position_cost_panel()`
- `Scripts/ui/hud.gd` 的加工厂操作面板：
  - `_recreate_operation_panel()`
  - `_rebuild_processor_panel()`
  - `_position_operation_panel()`

后续新增类似弹窗时，优先复用这一结构，而不是重新手写尺寸计算。

## Debug 数值覆盖登记

**记录时间**：2026-05-28
**适用范围**：任何为了减少等待、方便验证、制造极端场景或辅助手动测试而做的数值修改。

### 长期规则

后续每次因为调试目的修改数值，都必须同步更新：

- `llm-docs/mvp-dev-docs/debug-balance-overrides.md`

登记时至少写明：

- 修改日期。
- 数值项名称。
- 配置或脚本位置。
- 修改前数值。
- 修改后数值。
- 调试目的。
- 正式化前处理建议。

### 工程建议

调试数值优先放在外部配置中，不要散落在生产逻辑里。当前可参考：

- `Resources/data/debug/mvp_runtime_profile.json`：当前运行时库存切换入口，`use_debug_starting_inventory` 决定读取正式库存或 debug 库存。
- `Resources/data/balance/mvp_starting_inventory.json`：非 debug 开局库存。
- `Resources/data/debug/mvp_debug_starting_inventory.json`：调试开局库存，仅在需要快速测试生产链时临时启用。
- `Resources/data/units/mvp_unit_blueprints.json`：单位蓝图与基础机器人属性。

如果临时必须改脚本常量，也要在 `debug-balance-overrides.md` 记录，并在后续尽快迁移到外部配置。

## Godot `--script` Smoke Test 原生崩溃

**记录时间**：2026-05-31
**适用范围**：本项目的自动化验证、headless 测试脚本、阶段验收流程。

### 背景

本项目多次遇到以下问题：

- 使用 Godot console 执行 `--headless --script res://Tests/...gd` smoke test 时，Godot 可能直接发生原生 `signal 11` 崩溃。
- 崩溃发生在引擎层，不一定产生可定位的 GDScript 报错。
- 此前窗口缩放也曾触发 Godot 高内存占用与系统级异常，因此调试阶段应优先降低引擎崩溃风险。

### 长期规则

后续默认**不要主动运行** Godot `--script` smoke test，包括新建的 `Tests/*_smoke.gd`。

默认自动化验证方式：

1. JSON 使用 PowerShell `ConvertFrom-Json` 校验。
2. SVG 使用 XML 解析校验。
3. GDScript 与场景使用稳定的场景加载命令校验：

```powershell
& 'D:\Godot\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe' `
  --headless --path 'D:\Godot\finite-core' `
  res://Scenes/mvp/mvp_test_map.tscn --quit
```

4. 需要真实交互、战斗流程或长时间运行时，给出 F5 手工验收清单，由用户在编辑器内验证。

项目内提供稳定启动检查入口：

```powershell
.\Tools\check_mvp_startup.cmd
```

该工具启动真实 MVP 场景数秒，将日志写入 `debug_exports/logs/mvp_startup.log`，并在发现 `ERROR`、`WARNING`、`Invalid call`、失效 UID、资源缺失或崩溃特征时返回失败。使用 `.cmd` 入口可以避开本机 PowerShell 脚本执行策略限制。

阶段 7 的守军生命周期另有场景式回归检查：

```powershell
.\Tools\check_stage7_guard_lifecycle.cmd
```

它加载普通场景而非使用 `--script`，验证地图全局阵营目标列表、普通单位短时目标锁定、远距离敌巢可被玩家索敌、远距离玩家不会触发守军、守军锁定后离圈追杀、目标死亡后近距离续接、守军死亡注销和补员倒计时。

## 索敌结构约束

- 地图使用 `CombatTargetRegistry` 维护按阵营划分的全图 `combat_target` 列表，单位和建筑在启用、死亡或回收时注册或注销。
- 通用单位使用 `UnitEnemySensor` 查询地图注册表中的全图敌方目标，不依赖局部感知半径或摄像机可见区域。
- 普通单位使用短时间目标锁定，减少多个候选目标变化造成的频繁切换。
- 拾荒猎犬使用独立的 `ScavengerHoundSensor`：首次接敌受敌巢警戒半径限制；锁定后持续追杀；目标死亡后先从自身附近尝试续接目标。
- 敌巢警戒等敌军特例不要塞回通用机器人传感器。

### 例外

只有满足以下条件时才运行 `--script` smoke test：

- 用户明确要求尝试脚本级 smoke test。
- 已先说明本项目存在原生崩溃历史。
- 测试范围足够小，并且没有更稳定的替代验证方式。

如果一次 `--script` 测试出现原生崩溃，立即停止重复执行，改用稳定验证路径。

## 规则求值与事件记账

- `AIController` 按 `0.2s` 节拍求值规则，不应跟随物理帧率每帧完整求值。
- `rule_triggered` 表示机器人进入一条不同的匹配规则。持续执行同一条规则时，不重复增加触发次数。
- 调试事件面板应合并同一帧内的刷新请求，避免事件集中出现时反复销毁和重建 UI 行。
- 集结人数查询通过地图注册表共享短缓存，避免多个机器人抵达同一集结点时重复扫描全部单位。

规则触发节拍与记账语义可通过以下稳定场景检查验证：

```powershell
.\Tools\check_rally_rule_activation.cmd
```

## 物理回调中的建筑销毁

- 子弹的 `body_entered` 会发生在物理查询刷新期间。
- 建筑死亡回调中不要立即重建 `CollisionShape2D.shape`，也不要立即修改碰撞层或禁用状态。
- 建筑部署时才更新碰撞几何；死亡时只更新视觉，并通过 `set_deferred()` 延迟关闭碰撞。

可通过以下稳定场景检查验证：

```powershell
.\Tools\check_building_projectile_destruction.cmd
```
