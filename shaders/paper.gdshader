shader_type canvas_item;
// Parchment grain + soft edge darkening. Apply to a ColorRect/Panel filled with parchment.
uniform vec4 paper_color : source_color = vec4(0.918, 0.875, 0.784, 1.0);
uniform float grain : hint_range(0.0, 0.2) = 0.06;
uniform float edge_burn : hint_range(0.0, 0.6) = 0.22;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1,0)), f.x), mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x), f.y);
}
void fragment() {
	float n = noise(UV * 220.0) * 0.6 + noise(UV * 40.0) * 0.4;
	vec3 c = paper_color.rgb * (1.0 - grain + n * grain * 2.0);
	vec2 e = min(UV, 1.0 - UV);
	float edge = smoothstep(0.0, 0.12, min(e.x, e.y));
	c *= mix(1.0 - edge_burn, 1.0, edge);
	COLOR = vec4(c, texture(TEXTURE, UV).a * paper_color.a);
}
