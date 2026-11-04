shader_type sky;
// Neutral room/sky reflection with one broad window. Background and diffuse
// ambient are configured separately; this makes coated plastic differ from cloth.
void sky() {
 vec3 base = mix(vec3(0.22,0.21,0.19),vec3(0.38,0.43,0.48),smoothstep(-0.5,0.7,EYEDIR.y));
 vec3 window_direction = normalize(vec3(-0.8,0.55,0.45));
 float window_light = pow(max(dot(EYEDIR,window_direction),0.0),18.0);
 COLOR = base + vec3(1.7,1.6,1.42)*window_light;
}
