// The event horizon in 3D (M5-03): a disc in the Ring's hole. `amount` (0 to 1) grows it
// from the centre; `burst` (the opening surge, 0 to 1) pushes the surface out toward the
// camera, and as it settles a ripple ring runs out across the surface; `time` animates the
// layered noise ripples (frozen with reduced motion). Bright core, deeper blue at the rim.
// Bible: docs/content/interface-reference.md section 7
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform float amount = 1.0;
uniform float burst = 0.0;
uniform float settle = 0.0;
uniform float time = 0.0;
uniform float surge_depth = 1.1;
uniform vec3 tint : source_color = vec3(0.247, 0.663, 0.961);
uniform vec3 deep : source_color = vec3(0.04, 0.16, 0.42);
uniform vec3 alarm : source_color = vec3(0.898, 0.325, 0.239);
uniform float hostile = 0.0;

varying float radial;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Layered, drifting noise: no rotational symmetry.
float water(vec2 p, float t) {
	vec2 q = p * 7.0;
	float n = 0.0;
	float w = 0.5;
	for (int k = 0; k < 4; k++) {
		vec2 drift = vec2(sin(t * 0.31 + float(k) * 1.7), cos(t * 0.23 + float(k) * 2.3)) * 0.6;
		n += w * noise(q + drift + n * 1.3);
		q *= 2.03;
		w *= 0.5;
	}
	return n;
}

// The ripple ring that runs outward as the surge settles (settle 0 to 1).
float ring_wave(float r) {
	if (settle <= 0.0 || settle >= 1.0) {
		return 0.0;
	}
	float front = settle * 1.1;
	return exp(-pow((r - front) * 9.0, 2.0)) * (1.0 - settle);
}

void vertex() {
	radial = length(VERTEX.xy);
	VERTEX.xy *= amount;
	float bulge = burst * (1.0 - radial * radial) * surge_depth;
	float ripple = (water(VERTEX.xy, time) - 0.5) * 0.08 * amount;
	VERTEX.z += bulge + ripple + ring_wave(radial) * 0.35;
}

void fragment() {
	vec2 p = UV - 0.5;
	float n = water(p, time);
	float fine = water(p * 2.7 + 3.1, time * 1.3);
	float core = pow(max(0.0, 1.0 - radial), 1.8);
	vec3 base = mix(deep, tint, smoothstep(1.0, 0.15, radial));
	base = mix(base, mix(deep, alarm, 0.8), hostile);
	vec3 col = base * (0.15 + 1.5 * n * n + 0.45 * fine) + vec3(0.75, 0.9, 1.0) * core * 0.5;
	col += vec3(0.6, 0.85, 1.0) * ring_wave(radial) * 0.9;
	col = mix(col, vec3(0.92, 0.97, 1.0), burst * 0.6);
	ALBEDO = col * 0.55;
	ALPHA = smoothstep(1.0, 0.96, radial);
}
