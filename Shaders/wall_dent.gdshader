shader_type canvas_item;

// Data texture: 30x2
// Row 0: vec4(world_pos.x, world_pos.y, radius, strength)
// Row 1: vec4(hit_dir.x, hit_dir.y, 0, 0)
uniform sampler2D dent_data : filter_nearest, repeat_disable;
uniform int dent_count = 0;
uniform float max_dents = 100.0;

// Effect parameters
uniform float vertex_push_strength : hint_range(0.0, 50.0) = 12.0;
uniform float uv_distortion_strength : hint_range(0.0, 0.2) = 0.04;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.2;
uniform float dent_falloff : hint_range(0.5, 4.0) = 2.2;  // Higher = softer edges
uniform float max_compound : hint_range(1.0, 4.0) = 2.0;  // Max dent stacking

varying float v_dent_intensity;
varying vec2 v_dent_direction;

void vertex() {
	vec2 world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	
	float total_push = 0.0;
	vec2 total_direction = vec2(0.0);
	
	for (int i = 0; i < int(max_dents); i++) {
		if (i >= dent_count) break;
		
		// Sample dent data from row 0: x=pos.x, y=pos.y, z=radius, w=strength
		vec4 dent = texelFetch(dent_data, ivec2(i, 0), 0);
		vec2 dent_pos = dent.xy;
		float radius = dent.z;
		float strength = dent.w;
		
		// Sample hit direction from row 1
		vec4 dent_dir = texelFetch(dent_data, ivec2(i, 1), 0);
		vec2 hit_direction = dent_dir.xy;
		
		if (radius <= 0.0) continue;
		
		vec2 to_dent = world_pos - dent_pos;
		float dist = length(to_dent);
		
		if (dist < radius) {
			// Smooth falloff using smoothstep
			float falloff = 1.0 - smoothstep(0.0, radius, dist);
			falloff = pow(falloff, dent_falloff);
			
			float push = falloff * strength;
			total_push += push;
			
			// Use hit direction for displacement (push in the direction the player was hitting)
			// Mix with radial direction for more natural look
			vec2 radial_dir = vec2(0.0);
			if (dist > 0.001) {
				radial_dir = -normalize(to_dent);
			}
			
			// Primarily use hit direction, blend with radial for edges
			vec2 push_dir = normalize(mix(radial_dir, hit_direction, 0.7));
			total_direction += push_dir * push;
		}
	}
	
	// Clamp compounding to max_compound (default 2) dents worth of effect
	float clamped_push = min(total_push, max_compound);
	float compound_scale = (total_push > 0.001) ? (clamped_push / total_push) : 1.0;
	total_direction *= compound_scale;
	
	// Apply vertex displacement
	VERTEX += total_direction * vertex_push_strength;
	
	// Pass intensity to fragment shader for shading (clamped)
	v_dent_intensity = clamp(clamped_push / max_compound, 0.0, 1.0);
	v_dent_direction = total_direction;
}

void fragment() {
	// UV distortion based on dent intensity
	vec2 distorted_uv = UV;
	if (v_dent_intensity > 0.0) {
		// Warp UVs in the hit direction for crumble effect
		vec2 uv_offset = v_dent_direction * uv_distortion_strength * v_dent_intensity;
		distorted_uv += uv_offset;
		
		// Add some noise-like variation for roughness
		float noise = sin(UV.x * 40.0) * cos(UV.y * 40.0) * 0.5 + 0.5;
		distorted_uv += vec2(noise - 0.5) * uv_distortion_strength * v_dent_intensity * 0.4;
	}
	
	vec4 tex_color = texture(TEXTURE, distorted_uv);
	
	// Subtle darkening in dented areas
	float shadow = 1.0 - (v_dent_intensity * shadow_strength);
	tex_color.rgb *= shadow;
	
	// Very subtle color shift toward darker blue in dents (matches palette)
	tex_color.rgb = mix(tex_color.rgb, tex_color.rgb * vec3(0.9, 0.92, 0.98), v_dent_intensity * 0.25);
	
	COLOR = tex_color;
}
