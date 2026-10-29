shader_type canvas_item;
// Warm light pool. Put on a ColorRect/TextureRect, use with blend_add or on top of the backdrop.
uniform vec4 glow_color : source_color = vec4(0.949, 0.722, 0.294, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 0.8;
uniform float radius : hint_range(0.05, 1.0) = 0.5;
uniform float flicker : hint_range(0.0, 0.3) = 0.06;
uniform float speed = 1.3;
uniform vec2 center = vec2(0.5, 0.5);
void fragment() {
	float d = distance(UV, center) / radius;
	float f = 1.0 + flicker * (sin(TIME * speed * 3.1) * 0.5 + sin(TIME * speed * 7.3 + 1.7) * 0.5);
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.0) * intensity * f;
	COLOR = vec4(glow_color.rgb, a);
}
