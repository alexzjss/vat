shader_type canvas_item;
// Pós-processamento HD-2D em uma passada: desfoque tilt-shift, bloom, gradação e vinheta.
// Lê os mipmaps da tela, então roda no renderer Compatibility.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

uniform float focus_y : hint_range(0.0, 1.0) = 0.55; // altura da faixa nítida (0 = topo)
uniform float focus_band : hint_range(0.0, 0.5) = 0.22; // meia-altura da faixa nítida
uniform float focus_falloff : hint_range(0.01, 0.5) = 0.3;
uniform float blur_max : hint_range(0.0, 4.0) = 2.2; // mip máximo nas bordas

uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.78;
uniform float bloom_intensity : hint_range(0.0, 2.0) = 0.4;

uniform float saturation : hint_range(0.0, 2.0) = 1.04;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);
uniform float vignette : hint_range(0.0, 1.0) = 0.35;

vec3 bright(vec3 c) {
	return max(c - vec3(bloom_threshold), vec3(0.0));
}

void fragment() {
	float d = abs(SCREEN_UV.y - focus_y);
	float lod = smoothstep(focus_band, focus_band + focus_falloff, d) * blur_max;
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;

	vec3 glow = bright(textureLod(screen_tex, SCREEN_UV, 3.0).rgb)
		+ bright(textureLod(screen_tex, SCREEN_UV, 5.0).rgb);
	c += glow * bloom_intensity;

	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;

	vec2 v = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * smoothstep(0.25, 0.9, dot(v, v) * 2.0);

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
