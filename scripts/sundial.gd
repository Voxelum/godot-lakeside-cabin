extends Node2D
## A small pixel-set dial; no system fonts and no HUD in the reflected viewport.
const DIGITS: Array[int]=[0b111101101101111,0b010110010010111,0b111001111100111,0b111001111001111,0b101101111001001,0b111100111001111,0b111100111101111,0b111001010010010,0b111101111101111,0b111101111001111]
var clock: Node
var minutes := -1
var paused := false
var day := false
func _ready()->void: clock=get_tree().get_first_node_in_group(&"solar_clock")
func _process(_delta:float)->void:
	if not clock: return
	visible=clock.show_dial
	var t:=floori(float(clock.hour)*60.);var is_day:bool=clock.daylight>.42
	if t!=minutes or paused!=clock.halted or day!=is_day:
		minutes=t;paused=clock.halted;day=is_day;queue_redraw()
func px(x:int,y:int,w:int,h:int,c:Color)->void:draw_rect(Rect2(x,y,w,h),c)
func digit(index:int,x:int,c:Color)->void:
	for row in 5:
		for col in 3:
			if DIGITS[index] & (1<<(14-row*3-col)):px(x+col,5+row,1,1,c)
func _draw()->void:
	if minutes<0:return
	var trim:=Color("b99b69") if day else Color("8290b9");var face:=Color("203034e9");var light_ink:=Color("f9edbf") if day else Color("dee7fa")
	px(1,1,44,15,Color("14232c95"));px(0,1,45,12,face);px(1,0,43,14,face);px(2,1,41,1,trim.darkened(.42));px(2,12,41,1,trim.darkened(.43))
	if day:
		px(5,5,5,5,Color("dda859"));px(6,4,3,7,Color("f6ce79"));px(3,7,1,1,trim);px(11,7,1,1,trim);px(7,3,1,1,trim);px(7,11,1,1,trim)
	else:
		px(5,5,3,5,light_ink);px(6,4,2,1,light_ink);px(7,9,3,2,light_ink);px(10,8,1,2,light_ink);px(11,4,1,1,trim)
	var hh:=minutes/60;var mm:=minutes%60;digit(hh/10,15,light_ink);digit(hh%10,20,light_ink);px(25,6,1,1,trim);px(25,8,1,1,trim);digit(mm/10,28,light_ink);digit(mm%10,33,light_ink)
	if paused:px(39,5,1,5,trim);px(41,5,1,5,trim)
	else:px(39,7,1,2,trim)
