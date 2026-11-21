shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;
// Painted meadow banks belong to the landscape, not to a full-screen filter.
uniform vec4 sorrel : source_color = vec4(.380,.565,.320,1);
uniform vec4 fern   : source_color = vec4(.486,.648,.309,1);
uniform vec4 verge  : source_color = vec4(.567,.699,.307,1);
uniform vec4 lawn   : source_color = vec4(.624,.736,.335,1);
uniform vec4 straw  : source_color = vec4(.672,.765,.374,1);
uniform vec4 shade_ink : source_color = vec4(.315,.505,.635,1);
global uniform float moon_ink;
varying vec2 place;
float hash2(vec2 p){p=fract(p*vec2(.1031,.11369));p+=dot(p,p.yx+19.19);return fract((p.x+p.y)*p.x);}
float wash(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash2(i),hash2(i+vec2(1,0)),f.x),mix(hash2(i+vec2(0,1)),hash2(i+1.0),f.x),f.y); }
float bank(vec2 p,vec2 c,vec2 radius,float a){p-=c;return length(vec2(cos(a)*p.x-sin(a)*p.y,sin(a)*p.x+cos(a)*p.y)/radius);}
void vertex(){place=(MODEL_MATRIX*vec4(VERTEX,1.0)).xz;}
void fragment(){
 vec2 p=floor(place*13.0)/13.0;
 vec2 drift=p+vec2(1.48*(wash(p*.43+vec2(3.4,1.9))-.5)+.44*sin(1.45*p.y+.3*p.x),1.25*(wash(p*.52+vec2(5.8,3.2))-.5)+.36*sin(1.35*p.x-.22*p.y));
 float d=min(bank(drift,vec2(-6.35,6.4),vec2(3.65,2.12),.42),bank(drift,vec2(8.50,-1.85),vec2(3.22,1.94),.30));
 d=min(d,bank(drift,vec2(-7.9,-.45),vec2(3.8,2.15),-.38)); d=min(d,bank(drift,vec2(2.0,-8.4),vec2(3.52,2.6),.5));
 d=min(d,bank(drift,vec2(-2.8,-4.0),vec2(3.58,1.05),-.11));
 float edge=d+.58*(wash(p*.77+2.5)-.5)+.33*(wash(p*2.80)-.5);
 float warm=.60*wash(p*.235+2.6)+.25*wash(p*.77)+.15*wash(p*1.72);
 vec3 c=mix(lawn.rgb,straw.rgb,step(.54,warm));c=mix(verge.rgb,c,step(.335,warm));
 c=mix(verge.rgb,c,step(1.21,edge));c=mix(fern.rgb,c,step(.91,edge)); c=mix(sorrel.rgb,c,step(.48,edge));
 ALBEDO=c;ROUGHNESS=1.0;
}
void light(){
 if(LIGHT_IS_DIRECTIONAL){
   float elevation=clamp(dot(NORMAL,LIGHT),0.0,1.0);
   DIFFUSE_LIGHT+=LIGHT_COLOR/PI*mix(shade_ink.rgb,vec3(1),smoothstep(.22,.78,ATTENUATION))*(.82+.18*elevation)*mix(vec3(1.),vec3(.57,.90,3.65),moon_ink);
 }else{
   DIFFUSE_LIGHT+=LIGHT_COLOR/PI*ATTENUATION*(.15+.85*max(dot(NORMAL,LIGHT),0.0));
 }
}
