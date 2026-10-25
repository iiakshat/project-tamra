shader_type canvas_item;
// Painted dusk sky: vertical gradient, a glowing sun and slow-drifting cloud bands.
// One full-screen pass; `octaves` drops on low quality to save GPU on cheap phones.

uniform vec4 top_color : source_color = vec4(0.07, 0.02, 0.07, 1.0);
uniform vec4 mid_color : source_color = vec4(0.40, 0.07, 0.10, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.98, 0.50, 0.18, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.84, 0.52, 1.0);
uniform vec2 sun_pos = vec2(0.70, 0.66);
uniform float sun_size = 0.085;
uniform int octaves = 4;
uniform float cloud_speed = 0.012;
uniform float dim = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 6; i++) {
		if (i >= octaves) {
			break;
		}
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	vec3 col = mix(top_color.rgb, mid_color.rgb, smoothstep(0.0, 0.55, uv.y));
	col = mix(col, horizon_color.rgb, smoothstep(0.45, 0.95, uv.y));

	vec2 d = uv - sun_pos;
	d.x *= aspect;
	float r = length(d);
	col += sun_color.rgb * smoothstep(sun_size, sun_size * 0.9, r);
	col += sun_color.rgb * 0.5 * exp(-r * 5.5);
	col += horizon_color.rgb * 0.18 * exp(-abs(uv.y - sun_pos.y) * 9.0);

	vec2 cp = vec2(uv.x * aspect * 1.6 + TIME * cloud_speed, uv.y * 7.0);
	float c = fbm(cp);
	float band = smoothstep(0.2, 0.5, uv.y) * (1.0 - smoothstep(0.62, 0.9, uv.y));
	float cloud = smoothstep(0.48, 0.78, c) * band;
	vec3 lit = mix(mid_color.rgb * 0.55, horizon_color.rgb * 1.15, smoothstep(0.3, 0.8, uv.y));
	col = mix(col, lit, cloud * 0.65);
	// warm edge on cloud bottoms where the sun catches them
	col += horizon_color.rgb * 0.25 * cloud * exp(-r * 3.0);

	COLOR = vec4(col * dim, 1.0);
}
