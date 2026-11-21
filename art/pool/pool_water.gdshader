shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D mirror_tex : filter_nearest, repeat_disable;
uniform bool mirror_ready = false;
uniform vec3 mirror_origin;
uniform vec3 mirror_right;
uniform vec3 mirror_up;
uniform vec2 mirror_resolution = vec2(480.0, 270.0);
uniform float day_amount : hint_range(0.0, 1.0) = 1.0;
varying vec3 world_point;
varying vec2 basin_point;
varying float shore;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 plan = VERTEX.xz - vec2(0.0, 0.6);
	basin_point = vec2(dot(plan, vec2(0.8660254, -0.5)), dot(plan, vec2(0.5, 0.8660254)));
	shore = COLOR.r;
}

vec3 lit_tap(vec2 uv) {
	vec4 s = texture(mirror_tex, uv);
	float peak = max(s.r, max(s.g, s.b));
	return s.rgb * s.a * smoothstep(0.32, 0.85, peak);
}

void fragment() {
	vec3 delta = world_point - mirror_origin;
	// Project directly to normalized top-left ViewportTexture coordinates.
	vec2 uv = vec2(0.5 + dot(delta, mirror_right), 0.5 - dot(delta, mirror_up));
	vec2 pixel = floor(uv * mirror_resolution);
	if (!mirror_ready) {
		pixel = floor(vec2(basin_point.x, -0.6 * basin_point.y) * 19.5);
	}
	float row = pixel.y;
	float wave = sin(row * 0.32 + TIME * 0.74) * (0.72 + 0.28 * sin(row * 0.095 - TIME * 0.36 + pixel.x * 0.029));
	float shift_x = sign(wave) * floor(abs(wave) * 2.45 + 0.1);
	vec2 sample_uv = (pixel + vec2(0.5 + shift_x, 0.5)) / mirror_resolution;

	// A broad, asymmetric depression, with a shallower shelf along the near bank.
	vec2 p = basin_point;
	float bed = smoothstep(0.26, 1.0, abs(p.y - (6.28 + 0.31 * sin(p.x * 0.54))) * 0.40);
	float lobe = smoothstep(-0.63, 0.81, sin(p.x * 0.82 - p.y * 1.14) * 0.73 + cos(p.x * 0.39 + p.y * 1.7) * 0.34);
	float rim = smoothstep(0.03, 0.89, shore);
	vec3 trench = mix(vec3(0.058, 0.077, 0.157), vec3(0.055, 0.209, 0.232), day_amount);
	vec3 shelf = mix(vec3(0.091, 0.148, 0.223), vec3(0.108, 0.345, 0.346), day_amount);
	vec3 shallows = mix(vec3(0.104, 0.190, 0.219), vec3(0.273, 0.460, 0.359), day_amount);
	vec3 water = mix(trench, shelf, clamp(bed * 0.69 + lobe * 0.33, 0.0, 1.0));
	float pockets = sin(p.x * 2.1 + p.y * 0.7) * sin(p.y * 2.4 - p.x * 0.77);
	water = mix(water, shallows * (0.87 + pockets * 0.12), rim * (0.68 + pockets * 0.18));
	float bank_line = smoothstep(0.32, 0.60, shore) * (1.0 - smoothstep(0.68, 0.80, shore));
	float bank_break = smoothstep(0.49, 0.84, sin(p.x * 2.4 + p.y * 1.55));
	water += mix(vec3(0.022, 0.043, 0.044), vec3(0.029, 0.055, 0.045), day_amount) * bank_line * bank_break;

	if (mirror_ready && all(greaterThan(sample_uv, vec2(0.0))) && all(lessThan(sample_uv, vec2(1.0)))) {
		vec4 reflection = texture(mirror_tex, sample_uv);
		float peak = max(reflection.r, max(reflection.g, reflection.b));
		float glow = smoothstep(0.24, 0.77, peak);
		vec3 reflected = reflection.rgb * mix(vec3(0.83, 0.88, 1.0), vec3(0.74, 0.94, 0.97), day_amount);
		float amount = reflection.a * (mix(0.43, 0.54, day_amount) + glow * 0.35) * (1.0 - rim * 0.38);
		water = mix(water, reflected + water * 0.25, amount);
		// Only luminous source pixels bleed across a ripple; dark silhouettes stay readable.
		vec2 dx = vec2(1.0 / mirror_resolution.x, 0.0);
		float streak = 0.045 + 0.095 * smoothstep(0.31, 0.89, abs(wave));
		water += (lit_tap(sample_uv - dx) + lit_tap(sample_uv + dx)
			+ (lit_tap(sample_uv - dx * 2.0) + lit_tap(sample_uv + dx * 2.0)) * 0.36) * streak;
	}

	float band = sin(row * 0.39 + TIME * 0.16);
	float line = smoothstep(0.89, 0.99, band);
	float segment = smoothstep(0.63, 0.96, sin((pixel.x + TIME * 2.25) * 0.074 + row * 1.72));
	float envelope = smoothstep(-0.19, 0.89, sin(row * 0.146 + TIME * 0.23 + pixel.x * 0.015));
	water += mix(vec3(0.032, 0.056, 0.079), vec3(0.068, 0.101, 0.096), day_amount) * line * segment * envelope * (1.0 - rim * 0.8);
	ALBEDO = water;
}
