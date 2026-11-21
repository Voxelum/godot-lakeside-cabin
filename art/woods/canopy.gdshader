shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled;
// Five ink swatches across a bent volume; small grouped leaf marks break only
// the transitions. No time/noise animation, temporal AA or screen-space filter.
uniform vec4 recess : source_color = vec4(.137,.289,.259,1);
uniform vec4 pine   : source_color = vec4(.164,.375,.289,1);
uniform vec4 jade   : source_color = vec4(.218,.459,.316,1);
uniform vec4 leaf   : source_color = vec4(.323,.553,.328,1);
uniform vec4 lime   : source_color = vec4(.466,.633,.332,1);
uniform vec4 gold   : source_color = vec4(.606,.700,.367,1);
global uniform float moon_ink;
varying vec3 wood_pos;
varying float height_bias;
varying float leaves;
float h3(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float grain(vec3 p){vec3 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);return mix(mix(mix(h3(i),h3(i+vec3(1,0,0)),f.x),mix(h3(i+vec3(0,1,0)),h3(i+vec3(1,1,0)),f.x),f.y),mix(mix(h3(i+vec3(0,0,1)),h3(i+vec3(1,0,1)),f.x),mix(h3(i+vec3(0,1,1)),h3(i+1.0),f.x),f.y),f.z);}
void vertex(){ wood_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; height_bias=COLOR.g; leaves=COLOR.r; }
void fragment(){ALBEDO=vec3(1);ROUGHNESS=1.0;}
void light(){
 vec3 p=floor(wood_pos*14.0)/14.0;
 float patch=grain(p*2.35)+.48*grain(p*vec3(5.8,5.2,4.6));
 float value=dot(normalize(NORMAL),LIGHT)*.42 + height_bias*.27 + .215 + .27*(patch-.72) + leaves*.105;
 // Even trees growing inside their own shade keep a cool reflected-light band.
 value-=.285*(1.0-smoothstep(.15,.78,ATTENUATION));
 vec3 c=recess.rgb; c=mix(c,pine.rgb,step(.14,value)); c=mix(c,jade.rgb,step(.34,value));c=mix(c,leaf.rgb,step(.52,value));c=mix(c,lime.rgb,step(.68,value));c=mix(c,gold.rgb,step(.815,value));
 // Custom light accumulates linear irradiance even in the GL path. Convert the
 // selected sRGB ink, so the darkest leaves stay forest green, not pale mint.
 vec3 pigment=OUTPUT_IS_SRGB ? mix(c/12.92,pow((c+vec3(.055))/1.055,vec3(2.4)),step(vec3(.04045),c)) : c;
 if (LIGHT_IS_DIRECTIONAL) {
   DIFFUSE_LIGHT+=pigment*LIGHT_COLOR/PI*mix(vec3(1.),vec3(.69,.98,1.91),moon_ink);
 } else {
   DIFFUSE_LIGHT+=pigment*LIGHT_COLOR/PI*ATTENUATION*(.24+.76*max(dot(NORMAL,LIGHT),0.0));
 }
}
