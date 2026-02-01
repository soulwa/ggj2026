shader_type canvas_item;

// Flipbook settings (4 columns x 2 rows = 8 frames)
uniform int h_frames = 4;
uniform int v_frames = 2;

// Wiggle and warble settings
uniform float wiggle_speed : hint_range(0.0, 10.0) = 3.5;
uniform float wiggle_amount : hint_range(0.0, 20.0) = 5.0;
uniform float warble_speed : hint_range(0.0, 10.0) = 2.0;
uniform float warble_amount : hint_range(0.0, 0.5) = 0.12;

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

// Varying to pass particle ID from vertex to fragment
varying float v_particle_id;

void vertex() {
	// Get a unique ID per particle from vertex position
	v_particle_id = hash(VERTEX * 0.01);
	
	// Wiggle: sine wave displacement for floaty movement
	float wiggle_offset = sin(TIME * wiggle_speed + v_particle_id * 20.0) * wiggle_amount;
	float wiggle_offset_y = cos(TIME * wiggle_speed * 0.7 + v_particle_id * 15.0) * wiggle_amount * 0.6;
	
	VERTEX.x += wiggle_offset;
	VERTEX.y += wiggle_offset_y;
}

void fragment() {
	// Calculate flipbook frame based on particle ID (random frame per particle)
	int total_frames = h_frames * v_frames;
	int frame = int(v_particle_id * float(total_frames));
	frame = frame % total_frames;
	
	int frame_x = frame % h_frames;
	int frame_y = frame / h_frames;
	
	// Calculate UV within the flipbook frame
	vec2 frame_size = vec2(1.0 / float(h_frames), 1.0 / float(v_frames));
	vec2 frame_offset = vec2(float(frame_x), float(frame_y)) * frame_size;
	
	vec2 local_uv = UV;
	
	// Warble: distort UV coordinates for wobbly, organic edges
	float warble_x = sin(TIME * warble_speed + local_uv.y * 6.0 + v_particle_id * 10.0) * warble_amount;
	float warble_y = cos(TIME * warble_speed * 0.8 + local_uv.x * 6.0 + v_particle_id * 8.0) * warble_amount;
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
	float fade_line = lifetime_progress * (1.0 + directional_fade) - (1.0 - local_uv.y) * directional_fade;
	
	// Add noise to the fade line for organic, dusty dissolution
	float noisy_fade = fade_line + (noise_val - 0.5) * 0.4 * edge_softness;
	
	// Soft edge on the dissolution front
	float dissolve = 1.0 - smoothstep(-0.1, 0.3 + edge_softness * 0.2, noisy_fade);
	
	// Very soft overall edge (minimal, just to soften harsh sprite edges)
	float dist_from_center = length(local_uv - vec2(0.5));
	float edge_fade = 1.0 - smoothstep(0.4, 0.55, dist_from_center);
	
	// Combine alpha effects
	float final_alpha = tex_color.a * edge_fade * dissolve;
	
	// Subtle color drift for organic, dusty feel
	vec3 final_color = tex_color.rgb * COLOR.rgb;
	float color_noise = noise(local_uv * 3.0 + TIME * 0.2 + v_particle_id * 3.0);
	final_color.r += (color_noise - 0.5) * color_drift * 0.15;
	final_color.g += (color_noise - 0.5) * color_drift * 0.1;
	final_color.b -= (color_noise - 0.5) * color_drift * 0.05;  // Slight warm shift
	
	COLOR = vec4(final_color, final_alpha);
}
