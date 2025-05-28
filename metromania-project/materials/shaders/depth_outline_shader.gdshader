shader_type spatial;
// Prevent the quad from being affected by lighting and fog. This also improves performance.
render_mode unshaded, fog_disabled, shadows_disabled;

#define USE_CIRCLE_SHAPE 1

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

uniform float maxDistance = 25.0;
uniform float magnification = 1.0;

uniform float radius = 0.005;
uniform float threshold = 1.0;

uniform vec4 outlineColor: source_color = vec4(0.0, 0.0, 0.0, 1.0);

float CompressionAndMagnification(float x){
	return ((x * magnification + x))/(x * magnification + 1.0);
}

void vertex() {
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	
	vec4 newColor = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	float depth1 = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc1 = vec3(SCREEN_UV, depth1) * 2.0 - 1.0;
	#else
	vec3 ndc1 = vec3(SCREEN_UV * 2.0 - 1.0, depth1);
	#endif
	
	vec4 view1 = INV_PROJECTION_MATRIX * vec4(ndc1, 1.0);
	view1.xyz /= view1.w;
	float linear_depth1 = CompressionAndMagnification(-view1.z/maxDistance);
	
	
	for(float x = -radius; x <= radius; x++){
		for(float y = -radius; y <= radius; y++){

			float depth2 = texture(DEPTH_TEXTURE, SCREEN_UV + vec2(x,y)).x;
			
			#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
			vec3 ndc2 = vec3(SCREEN_UV, depth2) * 2.0 - 1.0;
			#else
			vec3 ndc2 = vec3(SCREEN_UV * 2.0 - 1.0, depth2);
			#endif
			
			vec4 view2 = INV_PROJECTION_MATRIX * vec4(ndc2, 1.0);
			view2.xyz /= view2.w;
			float linear_depth2 = CompressionAndMagnification(-view2.z/maxDistance);
			
			if(abs(linear_depth1 - linear_depth2) > threshold)
				newColor = outlineColor;
				break;
		}
	}
	
	ALBEDO.rgb = vec3(newColor.rgb);
}
