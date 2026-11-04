shader_type canvas_item;
void fragment() {
 vec4 face = texture(TEXTURE,UV);
 float radius = length(UV-vec2(0.5));
 vec3 mint = mix(vec3(0.62,0.82,0.72),vec3(0.84,0.94,0.83),1.0-UV.y);
 vec3 portrait = mix(mint,face.rgb,face.a);
 portrait = mix(portrait,vec3(1.0,0.96,0.85),smoothstep(0.46,0.475,radius));
 COLOR = vec4(portrait,1.0-smoothstep(0.48,0.5,radius));
}
