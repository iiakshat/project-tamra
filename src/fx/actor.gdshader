shader_type canvas_item;
// Painted character sprites: breathing, skin recolours, hit flash and a smoke dissolve.
// Breathing stretches everything above the waist upward and widens the chest a little,
// so one painted idle frame inhales and exhales without new art.

uniform float breath = 0.0;       // -1 exhale .. 1 inhale (already scaled by strength)
uniform float waist = 0.62;       // uv.y of the waist in the current frame
uniform float chest_x = 0.5;      // uv.x of the chest centre
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.6, 0.0);  // a = 0 off
uniform float outline_px = 2.5;
uniform float dissolve = 0.0;     // 0 solid .. 1 gone
uniform vec4 dissolve_edge : source_color = vec4(1.0, 0.45, 0.15, 1.0);
// Recolours: hue ranges of the base art moved to new colours (shop skins).
uniform vec4 cloth_to : source_color = vec4(0.0);  // a = 0 off
uniform float cloth_hue = 0.68;
uniform vec4 sash_to : source_color = vec4(0.0);
uniform float sash_hue = 0.97;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

float hue_dist(float a, float b) {
	float d = abs(a - b);
	return min(d, 1.0 - d);
}

vec3 recolor(vec3 col, float src_hue, vec4 to) {
	if (to.a <= 0.0) return col;
	vec3 hsv = rgb2hsv(col);
	float w = (1.0 - smoothstep(0.035, 0.07, hue_dist(hsv.x, src_hue))) * smoothstep(0.18, 0.3, hsv.y);
	vec3 t = rgb2hsv(to.rgb);
	// Keep the painted shading: value scales with the target's brightness.
	vec3 moved = hsv2rgb(vec3(t.x, clamp(hsv.y * (0.4 + t.y), 0.0, 1.0), clamp(hsv.z * (0.55 + t.z * 0.9), 0.0, 1.0)));
	return mix(col, moved, w * to.a);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	if (breath != 0.0) {
		float s = breath * 0.03;
		if (uv.y < waist) {
			uv.y = waist - (waist - uv.y) / (1.0 + s);
			float band = smoothstep(waist, waist - 0.12, uv.y) * smoothstep(waist - 0.45, waist - 0.25, uv.y);
			uv.x = chest_x + (uv.x - chest_x) / (1.0 + s * 0.7 * band);
		}
	}
	vec4 c = texture(TEXTURE, uv);
	if (outline_color.a > 0.0 && c.a < 0.9) {
		// A thin warm rim keeps the figure readable against busy painted backdrops.
		vec2 o = TEXTURE_PIXEL_SIZE * outline_px;
		float n = 0.0;
		n = max(n, texture(TEXTURE, uv + vec2(o.x, 0.0)).a);
		n = max(n, texture(TEXTURE, uv - vec2(o.x, 0.0)).a);
		n = max(n, texture(TEXTURE, uv + vec2(0.0, o.y)).a);
		n = max(n, texture(TEXTURE, uv - vec2(0.0, o.y)).a);
		n = max(n, texture(TEXTURE, uv + o * 0.7).a);
		n = max(n, texture(TEXTURE, uv - o * 0.7).a);
		n = max(n, texture(TEXTURE, uv + vec2(o.x, -o.y) * 0.7).a);
		n = max(n, texture(TEXTURE, uv + vec2(-o.x, o.y) * 0.7).a);
		float rim = n * outline_color.a * (1.0 - c.a);
		c = vec4(mix(outline_color.rgb, c.rgb, c.a), max(c.a, rim));
	}
	c.rgb = recolor(c.rgb, cloth_hue, cloth_to);
	c.rgb = recolor(c.rgb, sash_hue, sash_to);
	c.rgb = mix(c.rgb, flash_color.rgb, flash_color.a);
	if (dissolve > 0.0) {
		float n = noise(uv * 38.0) * 0.7 + noise(uv * 9.0) * 0.3 + (1.0 - uv.y) * 0.25;
		float cut = dissolve * 1.3;
		if (n < cut) {
			c.a = 0.0;
		} else if (n < cut + 0.06) {
			c.rgb = dissolve_edge.rgb;
		}
	}
	COLOR = c * COLOR;
}
