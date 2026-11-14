// Full-screen film grain and a faint vignette over the whole interface.
// Bible: docs/content/interface-pass.md section 2 (Texture)
shader_type canvas_item;

uniform float grain_strength : hint_range(0.0, 0.2) = 0.035;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float frame = floor(TIME * 24.0);
	float noise = hash(FRAGCOORD.xy + frame) - 0.5;
	vec2 centred = SCREEN_UV - vec2(0.5);
	float vignette = smoothstep(0.35, 0.85, length(centred)) * vignette_strength;
	float light = max(noise, 0.0) * grain_strength;
	float dark = max(-noise, 0.0) * grain_strength + vignette;
	COLOR = vec4(vec3(light > dark ? 1.0 : 0.0), max(light, dark));
}
