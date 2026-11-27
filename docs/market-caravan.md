# 井边村的外来马车（原 F5）

新局 06:00 起，在村口主路和菜地旁可等到两匹马拉的木货车。每天道路开放、没有上一趟在途时，**12:00 进村 → 14:00 到集市秤棚 → 15:00 掉头返程 → 17:00 离村**。默认 5 秒是一小时；不必用快捷键生成。它不是 11:00 将本地产物由场仓送去店库的村车。

- [进村 480](previews/market-caravan/village/arriving-480.png) / [320](previews/market-caravan/village/arriving-320.png)；[途中 480](previews/market-caravan/village/on-road-480.png) / [320](previews/market-caravan/village/on-road-320.png)；[14:00 停靠 480](previews/market-caravan/village/dock-480.png) / [320](previews/market-caravan/village/dock-320.png)。使用正常视角，人物位于路肩或停车坪南侧，未变焦。
- 到站时一次检查外地存货、村库存量及双方购买力；双方付款、卖方扣货、登记在途批次。停靠时木箱卸下、货包上车；只有当次实际成交对应方向才播搬运动作。模型代表货类，不按件数摆满车斗。沿用原账本，车程完成才从在途转入目的库。资金不足或无余货不会刷出订单。
- 关路时，旅程停在原位，保留当次进度，过午错过发车则等下一次；出发后若堵车，实际到站／入库一起顺延。过门、离屏、存读不会新增车或改记账。旧档已有的未完成订单仍按原 ETA 收尾，不补做一次成交。
- `world/outskirts/market_caravan.gd` 每帧只读账册，将一辆车投影到 `village_caravan_route` 的烘焙曲线，不推进时钟。世界 Almanac 单独调用 `VillageLedger.elapsed`。地图搬动终点后，车跟随，不修改路径。

回归：`godot --path . --windowed --resolution 960x540 --script res://tests/market_caravan_checks.gd`（加 `-- --320` 检查低档；可指定新的 `--photos=user://caravan-check` 目录）。从新局以常速时钟步长驱动，验证真实曲线首点、中点、末点、停靠搬运、返程、封路跨昼、室内外与六次独立槽写盘恢复。`tests/village_ledger_checks.gd` 另覆盖十天 / 九十天资金、物资及家庭收支。
