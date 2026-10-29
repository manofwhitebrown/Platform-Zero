shader_type canvas_item;
// Full-screen vignette + film grain. Put on a ColorRect over the world.
uniform float vignette : hint_range(0.0, 1.0) = 0.55;
uniform float grain : hint_range(0.0, 0.3) = 0.07;
uniform float t = 0.0;
uniform vec2 res = vec2(1080.0, 1920.0);

void fragment() {
	float d = distance(UV, vec2(0.5)) * 1.25;
	float v = smoothstep(0.35, 1.0, d) * vignette;
	float n = fract(sin(dot(floor(UV * res * 0.5) + vec2(t * 37.0, t * 91.0), vec2(12.9898, 78.233))) * 43758.5453);
	float g = (n - 0.5) * grain;
	float a_black = v + max(-g, 0.0);
	float a_white = max(g, 0.0);
	float a = clamp(a_black + a_white, 0.0, 1.0);
	float w = a_white / max(a, 0.0001);
	COLOR = vec4(vec3(w), a);
}
