shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float outline_width = 0.1;

void vertex() {
	VERTEX = VERTEX + NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}