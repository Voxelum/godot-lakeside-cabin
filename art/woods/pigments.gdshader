shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
// Vertex colors mark individual stone faces, bark planes, petals and grass.
uniform vec4 occluded : source_color = vec4(0.585,0.638,0.695,1.0);
void fragment(){ ALBEDO=COLOR.rgb; ROUGHNESS=1.0; }
void light(){
 float n=dot(normalize(NORMAL),LIGHT);
 float tone=mix(.35,.71,step(.04,n)); tone=mix(tone,.88,step(.37,n)); tone=mix(tone,1.0,step(.67,n));
 if (LIGHT_IS_DIRECTIONAL) {
   DIFFUSE_LIGHT+=LIGHT_COLOR/PI*mix(occluded.rgb,vec3(1.0),tone*smoothstep(.18,.8,ATTENUATION));
 } else {
   DIFFUSE_LIGHT+=LIGHT_COLOR/PI*ATTENUATION*(.14+.86*max(n,0.0));
 }
}
