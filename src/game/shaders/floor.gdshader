shader_type spatial;
// Piso procedural (madera o baldosas) con suciedad que baja al limpiar.
#include "res://src/game/shaders/common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.6, 0.47, 0.33);
uniform float dirt : hint_range(0.0, 1.0) = 1.0;
uniform int pattern = 0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = base_color;
	float rough = 0.5;
	if (pattern == 0) {
		float plank = floor(wpos.x / 0.18);
		float off = hash12(vec2(plank, 3.0)) * 2.0;
		float seg = floor((wpos.z + off) / 1.2);
		float tone = hash12(vec2(plank, seg));
		float grain = vnoise(vec2(wpos.x * 45.0, wpos.z * 2.5));
		c *= 0.8 + tone * 0.28 + grain * 0.12;
		float edge = step(0.965, fract(wpos.x / 0.18)) + step(0.993, fract((wpos.z + off) / 1.2));
		c *= 1.0 - min(edge, 1.0) * 0.45;
	} else {
		vec2 t = fract(wpos.xz / 0.3);
		float grout = step(t.x, 0.03) + step(t.y, 0.03);
		float tone = hash12(floor(wpos.xz / 0.3));
		c *= 0.93 + tone * 0.1;
		c = mix(c, vec3(0.5, 0.48, 0.45), min(grout, 1.0));
		rough = 0.3;
	}
	float grime = vnoise(wpos.xz * 2.2) * 0.6 + vnoise(wpos.xz * 8.0) * 0.4;
	c = mix(c, c * vec3(0.55, 0.5, 0.42), dirt * smoothstep(0.35, 0.85, grime) * 0.85);
	c *= 1.0 - dirt * 0.15;
	ALBEDO = c;
	ROUGHNESS = mix(rough, 0.9, dirt * 0.5);
}
