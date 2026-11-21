shader_type canvas_item;
render_mode unshaded;
// Work in texel centres of the *game*, not in window UV or clip space.
// The same material composes either world's ViewportTexture onto the fitted rect.
uniform bool shutter = false;
uniform vec2 buffer_size = vec2(480.0,270.0);
uniform vec2 threshold_px = vec2(200.0,150.0);
uniform float radius_px = 0.0;
void fragment() {
	vec2 texel = floor(UV * buffer_size) + vec2(0.5);
	vec4 scene = texture(TEXTURE, UV);
	bool visible_here = !shutter || (radius_px > 0.0 && distance(texel, threshold_px) < radius_px);
	COLOR = visible_here ? vec4(scene.rgb, 1.0) : vec4(0.0,0.0,0.0,1.0);
}
