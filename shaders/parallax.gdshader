shader_type canvas_item;
// Slowly drifting backdrop layer. Set scroll via uniform (script feeds tab/scroll offset) plus gentle idle drift.
uniform vec2 scroll = vec2(0.0);
uniform vec2 drift = vec2(0.004, 0.0);
uniform vec4 tint : source_color = vec4(1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
void fragment() {
	vec2 uv = UV + scroll + drift * TIME;
	vec4 t = texture(TEXTURE, fract(uv)) * tint;
	float v = 1.0 - vignette * pow(distance(UV, vec2(0.5)) * 1.4, 2.0);
	COLOR = vec4(t.rgb * v, t.a);
}
