shader_type spatial;
render_mode cull_disabled;

group_uniforms Basic;
uniform sampler2D base_texture; 

group_uniforms CelShading;
uniform vec4 lit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 unlit_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float cel_threshold: hint_range(0.0, 1.0) = 0.5;
uniform float cel_sharpness: hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = texture(base_texture, UV).rgb;
}

void light() {
	float dotProduct = (dot(NORMAL, LIGHT) + 1.0)/2.0;
	float litValue = dotProduct * ATTENUATION;
	float steppedLitValue = smoothstep(cel_threshold - cel_sharpness, cel_threshold + cel_sharpness, litValue);
	DIFFUSE_LIGHT = unlit_color.xyz + (lit_color.xyz - unlit_color.xyz) * steppedLitValue;
}
