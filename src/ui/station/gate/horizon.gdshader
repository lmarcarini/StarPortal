shader_type canvas_item;
// The event horizon in the Ring's hole: a bright, watery surface with depth. Three scrolling
// noise layers make the water, a brighter core gives it depth, ridged noise draws caustic
// highlights, a soft bright rim meets the Ring and a slow ripple runs out from the centre now
// and then. `burst` (0 to 1, the kawoosh) throws the surface outward past the rim and lets it
// settle back. Clipped to the hole's circle, grown from the centre by `amount`. The Ring's blue
// is the only saturated blue. With reduced motion `time` stops, so it stills.
uniform vec2 centre = vec2(0.0);
uniform float radius = 100.0;
uniform float amount = 0.0;
uniform float time = 0.0;
uniform float burst = 0.0;
uniform vec4 tint : source_color = vec4(0.247, 0.663, 0.961, 1.0);
uniform vec4 alarm : source_color = vec4(0.898, 0.325, 0.239, 1.0);
uniform float hostile = 0.0;

varying vec2 pixel;

void vertex() {
	pixel = VERTEX;
}

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

// Three layers scrolling in different directions and speeds, each turned so the noise grid
// never shows.
float water(vec2 p, float t) {
	mat2 turn_a = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	mat2 turn_b = mat2(vec2(0.28, 0.96), vec2(-0.96, 0.28));
	float n = noise(p * 2.6 + vec2(t * 0.11, t * 0.07)) * 0.5;
	n += noise(turn_a * p * 5.3 - vec2(t * 0.05, -t * 0.13)) * 0.3;
	n += noise(turn_b * p * 10.7 + vec2(-t * 0.17, t * 0.09)) * 0.2;
	return n;
}

void fragment() {
	vec2 d = (pixel - centre) / max(radius, 1.0);
	float r = length(d);
	// The kawoosh: the reach grows past the rim and comes back.
	float reach = min(amount, 1.0) + burst * 0.55;
	if (r > reach || (burst <= 0.0 && r > 1.0)) {
		discard;
	}
	// The slow ripple: every 7 s a soft ring runs out from the centre.
	float phase = fract(time / 7.0);
	float ripple = exp(-pow((r - phase * 1.3) * 9.0, 2.0)) * (1.0 - phase);
	vec2 q = d * (1.0 - ripple * 0.06) + d * sin(r * 10.0 - time * 1.1) * 0.015;
	float w = water(q, time);
	mat2 turn = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6));
	float c1 = noise(turn * q * 7.0 + time * 0.15);
	float c2 = noise(q * 4.5 - time * 0.1);
	float caustic = pow(1.0 - abs(c1 - c2), 12.0);
	vec3 deep = tint.rgb * 0.45;
	vec3 lit = tint.rgb * 1.3;
	vec3 base = mix(deep, lit, smoothstep(0.25, 0.85, w));
	base += vec3(0.75, 0.9, 1.0) * (1.0 - smoothstep(0.0, 0.45, r)) * 0.35;
	base += vec3(0.8, 0.95, 1.0) * caustic * 0.3;
	base += vec3(0.7, 0.85, 1.0) * ripple * 0.35;
	base = mix(base, vec3(0.85, 0.95, 1.0), smoothstep(0.82, 1.0, r) * 0.45);
	// The burst is white-hot and turbulent beyond the rim.
	float outside = smoothstep(0.95, 1.05, r);
	base = mix(base, vec3(0.9, 0.97, 1.0), burst * (0.4 + outside * 0.5) * (0.6 + w * 0.6));
	base = mix(base, alarm.rgb, hostile * 0.45);
	float rim = smoothstep(reach, reach - 0.03 - burst * 0.2, r);
	float alpha = rim * (1.0 - outside * (1.0 - burst) );
	COLOR = vec4(base, alpha * mix(1.0, 0.85 + w * 0.3, outside));
}
