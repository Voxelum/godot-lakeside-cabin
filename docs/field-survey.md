# M · 乡野舆图与 F5 聚落空间

F5 在室外按 **M** 展开北向图。红箭是角色的位置、朝向；地图不锁走路，室内、黑场与账册等模态界面会隐藏它。

## 修改实际布局

- `world/outskirts/settlement_lots.json` 是 Outskirts 11 栋房子的摆位表（本地 X、Y、Z、绕 Y 轴角度）。`Lots` 在编辑器及游戏共用相同定位器。原 Cottage 仍用 Clearing 场景的唯一变换。每栋以原结构 JSON 的 `building_id` 标识；首层外墙占地取 `size`、`center`，不取可见网格、屋檐或上层凸窗。门槛和接近点来自同一配方烘出的标记，室内 ID、节点名和存档协议不变。
- `settlement_space.gd` 提供地块、道路、定向连接与虚拟门前通行段。道路使用有序中心线、逐站**全宽米**、类别和父路 ID；道岔首点必须接触已连通路面。SouthLane、TownAlley、MarketStreet 的地形源为 `outskirts_profile.gd`；更改后需运行 `source/bake_clearing_outskirts.gd -- --replace` 同步 SouthVerge。田头、秤棚卸货区、魔物园路沿用其地块生成器的参数。商队、运粮运行轨迹不重复当成公共道路。M 图读取空间快照；既不采集 Mesh AABB，也不从生成后的曲线倒推宽度。
- 所有 12 栋封闭建筑（湖边、村、镇街与市集）的路面不得穿进首层墙体。门前原有泥路仍从各自接近点投向公共道路；门槛最后一段属于该门，不是新铺的路。小屋使用原露天门前院落（最远 5 米），不往旧石板上多铺一段。麦田、放牧地、鸡棚、牛羊舍、秤棚、魔物园牌楼使用声明的地块；敞开的铁匠棚、附属温室、家具、棚柱、围栏、楼上凸窗不是独立可进房屋。空间验算不代替它们的实体碰撞／行走测试，也不宣称覆盖山路、水域或任意室外地形。
- 空间检查发现原主路边缘压到灰泥农舍、铜顶镇屋，镇巷压到凸窗镇屋，市集末端压到公会。前三者移开；公会为保留酒馆及围栏净距不动，向西收回市集末三站并重烘。修改前后均使用真实 Walker 通行回归。

## 验证

`tests/settlement_space_checks.gd` 加载真实 Main，检查完整布局、门朝向、连接与跨压，另用移位／转向建筑、加宽田路、断开支巷做负例。烘焙道路按相同立方曲线采样并预留画边摆幅；田路按转角拼接截面算宽。`tests/field_survey_checks.gd` 验证 M、移动和旋转后的轮廓、图签及账册遮挡；`tests/pasture_map_checks.gd` 从主路步行到牧地和田中。`tests/clearing_route_checks.gd`、`tests/market_court_checks.gd` 和 `tests/field_occupancy_checks.gd` 保留物理与门槛回归。使用 `--fixed-fps 60`，要求截图/像素证据的项目使用真窗口而不是 `--headless`。

[早期布局照片 480 档](previews/field-survey/village-exchange/field-survey-480.png) · [320 档](previews/field-survey/village-exchange/field-survey-320.png)（旧图，不作为此次迁移证据）。
