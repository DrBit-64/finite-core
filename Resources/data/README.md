# 游戏数据

这个目录用于存放可编辑的 MVP 玩法数据。

- `recipes/mvp_recipes.json`：资源加工、建筑建造、单位生产配方。
- `buildings/mvp_buildings.json`：玩家建筑图标、占格尺寸与生命值。
- `enemies/mvp_enemies.json`：敌方单位与敌巢的生命、攻击、警戒半径、续接目标半径、刷新和奖励参数。
- `units/mvp_unit_blueprints.json`：MVP 单位蓝图与机器人属性配置，包括生命、速度、寿命、目标锁定时间、射程和伤害。
- `debug/mvp_debug_starting_inventory.json`：MVP 调试期初始库存，用来减少手动测试等待时间，不作为正式平衡数值。

后续平衡数值尽量放在这里。脚本负责将配置加载成类型化定义，避免硬编码成本。
