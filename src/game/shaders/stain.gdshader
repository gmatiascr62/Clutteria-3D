shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
// Mancha que se borra con una máscara (R=1 sucio, R=0 limpio).
#include "res://src/game/shaders/common.gdshaderinc"

uniform sampler2D mask : filter_linear;
uniform vec3 color : source_color = vec3(0.3, 0.24, 0.15);
uniform float seed = 0.0;

float shape(vec2 uv) {
	vec2 q = uv - 0.5;
	float d = length(q) * 2.0;
	float n = vnoise(uv * 5.0 + seed) - 0.5;
	return smoothstep(1.0, 0.55, d + n * 0.6);
}

void fragment() {
	float s = shape(UV);
	float m = texture(mask, UV).r;
	float n = vnoise(UV * 18.0 + seed * 3.0);
	ALBEDO = color * (0.75 + 0.5 * n);
	ALPHA = s * m * (0.65 + 0.3 * n);
	ROUGHNESS = 0.9;
}
