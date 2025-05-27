shader_type spatial;
render_mode cull_back;

group_uniforms Grid;
uniform sampler2D grid_texture: repeat_enable;
uniform float grid_scale = 1.0;
uniform vec4 gridBase_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 gridLine_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

group_uniforms CelShading;
uniform vec4 lit_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 unlit_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float cel_threshold: hint_range(0.0, 1.0) = 0.5;
uniform float cel_sharpness: hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 vertex = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 adjusted_normal = pow(abs(normal), vec3(8.0));
	vec3 weights = adjusted_normal / (adjusted_normal.x + adjusted_normal.y + adjusted_normal.z) * 3.0;
	
	vec2 uv_x = vertex.zy * grid_scale;
	vec2 uv_y = vertex.xz * grid_scale;
	vec2 uv_z = vertex.xy * grid_scale;
	
	float use_y_up = float(normal.y > 0.0);
	
	vec3 color_x = texture(grid_texture, uv_x).rgb * weights.x;
	vec3 color_y_up = texture(grid_texture, uv_y).rgb * weights.y;
	vec3 color_y_down = texture(grid_texture, uv_y).rgb * weights.y;
	vec3 color_z = texture(grid_texture, uv_z).rgb * weights.z;
	
	vec3 totalColor = (color_x + mix(color_y_down, color_y_up, use_y_up) + color_z) / 3.0;
	ALBEDO = mix(gridBase_color.rgb, gridLine_color.rgb, totalColor);
}

void light() {
	float dotProduct = (dot(NORMAL, LIGHT) + 1.0)/2.0;
	float litValue = dotProduct * ATTENUATION;
	float steppedLitValue = smoothstep(cel_threshold - cel_sharpness, cel_threshold + cel_sharpness, litValue);
	DIFFUSE_LIGHT = unlit_color.xyz + (lit_color.xyz - unlit_color.xyz) * steppedLitValue;
}
