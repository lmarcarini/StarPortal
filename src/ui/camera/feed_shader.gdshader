// Security camera look: the low-resolution feed upscaled with scanlines, grain and a slight
// bloom on bright parts. Bible: docs/content/interface-pass.md sections 1 and 2
shader_type canvas_item;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.25;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.06;
uniform float bloom : hint_range(0.0, 1.0) = 0.25;
uniform float lines = 240.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec3 base = texture(TEXTURE, UV).rgb;
	vec3 blur = (texture(TEXTURE, UV + vec2(px.x, 0.0)).rgb + texture(TEXTURE, UV - vec2(px.x, 0.0)).rgb
		+ texture(TEXTURE, UV + vec2(0.0, px.y)).rgb + texture(TEXTURE, UV - vec2(0.0, px.y)).rgb) * 0.25;
	float bright = max(max(blur.r, blur.g), blur.b);
	vec3 colour = base + blur * smoothstep(0.6, 1.0, bright) * bloom;
	float line = 0.5 + 0.5 * sin(UV.y * lines * 3.14159 * 2.0);
	colour *= 1.0 - scanline_strength * (1.0 - line);
	colour += (hash(UV * 512.0 + floor(TIME * 18.0)) - 0.5) * grain_strength;
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(colour, vec3(grey), 0.35), 1.0);
}
