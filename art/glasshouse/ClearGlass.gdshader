shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float night_mix : hint_range(0.0, 1.0) = 0.0;
uniform float pane_kind = 0.0;
uniform float top_shear = 0.0;

void vertex() {
	VERTEX.y += (UV.x - 0.5) * (1.0 - UV.y) * top_shear;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fresnel = pow(1.0 - clamp(abs(dot(n, v)), 0.0, 1.0), 2.4);
	vec3 reflected = normalize((INV_VIEW_MATRIX * vec4(reflect(-v, n), 0.0)).xyz);
	// Broad hemispheric sky, not a screen sample; also works in the mirror camera.
	float sky = smoothstep(-0.45, 0.75, reflected.y);
	float lobe = smoothstep(-0.2, 0.94, dot(reflected, normalize(vec3(0.42, 0.72, 0.56))));
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge = 1.0 - smoothstep(0.0, 0.036, edge_distance);
	// A broad, soft reflection patch on selected panes, with a thin brighter lip.
	float sweep = UV.y - 0.65 * UV.x + 0.12 * reflected.x;
	float patch = smoothstep(0.02, 0.12, sweep) * (1.0 - smoothstep(0.25, 0.40, sweep));
	float lip = 1.0 - smoothstep(0.012, 0.055, abs(sweep - 0.25));
	float accent = pane_kind * (0.72 * patch + 0.28 * lip) * smoothstep(0.03, 0.16, edge_distance);
	vec3 day = mix(vec3(0.32, 0.54, 0.47), vec3(0.66, 0.84, 0.75), sky * 0.65 + lobe * 0.35);
	vec3 night = mix(vec3(0.115, 0.20, 0.25), vec3(0.26, 0.43, 0.49), sky);
	ALBEDO = mix(day, night, night_mix) + (accent * 0.17 + edge * 0.08) * vec3(0.69, 0.94, 0.92);
	float day_alpha = 0.195 + 0.07 * sky + 0.055 * lobe;
	float night_alpha = 0.095 + 0.04 * sky;
	ALPHA = clamp(mix(day_alpha, night_alpha, night_mix) + 0.155 * fresnel + 0.065 * edge + mix(0.22, 0.11, night_mix) * accent, 0.0, 0.53);
}
