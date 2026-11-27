shader_type canvas_item;
render_mode unshaded;

float grain(vec2 p) {
	return fract(sin(dot(mod(p, 289.0), vec2(127.1, 311.7))) * 43758.5453);
}

float cloud(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(grain(i), grain(i + vec2(1,0)), f.x),
		mix(grain(i + vec2(0,1)), grain(i + vec2(1,1)), f.x), f.y);
}

float nick(float x, float center, float width, float depth) {
	return depth * max(0.0, 1.0 - abs(x - center) / width);
}

void fragment() {
	vec2 p = UV * vec2(408.0, 186.0);
	float top = 2.0 + 1.1 * sin(p.x * .035) + nick(p.x, 101.0, 11.0, 5.2) + nick(p.x, 326.0, 6.0, 3.2);
	float bottom = 2.2 + 1.1 * cos(p.x * .048) + nick(p.x, 263.0, 16.0, 5.2);
	float left = 2.3 + sin(p.y * .062) + nick(p.y, 117.0, 11.0, 5.9);
	float right = 2.2 + cos(p.y * .089) + nick(p.y, 49.0, 9.0, 5.5);
	float edge = min(min(p.y - top, 186.0 - p.y - bottom), min(p.x - left, 408.0 - p.x - right));
	vec2 q = min(p, vec2(408.0, 186.0) - p);
	edge = min(edge, (q.x + q.y - 6.0) * .71);
	edge += (cloud(p * .61) - .5) * 1.25;
	float age = exp(-max(edge, 0.0) * .100) * (.79 + .22 * cloud(p * .14));
	vec3 cream = vec3(.969, .885, .719);
	vec3 old = vec3(.60, .368, .179);
	float fiber = (cloud(p * vec2(1.05, .26)) - .5) * .041;
	float mottles = (cloud(p * .051) - .5) * .088 + (cloud(p * .20) - .5) * .027;
	vec3 paper = mix(cream, old, age) + fiber + mottles;
	// Sparse engraved corner strokes, not an outer rectangular border.
	float corner = min(abs(q.x - 10.0) + max(q.y - 23.0, 0.0), abs(q.y - 9.0) + max(q.x - 27.0, 0.0));
	float ornament = (1.0 - smoothstep(.20, .95, corner)) * step(8.0, min(q.x, q.y));
	float diamond = abs(abs(q.x - 14.0) + abs(q.y - 13.0) - 2.3);
	ornament = max(ornament, 1.0 - smoothstep(.15, .95, diamond));
	float aa = max(fwidth(edge), .45);
	COLOR = vec4(mix(paper, vec3(.37, .22, .116), ornament * .56), smoothstep(-aa * .5, aa * .5, edge));
}
