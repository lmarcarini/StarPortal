// The event horizon in 3D (M5-03): a disc in the Ring's hole. `amount` (0 to 1) grows it
// from the centre; `burst` (the opening surge, 0 to 1) pushes the surface out toward the
// camera and lets it settle; `time` animates the watery surface (frozen with reduced motion).
// Bible: docs/content/interface-reference.md section 7
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float amount = 1.0;
uniform float burst = 0.0;
uniform float time = 0.0;
uniform float surge_depth = 1.1;
uniform vec3 tint : source_color = vec3(0.247, 0.663, 0.961);
uniform vec3 alarm : source_color = vec3(0.898, 0.325, 0.239);
uniform float hostile = 0.0;

varying float radial;

float wave(vec2 p, float t) {
	float r = length(p);
	float a = atan(p.y, p.x);
	return 0.5 + 0.5 * sin(r * 22.0 - a * 3.0 + sin(a * 5.0 + t * 0.7) * 1.4 - t * 1.6);
}

void vertex() {
	radial = length(VERTEX.xy);
	VERTEX.xy *= amount;
	float bulge = burst * (1.0 - radial * radial) * surge_depth;
	float ripple = (wave(VERTEX.xy, time) - 0.5) * 0.06 * amount;
	VERTEX.z += bulge + ripple;
}

void fragment() {
	float w = wave(UV - 0.5, time);
	float core = pow(max(0.0, 1.0 - radial), 1.6);
	vec3 base = mix(tint, alarm, hostile);
	vec3 col = base * (0.55 + 0.45 * w * (0.4 + radial * 0.6)) + vec3(0.75, 0.9, 1.0) * core * 0.9;
	col = mix(col, vec3(0.92, 0.97, 1.0), burst * 0.6);
	ALBEDO = col * 0.55;
	ALPHA = smoothstep(1.0, 0.96, radial);
}
