@tool
extends RefCounted
## Short tiled slopes for attached roofs. The same dimensions drive the fascia
## and the tile courses, so no tile overhangs its own sub-roof.
const Batch := preload("res://art/building_trial/mesh_batch.gd")

static func slope(b: Batch, a: Vector3, c: Vector3, d: Vector3, e: Vector3,
		ink: Color, fascia: Color, rows: int) -> void:
	# a,c low edge; d,e high edge, in the same left-to-right order.
	b.quad(a,c,e,d,Vector3.UP,ink.darkened(.29))
	var dip := Vector3.DOWN * .085
	b.quad(a+dip,d+dip,e+dip,c+dip,Vector3.DOWN,fascia.darkened(.23),1)
	for edge in [[a,c], [a,d], [c,e]]:
		var p: Vector3 = edge[0]
		var q: Vector3 = edge[1]
		b.bar(p+dip*.63,q+dip*.63,.108,.107,fascia,Vector3.UP,1)
	var across := maxi(2,roundi(a.distance_to(c)/.37))
	for j in rows:
		var t0 := float(j)/rows
		var t1 := float(j+1)/rows
		var start := a.lerp(d,t0)
		var end := c.lerp(e,t0)
		var high_start := a.lerp(d,t1)
		var high_end := c.lerp(e,t1)
		for i in range(-1,across):
			var stagger := .50 * (j%2)
			var u0 := maxf(.0,(float(i)+stagger+.013)/across)
			var u1 := minf(1.,(float(i+1)+stagger-.013)/across)
			if u1-u0 < .005:
				continue
			var lip := Vector3.UP*.044
			var upper := Vector3.UP*.021
			var p := start.lerp(end,u0)+lip
			var q := start.lerp(end,u1)+lip
			var r := high_start.lerp(high_end,u1)+upper
			var s := high_start.lerp(high_end,u0)+upper
			var roll := p.lerp(q,.23)+Vector3.UP*.021
			var roll_end := s.lerp(r,.23)+Vector3.UP*.016
			var tint := Batch.tone(ink,.104*sin(3.71*i + 5.26*j))
			b.quad(p,roll,roll_end,s,Vector3.UP,tint.lightened(.13))
			b.quad(roll,q,r,roll_end,Vector3.UP,tint)
			b.quad(p-lip,q-lip,q,p,(a+c-d-e).normalized(),tint.darkened(.27))
