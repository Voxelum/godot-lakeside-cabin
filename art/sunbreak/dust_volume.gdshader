shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled, shadows_disabled, fog_disabled;
// Analytic box entry + eight density samples IN A WORLD-SPACE SHAFT. In an
// orthographic view each eye ray is parallel. Stop at the nearest opaque surface;
// never paint a stripe over a wall/foreground traveller merely because it is in a box.
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform float optical_density = 0.0;
uniform vec4 honey : source_color = vec4(1.0, 0.886, 0.604, 1.0);
varying vec3 box_entry;
varying vec3 box_ray;
void vertex(){
	box_entry = VERTEX;
	box_ray = mat3(inverse(MODEL_MATRIX)) * -INV_VIEW_MATRIX[2].xyz;
}
float edge_exit(float p, float d, float edge){
	if(abs(d) < 0.00001) return 1000.0;
	return (sign(d)*edge-p)/d;
}
void fragment(){
	float d = textureLod(scene_depth,SCREEN_UV,0.0).r;
	vec4 opaque = INV_PROJECTION_MATRIX * vec4(SCREEN_UV*2.0-1.0,mix(CLIP_SPACE_FAR,1.0,d),1.0);
	float until_hit = -opaque.z/opaque.w + VERTEX.z;
	float until_box = min(min(edge_exit(box_entry.x,box_ray.x,1.0),edge_exit(box_entry.y,box_ray.y,0.5)), edge_exit(box_entry.z,box_ray.z,1.0));
	float step_m = min(until_box,until_hit)/8.0;
	if(step_m <= 0.0001) discard;
	float sum_density=0.0;
	for(int i=0;i<8;i++){
		vec3 p=box_entry+box_ray*(float(i)+0.5)*step_m;
		float h=clamp(p.y+0.5,0.0,1.0);
		float r=mix(1.0,0.51,h);
		float r2=dot(p.xz,p.xz)/(r*r);
		float radial=(0.77+0.23*exp(-3.6*r2))*(1.0-smoothstep(0.12,1.0,r2));
		float ends=smoothstep(0.002,0.14,h)*(1.0-smoothstep(0.88,1.0,h));
		sum_density+=radial*ends;
	}
	ALBEDO=honey.rgb;
	ALPHA=min(0.36,1.0-exp(-1.55*optical_density*sum_density*step_m));
}
