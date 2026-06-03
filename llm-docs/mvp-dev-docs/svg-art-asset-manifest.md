# Logic Line SVG 美术资产 Manifest

本文档是 SVG 美术素材的全量登记表，用于一次性规划完整战役需要的图标，并按开发阶段接入正式素材。

视觉规则、色板、尺寸原则和 AI 提示模板见 [svg-art-direction-and-asset-guide.md](svg-art-direction-and-asset-guide.md)。

---

## 一、使用规则

### 1. 状态定义

| 状态 | 含义 |
| --- | --- |
| `existing` | 当前仓库已经存在 SVG 文件。 |
| `generate` | 设计已经明确，建议生成 SVG 占位图。 |
| `programmatic` | 优先由 Godot 绘制、调色或组合，不单独生成 SVG。 |
| `reuse` | 优先复用已有图标，通过 UI 容器、颜色或角标区分。 |
| `pending` | 设计或命名尚未收敛，暂不生成正式素材。 |

### 2. 优先级定义

| 优先级 | 含义 |
| --- | --- |
| `P0` | 当前 MVP 或下一轮开发直接需要。 |
| `P1` | 玩家阶段 2：晶体荒原需要。 |
| `P2` | 玩家阶段 3：干扰高地需要。 |
| `P3` | 玩家阶段 4：主脑核心区需要。 |
| `PX` | 候选设计，不进入正式批量生成。 |

### 3. 路径规则

| 目录 | 内容 |
| --- | --- |
| `Resources/art/resources/` | 原料、中间产物、敌方掉落物、残骸和可搬运物品。 |
| `Resources/art/buildings/` | 地图建筑。 |
| `Resources/art/chassis/` | 战斗和物流底盘。 |
| `Resources/art/modules/` | 武器、工具、护盾、逻辑板和功能模块。 |
| `Resources/art/blueprints/` | 玩家可生产的代表性机器人组合预览。 |
| `Resources/art/enemies/` | 敌人、敌巢、Boss 和敌方建筑。 |
| `Resources/art/units/` | 通用单位或开发期占位单位。 |
| `Resources/art/ui/` | UI 入口、分类、操作和状态图标。 |
| `Resources/art/map/` | 地图信号、标记和独立覆盖图标。 |
| `Resources/art/effects/` | 不能仅靠程序绘制表达的战斗反馈素材。 |

---

## 二、命名与设计待确认

以下问题不阻塞占位图规划，但在正式批量生成前应统一。

| 问题 | 当前文档中的表达 | 建议暂定方案 |
| --- | --- | --- |
| 齿轮名称 | `基础齿轮`、`简易齿轮` | 稳定 ID 使用 `simple_gear`，显示名暂定“简易齿轮”。 |
| 高阶芯片名称 | `集成处理器`、`集成芯片` | 稳定 ID 使用 `integrated_processor`，显示名暂定“集成芯片”。 |
| 中期激光名称 | `热能激光`、`热熔激光`、`热熔激光束` | 稳定 ID 使用 `thermal_laser`，显示名暂定“热熔激光”。 |
| 集结设施名称 | `集结点`、`集结信标` | 建筑或可搬运物品使用 `rally_beacon`；地图标记使用 `rally_point_marker`。 |
| 前期生产建筑 | `基础冶炼炉`、`基础加工厂`、`部件装配机` | 当前 MVP 的 `processor` 继续保留；正式生产链确认后再决定是否拆分。 |
| 机器人生产建筑 | `机器人装配台`、`机器人锻造厂` | 统一稳定 ID 为 `robot_forge`，显示名使用“机器人锻造厂”。 |
| 阶段 4 研究设施 | `终局研究设施`、`主脑解析器` | 暂不合并，待确认胜利流程后决定。 |
| 传送带 | GDD 提到传送带，前 30 分钟流程建议暂缓 | 不进入当前正式生成清单，保留为候选系统。 |

---

## 三、当前已有 SVG

以下文件已经存在，应保持路径稳定。

| 稳定 ID | 显示名 | 文件路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `construction_mass` | 建设质料 | `Resources/art/resources/construction_mass.svg` | `32x32` | `existing` |
| `iron_ore` | 铁矿 | `Resources/art/resources/iron_ore.svg` | `32x32` | `existing` |
| `copper_ore` | 铜矿 | `Resources/art/resources/copper_ore.svg` | `32x32` | `existing` |
| `iron_plate` | 铁板 | `Resources/art/resources/iron_plate.svg` | `32x32` | `existing` |
| `copper_wire` | 铜线 | `Resources/art/resources/copper_wire.svg` | `32x32` | `existing` |
| `main_base` | 主基地 | `Resources/art/buildings/main_base.svg` | `64x64` | `existing` |
| `miner` | 采矿机 | `Resources/art/buildings/miner.svg` | `48x48` | `existing` |
| `processor` | 基础加工厂 | `Resources/art/buildings/processor.svg` | `48x48` | `existing` |
| `robot_forge` | 机器人锻造厂 | `Resources/art/buildings/robot_forge.svg` | `48x48` | `existing` |
| `light_chassis` | 轻型底盘 | `Resources/art/chassis/light_chassis.svg` | `32x32` | `existing` |
| `rifle_module` | 基础步枪 | `Resources/art/modules/rifle_module.svg` | `32x32` | `existing` |
| `basic_rifle_robot` | 基础步枪机器人 | `Resources/art/blueprints/basic_rifle_robot.svg` | `32x32` | `existing` |
| `scavenger_hound` | 拾荒猎犬 | `Resources/art/enemies/scavenger_hound.svg` | `32x32` | `existing` |
| `enemy_nest` | 敌巢 | `Resources/art/enemies/enemy_nest.svg` | `96x96` | `existing` |
| `debug_enemy_unit` | 调试敌军 | `Resources/art/units/debug_enemy_unit.svg` | `48x48` | `existing` |

---

## 四、P0：当前 MVP 与起始盆地

### 1. 资源、中间产物与掉落物

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `simple_gear` | 简易齿轮 | `Resources/art/resources/simple_gear.svg` | `32x32` | `generate` | 前期加工和拾荒猎犬掉落。 |
| `basic_circuit` | 基础电路 | `Resources/art/resources/basic_circuit.svg` | `32x32` | `generate` | 阶段 1 科技依赖。 |
| `copper_coil` | 铜线圈 | `Resources/art/resources/copper_coil.svg` | `32x32` | `generate` | 集结信标和电气科技依赖。 |
| `basic_sensor` | 基础传感器 | `Resources/art/resources/basic_sensor.svg` | `32x32` | `generate` | 战斗报告科技依赖。 |
| `initial_sensor_coil` | 初级感应线圈 | `Resources/art/resources/initial_sensor_coil.svg` | `32x32` | `generate` | 第一阶段关键 Boss 掉落物。 |

### 2. 建筑与地图标记

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `basic_smelter` | 基础冶炼炉 | `Resources/art/buildings/basic_smelter.svg` | `48x48` | `pending` | 是否与当前 `processor` 拆分仍需确认。 |
| `component_assembler` | 部件装配机 | `Resources/art/buildings/component_assembler.svg` | `48x48` | `pending` | 是否由当前 `processor` 承担仍需确认。 |
| `small_depot` | 小型仓库 | `Resources/art/buildings/small_depot.svg` | `48x48` | `generate` | 阶段 1 生产缓冲。 |
| `research_terminal` | 研究终端 | `Resources/art/buildings/research_terminal.svg` | `48x48` | `generate` | 科技解锁入口。 |
| `rally_beacon` | 集结信标 | `Resources/art/buildings/rally_beacon.svg` | `48x48` | `generate` | 如果集结点采用建筑形式。 |
| `rally_point_marker` | 集结点标记 | `Resources/art/map/rally_point_marker.svg` | `32x32` | `generate` | 当前 MVP 地图交互直接需要。 |

### 3. 底盘、模块与蓝图

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `micro_hauler_chassis` | 微型搬运底盘 | `Resources/art/chassis/micro_hauler_chassis.svg` | `32x32` | `generate` | 前期默认物流单位。 |
| `basic_cargo_pack` | 基础背包模块 | `Resources/art/modules/basic_cargo_pack.svg` | `32x32` | `generate` | 前期物流模块。 |
| `kinetic_chainsaw` | 近战链锯 | `Resources/art/modules/kinetic_chainsaw.svg` | `32x32` | `generate` | 前期可选武器。 |
| `basic_logic_board` | 基础逻辑板 | `Resources/art/modules/basic_logic_board.svg` | `32x32` | `generate` | 第一条自定义规则入口。 |
| `micro_hauler_robot` | 搬运蜂 | `Resources/art/blueprints/micro_hauler_robot.svg` | `32x32` | `generate` | 默认物流机器人预览。 |
| `rally_rifle_robot` | 集结步枪兵 | `Resources/art/blueprints/basic_rifle_robot.svg` | `32x32` | `reuse` | 与基础步枪兵硬件相同，通过 UI 名称和规则摘要区分。 |

### 4. 敌人与阶段目标

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `nest_guardian` | 巢穴守卫者 | `Resources/art/enemies/nest_guardian.svg` | `48x48` | `generate` | 第一阶段低复杂度小 Boss。 |
| `stage1_nest` | 起始盆地敌巢 | `Resources/art/enemies/enemy_nest.svg` | `96x96` | `reuse` | 当前敌巢图标可继续使用。 |

### 5. UI 与状态

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `blueprint_menu` | 蓝图入口 | `Resources/art/ui/blueprint_menu.svg` | `24x24` | `generate` |
| `statistics_menu` | 统计入口 | `Resources/art/ui/statistics_menu.svg` | `24x24` | `generate` |
| `state_rally` | 集结 | `Resources/art/ui/state_rally.svg` | `20x20` | `generate` |
| `state_wait` | 等待 | `Resources/art/ui/state_wait.svg` | `20x20` | `generate` |
| `state_default_brain` | 默认脑干接管 | `Resources/art/ui/state_default_brain.svg` | `20x20` | `generate` |
| `technology_unlocked` | 科技解锁 | `Resources/art/ui/technology_unlocked.svg` | `20x20` | `generate` |
| `building_damaged` | 建筑受损 | `Resources/art/ui/building_damaged.svg` | `20x20` | `generate` |
| `emergency_shield` | 新手紧急护盾 | `Resources/art/ui/emergency_shield.svg` | `20x20` | `generate` |

### 6. 战斗反馈

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `kinetic_projectile` | 基础子弹 | `Resources/art/effects/kinetic_projectile.svg` | `8x8` | `generate` | 也可以后续改为程序绘制。 |
| `hit_flash` | 命中闪烁 | 无独立文件 | - | `programmatic` | 使用调色或短时叠层。 |
| `unit_death_fade` | 单位死亡淡出 | 无独立文件 | - | `programmatic` | 使用缩放、透明度和对象池。 |
| `building_wreck_tint` | 建筑残骸灰化 | 无独立文件 | - | `programmatic` | 使用原建筑图标调色。 |

---

## 五、P1：晶体荒原

### 1. 资源、中间产物与掉落物

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `crystal_ore` | 晶体矿 | `Resources/art/resources/crystal_ore.svg` | `32x32` | `generate` |
| `coal` | 原煤 | `Resources/art/resources/coal.svg` | `32x32` | `generate` |
| `water` | 水 | `Resources/art/resources/water.svg` | `32x32` | `generate` |
| `steel_billet` | 钢坯 | `Resources/art/resources/steel_billet.svg` | `32x32` | `pending` |
| `reinforced_steel_plate` | 强化钢板 | `Resources/art/resources/reinforced_steel_plate.svg` | `32x32` | `generate` |
| `optical_lens` | 光学透镜 | `Resources/art/resources/optical_lens.svg` | `32x32` | `generate` |
| `high_capacity_battery` | 大容量电池 | `Resources/art/resources/high_capacity_battery.svg` | `32x32` | `generate` |
| `cryo_gel` | 冷凝凝胶 | `Resources/art/resources/cryo_gel.svg` | `32x32` | `generate` |
| `kinetic_ammo_box` | 动能弹药箱 | `Resources/art/resources/kinetic_ammo_box.svg` | `32x32` | `generate` |
| `construction_pack` | 结构打印包 | `Resources/art/resources/construction_pack.svg` | `32x32` | `generate` |
| `high_frequency_oscillator` | 高频振荡器 | `Resources/art/resources/high_frequency_oscillator.svg` | `32x32` | `generate` |
| `energy_conduction_fluid` | 能量传导液 | `Resources/art/resources/energy_conduction_fluid.svg` | `32x32` | `generate` |
| `transmission_component` | 传动组件 | `Resources/art/resources/transmission_component.svg` | `32x32` | `pending` |
| `advanced_circuit` | 进阶电路 | `Resources/art/resources/advanced_circuit.svg` | `32x32` | `pending` |
| `light_weapon_component` | 轻型武器组件 | `Resources/art/resources/light_weapon_component.svg` | `32x32` | `pending` |
| `repair_material` | 维修材料 | `Resources/art/resources/repair_material.svg` | `32x32` | `generate` |

### 2. 建筑

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `advanced_smelter` | 强化冶炼炉 | `Resources/art/buildings/advanced_smelter.svg` | `48x48` | `generate` |
| `chemical_processor` | 化学精炼厂 | `Resources/art/buildings/chemical_processor.svg` | `48x48` | `generate` |
| `ammo_loader` | 弹药装填厂 | `Resources/art/buildings/ammo_loader.svg` | `48x48` | `generate` |
| `structure_printer` | 结构打印厂 | `Resources/art/buildings/structure_printer.svg` | `48x48` | `generate` |
| `forward_supply_point` | 前线补给点 | `Resources/art/buildings/forward_supply_point.svg` | `48x48` | `generate` |

### 3. 底盘、模块与蓝图

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `standard_cargo_chassis` | 标准货运底盘 | `Resources/art/chassis/standard_cargo_chassis.svg` | `32x32` | `generate` |
| `heavy_tracked_chassis` | 重型履带底盘 | `Resources/art/chassis/heavy_tracked_chassis.svg` | `32x32` | `generate` |
| `expanded_cargo_pack` | 扩展背包 | `Resources/art/modules/expanded_cargo_pack.svg` | `32x32` | `generate` |
| `light_shield_module` | 轻型护盾 | `Resources/art/modules/light_shield_module.svg` | `32x32` | `generate` |
| `light_self_defense_weapon` | 轻型自卫武器 | `Resources/art/modules/light_self_defense_weapon.svg` | `32x32` | `generate` |
| `heavy_machine_gun` | 重机枪 | `Resources/art/modules/heavy_machine_gun.svg` | `32x32` | `generate` |
| `thermal_laser` | 热熔激光 | `Resources/art/modules/thermal_laser.svg` | `32x32` | `generate` |
| `cryo_gel_sprayer` | 冷凝凝胶喷射器 | `Resources/art/modules/cryo_gel_sprayer.svg` | `32x32` | `generate` |
| `mid_logic_board` | 中级逻辑板 | `Resources/art/modules/mid_logic_board.svg` | `32x32` | `generate` |
| `zone_shield_guard` | 战区盾卫 | `Resources/art/blueprints/zone_shield_guard.svg` | `48x48` | `generate` |
| `battlefield_hauler` | 战地搬运车 | `Resources/art/blueprints/battlefield_hauler.svg` | `48x48` | `generate` |

### 4. 敌人与敌巢

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `armored_rhino` | 重甲犀牛 | `Resources/art/enemies/armored_rhino.svg` | `48x48` | `generate` |
| `plasma_mosquito` | 等离子飞蚊 | `Resources/art/enemies/plasma_mosquito.svg` | `32x32` | `generate` |
| `armored_nest` | 装甲型敌巢 | `Resources/art/enemies/armored_nest.svg` | `96x96` | `generate` |
| `energy_nest` | 能量型敌巢 | `Resources/art/enemies/energy_nest.svg` | `96x96` | `generate` |

### 5. UI、状态与战斗反馈

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `state_retreat` | 撤退 | `Resources/art/ui/state_retreat.svg` | `20x20` | `generate` |
| `state_transport` | 运输 | `Resources/art/ui/state_transport.svg` | `20x20` | `generate` |
| `state_shield` | 护盾 | `Resources/art/ui/state_shield.svg` | `20x20` | `generate` |
| `state_overheat` | 过热 | `Resources/art/ui/state_overheat.svg` | `20x20` | `generate` |
| `state_ammo_depleted` | 弹药不足 | `Resources/art/ui/state_ammo_depleted.svg` | `20x20` | `generate` |
| `laser_beam` | 激光束 | 无独立文件 | - | `programmatic` |
| `shield_arc` | 护盾弧 | 无独立文件 | - | `programmatic` |
| `heat_bar` | 热量条 | 无独立文件 | - | `programmatic` |

---

## 六、P2：干扰高地

### 1. 资源、中间产物、掉落物与残骸

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `silicon_ore` | 硅石 | `Resources/art/resources/silicon_ore.svg` | `32x32` | `generate` |
| `heavy_metal` | 重金属 | `Resources/art/resources/heavy_metal.svg` | `32x32` | `generate` |
| `silicon_wafer` | 高纯硅片 | `Resources/art/resources/silicon_wafer.svg` | `32x32` | `generate` |
| `integrated_processor` | 集成芯片 | `Resources/art/resources/integrated_processor.svg` | `32x32` | `generate` |
| `anti_gravity_coil` | 反重力线圈 | `Resources/art/resources/anti_gravity_coil.svg` | `32x32` | `generate` |
| `missile_assembly` | 导弹制导模组 | `Resources/art/resources/missile_assembly.svg` | `32x32` | `generate` |
| `quantum_processor` | 量子处理器 | `Resources/art/resources/quantum_processor.svg` | `32x32` | `generate` |
| `sensor_array` | 传感器阵列 | `Resources/art/resources/sensor_array.svg` | `32x32` | `pending` |
| `power_winch` | 动力绞盘 | `Resources/art/resources/power_winch.svg` | `32x32` | `pending` |
| `explosives` | 爆炸物 | `Resources/art/resources/explosives.svg` | `32x32` | `pending` |
| `wreckage_scrap` | 残骸碎片 | `Resources/art/resources/wreckage_scrap.svg` | `32x32` | `generate` |
| `heavy_wreckage` | 重型残骸 | `Resources/art/resources/heavy_wreckage.svg` | `48x48` | `generate` |
| `salvage_marker` | 回收标记 | `Resources/art/map/salvage_marker.svg` | `24x24` | `generate` |

### 2. 建筑

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `silicon_foundry` | 芯片净化炉 | `Resources/art/buildings/silicon_foundry.svg` | `48x48` | `generate` |
| `heavy_munitions_factory` | 重武器军工厂 | `Resources/art/buildings/heavy_munitions_factory.svg` | `48x48` | `generate` |
| `remote_drop_tower` | 远程投送塔 | `Resources/art/buildings/remote_drop_tower.svg` | `48x48` | `generate` |
| `radar_tower` | 雷达塔 | `Resources/art/buildings/radar_tower.svg` | `48x48` | `generate` |

### 3. 底盘、模块与蓝图

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `anti_gravity_hover_chassis` | 反重力悬浮底盘 | `Resources/art/chassis/anti_gravity_hover_chassis.svg` | `32x32` | `generate` |
| `armored_salvage_chassis` | 装甲回收底盘 | `Resources/art/chassis/armored_salvage_chassis.svg` | `32x32` | `generate` |
| `compressed_cargo_bay` | 压缩货舱 | `Resources/art/modules/compressed_cargo_bay.svg` | `32x32` | `generate` |
| `armored_cargo_shell` | 装甲货壳 | `Resources/art/modules/armored_cargo_shell.svg` | `32x32` | `generate` |
| `wreckage_tether` | 残骸牵引器 | `Resources/art/modules/wreckage_tether.svg` | `32x32` | `generate` |
| `salvage_scanner` | 回收扫描器 | `Resources/art/modules/salvage_scanner.svg` | `32x32` | `generate` |
| `emp_emitter` | EMP 发生器 | `Resources/art/modules/emp_emitter.svg` | `32x32` | `generate` |
| `tactical_target_locker` | 战术目标锁定器 | `Resources/art/modules/tactical_target_locker.svg` | `32x32` | `generate` |
| `cruise_missile_launcher` | 巡航导弹发射器 | `Resources/art/modules/cruise_missile_launcher.svg` | `32x32` | `generate` |
| `late_logic_board` | 高级战略逻辑板 | `Resources/art/modules/late_logic_board.svg` | `32x32` | `generate` |
| `hover_scout` | 前线反重力侦察兵 | `Resources/art/blueprints/hover_scout.svg` | `48x48` | `generate` |
| `missile_truck` | 后勤导弹发射车 | `Resources/art/blueprints/missile_truck.svg` | `48x48` | `generate` |
| `armored_salvage_vehicle` | 装甲回收车 | `Resources/art/blueprints/armored_salvage_vehicle.svg` | `48x48` | `generate` |

### 4. 敌人与敌巢

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `jammer_construct` | 信号干扰塔 | `Resources/art/enemies/jammer_construct.svg` | `64x64` | `generate` |
| `heavy_guard` | 重甲护卫 | `Resources/art/enemies/heavy_guard.svg` | `48x48` | `generate` |
| `ranged_enemy` | 远程单位 | `Resources/art/enemies/ranged_enemy.svg` | `48x48` | `generate` |
| `interference_nest` | 干扰型敌巢 | `Resources/art/enemies/interference_nest.svg` | `96x96` | `generate` |

### 5. UI、状态与战斗反馈

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `state_salvage` | 回收 | `Resources/art/ui/state_salvage.svg` | `20x20` | `generate` |
| `state_broadcast` | 广播 | `Resources/art/ui/state_broadcast.svg` | `20x20` | `generate` |
| `state_receive` | 接收 | `Resources/art/ui/state_receive.svg` | `20x20` | `generate` |
| `state_target_locked` | 目标锁定 | `Resources/art/ui/state_target_locked.svg` | `20x20` | `generate` |
| `missile_projectile` | 导弹 | `Resources/art/effects/missile_projectile.svg` | `16x16` | `generate` |
| `emp_ring` | EMP 扩散圈 | 无独立文件 | - | `programmatic` |
| `broadcast_ring` | 广播信号波纹 | 无独立文件 | - | `programmatic` |
| `tether_line` | 残骸牵引线 | 无独立文件 | - | `programmatic` |
| `target_lock_overlay` | 锁定覆盖标记 | 无独立文件 | - | `programmatic` |

---

## 七、P3：主脑核心区

### 1. 资源、中间产物与掉落物

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `antimatter` | 反物质 | `Resources/art/resources/antimatter.svg` | `32x32` | `generate` |
| `superconducting_lattice` | 超导矩阵 | `Resources/art/resources/superconducting_lattice.svg` | `32x32` | `generate` |
| `antimatter_containment_cell` | 反物质约束体 | `Resources/art/resources/antimatter_containment_cell.svg` | `32x32` | `generate` |
| `brain_core` | 主脑核心 | `Resources/art/resources/brain_core.svg` | `32x32` | `generate` |
| `ultimate_material` | 终极材料 | `Resources/art/resources/ultimate_material.svg` | `32x32` | `pending` |

### 2. 建筑

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `antimatter_well` | 反物质收集井 | `Resources/art/buildings/antimatter_well.svg` | `48x48` | `generate` |
| `singularity_collider` | 奇点碰撞机 | `Resources/art/buildings/singularity_collider.svg` | `64x64` | `generate` |
| `final_research_facility` | 终局研究设施 | `Resources/art/buildings/final_research_facility.svg` | `48x48` | `pending` |

### 3. 底盘、模块与蓝图

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `fortress_hexapod_core` | 堡垒级多足底盘 | `Resources/art/chassis/fortress_hexapod_core.svg` | `48x48` | `generate` |
| `remote_drop_drone_chassis` | 远程投送无人机底盘 | `Resources/art/chassis/remote_drop_drone_chassis.svg` | `32x32` | `generate` |
| `arc_lightning_emitter` | 电弧闪电链发射器 | `Resources/art/modules/arc_lightning_emitter.svg` | `32x32` | `generate` |
| `antimatter_singularity` | 反物质奇点模块 | `Resources/art/modules/antimatter_singularity.svg` | `32x32` | `generate` |
| `ultimate_ai_board` | 终极 AI 逻辑矩阵 | `Resources/art/modules/ultimate_ai_board.svg` | `32x32` | `generate` |
| `remote_drop_module` | 远程投送模块 | `Resources/art/modules/remote_drop_module.svg` | `32x32` | `generate` |
| `advanced_decoy_beacon` | 高级诱饵信标 | `Resources/art/modules/advanced_decoy_beacon.svg` | `32x32` | `generate` |
| `judgement_titan` | 末日审判者泰坦 | `Resources/art/blueprints/judgement_titan.svg` | `64x64` | `generate` |
| `remote_drop_swarm` | 远程投送蜂群 | `Resources/art/blueprints/remote_drop_swarm.svg` | `48x48` | `generate` |

### 4. 敌人与敌巢

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `adaptive_behemoth` | 自适应巨兽 | `Resources/art/enemies/adaptive_behemoth.svg` | `96x96` | `generate` |
| `brain_core_guard` | 主脑核心守卫 | `Resources/art/enemies/brain_core_guard.svg` | `64x64` | `generate` |
| `final_nest` | 终极巢穴 | `Resources/art/enemies/final_nest.svg` | `96x96` | `generate` |
| `assault_swarm` | 小型突袭群单位 | `Resources/art/enemies/assault_swarm.svg` | `32x32` | `generate` |

### 5. UI、状态与战斗反馈

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `remote_drop_marker` | 远程投送目标 | `Resources/art/map/remote_drop_marker.svg` | `24x24` | `generate` |
| `decoy_marker` | 诱饵标记 | `Resources/art/map/decoy_marker.svg` | `24x24` | `generate` |
| `lightning_arc` | 电弧链 | 无独立文件 | - | `programmatic` |
| `singularity_field` | 奇点场 | 无独立文件 | - | `programmatic` |
| `remote_drop_path` | 投送路径 | 无独立文件 | - | `programmatic` |

---

## 八、跨阶段地图素材

### 1. 地图区域与覆盖层

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `grid_lines` | 网格线 | 无独立文件 | - | `programmatic` | 当前继续程序绘制。 |
| `hover_cell` | 悬停格 | 无独立文件 | - | `programmatic` | 半透明描边。 |
| `selected_cell` | 选中格 | 无独立文件 | - | `programmatic` | 与悬停格分离。 |
| `placement_ghost` | 建造虚影 | 无独立文件 | - | `programmatic` | 使用建筑图标加合法性颜色。 |
| `service_radius` | 基地服务半径 | 无独立文件 | - | `programmatic` | 半透明圆形。 |
| `threat_circle` | 威胁圈 | 无独立文件 | - | `programmatic` | 使用区域颜色和透明度表达。 |
| `radar_radius` | 雷达覆盖范围 | 无独立文件 | - | `programmatic` | 使用描边圆形或扫描扇形。 |
| `light_fog` | 轻战争迷雾 | 无独立文件 | - | `programmatic` | 使用覆盖层，不生成复杂 SVG。 |
| `starting_basin_tile` | 起始盆地底纹 | `Resources/art/map/starting_basin_tile.svg` | `64x64` | `generate` | 可平铺、低对比度。 |
| `crystal_wasteland_tile` | 晶体荒原底纹 | `Resources/art/map/crystal_wasteland_tile.svg` | `64x64` | `generate` | 可平铺、少量晶体符号。 |
| `interference_highlands_tile` | 干扰高地底纹 | `Resources/art/map/interference_highlands_tile.svg` | `64x64` | `generate` | 可平铺、少量信号断线符号。 |
| `brain_core_zone_tile` | 主脑核心区底纹 | `Resources/art/map/brain_core_zone_tile.svg` | `64x64` | `generate` | 可平铺、终局高对比符号克制使用。 |

### 2. 敌巢信号轮廓

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `signal_weak_nest` | 弱敌巢信号 | `Resources/art/map/signal_weak_nest.svg` | `24x24` | `generate` |
| `signal_armored_activity` | 重甲活动迹象 | `Resources/art/map/signal_armored_activity.svg` | `24x24` | `generate` |
| `signal_high_energy` | 高能反应 | `Resources/art/map/signal_high_energy.svg` | `24x24` | `generate` |
| `signal_jammer_source` | 干扰源 | `Resources/art/map/signal_jammer_source.svg` | `24x24` | `generate` |
| `signal_brain_core` | 主脑核心信号 | `Resources/art/map/signal_brain_core.svg` | `24x24` | `generate` |

---

## 九、跨阶段 UI 素材

### 1. 统计菜单

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `statistics_overview` | 总览 | `Resources/art/ui/statistics_overview.svg` | `20x20` | `generate` |
| `statistics_blueprints` | 蓝图 | `Resources/art/ui/statistics_blueprints.svg` | `20x20` | `generate` |
| `statistics_rules` | 规则 | `Resources/art/ui/statistics_rules.svg` | `20x20` | `generate` |
| `statistics_loss_causes` | 死因 | `Resources/art/ui/statistics_loss_causes.svg` | `20x20` | `generate` |
| `statistics_enemies` | 敌人 | `Resources/art/ui/statistics_enemies.svg` | `20x20` | `generate` |
| `statistics_resources` | 资源 | `Resources/art/ui/statistics_resources.svg` | `20x20` | `generate` |
| `statistics_events` | 事件 | `Resources/art/ui/statistics_events.svg` | `20x20` | `generate` |

### 2. 蓝图库与锻造厂

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `action_create` | 新建 | `Resources/art/ui/action_create.svg` | `20x20` | `generate` |
| `action_edit` | 编辑 | `Resources/art/ui/action_edit.svg` | `20x20` | `generate` |
| `action_copy` | 复制 | `Resources/art/ui/action_copy.svg` | `20x20` | `generate` |
| `action_save` | 保存 | `Resources/art/ui/action_save.svg` | `20x20` | `generate` |
| `action_update_binding` | 更新产线绑定 | `Resources/art/ui/action_update_binding.svg` | `20x20` | `generate` |
| `action_search` | 搜索 | `Resources/art/ui/action_search.svg` | `20x20` | `generate` |
| `action_filter` | 筛选 | `Resources/art/ui/action_filter.svg` | `20x20` | `generate` |
| `state_favorite` | 收藏 | `Resources/art/ui/state_favorite.svg` | `20x20` | `generate` |
| `state_deprecated` | 废弃 | `Resources/art/ui/state_deprecated.svg` | `20x20` | `generate` |
| `state_binding_outdated` | 产线版本落后 | `Resources/art/ui/state_binding_outdated.svg` | `20x20` | `generate` |

### 3. 科技树与通用状态

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 |
| --- | --- | --- | --- | --- |
| `technology_locked` | 未解锁 | `Resources/art/ui/technology_locked.svg` | `20x20` | `generate` |
| `technology_available` | 可研究 | `Resources/art/ui/technology_available.svg` | `20x20` | `generate` |
| `technology_missing_material` | 材料不足 | `Resources/art/ui/technology_missing_material.svg` | `20x20` | `generate` |
| `technology_boss_locked` | Boss 门槛未满足 | `Resources/art/ui/technology_boss_locked.svg` | `20x20` | `generate` |
| `enemy_detected` | 发现敌人 | `Resources/art/ui/enemy_detected.svg` | `20x20` | `generate` |
| `resource_shortage` | 资源短缺 | `Resources/art/ui/resource_shortage.svg` | `20x20` | `generate` |
| `robot_lost` | 机器人损失 | `Resources/art/ui/robot_lost.svg` | `20x20` | `generate` |
| `enemy_killed` | 击杀敌人 | `Resources/art/ui/enemy_killed.svg` | `20x20` | `generate` |

### 4. 复盘面板死亡原因

| 稳定 ID | 显示名 | 建议路径 | 尺寸 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `loss_killed` | 被击杀 | `Resources/art/ui/robot_lost.svg` | `20x20` | `reuse` | 复用机器人损失图标。 |
| `loss_lifespan_expired` | 寿命耗尽 | `Resources/art/ui/loss_lifespan_expired.svg` | `20x20` | `generate` | 使用计时器或耗尽符号。 |
| `loss_overheat` | 过热宕机 | `Resources/art/ui/state_overheat.svg` | `20x20` | `reuse` | 复用过热状态图标。 |
| `loss_ammo_depleted` | 弹药耗尽 | `Resources/art/ui/state_ammo_depleted.svg` | `20x20` | `reuse` | 复用弹药不足状态图标。 |
| `loss_path_blocked` | 迷路或卡死 | `Resources/art/ui/loss_path_blocked.svg` | `20x20` | `generate` | 使用断路或阻塞符号。 |
| `loss_idle` | 无目标闲置 | `Resources/art/ui/loss_idle.svg` | `20x20` | `generate` | 使用空心雷达或暂停符号。 |

---

## 十、候选设计：暂不进入正式生成

这些对象出现在设计脑暴或示例中，但尚未被科技树和战役路线完全收敛。可以生成少量草案用于讨论，不应作为正式素材批量生产。

### 1. 候选建筑与地图对象

| 稳定 ID | 显示名 | 建议路径 | 状态 | 来源说明 |
| --- | --- | --- | --- | --- |
| `conveyor_belt` | 传送带 | `Resources/art/buildings/conveyor_belt.svg` | `pending` | GDD 中存在，前期流程建议暂缓。 |
| `repair_pad` | 修理坪 | `Resources/art/buildings/repair_pad.svg` | `pending` | 逻辑规则示例。 |
| `cover_object` | 掩体 | `Resources/art/map/cover_object.svg` | `pending` | 激光躲避示例。 |
| `mine_trap` | 地雷 | `Resources/art/map/mine_trap.svg` | `pending` | 悬浮底盘免疫示例。 |
| `acid_pool` | 酸液坑 | `Resources/art/map/acid_pool.svg` | `pending` | 地形减速示例。 |
| `swamp_tile` | 沼泽地块 | `Resources/art/map/swamp_tile.svg` | `pending` | 地形减速示例。 |
| `orbital_uplink` | 轨道上传装置 | `Resources/art/buildings/orbital_uplink.svg` | `pending` | 可选全局胜利目标。 |
| `brain_parser` | 主脑解析器 | `Resources/art/buildings/brain_parser.svg` | `pending` | 可选全局胜利目标。 |
| `power_plant` | 发电设施 | `Resources/art/buildings/power_plant.svg` | `pending` | 电网设计尚未收敛。 |

### 2. 候选敌人

| 稳定 ID | 显示名 | 建议路径 | 状态 | 来源说明 |
| --- | --- | --- | --- | --- |
| `tank_enemy` | 巨型坦克 | `Resources/art/enemies/tank_enemy.svg` | `pending` | 肉盾与后排考题。 |
| `healer_enemy` | 治疗单位 | `Resources/art/enemies/healer_enemy.svg` | `pending` | 肉盾与后排考题。 |
| `sniper_enemy` | 狙击单位 | `Resources/art/enemies/sniper_enemy.svg` | `pending` | 肉盾与后排考题。 |
| `suicide_swarm` | 自爆虫群 | `Resources/art/enemies/suicide_swarm.svg` | `pending` | AOE 与风筝考题。 |
| `guerilla_enemy` | 游击突袭单位 | `Resources/art/enemies/guerilla_enemy.svg` | `pending` | 弹性防线考题。 |
| `dual_form_elite` | 双形态精英 | `Resources/art/enemies/dual_form_elite.svg` | `pending` | 动态状态切换示例。 |

### 3. 候选模块

| 稳定 ID | 显示名 | 建议路径 | 状态 | 来源说明 |
| --- | --- | --- | --- | --- |
| `weakness_analysis_processor` | 弱点分析处理器 | `Resources/art/modules/weakness_analysis_processor.svg` | `pending` | 逻辑动作与模块绑定示例。 |
| `mobile_battery_module` | 移动电池模块 | `Resources/art/modules/mobile_battery_module.svg` | `pending` | 终局耗电武器配套示例。 |
| `cooling_module` | 冷却模块 | `Resources/art/modules/cooling_module.svg` | `pending` | 过热系统可选扩展。 |
| `repair_tool` | 维修焊枪 | `Resources/art/modules/repair_tool.svg` | `pending` | GDD 工具槽示例。 |

---

## 十一、生成顺序

### 1. 全量占位图批次

如果要一次性生成全阶段 SVG 草案，推荐顺序：

1. 所有 `generate` 状态的资源。
2. 所有 `generate` 状态的建筑。
3. 所有底盘。
4. 所有模块。
5. 所有代表性蓝图。
6. 所有敌人和敌巢。
7. 地图标记。
8. UI 状态和操作图标。

`pending` 项不进入第一轮批量生成。

### 2. 正式接入批次

正式清理和接入仍按优先级推进：

`P0 -> P1 -> P2 -> P3`

### 3. 每批验收

每批素材至少完成：

- SVG XML 解析检查。
- Godot 导入检查。
- 文件名与稳定 ID 对照检查。
- 实际游戏缩放比例检查。
- 同阶段并排辨识度检查。
- 前后阶段视觉层级检查。
- 后期专属符号预算检查。

---

## 十二、设计来源

本清单综合以下文档：

- [game-design-document.md](../design-docs/game-design-document.md)
- [first-30-minutes.md](../design-docs/first-30-minutes.md)
- [production.md](../design-docs/production.md)
- [tech-tree.md](../design-docs/tech-tree.md)
- [weapon-chasis-docs.md](../design-docs/weapon-chasis-docs.md)
- [enemy-docs.md](../design-docs/enemy-docs.md)
- [victory-loss-and-map-flow.md](../design-docs/victory-loss-and-map-flow.md)
- [robot-blueprint-flow.md](../design-docs/robot-blueprint-flow.md)
- [combat-report-and-debug-ui.md](../design-docs/combat-report-and-debug-ui.md)
- [logic-rules-1.md](../design-docs/logic-rules-1.md)
- [logic-rules-2.md](../design-docs/logic-rules-2.md)

后续修改设计文档中的资源、建筑、模块、敌人或 UI 入口时，应同步更新本 manifest。
