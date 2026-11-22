# 地基首轮验收记录

[返回系统总览](../SYSTEMS.md)

环境：CI010 / Windows，Godot **4.7.2**，实际窗口为 GL Compatibility / NVIDIA RTX 4090。各用例使用独立存档/绑定文件，不清空玩家档。手动入口见 [启动与编辑.md](./启动与编辑.md)。

| 验证 | 实际结果 |
| --- | --- |
| A · 跨门、退出重开 | 实际 Walker 走过室内外门平面。在关闭、源黑帧、目的黑帧、展开四段尝试移动、攻击、使用、开菜单、存读和推进，未穿透；一直按住方向不会立即折返。室外拾取 1、屋内箱取 3，同一背包为 4。出屋、再进仍开盖且不给第二次；不按存档时连续过门不产生存档。F5 保存的非门口位置，F9 与**退出后新的 Godot 进程**均正确恢复，仍为 4 / 空箱。 |
| B · 独立的连续室外测试 | 初始仅湖岸表现进树；F6 重放两次，源 12→11、未载入的坡上 0→1、进度为 1。沿原碰撞连续往返，当前角色不换不锁；每次新挂的坡上托盘显示样品和 `库存 1 / t=1`，离开后节点已释放。读回湖岸的档再重放、再到场仍是 1。调光不推进。 |
| 数据、选择与 UI | `state_checks`：63 项、0 失败，含坏档/未来版本不覆盖内存、区间重叠、闭路和守恒。`target_checks`：范围、已空/无效、稀有度、距离、ID、第二次执行均通过；实际右键也选中隔离夹具中略远但更稀有的一堆。`binding_checks`、`inventory_ui_checks` 覆盖改绑回读/默认、死区和解锁，以及 960×540、480×270、320×180 的遮罩、面板边界、选择、空包和说明。 |
| 键鼠及手柄的证据边界 | 向本次 Windows 游戏窗口定向投递原生 W / 左键 / 右键消息，分别验证实际行走、一次攻击请求、一次拾取。另以 Godot 输入事件经过真实窗口/GUI 验证 Shift、开发组合键与攻击互斥、菜单锁、列表选择、摇杆半推/满推和手柄按钮。Godot 枚举到 `0: SKN Wireless Link`；合成手柄用另一个设备 ID。另跑了不注入事件的 `--pad-live`：25 秒窗口未采到轻推/推满、LB 或 X 的完整实按，退出码 2（未验，不是硬件故障结论）。**物理手柄输入与手感、摇杆漂移及按键舒适性不算通过**。远程未能直接逐像素比对 `ref/inv.png`；已验 S09 布局与选择，不是最终美术验收。 |

**复跑（在工程根目录的 PowerShell；`$g` 指向 Godot 4.7.2 可执行文件）：**

```powershell
foreach ($t in 'state_checks','target_checks','binding_checks','inventory_ui_checks','table_checks','shore_checks') {
    & $g --headless --path . --script "res://tests/$t.gd"
    if ($LASTEXITCODE -ne 0) { throw "$t failed" }
}
foreach ($t in 'device_checks','floor_checks','paper_edge_checks') {
    & $g --path . --script "res://tests/$t.gd"
    if ($LASTEXITCODE -ne 0) { throw "$t failed" }
}
$id = [guid]::NewGuid().ToString('N')
foreach ($phase in 'door-write','door-read','regions','table-menu') {
    & $g --path . --fixed-fps 60 --script res://tests/play_checks.gd -- "--case=$phase" "--run=$id"
    if ($LASTEXITCODE -ne 0) { throw "$phase failed" }
}
```

`door-write` 留下的是带本次随机 ID 的测试档，供下一进程 `door-read` 验证后移除；`regions` 重新从零开始。真实黑场用例需要渲染窗口，不能用无头帧代替。

**补验实体手柄：** `& $g --path . --script res://tests/device_checks.gd -- --pad-live`。25 秒内横向轻推左杆、推满，按住 LB 推满，再松开按 X；只有实际轴/按钮和游戏响应均采到才记录通过。随后可在普通 Demo 以 A 拾取、Back 开包、Start 改绑，再过门确认松手才能继续走。`--native` 是独立的窗口键鼠用例：按 W 走一小步，单击左键，看到 `NATIVE_USE` 后再单击右键。以上模式都不使用玩家档。

本轮没有实现 S07、S20、战斗、经济系统或地图流式加载器。
