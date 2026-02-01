shader_type canvas_item;

// Flipbook settings for dust sprites (adjust based on your atlas)
uniform int h_frames = 3;
uniform int v_frames = 4;

// Floating movement settings
uniform float drift_speed : hint_range(0.0, 5.0) = 0.3;
uniform float drift_amount : hint_range(0.0, 15.0) = 2.0;
uniform float vertical_drift : hint_range(0.0, 10.0) = 1.5;

// Warble settings for organic feel
uniform float warble_speed : hint_range(0.0, 5.0) = 0.2;
uniform float warble_amount : hint_range(0.0, 0.3) = 0.03;

// Softness and blur settings
uniform float blur_amount : hint_range(0.0, 8.0) = 2.0;
uniform float edge_softness : hint_range(0.0, 1.0) = 0.6;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.3;

// Fade settings
uniform float pulse_amount : hint_range(0.0, 1.0) = 0.1;
uniform float pulse_speed : hint_range(0.0, 3.0) = 0.4;

// Hash function for pseudo-random values per particle
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal brownian motion for organic warble
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}

varying float v_particle_id;

void vertex() {
	// Unique ID per particle
	v_particle_id = hash(VERTEX * 0.01);
	
	// Gentle, lazy drifting motion
	float time_offset = v_particle_id * 100.0;
	
	// Horizontal drift - slow, meandering with organic noise
	float drift_x = sin(TIME * drift_speed * 0.7 + time_offset) * drift_amount;
	drift_x += cos(TIME * drift_speed * 0.4 + time_offset * 0.5) * drift_amount * 0.5;
	drift_x += sin(TIME * drift_speed * 0.2 + time_offset * 0.3) * drift_amount * 0.25;
	
	// Vertical drift - even slower, gentle bobbing
	float drift_y = sin(TIME * drift_speed * 0.5 + time_offset * 1.3) * vertical_drift;
	drift_y += cos(TIME * drift_speed * 0.3 + time_offset * 0.7) * vertical_drift * 0.4;
	drift_y += sin(TIME * drift_speed * 0.15 + time_offset * 0.9) * vertical_drift * 0.2;
	
	VERTEX.x += drift_x;
	VERTEX.y += drift_y;
}

void fragment() {
	// Calculate flipbook frame based on particle ID
	int total_frames = h_frames * v_frames;
	int frame = int(v_particle_id * float(total_frames));
	frame = frame % total_frames;
	
	int frame_x = frame % h_frames;
	int frame_y = frame / h_frames;
	
	// UV within flipbook frame
	vec2 frame_size = vec2(1.0 / float(h_frames), 1.0 / float(v_frames));
	vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;
	
	vec2 local_uv = UV;
	
	// Organic warble using noise for natural, flowing distortion
	float warble_noise = fbm(local_uv * 3.0 + TIME * warble_speed * 0.5 + v_particle_id * 5.0);
	float warble_x = sin(TIME * warble_speed + local_uv.y * 4.0 + v_particle_id * 8.0 + warble_noise * 2.0) * warble_amount;
	float warble_y = cos(TIME * warble_speed * 0.7 + local_uv.x * 4.0 + v_particle_id * 6.0 + warble_noise * 2.0) * warble_amount;
	
	// Add secondary slower warble layer
	warble_x += sin(TIME * warble_speed * 0.3 + local_uv.y * 2.0 + v_particle_id * 4.0) * warble_amount * 0.5;
	warble_y += cos(TIME * warble_speed * 0.25 + local_uv.x * 2.0 + v_particle_id * 3.0) * warble_amount * 0.5;
	
	vec2 warbled_uv = local_uv + vec2(warble_x, warble_y);
	
	// Clamp warbled UV to stay within frame bounds
	warbled_uv = clamp(warbled_uv, vec2(0.001), vec2(0.999));
	
	vec2 final_uv = frame_offset + warbled_uv * frame_size;
	
	// Multi-sample blur for soft, dreamy dust effect
	vec2 pixel_size = frame_size / vec2(32.0);  // Approximate pixel size within frame
	float blur_radius = blur_amount * 0.01;
	
	vec4 tex_color = vec4(0.0);
	float total_weight = 0.0;
	
	// 9-tap gaussian-like blur
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			vec2 offset = vec2(float(x), float(y)) * blur_radius;
			vec2 sample_uv = final_uv + offset * frame_size;
			
			// Keep samples within frame bounds
			sample_uv = clamp(sample_uv, frame_offset + vec2(0.001), frame_offset + frame_size - vec2(0.001));
			
			// Gaussian weight
			float weight = 1.0 / (1.0 + float(x * x + y * y) * 0.5);
			tex_color += texture(TEXTURE, sample_uv) * weight;
			total_weight += weight;
		}
	}
	tex_color /= total_weight;
	
	// Gentle alpha pulsing for dreamy effect
	float pulse = 1.0 - pulse_amount * 0.5 + sin(TIME * pulse_speed + v_particle_id * 10.0) * pulse_amount * 0.5;
	
	// Radial fade from center - controlled by edge_softness
	float dist_from_center = length(local_uv - vec2(0.5));
	
	// When edge_softness is 0, show full sprite with no radial fade
	// When edge_softness > 0, apply soft edge falloff
	float edge_fade = 1.0;
	if (edge_softness > 0.01) {
		float inner_radius = 0.3 * (1.0 - edge_softness);
		float outer_radius = 0.5 + edge_softness * 0.1;
		edge_fade = 1.0 - smoothstep(inner_radius, outer_radius, dist_from_center);
	}
	
	// Glow effect - brighten the center slightly
	float glow = (1.0 - dist_from_center * 1.5) * glow_strength;
	glow = max(0.0, glow);
	
	// Apply alpha from particle system (lifetime fade)
	float particle_alpha = COLOR.a;
	
	float final_alpha = tex_color.a * particle_alpha * edge_fade * pulse;
	
	// Apply tint from particle system with subtle glow
	vec3 final_color = tex_color.rgb * COLOR.rgb * (1.0 + glow);
	
	COLOR = vec4(final_color, final_alpha);
}
