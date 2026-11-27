# S04 / S06 · F5 房屋：内外尺度、共享构件与剖切光

从 **`Main.tscn`（编辑器 F5）→ `Clearing`** 进入。靠近门会看到门叶沿各自铰链向建筑内侧打开，露出黑色门洞；停在门前不切换。再走过墙面处的门槛才走原 iris；黑场结束，在门内面向房间站定。反向跨过室内门槛，回到该栋的室外接路点。游戏内 **F5 存档、F9 读档**，旅途手册也可存读档；过门本身不存档。先看镇街面包铺和井后铁匠料房，再看两间带真楼梯的镇屋；铁匠敞棚不是入口。

## F5 路线 · 镇街后的市集

1. 从池畔背向小屋走米白石路，循车辙过井边、铁匠和山坳，上到原石板镇街。**不用进入面包铺，也不用转开发镜头。** 在凸窗镇屋和面包铺之前，从镇街石板向灯匠／石凳所在的一侧拐，在蓝底三纹短路牌旁沿新石巷穿过木栏口。岔路约在 `XZ (25.43, 74.16)`，栏口约 `(25.44, 79.43)`。
2. 沿市集石巷先找**左侧绿白布棚、秤牌的杂货店**；再向前，右侧是**陶杯牌的酒馆**。酒馆门内可先到炉边和公桌，沿柜左侧找隔墙上的常开门洞，穿过去便是独立的酒桶后房，不再转场。
3. 再沿石巷，左侧**红瓦床牌是旅馆**，楼下登记，右边沿墙走到梯脚，从楼上走廊可分别进两间客房。走到石巷末梢，右侧是**蓝灰瓦、中央山墙盾徽、宽石阶和双开门的冒险者公会**。大厅里，正面登记、左侧靠墙等候，右侧真梯通二楼议事与档案；可原梯下楼，跨门回石巷支路。

只在原镇街外侧接了一条支巷，原车道、石板镇街、镇巷和建筑不挪动。新地块在原围栏外的 1.12 m 台地上，旧围栏内的地面高程保留，开放一个栏口并沿新地块外缘接回旧围栏；坡口、石巷和地面碰撞仍来自同一 [Outskirts 测绘](../world/outskirts/outskirts_profile.gd)。改支巷或台地后用 `godot --headless --path . --script source/bake_clearing_outskirts.gd -- --replace` 重烘 `SouthVerge`；不改 Lakeside／Mountain 地形。

### 原生游戏截图

从实际走到的位置截取原 F5 视口，不拉伸像素。公会一行使用本次重建的新图，其余为原市集记录。

| 区域 | 480×270 | 320×180 |
| --- | --- | --- |
| 市集入口／巷道 | [栏口](previews/interiors/market-court-480/market-gate.png) · [街内](previews/interiors/market-court-480/market-upper-lane.png) | [栏口](previews/interiors/market-court-320/market-gate.png) · [街内](previews/interiors/market-court-320/market-upper-lane.png) |
| 冒险者公会 | [外景](previews/interiors/guild-hall-480/guild-outside.png) · [接待与等候](previews/interiors/guild-registry-480.png) · [议事与档案](previews/interiors/guild-hall-480/guild-upper.png) | [外景](previews/interiors/guild-hall-320/guild-outside.png) · [接待与等候](previews/interiors/guild-registry-320.png) · [议事与档案](previews/interiors/guild-hall-320/guild-upper.png) |
| 旅馆 | [门面](previews/interiors/market-court-480/inn-outside.png) · [登记](previews/interiors/market-court-480/inn-ground.png) · [两间客房](previews/interiors/market-court-480/inn-upper.png) | [门面](previews/interiors/market-court-320/inn-outside.png) · [登记](previews/interiors/market-court-320/inn-ground.png) · [两间客房](previews/interiors/market-court-320/inn-upper.png) |
| 酒馆 | [门面](previews/interiors/market-court-480/tavern-outside.png) · [堂前](previews/interiors/market-court-480/tavern-taproom.png) · [后房](previews/interiors/market-court-480/tavern-rear.png) | [门面](previews/interiors/market-court-320/tavern-outside.png) · [堂前](previews/interiors/market-court-320/tavern-taproom.png) · [后房](previews/interiors/market-court-320/tavern-rear.png) |
| 杂货店 | [门面](previews/interiors/market-court-480/general_store-outside.png) · [取货和过秤](previews/interiors/market-court-480/general_store-ground.png) | [门面](previews/interiors/market-court-320/general_store-outside.png) · [取货和过秤](previews/interiors/market-court-320/general_store-ground.png) |

## 一楼接待区校正 · `ref/01.png`

[原 GPT 图 GROUND 局部／上版与本版同角度实机](previews/interiors/guild-registry-comparison.png) · 本版原生 [480×270](previews/interiors/guild-registry-480.png) / [320×180](previews/interiors/guild-registry-320.png)。原图仅作平面关系与造型参考；场内柜台、档架和小物均为三维几何，不使用概念图贴图。

- **柜台与工作区。** 以北墙原有 `registry_light` 为中心，在窗前留一条柜后工作带；3.24 × 0.84 m 横柜与后墙平行，厚木台面和深浅分明的四块木质柜面朝大厅。既可从等候侧绕入，也可从梯侧绕入；柜后左右档架处两条测量断面均为 **0.965 m**。台面只留摊开的登记簿、两张散页和插笔墨瓶。委托板保留在等候长凳同侧的西墙实段。
- **两侧档架不堵窗。** 分别落在北墙中心真窗两旁的实墙段，右架在默认剖切角度会被原楼梯部分挡住；不调整楼梯或挪窗来让家具出镜。公会外壳、楼梯、1:1 净平面、二楼、其他建筑和结构烘焙文件均未改动。
- **复测：Windows / Godot 4.7.2 Compatibility，公会 197/197 × 两档。** 实际 Walker 从等候区到柜前，被柜体挡住后分别从梯侧、等候侧绕过柜体；验证两档两架的物理占位及默认镜头可见度。F5/F9 用隔离槽分别精确恢复柜前和柜后脚点；同版旧脚点落在新柜台范围时回安全门内，保留行囊。楼梯往返与既有旧档回归同时通过。复跑命令见下节，图表中公会一楼以本次截图为准。

## 冒险者公会重建 · `ref/01.png`

[建筑概念图：外观与同尺两层平面](building-concepts/01-adventurers-guild-hall.svg) · [上一版／新版实机并排：外景、一楼、二楼](previews/interiors/guild-hall-before-after.png)。参考图的切屋与外观不是等比例的同一栋，重建采用一份可走的米制结构：宽阶、柱廊和双门作为公共入口，剖切显示省略屋顶；实体屋顶里的高窗只服务二楼，不用假三楼解释。对照保留上一版原图；新版外景从巷尾拍全屋，旧图从门前拍摄，两者均用默认镜头，取景脚点不同。两档六张新图来自实际走到的位置，不改镜头、不传送、不裁切。

- **街道到登记大厅。** 原 F5 市集地块不变；壳体在地块内向后退 0.51 m。三阶 **4.38 m** 宽石台接现有接路支线，厚木柱和石基托住实心廊顶，**1.86 m** 双扇门仍向内开。石阶是有踢面、踏面和阳角的实体三维网格，Walker 用吻合的连续坡面碰撞跨阶，如同室内梯。门内石板大厅以地毯引向登记柜，沿西墙的两张带靠背长凳等候，委托板在同墙实段；柜台两侧可绕，右侧走到楼梯。楼上木板面、六席议事长桌、档架与抄录台分区；无新增 NPC、任务或交互。
- **两层，一把尺。** [`guild.json`](../world/interiors/structures/guild.json) 产出两份烘焙：外壳 **8.44×7.00 m**，0.25 m 墙厚，室内净平面 **7.94×6.50 m**；二楼楼面 **+2.88 m**，右侧直梯 **16 级 / 宽 1.46 m / 梯跑 3.85 m**。`front_roof` 的三个交叉山墙切入同一个主坡；中间山墙为盾徽实墙，左右老虎窗由同一开口坐标烘出立面墙洞、玻璃实体和二楼采光，窗后没有旧屋坡截断，也没有阁楼楼板。开敞柱廊不计入净面积。柱、廊顶、梯、护栏及柜台都有碰撞；房间剖切只改变显示。
- **地块净空。** 包含屋檐、门台的地块投影包络，保守测得距酒馆 **1.73 m**、旅馆 **3.96 m**、围栏中心折线 **1.00 m**。原石巷、地形、栏线、邻房均未移动；Walk 测试实走支线往返并验证脚下支撑。
- **旧档。** `place.guild`、原过门 iris 和存档格式保留。公会结构修订升级：旧 v1/v2 室内档和上一版 v3 进入新的一楼安全门内，保留行囊与世界状态，不复用旧净尺寸或楼层坐标。老室外脚点若落进新房壳、柱脚或埋在宽石台下面，则回公会接路点；当前无遮挡的一楼、二楼和台面脚点均能精确恢复。过门不自动写档。
- 只重烘 `GuildExterior.scn` / `GuildStructure.scn`，其余 22 个烘焙场景哈希不变。复烘：`godot --headless --path . --script source/bake_buildings.gd -- --only=guild --replace`。
- **Windows / Godot 4.7.2 Compatibility**：两档真实窗口公会各 **183/183**（含每档三张实拍），全市集各 **415/415**；结构名册 **2224/2224**、原结构 **163/163**。验证真实门叶与黑场、柜台碰撞、等候和柜前柜后、原梯上楼／下楼、议事与档案路线、回主街，以及隔离槽 F5/F9、二楼冷启动、三种旧室内档回退和旧室外柱／台脚点回退。

公会复跑（不加 `--headless`，可选 `--capture=user://guild-hall-review-480` 或 `--capture=user://guild-hall-review-320`；输出目录必须尚未存在）：

```powershell
godot --path . --windowed --resolution 960x540 --disable-vsync --fixed-fps 60 --script tests/market_court_checks.gd -- --guild-only
godot --path . --windowed --resolution 960x540 --disable-vsync --fixed-fps 60 --script tests/market_court_checks.gd -- --guild-only --320
```

## 同尺对照：1:1 建筑局部坐标

十二栋均使用同一建筑局部坐标：外壳宽 `W`、深 `D`、墙厚 `t`，净壳严格为 `(W−2t, D−2t)`，不设用途倍率、逐栋覆盖，也不缩房间根节点。墙洞用同一个米制局部变换；窗、门、楼层、楼梯、凸窗和独立隔间在两个世界一一对应。下表净平面是一楼内侧主矩形，未扣家具和楼梯。玩法相机按实际可见几何构图，比固定跨度对照更近；背景为黑，仍使用两个 World3D。旧版 [480×270](previews/interiors/calibrated-cutaway-480.png) 和 [320×180](previews/interiors/calibrated-cutaway-320.png) 对照仅作历史留档，不代表 1:1 版本。复跑可生成新对照：固定 **9 m 正交垂直跨度、39°俯角**，两档 **30 / 20 px/m**；同一 **1.68 m 高、直径 0.62 m** 的 Walker 测得投影高度 **39.2 / 26.1 px**。

从小屋背向小屋沿米白石路朝画面左下走，石板渐疏后沿车辙去井边；过地形接缝、继续沿车辙到石板镇街。表内坐标是建筑根的 `Clearing` 本地 XZ，不是玩家落点。外壳宽深不含屋檐／敞棚。

| 地点（X, Z） / 存档 ID | 外壳宽×深（m） | 净宽×深（m） | 功能 |
| --- | --- | --- | --- |
| 湖畔 Cottage（−1.00, −1.25）`place.cabin` | 6.28×5.08 | 6.00×4.80 | 餐桌、炉、入口箱和餐边柜。 |
| 井边 LimeHouse（7.10, 17.68）`place.lime_house` | 6.15×4.23 | 5.87×3.95 | 换靴、共餐、东侧睡铺和西窗种子台。 |
| 井边 OrchardHouse（13.45, 20.34）`place.orchard_house` | 5.85×4.42 | 5.57×4.14 | 偏右入口，西侧分拣、东侧屏风床铺。 |
| 井边 HayBarn（19.72, 21.05）`place.hay_barn` | 5.86×4.74 | 5.56×4.44 | 双开门与卸货带；西草捆、东粮架，百叶通气孔，无假二楼。 |
| 井后 Blacksmith（14.90, 31.80）`place.smith_stock` | 4.16×4.44 | 3.86×4.14 | 只进闭合料房；露天砧、火炉、棚、夜灯均在室外。 |
| 镇街 CopperLoft（23.62, 66.87）`place.copper_loft` | 3.34×4.35 | 3.06×4.07 | 起居与档柜，二楼账桌与床；楼高/级数/梯宽/梯跑为 2.21 m / 13 / 0.94 m / 2.35 m。 |
| 镇街 SillHouse（29.08, 67.92）`place.sill_house` | 3.96×4.71 | 3.68×4.43 | 会客区、二楼三面窗龛和缝补案；楼梯 2.26 m / 13 / 0.96 m / 2.46 m。 |
| 镇街 Bakery（34.56, 68.93）`place.bakery` | 5.45×4.33 | 5.15×4.03 | 保留柜前排队区，能从柜左绕至面案、砖炉、面粉与陈列。 |
| 市集 GeneralStore（19.50, 83.50）`place.general_store` | 5.40×4.40 | 5.10×4.10 | 单层：前窗陈列、秤台，右侧走货架／工具及柜后补货。柜与工具架之间测得 1.595 m，柜后到粮架测得 1.010 m。 |
| 市集 Tavern（32.00, 84.70）`place.tavern` | 6.55×6.30 | 6.23×5.98 | 单层：炉、公桌和侧置服务柜；0.14 m 隔墙与 1.18 m 门洞分出净深 2.06 m 的酒桶后房。 |
| 市集 Inn（19.50, 92.25）`place.inn` | 7.40×6.10 | 7.08×5.78 | 两层：入口与登记区中间留行走区，右侧直梯独立上楼。楼高/级数/梯宽/梯跑为 2.46 m / 14 / 1.08 m / 2.86 m；上层共用走廊测得 2.123 m，两客房开口各 1.06 m。 |
| 市集 Guild（32.05, 95.25）`place.guild` | 8.44×7.00 | 7.94×6.50 | 两层：登记、沿墙等候、右侧直梯到六席议事厅和档案区；楼梯 2.88 m / 16 / 1.46 m / 3.85 m。 |

## 一份结构三种表现：外壳、完整内壁、剖切内壁

- **窗洞是结构，不是贴纸。** `openings` 的稳定 ID、墙段、`u`、层号、窗台和宽高，同一次烘焙生成墙真实开口、玻璃实体和可见结构；开口在内外拥有同一个建筑局部变换，不镜像。外门的网格和实体碰撞都跟着铰链；双开门各自向内转。黑色门洞只绘制，不封住物理通道。门叶打开不触发切换，只有 Walker 从正面跨过墙面门槛才开始原 iris；室内门洞可直接走出。独立视口不会透过玻璃看到另一张地图。
- **老虎窗打断主坡，不另造楼。** 公会的 `front_roof` 用 `u`（沿南墙）、`setback`（从南墙向里）、`width`、`shoulder` 和 `peak` 定交叉山墙；可选 `window` 给玻璃宽高和绝对窗台高程。烘焙从主坡同时裁去网格与碰撞，在同份边界内生成窗墙、山墙屋面与侧壁。窗洞仍有内外同坐标的 `Opening_*` 与实体玻璃；采光归二楼。默认剖切隐藏屋壳，避免占据二楼画面。`upper_floor_finish` 只换楼上饰面，不改楼板或存档修订。
- **隔室也是结构，不是家具屏风。** `partitions` 由同一 JSON 搭出全高实体墙、实心过梁和可走门洞。`floor` 选择楼层，`axis` 是沿局部 `x`／`z` 的方向，`at` 是另一轴的坐标；`from`／`to` 可用米制坐标或 `min`／`max` 贴住对应内墙，`passages` 中 `u/width/height` 定开口。内景只显示低于腰部的墙体剖切和截短门柱，**碰撞不随显示缩短**；外景含同坐标的完整内部结构。楼梯、出入口、过梁净高及门洞间距不合法时拒绝烘焙。
- **完整窗不会立在剖切方向挡视线。** 房间按相机的水平视线选择近墙的 `Section`，只留矮墙和对应窗位的浅缺口，不画整扇窗框／玻璃；远墙用 `Full`。剖切不关闭真实墙、玻璃或楼板碰撞。阁窗所属屋壳仍隐去；凸窗各墙面按各自法线选择剖切，楼板连续接进窗龛。
- **没画窗，也有同窗位的入光。** 每个有玻璃的开口烘出独立 `WindowDaylight` 光源，从玻璃内侧沿该墙向内、向下照，照亮附近地板和家具而非抬高全屋曝光。楼层视图只启用该层的窗光。与室外共用 Almanac，光量从白天到傍晚连续下降；当前室内基准填光和自身炉光不会为突出窗光而整屋变白。这是局部漫入光的风格化近似，不模拟完整太阳光线追踪；百叶通气孔不是玻璃窗光源。用室外 `1/2/3` 设 14:00／16:45／18:40 再入门看区别，室外按 `P` 让同一个时钟继续走，入室后也继续生效。
- **跨门空间方向对齐。** `DoorAnchor` 存的是有局部基底的门框；+Z 是向外法线。实际过门时，Guest 在黑场中面向室内门框 −Z，回到外面面向各栋自己的外门 +Z，不按世界固定方向旋转。目的相机用源相机在门框局部的水平右轴，所以按同一个方向键在门两侧没有左右翻转。俯角和画幅可按内景取景；二楼俯角变化，但不更换水平轴。防止长按越门造成连走的中立输入锁仍保留。

## 构件怎么复用

1. 改 [`world/interiors/structures/`](../world/interiors/structures/) 内对应 JSON。建筑局部 **+Z 朝街、Y=0 是完成地面**；`floors` 是真实楼面列表；只改 `size` 就会重算共同净平面；旧 `interior_clear_size` 和 `interior_area_multiplier` 都会拒绝烘焙，不提供逐栋覆盖。开口宽高、窗台、门宽、人物和家具不随净平面缩放。直梯和梯井的 `x/min_x/max_x` 相对东内墙，`bottom_z/top_z/min_z/max_z` 相对南内墙，向室内为负；因此改外壳宽或深，梯和井同移，梯宽、梯跑、楼高都不变。`bay_left/front/right` 是凸窗实际三面墙，`gable` 只用于未隔层的屋顶开口。`center` 调外壳相对地块的位置，不动室内坐标系。缺梯、缺洞、侵入楼板的窗和不够 Walker 净空的梯口会拒绝烘焙。
2. 用 `wall_panel` 选共享墙系统（`plaster_posts` 灰泥木柱、`framed_plaster` 框架灰泥、`board_batten` 板壁压条、`masonry_plinth` 石基灰泥）。每个窗 `component` 选 `casement`、`triplet`、两者的 `shuttered_` 变体或 `shop_display`；通风孔选 `louver`。[`building_components.gd`](../source/building_components.gd) 管实际部件，内外从同一类型分配板壁、压条、窗格、框台；外百叶只在外侧，类型不因切视角而切换，剖切显示是另外的 `Full/Section` 表现层。内外颜料角色仍由同一 `style` 记录的外漆、内衬、木料、窗框、玻璃、石基等指定。旧 `panes`／`shutters` 可作未指定组件时的兼容输入。
3. 运行 `godot --headless --path . --script source/bake_buildings.gd -- --replace`；只做一栋加 `--only=sill_house`（JSON 文件名，不含扩展名）。旧 `source/bake_copper_loft.gd` 仍可用。烘焙器先校验投影及打包全部选中对，再写 `*Exterior.scn` / `*Structure.scn`，两份含同一来源版本；不要手改输出。组件仅改表现时不让当前 v3 脚点失效。改净平面、门位等结构后，跑结构检测、门台、家具通道、楼梯与旧档回归。
4. 复用 [`world/interiors/`](../world/interiors/) 的独立 `PackedScene` 家具，放置实例根，带碰撞家具的模型和碰撞一起动。此次把小屋**铸铁炉（含炉光）、餐边柜、刺绣毯**从内嵌网格归成 `CastIronHearth`、`CrockerySideboard`、`EmbroideredRug`，保留原摆放。常用桌（`DiningTable`，X 为长边，`Tabletop` Y=0.8）、椅凳、床、工具架、粮袋、砖炉、案板、托盘继续复用，小阁楼和新房也用相同构件。新添 `NoticeBoard`（真实靠墙道具，非界面）和 `CellarCask`（自带碰撞）可独立实例化；店号的 `sign` 选编入外景的盾、床、杯或秤轮廓，不改结构或存档版本。小配件可挂在家具上，薄毯与贴墙美术摆件不另加碰撞。底层 `Furnishing` 下实例的可见包围盒若超出壁面，共用规则仅平移实例及其碰撞留 0.035 m 壁边；不缩放、不自动消解实例间的碰撞。阁楼、窗龛、存档实体及专用固定摆件仍按真实米制落位。各屋作者负责家具摆位、通道和额外灯；通用 `RoomPresentation` 负责取景、窗光及按脚高切换上层墙面/家具表现。物理楼梯、楼板不会开关。

**归并例外：** `CabinDiningTable` 组合通用桌和小屋独占 `CabinTableSetting`；`cabin.entry_chest`、`cabin.dining.bread.01`、`cabin.dining.cup.01` 属于存档实体，不复制去别屋。谷仓卸货磨痕是场地标记，不是家具；凸窗屋已移除没有房间对应的旧装饰性屋顶窗，真实凸窗三区保留。池畔封闭 `Glasshouse` 的透光材质/砖基/物理仍是原景观；铁匠敞棚、谷仓东侧附属面、雨棚、井、路标及灯不生成房间。旧 `CabinShell`／`RoomShell`、旧阁楼表现脚本、F6 美术试产及 `overland_demo` 不参与 F5 的新流程。不新增交易、炉火操作、开关窗或播种玩法。

## 门槛与旧档

注册入口是 [`world/interiors/room_catalog.gd`](../world/interiors/room_catalog.gd) 的 `ROOMS`（存档 ID → Clearing 地块节点、室内场景），以及 [`source/bake_buildings.gd`](../source/bake_buildings.gd) 的 `STEMS`（结构 JSON → 生成场景文件名前缀）。原八个房间 ID、七个村镇 `lot_id`、地块根和朝向都保留；小屋定义 `clearing.lakeside.cottage`，存档仍用 `place.cabin`。新增四栋的地块命名为 `clearing.market_court.*`，共十二栋。仍使用原 `Main` iris、`RoomPixels/Guest` 和 `FieldSession`，不改存档格式。

- **室内 v3**：稳定房间 ID、结构版本、建筑局部脚点（Y 是真实高度），同版精确恢复足底和楼层视图。切换到 1:1 后八栋结构修订均改变；旧扩张几何的 v3 坐标不直接套用。
- **旧 v1/v2 室内档或结构版本不符的 v3**：保留行囊、已拿走的来源、角色数据（v1 没有的字段按原规则补默认）和世界变化，从对应房间的新一楼安全门内起步，不拿旧坐标猜测楼层。旧客户端不能读取新增房间的 v3 档。
- **室外 v2**：世界脚点通常原样恢复；如果原座标落在先前扩建后的闭合房壳内，回该栋室外接路点。不为任意手改坐标、附属体占用或未来家具移位做全地图搜路。原默认槽验读未写入，回归写随机隔离槽。

## 实测与复跑

- **十二栋结构名册 2155/2155；原结构回归 164/164。** 检查 F5 实际挂载的双场景、局部门窗、楼面、剖切与碰撞；分别只改外壳宽、深重烘，验证净平面随同一轴变化。新增隔墙检查两份烘焙的门洞变换、实体墙、实心过梁和肩部开口；拒绝阻挡梯口、楼层错误、门洞过窄或相交的定义。默认 v2 槽只读验档，哈希不变。
- **市集真窗口 386/386 × 两档（Windows Godot 4.7.2 Compatibility）。** 从 F5 出生点靠镜头相对输入一路走到四栋、出入后返回原镇街；门前停留只开门，跨门才走黑场且不自动存档。实际 Walker 到达四处主要区域、两栋上层、旅馆两间独立客房和酒馆后房；压向剖切隔墙会被物理墙挡下。四处 F5/F9 恢复脚点和行囊（包括酒馆后房与两个上层），重建 Main 也能恢复公会议事楼层。存读使用随机隔离槽。
- **原路真窗口 34/34 × 两档。** 池畔往返原 95 m 车道、井边与铁匠、石板镇街、镇巷和七个旧门台，移动中离地 0/5454 帧；旧车道及镇巷路面网格未改。两个旧镇屋的实走楼梯、存读与旧档回退两档均零失败。另有旧门槛套件中的窗口整倍缩放断言需随显示契约核对；不属于此次原生视口／建筑回归。
- 横截面射线是固定断面净空，不是整条路线的最窄值。这里是注入实际 Walker 输入和原生渲染的自动化实测；不是人工实体手柄或全角度目视验收。将来调整外壳或家具需重跑通行和存档回归。

复跑市集（不加 `--headless`，`--capture` 可省略，否则必须用新目录）：

```powershell
godot --path . --windowed --resolution 960x540 --disable-vsync --fixed-fps 60 --script tests/market_court_checks.gd -- --capture=user://market-review-480
godot --path . --windowed --resolution 960x540 --disable-vsync --fixed-fps 60 --script tests/market_court_checks.gd -- --320 --capture=user://market-review-320
```

结构 `godot --headless --path . --script tests/building_roster_checks.gd`。原路、原门槛、原尺度分别用 `tests/clearing_route_checks.gd`、`tests/interior_door_checks.gd`、`tests/interior_scale_checks.gd`；旧两层实走 `tests/copper_loft_walk_checks.gd`（`-- --sill` 改测凸窗镇屋）。需要小档时在 `--` 后加 `--320`。
