这份文档是专门为你与 GitHub Copilot（或任何代码辅助 AI）结对编程设计的。

为了最大化 Copilot 的上下文理解能力，我将第二阶段（核心战斗MVP与逻辑UI）拆解为了 **6 个标准化的开发任务（Task）**。

**💡 如何使用这份文档：**
每次开发一个新模块时，你可以直接复制对应的 **[Task X]** 的全部文本作为 Prompt 发给 Copilot，并在末尾加上你自己的具体要求（例如：“请帮我生成这个 `ai_rule.gd` 的完整代码”）。

---

### 第二阶段开发管线：核心战斗 MVP 与逻辑 UI

#### [Task 1] 定义核心数据结构：AI 规则资源 (Custom Resource)
**目标：** 创建用于在 UI 和 机器人实体 之间传递数据的标准化数据结构。
**Godot 节点/文件：** 创建纯脚本 `ai_rule.gd`。
**Copilot 开发指南：**
1. 脚本需继承自 `Resource` 并声明 `class_name AIRule`。
2. 定义四个核心元素：
   * `enum Subject`: 包含 `SELF` (自身), `TARGET_NEAREST` (最近敌人), `TARGET_LOWEST_HP` (最低血量敌人)。
   * `enum Condition`: 包含 `DISTANCE_LESS` (距离小于), `HP_LESS_PERCENT` (血量低于%), `HAS_TAG` (包含标签)。
   * `enum Action`: 包含 `APPROACH` (靠近), `FLEE` (逃跑), `FIRE_MAIN` (主武器开火), `STOP_ACTION` (停止动作)。
3. 使用 `@export` 暴露以下变量：`subject` (Subject), `condition` (Condition), `condition_param` (String/float，用于存储具体数值或标签字符串), `action` (Action)。

#### [Task 2] 构建逻辑配置 UI 面板 (Logic UI Panel)
**目标：** 实现一个下拉菜单式的“四段式填空” UI，并将用户的选择导出为 `Array[AIRule]`。
**Godot 节点/文件：** 创建场景 `rule_row_ui.tscn` 和 `logic_board_ui.tscn`。
**Copilot 开发指南：**
1. **单行规则 (RuleRowUI):** 根节点使用 `HBoxContainer`。添加 4 个 `OptionButton` 子节点（分别对应 Subject, Condition, Param, Action）。编写脚本，根据 `ai_rule.gd` 的枚举初始化下拉菜单项。
2. **UI 联动逻辑:** 在 RuleRowUI 中编写 `_on_subject_item_selected(index)` 信号回调，例如：当选择 `SELF` 时，禁用或隐藏与敌人相关的 Condition 选项。
3. **主面板 (LogicBoardUI):** 根节点使用 `VBoxContainer`。提供“添加新规则”按钮，动态实例化 `rule_row_ui`。提供一个 `export_rules() -> Array[AIRule]` 函数，遍历所有行并生成真实数据。

#### [Task 3] 建立全局对象池 (Global Object Pool)
**目标：** 避免频繁实例化带来的性能卡顿，为子弹和机器人提供复用池。
**Godot 节点/文件：** 创建脚本 `object_pool.gd`，并在项目设置中注册为 AutoLoad 单例。
**Copilot 开发指南：**
1. 内部维护一个字典 `var _pools: Dictionary = {}`，键为 String (池名称)，值为 `Array[Node]`。
2. 实现 `get_instance(scene: PackedScene, parent: Node, pool_name: String) -> Node` 方法。如果池为空则实例化；如果不为空则 `pop_back()`，并调用该节点的 `show()` 和设置 `process_mode`。
3. 实现 `return_instance(instance: Node, pool_name: String)` 方法。调用节点的 `hide()`，禁用物理/Process，并 `append` 回数组。

#### [Task 4] 机器人控制器：大脑 (AI Controller)
**目标：** 解析 `Array[AIRule]`，并在每个逻辑帧向机器人躯体发送动作指令。
**Godot 节点/文件：** 创建场景 `ai_controller.tscn` (根节点 Node)。
**Copilot 开发指南：**
1. 包含变量 `@export var rules: Array[AIRule]` 和对象引用 `@onready var body = get_parent()`。
2. 添加 `Timer` 子节点（命名为 `TickTimer`，如 0.2s 触发一次）。
3. 在 `timeout` 回调中编写 `evaluate_rules()` 函数：按索引顺序遍历 `rules`。
4. 编写 `check_condition(rule)`：利用 `body.get_radar_targets()` 获取周围敌人，并根据规则筛选（如：检查对象的 Node Group 标签，或计算 Distance）。
5. 一旦某条 Rule 的条件返回 `true`，立刻调用 `execute_action(rule)` 并 `return` 跳出循环。

#### [Task 5] 机器人躯干：物理与执行层 (Robot Actor)
**目标：** 响应大动作指令，处理移动、索敌和受击逻辑。
**Godot 节点/文件：** 创建场景 `robot.tscn` (根节点 `CharacterBody2D`)。
**Copilot 开发指南：**
1. **子节点结构：** 包含 `Sprite2D` (底盘)、`Area2D` (命名为 Radar，用于索敌)、`Marker2D` (武器挂载点)。
2. **基础属性：** 定义 `hp`, `max_hp`, `speed`, `team_id`。并在 `_ready()` 中使用 `add_to_group()` 为自身添加阵营标签（如 "team_a"）。
3. **接口提供：** 实现供 AI Controller 调用的具体动作函数：`move_towards(target_pos)`, `flee_from(target_pos)`, `fire_weapon(target)`。
4. **雷达逻辑：** 连接 Radar 的 `body_entered` 信号，维护一个当前视野内的 `enemies_in_range: Array[Node2D]` 列表，供大脑查询。

#### [Task 6] 战斗表现与生命周期闭环 (Combat & Lifecycle)
**目标：** 实现武器开火、极简 VFX、伤害计算以及死亡回收。
**Godot 节点/文件：** 创建场景 `bullet.tscn` (根节点 `Area2D`)。
**Copilot 开发指南：**
1. **子弹逻辑：** 使用亮黄色/品红色的纯色 `ColorRect` 作为视觉。实现直线匀速移动。连接 `body_entered`，检测到拥有敌对方 group 标签的 body 时，调用其 `take_damage(amount)`，随后调用 `ObjectPool.return_instance()` 回收自己。
2. **生命周期限制：** 在 `robot.tscn` 中添加 `LifespanTimer`。超时后，触发自身的 `die()` 函数（可生成简单的 `GPUParticles2D` 爆炸特效），并回收躯体。
3. **状态重置：** 在 `robot.gd` 中实现 `reset_state()` 函数。这是对象池模式的关键，确保从池中拿出的机器人，其 HP、视野列表、位置等被彻底清空归零。

---

**给你的下一步建议：**
准备开始编码时，直接复制 **[Task 1]** 给 Copilot。Task 1 的数据结构是一切的基础，只要 `AIRule` 定义清晰，后续的 UI 导出和大脑解析都会水到渠成。遇到 Copilot 给出旧版 Godot 3 语法（如 `export` 而不是 `@export`）时，及时纠正它即可。