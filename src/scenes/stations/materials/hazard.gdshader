// Yellow-black hazard stripes painted on the floor, worn at the edges.
// Bible: docs/content/interface-reference.md section 7
shader_type spatial;

uniform vec3 yellow : source_color = vec3(0.42, 0.31, 0.07);
uniform vec3 black : source_color = vec3(0.05, 0.05, 0.045);
uniform float stripes = 8.0;

void fragment() {
	float band = step(0.5, fract((UV.x + UV.y) * stripes));
	ALBEDO = mix(black, yellow, band);
	ROUGHNESS = 0.45;
}
