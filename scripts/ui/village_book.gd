extends Panel
const Layout := preload("res://scripts/ui/ui_layout.gd")
var text := Label.new()
var note := ""
var session
var caravan := preload("res://world/outskirts/market_caravan.gd").new()
var worker: Node3D
var worker_tag: Label3D
var tag := Label3D.new()
const FarmSite := preload("res://world/outskirts/village_pasture.gd")
var grounds: Node3D
const Survey := preload("res://world/outskirts/outskirts_profile.gd")
var pack: MeshInstance3D

func install(s) -> void:
	session = s
	s.host.add_child(self); hide(); mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text); text.position = Vector2(22,15); Layout.ink(text,Layout.BODY)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layout = s.host.get_node("UILayout")
	var fit := func(): layout.place(self,Rect2(52,12,536,334))
	layout.changed.connect(fit); fit.call()
	var resident = s.host.field.find_child("NetMender",true,false)
	if resident:
		resident.add_child(tag); tag.position.y = 2.0; tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED; tag.font_size=24; tag.pixel_size=.004; tag.visibility_range_end=9
		worker=preload("res://art/field_cast/field_looks.gd").new(); resident.get_parent().add_child(worker)
		worker_tag=Label3D.new(); worker.add_child(worker_tag); worker_tag.position.y=1.85; worker_tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED; worker_tag.font_size=24; worker_tag.pixel_size=.004; worker_tag.visibility_range_end=9
		pack=MeshInstance3D.new(); var crate:=BoxMesh.new(); crate.size=Vector3(.56,.42,.38); var wood:=StandardMaterial3D.new(); wood.albedo_color=Color("aa7344"); crate.material=wood; pack.mesh=crate; worker.add_child(pack); pack.position=Vector3(0,.92,.32)
	grounds=s.host.field.get_node("Clearing/Outskirts/VillageFarm")

func near(grass:=false) -> bool:
	if session.host.indoors: return false
	var p:Vector3=grounds.to_local(session.host.active_actor().global_position)
	var area:Rect2=FarmSite.GRASS if grass else FarmSite.FIELD
	return area.grow(.48).has_point(Vector2(p.x,p.z))

func refresh() -> void:
	var ledger = session.state.village; var d: Dictionary = ledger.d
	if not caravan.is_inside_tree(): session.host.field.add_child(caravan)
	caravan.update_view(d)
	if worker:
		var h:=int(d.hour)%24
		var site:=grounds.get_parent(); worker.global_position=site.worker_station(h)
		worker_tag.text="住户 · "+ledger.duty()
		pack.visible=d.cart_eta>0
		if pack.visible:
			var lane:Path3D=site.get_node("LocalProduceRoute")
			var t:=clampf((2.0-float(d.cart_eta)+(float(d.seconds)/5.0 if d.road else 0.0))*.5,0,1)
			var at:=lane.curve.get_baked_length()*t; var pos:=lane.curve.sample_baked(at); var next:=lane.curve.sample_baked(at+.04)
			worker.global_position=lane.to_global(pos); worker.rotation.y=atan2(next.x-pos.x,next.z-pos.z)
			worker_tag.text="本村送货 · %s"%("草仓至秤棚" if d.road else "封路等待")
		tag.text="井边村农场 · J 账册"
	grounds.grow(d.crop)
	if not visible: return
	var goods: Dictionary=d.store; var wagon: Dictionary=d.wagon
	text.text=("井边村收支簿　　第 %d 日　%02d:00　　J / Esc 合上\n居民一家三口：%s\n家用 %d　村库 %d　车队 %d　　健康 %d/10　累计缺餐 %d\n家中晚饭 %d/3　麦种 %d　生长 %d/3 · %s　草 %d / 干草 %d\n原麦 %d → 面粉 %d → 面包 %d　　蛋 %d　奶 %d　毛 %d\n铁料 %d　工具 %d　　累计出口 +%d / 进口 −%d\n车队：口粮 %d　铁 %d　已收工具 %d / 毛 %d / 蛋 %d / 奶 %d\n在途 %d 批%s　　道路：%s\nN 推进一小时　B 切换通路　G 农户代种：%s\n麦田 P 播种 / 浇水 / 收割　草甸 H 割草\n%s" % [1+int(d.hour)/24,int(d.hour)%24,ledger.duty(),d.purse.family,d.purse.village,d.purse.caravan,d.health,d.missed,d.meal,d.seed,d.crop,"已浇" if d.wet else "干燥",d.grass,d.hay,d.wheat,d.flour,goods.bread,goods.egg,goods.milk,goods.wool,goods.iron,goods.tool,d.paid_in,d.paid_out,wagon.bread,wagon.iron,wagon.tool,wagon.wool,wagon.egg,wagon.milk,d.cargo.size(),"" if d.cargo.is_empty() else " · 余 %d 行车小时"%d.cargo[0].eta,"开放" if d.road else "中断","开" if d.auto_farm else "关",note])

	text.text += "\n场仓 粮%d / 毛%d / 工具%d　村车 粮%d · 余%d小时" % [d.shed.bread+d.shed.egg+d.shed.milk,d.shed.wool,d.shed.tool,d.cart.bread+d.cart.egg+d.cart.milk,d.cart_eta]
	text.text += "\n上次采购：%s　返家提篮 %d 份" % [["未到集市","购齐三份","家用不足","道路中断","货架缺粮"][d.shop_result],d.basket]

func key(code: int) -> void:
	var l=session.state.village
	match code:
		KEY_N: l.step()
		KEY_B: l.d.road=not l.d.road
		KEY_G: l.d.auto_farm=not l.d.auto_farm
		KEY_P,KEY_H:
			note = (l.tend() if code==KEY_P else l.cut()) if near(code==KEY_H) else ("请到牛羊舍前的放牧草甸。" if code==KEY_H else "请走进乡道旁的麦田。")
	refresh()
