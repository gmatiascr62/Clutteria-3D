shader_type spatial;
// Pared con pintura animada de abajo hacia arriba y manchas de humedad.
#include "res://src/game/shaders/common.gdshaderinc"

uniform vec3 old_color : source_color = vec3(0.8, 0.78, 0.7);
uniform vec3 new_color : source_color = vec3(0.9, 0.9, 0.88);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float dirt : hint_range(0.0, 1.0) = 1.0;
uniform float height = 2.7;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(wpos.x + wpos.z, wpos.y);
	float tex = vnoise(p * 30.0) * 0.04 + vnoise(p * 3.0) * 0.03;
	float grime = vnoise(p * 2.6) * 0.55 + vnoise(p * 9.0) * 0.45;
	float low = smoothstep(0.9, 0.0, wpos.y);
	vec3 oldc = old_color * (1.0 - dirt * (0.1 + 0.18 * smoothstep(0.55, 0.95, grime) + 0.15 * low));
	oldc = mix(oldc, oldc * vec3(0.85, 0.8, 0.65), dirt * 0.4);
	float h = wpos.y / height;
	float edge = progress * 1.1 - 0.05;
	float k = smoothstep(edge + 0.02, edge - 0.02, h);
	vec3 c = mix(oldc, new_color, k);
	// Brillo de pintura fresca justo en el borde.
	c += vec3(0.08) * (1.0 - smoothstep(0.0, 0.04, abs(h - edge))) * step(0.001, progress) * step(progress, 0.999);
	ALBEDO = c * (1.0 - tex);
	ROUGHNESS = 0.85;
}
