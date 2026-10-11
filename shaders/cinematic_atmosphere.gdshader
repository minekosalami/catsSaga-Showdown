shader_type canvas_item;
// Six decorative layers, evaluated in arena UVs; no screen texture or actors.
uniform float clock = 0.0;
uniform float stage = 0.0;
uniform float pulse = 0.0;
uniform float effect_strength = 0.7;
uniform vec4 accent : source_color = vec4(0.2,0.85,0.95,1.0);
uniform vec4 secondary : source_color = vec4(0.4,0.3,0.7,1.0);
uniform bool flooded = false;
float mist(vec2 p) {
 return sin(p.x*5.7+sin(p.y*4.1))*0.32 + sin(p.y*6.9-p.x*2.2)*0.25 + sin(p.x*13.0+p.y*7.0)*0.12;
}
void fragment() {
 vec2 uv = UV;
 float distortion = sin(uv.y*32.0-clock*1.2)*stage*0.003*effect_strength;
 uv.x += distortion;
 float fog1 = smoothstep(-0.22,0.7,mist(uv*vec2(1.1,1.8)+vec2(clock*0.015,-clock*0.007)));
 float fog2 = smoothstep(0.0,0.85,mist(uv*vec2(2.1,1.0)+vec2(-clock*0.009,clock*0.013)));
 float edge = pow(abs(uv.x-0.5)*2.0,5.0);
 float halo = exp(-length((uv-vec2(0.5,0.27))*vec2(1.0,0.65))*8.0);
 float water = flooded ? pow(0.5+0.5*sin(uv.y*110.0+sin(uv.x*18.0+clock*0.3)+clock*0.7),16.0) : 0.0;
 vec3 hue = mix(accent.rgb,secondary.rgb,uv.y*0.65);
 vec3 color = hue*(fog1*0.055+fog2*0.022+halo*(0.08+stage*0.08+pulse*0.025)+water*0.012);
 color += accent.rgb*edge*(0.035+stage*0.04+pulse*0.02);
 // Veil deepens smoothly; bright geometry and fog stay below bullet contrast.
 COLOR = vec4(color, (0.16+stage*0.42)*effect_strength);
}
