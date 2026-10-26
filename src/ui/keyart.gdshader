shader_type canvas_item;
// Title key art: wind in Tamra's hair and sash. Pixels inside two soft regions (in
// key-art pixels) are displaced in a travelling wave that grows toward the tips, which
// stream left away from where they are tied.

uniform vec2 art_size = vec2(1920.0, 1080.0);
uniform vec4 hair = vec4(515.0, 625.0, 78.0, 72.0);   // centre x, y, radius x, y
uniform vec2 hair_root = vec2(578.0, 612.0);
uniform vec4 sash = vec4(505.0, 765.0, 72.0, 46.0);
uniform vec2 sash_root = vec2(566.0, 744.0);
uniform float strength = 5.0;  // px of sway at the tips

float region(vec2 p, vec4 r) {
	vec2 d = (p - r.xy) / r.zw;
	return 1.0 - smoothstep(0.75, 1.0, length(d));
}

vec2 sway(vec2 p, vec4 r, vec2 root, float speed, float phase) {
	float w = region(p, r);
	if (w <= 0.0) return vec2(0.0);
	float tip = clamp((root.x - p.x) / (r.z * 1.6), 0.0, 1.0);
	float wave = sin(TIME * speed + p.x * 0.07 + phase) + 0.45 * sin(TIME * speed * 1.9 + p.x * 0.13);
	return vec2(tip * 0.6 * strength * (0.5 + 0.5 * sin(TIME * speed * 0.5)), wave * strength * tip) * w;
}

void fragment() {
	vec2 p = UV * art_size;
	vec2 off = sway(p, hair, hair_root, 5.0, 0.0) + sway(p, sash, sash_root, 6.5, 1.3);
	COLOR = texture(TEXTURE, (p + off) / art_size);
}
