shader_type spatial;
render_mode unshaded, shadows_disabled, cull_back, depth_draw_never, depth_test_disabled;
// An optional, muted travelling silhouette, drawn ONLY behind real opaque geometry.
// The delay is in sightline.gd: brief crossings still read as true occlusion.
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float strength = 0.0;
void fragment(){
	float sampled = textureLod(scene_depth, SCREEN_UV, 0.0).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, mix(CLIP_SPACE_FAR, 1.0, sampled), 1.0);
	float separation = -VERTEX.z + view.z / view.w;
	if (separation < 0.64) discard;
	ALBEDO = mix(vec3(0.24,0.35,0.36),vec3(0.70,0.81,0.72),step(0.10, dot(NORMAL,normalize(vec3(-0.4,0.8,0.45)))));
	ALPHA = strength;
}
