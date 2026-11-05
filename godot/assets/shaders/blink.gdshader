shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float surface_roughness = 0.6;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform vec3 eye_center;
uniform vec3 eye_up = vec3(0.0, 1.0, 0.0);
// Only the existing white/iris inlays use this material. Skin, cheeks and
// glasses keep their original materials; no floating eyelid geometry.
void vertex() {
 VERTEX -= eye_up * dot(VERTEX - eye_center, eye_up) * blink * 0.97;
}
void fragment() {
 ALBEDO = base_color.rgb * COLOR.rgb;
 ROUGHNESS = surface_roughness;
}
