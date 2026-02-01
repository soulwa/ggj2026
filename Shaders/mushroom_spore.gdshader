shader_type canvas_item;

// Flipbook settings (4 columns x 2 rows = 8 frames)
uniform int h_frames = 4;
uniform int v_frames = 2;

// Wiggle and warble settings
uniform float wiggle_speed : hint_range(0.0, 10.0) = 3.5;
uniform float wiggle_amount : hint_range(0.0, 20.0) = 5.0;
uniform float warble_speed : hint_range(0.0, 10.0) = 2.0;
uniform float warble_amount : hint_range(0.0, 0.5) = 0.12;

// Spread over time settings
uniform float spread_over_time : hint_range(0.0, 50.0) = 25.0;  // How much particles spread as they age
uniform float late_rotation : hint_range(0.0, 3.0) = 1.5;  // Rotation variation near end of life
uniform float late_noise_strength : hint_range(0.0, 1.0) = 0.4;  // Extra noise displacement near end

// Dusty dissipation settings
uniform float edge_softness : hint_range(0.0, 1.0) = 0.5;
uniform float noise_dissipate : hint_range(0.0, 1.0) = 0.25;
uniform float color_drift : hint_range(0.0, 1.0) = 0.15;
uniform float directional_fade : hint_range(0.0, 2.0) = 1.2;  // How much fade follows movement direction

// Hash function for pseudo-random noise
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

// Fractal brownian motion for organic noise
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

// Varying to pass particle ID and lifetime from vertex to fragment
varying float v_particle_id;
varying float v_lifetime_progress;

void vertex() {
	// Get a unique ID per particle from vertex position
	v_particle_id = hash(VERTEX * 0.01);
	
	// Calculate lifetime progress (0 at start, 1 at end) from COLOR.a
	v_lifetime_progress = 1.0 - COLOR.a;
	
	// Base wiggle: sine wave displacement for floaty movement
	float wiggle_offset = sin(TIME * wiggle_speed + v_particle_id * 20.0) * wiggle_amount;
	float wiggle_offset_y = cos(TIME * wiggle_speed * 0.7 + v_particle_id * 15.0) * wiggle_amount * 0.6;
	
	VERTEX.x += wiggle_offset;
	VERTEX.y += wiggle_offset_y;
	
	// Spread out over time: particles diverge as they age
	// Each particle gets a random direction to drift
	float spread_angle = v_particle_id * 6.28318;  // Random angle per particle
	float spread_strength = v_lifetime_progress * v_lifetime_progress * spread_over_time;  // Quadratic increase
	VERTEX.x += cos(spread_angle) * spread_strength;
	VERTEX.y += sin(spread_angle) * spread_strength;
	
	// Late-life noise displacement - smooth sine-based for organic movement
	float late_factor = smoothstep(0.5, 0.9, v_lifetime_progress);  // Kicks in after 50% lifetime
	float noise_x = sin(TIME * 1.5 + v_particle_id * 25.0) * cos(TIME * 0.8 + v_particle_id * 17.0);
	float noise_y = cos(TIME * 1.2 + v_particle_id * 31.0) * sin(TIME * 0.9 + v_particle_id * 23.0);
	VERTEX.x += noise_x * late_noise_strength * late_factor * 12.0;
	VERTEX.y += noise_y * late_noise_strength * late_factor * 12.0;
}

void fragment() {
	// Calculate flipbook frame - changes over lifetime for visual variety
	int total_frames = h_frames * v_frames;
	
	// Frame changes based on particle ID + lifetime progress (each particle cycles through different frames)
	float frame_cycle = v_particle_id * float(total_frames) + v_lifetime_progress * 2.0;
	int frame = int(frame_cycle) % total_frames;
	
	// Smooth frame transitions near end of life
	float late_factor = smoothstep(0.4, 0.85, v_lifetime_progress);
	if (late_factor > 0.3) {
		// Smoothly cycle to different frames based on sine wave (no harsh jumps)
		float frame_offset = sin(TIME * 2.0 + v_particle_id * 15.0) * 0.5 + 0.5;
		frame = int(v_particle_id * float(total_frames) + frame_offset * 2.0) % total_frames;
	}
	
	int frame_x = frame % h_frames;
	int frame_y = frame / h_frames;
	
	// Calculate UV within the flipbook frame
	vec2 frame_size = vec2(1.0 / float(h_frames), 1.0 / float(v_frames));
	vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;
	
	vec2 local_uv = UV;
	
	// Late-life rotation: spin UV around center as particle ages
	float rotation_amount = late_rotation * late_factor * (v_particle_id * 2.0 - 1.0);  // Random direction per particle
	// Add extra spin near end
	rotation_amount += late_factor * sin(TIME * 3.0 + v_particle_id * 10.0) * 0.5;
	vec2 centered_uv = local_uv - vec2(0.5);
	float cos_rot = cos(rotation_amount);
	float sin_rot = sin(rotation_amount);
	local_uv = vec2(
		centered_uv.x * cos_rot - centered_uv.y * sin_rot,
		centered_uv.x * sin_rot + centered_uv.y * cos_rot
	) + vec2(0.5);
	
	// Warble: distort UV coordinates for wobbly, organic edges (increases with age)
	float warble_scale = 1.0 + late_factor * 1.0;  // Double warble near end
	float warble_x = sin(TIME * warble_speed + local_uv.y * 6.0 + v_particle_id * 10.0) * warble_amount * warble_scale;
	float warble_y = cos(TIME * warble_speed * 0.8 + local_uv.x * 6.0 + v_particle_id * 8.0) * warble_amount * warble_scale;
	vec2 warbled_uv = local_uv + vec2(warble_x, warble_y);
	
	// Map to flipbook frame
	vec2 final_uv = frame_offset + warbled_uv * frame_size;
	
	// Sample the texture
	vec4 tex_color = texture(TEXTURE, final_uv);
	
	// Directional dissipation: fade from trailing edge (bottom) toward leading edge (top)
	// Particles move upward, so bottom (high y in UV space) fades first
	float noise_val = fbm(local_uv * 5.0 + TIME * 0.4 + v_particle_id * 5.0);
	
	// Direction-based fade: use particle's lifetime (from COLOR.a) to drive the sweep
	// As alpha decreases over lifetime, the fade line sweeps upward
	float lifetime_progress = 1.0 - COLOR.a;  // 0 at start, 1 at end
	
	// Calculate directional fade - bottom fades first, sweeps upward
	// local_uv.y: 0 = top, 1 = bottom (in typical UV space)
	// Gentle S-curve for smooth fade progression
	float smooth_progress = smoothstep(0.0, 1.0, lifetime_progress);
	float fade_line = smooth_progress * (1.0 + directional_fade) - (1.0 - local_uv.y) * directional_fade;
	
	// Add subtle noise to the fade line for organic dissolution
	float noisy_fade = fade_line + (noise_val - 0.5) * 0.2 * edge_softness;
	
	// Soft edge on the dissolution front for smooth fadeout
	float dissolve = 1.0 - smoothstep(-0.1, 0.4 + edge_softness * 0.15, noisy_fade);
	
	// Very soft overall edge (minimal, just to soften harsh sprite edges)
	float dist_from_center = length(local_uv - vec2(0.5));
	float edge_fade = 1.0 - smoothstep(0.4, 0.55, dist_from_center);
	
	// Combine alpha effects
	float final_alpha = tex_color.a * edge_fade * dissolve;
	
	// Color drift - increases significantly near end for visual variety
	vec3 final_color = tex_color.rgb * COLOR.rgb;
	float color_noise = noise(local_uv * 3.0 + TIME * 0.2 + v_particle_id * 3.0);
	
	// Base color drift
	final_color.r += (color_noise - 0.5) * color_drift * 0.15;
	final_color.g += (color_noise - 0.5) * color_drift * 0.1;
	final_color.b -= (color_noise - 0.5) * color_drift * 0.05;
	
	// Late-life brightness variation - smooth sine-based
	float late_color_factor = smoothstep(0.5, 0.85, v_lifetime_progress);
	float brightness_wave = sin(TIME * 1.5 + v_particle_id * 20.0) * 0.5 + 0.5;
	final_color *= 1.0 + (brightness_wave - 0.5) * 0.25 * late_color_factor;  // Subtle brightness pulse
	
	// Gentle hue shift per particle near end
	float hue_shift = (v_particle_id - 0.5) * 0.1 * late_color_factor;
	final_color.r += hue_shift;
	final_color.g -= hue_shift * 0.3;
	
	COLOR = vec4(final_color, final_alpha);
}
