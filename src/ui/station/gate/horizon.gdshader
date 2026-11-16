shader_type canvas_item;
// The event horizon in the Ring's hole: calm moving ripples, clipped exactly to the hole's
// circle, grown from the centre by `amount`. The Ring's blue is the only saturated blue.
uniform vec2 centre = vec2(0.0);
uniform float radius = 100.0;
uniform float amount = 0.0;
uniform float time = 0.0;
uniform vec4 tint : source_color = vec4(0.247, 0.663, 0.961, 1.0);
uniform vec4 alarm : source_color = vec4(0.898, 0.325, 0.239, 1.0);
uniform float hostile = 0.0;

varying vec2 pixel;

void vertex() {
	pixel = VERTEX;
}

void fragment() {
	vec2 d = pixel - centre;
	float r = length(d) / max(radius, 1.0);
	float edge = amount;
	if (r > 1.0 || r > edge) {
		discard;
	}
	float a = atan(d.y, d.x);
	float wave = sin(r * 22.0 - time * 1.6 + sin(a * 3.0 + time * 0.4) * 0.8) * 0.5 + 0.5;
	float swirl = sin(a * 5.0 + r * 9.0 - time * 0.7) * 0.5 + 0.5;
	vec3 base = mix(tint.rgb * 0.55, tint.rgb * 1.25, wave * 0.6 + swirl * 0.25);
	base = mix(base, vec3(0.85, 0.95, 1.0), smoothstep(0.75, 1.0, r) * 0.35);
	base = mix(base, alarm.rgb, hostile * 0.45);
	float rim = smoothstep(edge, edge - 0.02, r);
	COLOR = vec4(base, rim);
}
