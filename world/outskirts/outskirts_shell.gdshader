shader_type spatial;
render_mode specular_disabled, ambient_light_disabled;
// Vertex paint plus the meadow's 13 samples/m, with broad pigment on limewash
// and clay roof faces rather than a high-frequency trial-panel finish.
global uniform float moon_ink;
varying vec3 place;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * vec3(.1031,.11369,.13787));
	p += dot(p,p.yzx+19.19);
	return fract((p.x+p.y)*p.z);
}
void vertex() {
	place = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	vec3 brush = floor(place*13.0)/13.0;
	float grit = hash3(floor(brush*13.0+.5));
	float wash = .55 * sin(brush.x*3.2 + brush.z*2.7 + 1.4*sin(brush.y*4.3));
	wash += .44 * cos(brush.x*6.9 - brush.y*2.5 + brush.z*3.9);
	float pigment = .985 + .039*step(-.05,wash) - .036*step(wash,-.59);
	pigment += .035*step(.91,grit) - .034*step(grit,.09);
	if (abs(UV.x-1.0)<.45) {
		vec3 grain = abs(local_normal.y)>.6 ? vec3(3.2,12.,3.2) : vec3(11.9,1.3,12.7);
		pigment *= .939 + .114 * hash3(floor(brush*grain+.5));
	}
	if (abs(UV.x-3.0)<.45) {
		pigment = 1.0;
		// Use the original almanac's shared night phase; no separate dusk toggle.
		EMISSION = vec3(.65,.33,.15) * moon_ink * (.38+.24*COLOR.r);
	}
	ALBEDO = COLOR.rgb * pigment;
	ROUGHNESS = 1.0;
}
void light() {
	float n = dot(normalize(NORMAL),LIGHT);
	if (LIGHT_IS_DIRECTIONAL) {
		float tone = mix(.69,.85,smoothstep(.04,.44,n));
		tone = mix(tone,1.02,smoothstep(.38,.80,n));
		DIFFUSE_LIGHT += LIGHT_COLOR/PI * mix(vec3(.585,.638,.695),vec3(tone),smoothstep(.18,.8,ATTENUATION));
	} else {
		DIFFUSE_LIGHT += LIGHT_COLOR/PI * ATTENUATION * (.17+.83*max(n,0.0));
	}
}
