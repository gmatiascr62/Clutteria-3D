shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// Vidrio roto: rayos desde un punto de impacto y un anillo irregular.

uniform vec2 center = vec2(0.35, 0.6);

float h(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - center) * vec2(1.6, 1.0);
	float a = atan(p.y, p.x);
	float r = length(p);
	float rays = 9.0;
	float sector = floor((a + PI) / (TAU / rays));
	float local = fract((a + PI) / (TAU / rays)) - 0.5 - (h(sector) - 0.5) * 0.5;
	float line = (1.0 - smoothstep(0.0, 0.02, abs(local) * r * 5.0)) * step(r, 0.25 + h(sector + 3.0) * 0.45);
	float ring = (1.0 - smoothstep(0.0, 0.008, abs(r - 0.09 - h(floor(a * 2.5)) * 0.05))) * step(r, 0.2);
	ALBEDO = vec3(0.96, 0.98, 1.0);
	ALPHA = max(line, ring) * 0.95;
}
