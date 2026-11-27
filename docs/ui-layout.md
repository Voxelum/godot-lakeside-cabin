# 屏幕 UI 尺寸与实测

## 尺寸契约

- `Main.tscn` 下的 `UILayout`（[`ui_layout.gd`](../scripts/ui/ui_layout.gd)）按实际游戏客户区计算一次 `k = min(宽 / 640, 高 / 360)`。640×360 逻辑框居中；安全区是 `(12, 8, 616, 344)`。超宽或较高窗口不会拉伸纸面和字体。
- 角色面板、对话、旅途手册、改绑、生命牌、设置入口、提示／反馈与屏幕时钟同用此变换。只用 `place()` 摆放外层界面；纸面内的控件用逻辑坐标，不能再乘 `k`。全窗暗幕无需缩放。屏幕时钟保留自绘位图数字；场景内 3D 标牌仍属于世界。拾取浮签先把世界投影转换到客户区，再逆变换进 UI 安全区。
- 文字按用途选 `TITLE` / `BODY` / `AUX`：**17 / 14 / 11** 逻辑字号。行囊、属性与对白正文用 `BODY`，槽位短标签、辅助状态和小按钮用 `AUX`。不要根据低分辨率视口、纸面自身宽度或同一层的全屏状态另乘缩放。复用共享羊皮纸主题、四边透景与控件焦点；正文过长优先换行或滚动。
- 两档世界仍分别使用 480×270 或 320×180 的最近邻等比缓冲，与这套规则无关。320×180 是两档都允许的测试窗口下限，不是推荐阅读尺寸（该小窗正文实际只有 7 px）；建议用 960×540 或更大的客户区体验中文。

## 当前布局

- **角色面板：** 544×246 逻辑单位，占 16:9 游戏画面的 **85.0% × 68.3%**；分栏近似 **35 / 33 / 32**。容器比之前更宽松，纸边、两条墨线、属性的细进度条保留。128×192 的透明 3D 预览是独立视口，只作为 64×96 的等比纹理显示，不以源纹理尺寸撑大控件。头、鞋槽分列其上、下，左右各留净空。物品行／说明可滚，装备按钮固定不随列表移动。
- **对话：** 464×92 逻辑单位，底部居中，占 16:9 画面 **72.5% × 25.6%**；保留左侧独立透明 176×176 逻辑立绘、上沿姓名纸签、原对白与继续／离开。正文不压立绘与姓名签。
- **设置：** 手册／改绑各自的羊皮纸内只排逻辑尺寸；改绑的动作网格可滚，状态及返回按钮始终在滚动区域外。模态锁、键鼠／手柄焦点、操作和存档不变。

## CI010 实窗数据

Windows / Godot 4.7.2 / GL Compatibility。实拍从正式 `Main.tscn` 开始，站在榛树园丁旁、14:00、同一机位；每次运行冻结实际相机生成的世界贴图再拍两张，避免场景动画干扰。相同全屏尺寸或窗口尺寸下，两档 UI 几何、字号、对白实绘字高和纸娃娃净空一致。世界贴图、阴影等像素随世界档位而变化。

- **2560×1440 全屏：** 角色标题／物品行／说明有效字号由 **101.3 / 74.7 / 74.7 px** 降至 **68 / 56 / 56 px**（标题降 33%，正文降 25%；标题是正文的 1.21 倍）。对白正文由 **13 → 56 px**（约 4.31 倍），纸宽由 **660 → 1856 px（25.8% → 72.5%）**。新版标题和这一行对白的屏幕字墨高分别为 **64 / 56 px**（逐像素差分量测，不等于字号设置）。
- **960×540 窗口：** 角色标题／物品行／说明从 **38 / 28 / 28 → 25.5 / 21 / 21 px**；对白 **13 → 21 px**，纸宽 **660 → 696 px（68.8% → 72.5%）**。标题／这行对白字墨高 **24 / 21 px**。
- **3D 预览：** 旧版 `TextureRect` 被源纹理最小尺寸撑大，全屏下 Isaac 实际轮廓下沿超出纸约 **171 px**。新版从 3D 视口 alpha 量得 Isaac 轮廓为 `63×140`，源贴图四边均有透明边；映到 2560×1440 后轮廓离最近槽 **60 px**、离纸外框最近边 **276 px**，960×540 分别 **22.5 / 103.5 px**。头像框本身也不和九槽相交。另试 Reed、Linnet，均完整且不压槽。
- **对白净空：** 正文／按钮至姓名签或立绘最近 **24 px（全屏）／9 px（窗口）**；立绘方框高 **704 / 264 px**，上方和两侧均在安全框内。纸边仍可透出场景。
- **其它窗口：** 1100×540（非 16:9）两档等比居中，保留与 960×540 同一字号；320×180 最小窗检查边缘透景、文字布局与焦点，不将其视为舒适阅读验证。没有在本执行器目视打开远端 PNG 或原参考附件；结果以实帧、逐像素与控制几何检测为依据。

## 同尺截图

每组顺序是：旧角色／新角色，旧对话／新对话。均为原生客户区 PNG，未缩放、裁切或拼接。

- **2560×1440 全屏 · 480 档**：[旧角色](previews/ui-layout/before-fullscreen-480-character.png) / [新角色](previews/ui-layout/fullscreen-480-character.png) · [旧对话](previews/ui-layout/before-fullscreen-480-dialogue.png) / [新对话](previews/ui-layout/fullscreen-480-dialogue.png)
- **2560×1440 全屏 · 320 档**：[旧角色](previews/ui-layout/before-fullscreen-320-character.png) / [新角色](previews/ui-layout/fullscreen-320-character.png) · [旧对话](previews/ui-layout/before-fullscreen-320-dialogue.png) / [新对话](previews/ui-layout/fullscreen-320-dialogue.png)
- **960×540 窗口 · 480 档**：[旧角色](previews/ui-layout/before-window-480-character.png) / [新角色](previews/ui-layout/window-480-character.png) · [旧对话](previews/ui-layout/before-window-480-dialogue.png) / [新对话](previews/ui-layout/window-480-dialogue.png)
- **960×540 窗口 · 320 档**：[旧角色](previews/ui-layout/before-window-320-character.png) / [新角色](previews/ui-layout/window-320-character.png) · [旧对话](previews/ui-layout/before-window-320-dialogue.png) / [新对话](previews/ui-layout/window-320-dialogue.png)

复跑：`godot --path . --script res://tests/ui_layout_checks.gd` 和 `godot --path . --script res://tests/ui_layout_checks.gd -- --320`；实窗执行，不加 `--headless`。另加 `--capture=<已存在的空目录>` 可采集当次全屏／窗口实帧，不覆盖原图。`display_checks.gd` 检查全屏切换、尺寸／位置恢复和最大化，`paper_edge_checks.gd` 检查两种菜单在 960／480／320 下真实透景边缘，`dialogue_checks.gd` 检查两位 NPC、立绘回退、拾取优先级及焦点。相关用例使用隔离夹具，不改玩家存档。

本轮回归：`ui_layout_checks`、`display_checks`、`combat_checks` 两档均零失败；`dialogue_checks`、`paper_edge_checks`、`inventory_ui_checks`、`binding_checks` 和 `growth_checks`（313 项）通过。`device_checks` 以 `--windowed --resolution 960x540` 启动，键鼠和注入的手柄输入通过；直接默认全屏启动该窗口夹具时有两项开头的行走／跑步采样未稳定复现，后续模态锁和输入项通过。未做实体手柄按键确认。
