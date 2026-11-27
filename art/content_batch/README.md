# 城镇与林路 · 第二批外景素材

下列 **5 个 PackedScene 已接入 F5 原地图**，不另建入口。造型使用工程现有瓦片、木作、粉墙和场地着色，没有外采模型、贴图或插件。实走路线与回归结果见 [内容生产文档](../../docs/content-production.md)。

## 建筑 × 3

- **[铁匠铺](buildings/Blacksmith.tscn)**：宽阔开放工位和闭合料房并排；高砌石烟囱、烟熏炉口、锥角铁砧、淬水木桶和锻造挂招牌在远景提示用途。工位可走进，料房的拱门只有外景和门台，没有商店或室内。约 **6.85 m 宽 × 5.2 m 深**（含檐及坡脚），烟囱高约 **4.82 m**。
- **[雨廊农舍](buildings/RainPorchFarmhouse.tscn)**：保留低宽卷檐、左拱门和青绿百叶；临街三分之二加独立低瓦雨廊、撑柱和石柱脚，另一侧露出窗台与花盆。不只换色。沿用 `LimeHouse` 的壳体跨度和门台。
- **[凸窗镇屋](buildings/OrielTownhouse.tscn)**：以 `SillHouse` 窄高体量为底；二层斜切三面凸窗向街挑出 0.82 m，带陶瓦小帽、托木及朝巷侧的老虎窗。左侧入口和原坡脚保持不动。凸窗底留过人净高，不占地面巷宽。

1 Godot 单位 = 1 m；局部 **+Y 向上、+Z 临街**，建筑根原点在体块中心的地表；两栋变体遵循原地块模板，铁匠铺用固定构型。都可直接实例化。建筑碰撞在第 1 层，门台是连续斜坡接平台，门后整片外壳阻挡；铁匠铺主要大件和雨廊柱脚也有碰撞，不用瓦片、木纹当碰撞。通用挂点为 `Generated/Anchors/{DoorAnchor,Landing,Approach,Lamp}`（也可用 `marker("Approach")`）。铁匠铺另有 `Sign` / `Anvil` / `Hearth`，两栋变体分别有 `PorchEave` / `Oriel`。

### 主地图建筑站位

- 两栋变体已原位替换 `Outskirts/Lots/LimeHouse`、`SillHouse`，沿用各自节点名、`lot_id`、位置和角度。保持踏步对齐原通路；不要缩放以迁就地块。雨廊与凸窗前缘各离根约 3.2 m / 3.0 m，坡脚之外仍需给信使留落脚空间。
- 铁匠铺在井边村转林路外肩：Clearing 坐标 **`Vector3(14.9, 0, 31.8)`、偏航 `+61°`**。料房的 `Approach` 接最近车辙；敞棚在同一立面右侧、入口保持无障碍。现用平地站位；若移到坡地要另做接地，不平移或盖掉原地形。
- 放在 `Outskirts/Lots` 可沿用 `marker("Approach")` / `door_width` 生成支路；给新铺分配稳定 `lot_id`。壁灯随原 `Almanac` 的 `night_omni` 组点亮，在其 `_ready()` 收集前实例化即可。新增地块后，主地图的既有回归脚本应按命名站位取景、单列铁匠铺门台，而不是把新地块按旧六栋的列表索引划到镇上。

## 经典魔物 × 2

- **[巨鼠](creatures/GiantRat.tscn)**：低矮弓背、宽后腿、圆耳、胡须、双门齿和约 1.4 m 裸尾，靠贴地轮廓区别于狼的长腿和粗尾。`idle`（2.48 s，耳动与嗅探）、`move`（0.54 s，对角快步）、`rear_and_sniff`（1.84 s，后腿撑起、鼻尖前探，两爪交替拨动，落回原点）。
- **[骷髅兵](creatures/SkeletonSentry.tscn)**：松散肋骨与眼窝的负形、赭红鸢盾、骨白和褪色绿布；直立轮廓与巨鼠相反。`idle`（2.94 s，散步前的晃头）、`move`（1.06 s，不对称咔哒步态）、`rattle_guard`（1.93 s，跨一步举盾，颌骨快速开合两次再回位）。

这两份场景是**无脚本、无碰撞**的原生网格与动画，根原点在脚下，局部 +Z 为正面。`AnimationPlayer` 默认循环 `idle`，`move` 循环，招牌动作单次，`RESET` 为中立姿势。宿主移动实例根，动画只改 `Rig`。播放招牌动作后可在 `animation_finished` 切回 `idle`；不触发攻击、追逐、命中、掉落、保存或其他游戏状态。均有 `Look` 挂点；巨鼠另有 `NoseTip` / `TailTip`，骷髅有 `ShieldSocket` / `RimTip`。

巨鼠在井边村外草肩，骷髅兵在石街前的坡边。正式站位分别为 `(x=10.70, z=27.75, yaw=97°)` 与 `(x=16.13, z=58.83, yaw=13°)`，用 `Survey.surface(xz)+0.009` 接地。避开原路中央、深草和树冠正下方；按新站位复查前景遮挡、落脚和昼暮照明。宿主可独立错峰轮播，勿把新 ID 填进原三种的固定 `species` 枚举。`source/` 是造型与动作烘焙源码；`godot --headless --path . --script res://art/content_batch/source/bake_creatures.gd` 只生成这两份场景，已有文件默认拒绝覆盖。

## 原 F5 取景与验收

`batch_review.gd` 直接加载正式 `Main.tscn` 中的五个实例，不再注入或替换素材，也不写存档或键位。无头 **47/47**；**480×270 与 320×180** 真窗口各 **102/102**。两档在 **14:00 / 18:40** 用默认 **13.4 m** 跟随镜头抽样五项素材可见性，并用定帧取景检查关键细节和动画剪影；两只魔物另用地面碰撞射线核对落位。由实际 `Walker` 走到三个门台、推门确认碰撞并回原路，铁匠铺另走进、走出敞棚。连续路线另由 `tests/clearing_route_checks.gd` 从出生点实走。渲染抽样不是连续视野或肉眼美术验收。

### 接入前素材截图

每格是原尺寸实渲染 `Pixels`，合图无缩放。建筑拍在游戏 **8.95 m** 档、魔物拍在 **6.2 m** 档，便于看已通过默认远档抽样的细节。执行端不能回显远端 PNG，可在项目中直接打开。

- 建筑：[480 档](captures/buildings-480.png) / [320 档](captures/buildings-320.png)。从左至右：铁匠铺、雨廊农舍、凸窗镇屋；上白天，下薄暮。
- 魔物：[480 档](captures/creatures-480.png) / [320 档](captures/creatures-320.png)。左巨鼠、右骷髅；四行依次为白天待机、白天招牌帧、薄暮待机、薄暮招牌帧。

在工程根目录复跑（Windows 可用实际 Godot 控制台程序路径）：

```text
godot --headless --path . --fixed-fps 60 --script res://art/content_batch/batch_review.gd
godot --path . --disable-vsync --fixed-fps 60 --script res://art/content_batch/batch_review.gd
godot --path . --disable-vsync --fixed-fps 60 --script res://art/content_batch/batch_review.gd -- --320
```

在 `--` 后加 `--capture` 可生成缺失的合图；现有 PNG 不会覆盖。当前脚本只从原 F5 正式场景取样。
