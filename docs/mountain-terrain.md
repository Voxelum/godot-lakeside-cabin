# 蕨岩台地 · F5 山体地形基础

## 在原地图上怎么走

仍在 [Main.tscn](../Main.tscn) 按 **F5**，进入原 [Clearing](../world/Clearing.tscn)。从无存档的池畔出生点，**背向小屋**沿米色石路过旧路口；石板渐疏、车道开始转向井边村时，走左侧那条较窄的浅赭色碎石支路。岔口约在 `XZ (4.29, 20.17)`，低石标和木栏转折标出山脚入口。沿支路过栏口，先上第一段缓坡；顺中层带碎石的横路绕过岩坎，再沿第二段坡登顶。**原路可以走／跑下山，不用跳，也不切场。** 晚上不另设地形专用光照。

- 默认地形是**平地 → 1.62 m 草台 → 3.36 m 顶台**。保留断续的岩层阴面、苔色岩唇和少量坎脚碎石；在石路和放缓的土坡处留出通行面的剪影。陡坎从低侧挡人，缓坡是有持续地面支撑的上下路线；没有在上缘另加隐形防坠墙。
- 只把原车道西侧的一小段围栏外绕到新台地周边。旧草地、石路、井边村到镇子的车道、池岸、小屋、室内、角色操控、镜头和存档脚本未改；山体仍是同一个 Clearing 的一块静态地面。建筑／魔物试产目录不参与这次改动。

## 配置与重烘焙

- **形状配置**：[fern_fold.tres](../source/mountain/fern_fold.tres) 是 F5 使用的形状；[split_spur.tres](../source/mountain/split_spur.tres) 是复用样本。配置包含原点、种子、各台高度、径向轮廓锚点、岩坎厚度／开裂幅度、坡口方向／开角／长度，以及局部 XZ 路线和每点整宽。角度由 `+X` 向 `+Z` 增大。第二套把高坡口从 `102°` 移到 `-94°`，并改了轮廓、台高和岩层，不只是转向或换色。
- **生成链**：[ridge_profile.gd](../source/mountain/ridge_profile.gd) / [ridge_tier.gd](../source/mountain/ridge_tier.gd) 定义参数与约束；[ridge_mesh.gd](../source/mountain/ridge_mesh.gd) 用不规则闭合断面放样台面、露岩和坡口，可见地面与静态三角碰撞共用顶点与三角剖分。[bake_mountain.gd](../source/bake_mountain.gd) 复用原 meadow / pigments 材质、原切石与植草笔刷，把土路和切石贴到同一份地面三角面上。石板只是浅薄饰面，不用其缝隙和倒角承重；少量散石用各自的凸包。
- **接地约束**：现为单值高度场（不做悬岩洞穴），套叠台地之间最少留 0.45 m；要移动到别的地块，先确认坡脚能在同一高程接宿主。默认只生成凸起部分，坡脚在原平坦草面 `Y=0` 合拢，不叠铺一块共面的新地皮。烘焙会拒绝重叠台面和穿过陡坎的样本路线。F5 只实例化 [FernFold.tscn](../art/terrace/FernFold.tscn)，不在运行时重新放样，也不重新烘焙原岸坡 `BanksideRise` 或 `SouthVerge`。

在工程根目录用 Godot **4.7.2**。`godot` 可换成本机引擎可执行文件路径；`--output` 必填，选择一个新路径，**不会覆盖已有场景**。两套配置可直接重建：

```powershell
godot --headless --path . --script res://source/bake_mountain.gd -- --output=user://FernFold-check.tscn
godot --headless --path . --script res://source/bake_mountain.gd -- --profile=res://source/mountain/split_spur.tres --output=user://SplitSpur-check.tscn
```

更换形状时，可在编辑器替换 `Clearing/MountainRise` 的场景实例后重查放置、坡脚与围栏；也可先用下列测试参数，仅在测试进程替换这一节点。**不要把换地形当成旧档迁移**：正在山上的旧 XYZ 未重定位；若要临时换样式继续自己的档，先回到两套共用的平地再存。

## 实测

Windows / Godot 4.7.2 / GL Compatibility / NVIDIA RTX 4090。所有存读档测试使用隔离槽；没有用真实玩家存档或改键文件。

- **走通及挡坎：** [mountain_checks.gd](../tests/mountain_checks.gd) 在真实 Main 以镜头相对输入驱动原 Traveler，从出生点上两段坡、在峰顶存档、移走再 F9 读回，然后下两段坡回到出生点。两套地形、两档像素均 **25/25**；默认 **0/1552**、变体 **0/1527** 个移动物理帧离地。分别从下方持续冲两道陡坎，实际滑动接触命中的是露岩共用的三角地面，不是栏杆或隐藏墙；脚没有被推上台。山顶 F5/F9 恢复脚下高程，以及原拾取物的背包和耗尽状态。测试通过脚本注入输入，不是人工实体按键。
- **换配方：** 默认 `3472` 个地面三角，坡道采样最大升/进比 `0.657`；变体高程 `1.32 / 3.48 m`，`3348` 三角，`0.701`。同一配置各重烘焙两次，三角数据 SHA-256 分别稳定为 `8edefc8c…`、`1685827f…`。实际加载的碰撞网格与各自配置重建的三角点序一致；轮廓、两段转向与岩坎都随配置变化。
- **原地图回归：** `clearing_route_checks.gd` 两档均 **32/32**，原 **95 m** 车道、镇巷和六个门台仍走通；`shore_checks.gd` **0 失败、0 帧进水**；`pond_render_checks.gd` **0 失败**，岸带和池塘镜面仍在；`play_checks.gd` 的过门保存、另一进程重启读档、地区和桌面交互均 **0 失败**。
- **两档实际像素输出：** [mountain_pixel_checks.gd](../tests/mountain_pixel_checks.gd) 在真实 F5 的 `Pixels` 上取 **480×270 / 320×180** 原生帧，确认显示仍为最近邻整倍。两地形、两档均 **0 失败**。对白天和 18:40 的中层机位测可见像素与交界色差；例如默认 **320×180** 白天两级岩面约有 **4035 / 1952 像素**，薄暮两级岩坎与草地分别约 **34% / 38%** 的抽样交界达到单通道色差 `0.06`。这只表明这些实渲染样本没有全糊成一色，**不是美术通过**。

复跑真窗口（不要给取景脚本加 `--headless`）：

```powershell
godot --path . --disable-vsync --fixed-fps 60 --script res://tests/mountain_checks.gd -- --320
godot --path . --disable-vsync --fixed-fps 60 --script res://tests/mountain_checks.gd -- --alternate=user://SplitSpur-check.tscn
godot --path . --disable-vsync --fixed-fps 60 --script res://tests/mountain_pixel_checks.gd -- --320
```

不带 `--320` 即为 480 档；像素脚本也支持 `--alternate=...`，和 `--output=<新的绝对目录>` 保存未染诊断色的画面。

## 真机截图与目视复核

- 默认形状、同一站位： [480×270 白天](previews/mountain-rise/fern-fold-480.png) ／ [320×180 白天](previews/mountain-rise/fern-fold-320.png) ／ [320×180 薄暮](previews/mountain-rise/fern-fold-dusk-320.png)。[从原路看支路](previews/mountain-rise/fern-fold-fork-320.png)。
- 替代轮廓，从反向开发机位看坡口： [480×270](previews/mountain-rise/split-spur-480.png) ／ [320×180](previews/mountain-rise/split-spur-320.png)。均为游戏在原 Main 的实拍，不经插值放大。
- **参考与验收边界：** 尝试直接读取 `ref/高低差.png`，远端执行器明确不支持回显 PNG；当前远程工作区也没有可用的桌面／浏览器图像回显。未看到参考原图，也没有目视审查远端实拍。请在 F5 原镜头走一趟、滚轮切近远、在 320 档按 **3** 看薄暮，重点看入口是否容易发现、两层草岩边缘是否清楚、人物在弯道和岩坎前是否被遮住。程序数字、定帧截图及物理通过不能代替这一步。
