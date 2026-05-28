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

- `Resources/data/debug/mvp_debug_starting_inventory.json`：调试开局库存。
- `Resources/data/units/mvp_unit_blueprints.json`：单位蓝图与基础机器人属性。

如果临时必须改脚本常量，也要在 `debug-balance-overrides.md` 记录，并在后续尽快迁移到外部配置。
