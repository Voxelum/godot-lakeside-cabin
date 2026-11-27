shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
// Metre-scale pools, not independent pixels. Fixed offsets are the pigment seed.
uniform vec4 loam : source_color = vec4(.48,.355,.247,1);
uniform vec4 packed : source_color = vec4(.64,.505,.355,1);
uniform vec4 verge : source_color = vec4(.55,.56,.303,1);
uniform vec4 shade_ink : source_color = vec4(.315,.505,.635,1);
global uniform float moon_ink;
varying vec2 place;
float hash2(vec2 p){p=fract(p*vec2(.1031,.11369));p+=dot(p,p.yx+19.19);return fract((p.x+p.y)*p.x);}
float wash(vec2 p){vec2 i=floor(p),f=fract(p); f=f*f*(3.-2.*f);return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+1.),f.x),f.y);}
void vertex(){place=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
 vec2 p=floor(place*13.)/13.; float drift=wash(p*.74+3.1); float patch=wash(p*1.55+8.6);
 float u=abs(UV.x+.16*(drift-.5)); float edge=u+.34*(patch-.5)+.23*(drift-.5);
 if(edge>.95) discard;
 float wear=UV.y<.5 ? 1.-smoothstep(.07,.38,abs(u-.43)) : 1.-smoothstep(.16,.78,u);
 float pigment=.34*wear+.51*drift+.15*patch;
 vec3 clay=mix(loam.rgb,packed.rgb,.12+floor(clamp(pigment,0.,.999)*5.)*.21);
 ALBEDO=mix(clay,verge.rgb,.72*step(.75,edge)); ROUGHNESS=1.;
}
void light(){if(LIGHT_IS_DIRECTIONAL){DIFFUSE_LIGHT+=LIGHT_COLOR/PI*mix(shade_ink.rgb,vec3(1),smoothstep(.22,.78,ATTENUATION))*(.82+.18*clamp(dot(NORMAL,LIGHT),0.,1.))*mix(vec3(1.),vec3(.57,.90,3.65),moon_ink);}else{DIFFUSE_LIGHT+=LIGHT_COLOR/PI*ATTENUATION*(.15+.85*max(dot(NORMAL,LIGHT),0.));}}
