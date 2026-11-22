shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform bool dusk = false;
uniform vec4 sky_ink : source_color = vec4(.53, .59, .69, 1);
varying vec3 place;
varying vec3 face_normal;

float hash_cell(vec3 p) {
	p = fract(p * vec3(.1031, .11369, .13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	place = VERTEX;
	face_normal = NORMAL;
}

void fragment() {
	float finish = UV.x;
	vec3 s = floor(place * 14.0) / 14.0;
	float grit = hash_cell(floor(s * 14.0 + .5));
	float smear = hash_cell(floor(s * vec3(3.0, 12.0, 3.0)) + .7);
	float wash = hash_cell(floor(s * vec3(1.7, 2.9, 1.8)) + 1.3);
	float paint = .973 + .054 * wash + .049 * step(.93, grit) - .042 * step(grit, .057);
	if (finish > .5 && finish < 1.5) {
		float fibers = abs(face_normal.y) > .6 ? smear : hash_cell(floor(s * vec3(16., 1.4, 17.)) + 2.4);
		paint *= .928 + .136 * fibers;
	} else if (finish > 2.5 && finish < 3.5) {
		// The panes and glass lanterns retain graphic-color accents.
		paint = 1.0;
		if (dusk) {
			EMISSION = vec3(.67, .30, .11) * (.44 + .44 * COLOR.r);
		}
	} else if (finish > 3.5) {
		// Larger contiguous pigment islands under the planted mesh.
		float field = cos(s.x * .91 + sin(s.z * .54)) + .80 * sin(s.z * .92 + s.x * .35) + .36 * cos(s.z * 2.29 + s.x * 1.91);
		paint *= .92 + .065 * step(-.48, field) + .07 * step(.46, field) + .038 * step(1.4, field);
	}
	ALBEDO = COLOR.rgb * paint;
	ROUGHNESS = 1.0;
}

void light() {
	float n = dot(NORMAL, LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float tone = mix(.70, .83, smoothstep(.02, .38, n));
		tone = mix(tone, 1.04, smoothstep(.40, .78, n));
		vec3 pigment = mix(sky_ink.rgb, vec3(tone), smoothstep(.18, .80, ATTENUATION));
		DIFFUSE_LIGHT += LIGHT_COLOR * pigment / PI;
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (.18 + .82 * max(n, 0.0)) / PI;
	}
}
