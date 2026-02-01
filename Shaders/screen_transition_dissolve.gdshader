shader_type canvas_item;

// Main animation progress (0 = start, 0.5 = fully black, 1 = fully revealed)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Dissolve configuration
uniform float noise_scale : hint_range(1.0, 100.0) = 30.0;  // Scale of the noise pattern
uniform float edge_softness : hint_range(0.0, 0.3) = 0.08;  // Softness of dissolve edge
uniform float dither_size : hint_range(1.0, 16.0) = 4.0;  // Size of dither pixels for extra crunch

// Colors
uniform vec3 color_black : source_color = vec3(0.0, 0.0, 0.0);

// Hash function for noise generation
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	
	// Four corners
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	
	// Smooth interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);
	
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Fractal Brownian Motion for more interesting noise
float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;
	
	// 4 octaves of noise
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p * frequency);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	
	return value;
}

// 8x8 Bayer matrix for additional dithering
float bayer8x8(vec2 pos) {
	int x = int(mod(pos.x, 8.0));
	int y = int(mod(pos.y, 8.0));
	
	int bayer[64] = int[64](
		 0, 32,  8, 40,  2, 34, 10, 42,
		48, 16, 56, 24, 50, 18, 58, 26,
		12, 44,  4, 36, 14, 46,  6, 38,
		60, 28, 52, 20, 62, 30, 54, 22,
		 3, 35, 11, 43,  1, 33,  9, 41,
		51, 19, 59, 27, 49, 17, 57, 25,
		15, 47,  7, 39, 13, 45,  5, 37,
		63, 31, 55, 23, 61, 29, 53, 21
	);
	
	return float(bayer[y * 8 + x]) / 64.0;
}

void fragment() {
	vec2 uv = UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	
	// Get pixel position for dithering
	vec2 pixel_pos = floor(uv * screen_size / dither_size);
	
	// Generate noise value for this position
	// Use the pixel position for a more pixelated look
	float noise_value = fbm(pixel_pos * noise_scale / screen_size * dither_size);
	
	// Add some variation with a second noise layer
	noise_value = noise_value * 0.7 + hash(pixel_pos * 0.1) * 0.3;
	
	// Get dither threshold
	float dither_threshold = bayer8x8(pixel_pos);
	
	// Combine noise with dither for a crunchy pixel effect
	float combined_threshold = noise_value * 0.85 + dither_threshold * 0.15;
	
	float alpha = 0.0;
	
	if (progress <= 0.5) {
		// Phase 1: Dissolve IN (screen becomes black)
		// Progress 0 = nothing visible, 0.5 = fully black
		float dissolve_progress = progress * 2.0;  // Normalize to 0-1
		
		// Expand the threshold range to ensure full coverage
		float threshold = dissolve_progress * (1.0 + edge_softness * 2.0);
		
		// Soft edge calculation
		float edge = smoothstep(threshold - edge_softness, threshold + edge_softness, combined_threshold);
		
		// Invert: low threshold values become black first as progress increases
		alpha = 1.0 - edge;
		
		// Ensure fully black at the end of phase 1
		if (dissolve_progress >= 1.0) {
			alpha = 1.0;
		}
	} else {
		// Phase 2: Dissolve OUT (black reveals screen)
		// Progress 0.5 = fully black, 1.0 = fully revealed
		float reveal_progress = (progress - 0.5) * 2.0;  // Normalize to 0-1
		
		// Expand the threshold range
		float threshold = reveal_progress * (1.0 + edge_softness * 2.0);
		
		// Soft edge calculation
		float edge = smoothstep(threshold - edge_softness, threshold + edge_softness, combined_threshold);
		
		// Low threshold values reveal first as progress increases
		alpha = edge;
		
		// Ensure fully revealed at the end
		if (reveal_progress >= 1.0) {
			alpha = 0.0;
		}
	}
	
	COLOR = vec4(color_black, alpha);
}
