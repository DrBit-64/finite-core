# 游戏数据

这个目录用于存放可编辑的 MVP 玩法数据。

- `recipes/mvp_recipes.json`：资源加工、建筑建造、单位生产配方。
- `debug/mvp_debug_starting_inventory.json`：MVP 调试期初始库存，用来减少手动测试等待时间，不作为正式平衡数值。

后续平衡数值尽量放在这里。脚本负责将配置加载成类型化定义，避免硬编码成本。
