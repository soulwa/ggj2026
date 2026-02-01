shader_type canvas_item;

// Main animation progress (0 = start, 0.5 = fully black, 1 = fully revealed)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Direction: 1.0 = top to bottom, -1.0 = bottom to top
uniform float direction : hint_range(-1.0, 1.0) = 1.0;

// Dither pattern configuration
uniform float dither_size : hint_range(1.0, 16.0) = 4.0;  // Size of dither pixels
uniform float edge_softness : hint_range(0.0, 0.5) = 0.15;  // How soft the transition edge is

// Colors
uniform vec3 color_black : source_color = vec3(0.0, 0.0, 0.0);

// 8x8 Bayer matrix for ordered dithering
float bayer8x8(vec2 pos) {
	int x = int(mod(pos.x, 8.0));
	int y = int(mod(pos.y, 8.0));
	
	// 8x8 Bayer matrix
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
	
	// Get dither threshold for this pixel
	float dither_threshold = bayer8x8(pixel_pos);
	
	// Calculate sweep position based on direction
	float sweep_pos;
	if (direction > 0.0) {
		// Top to bottom
		sweep_pos = uv.y;
	} else {
		// Bottom to top
		sweep_pos = 1.0 - uv.y;
	}
	
	// Phase 1 (progress 0 to 0.5): Black sweeps in
	// Phase 2 (progress 0.5 to 1): Black sweeps out (revealing screen)
	
	float alpha = 0.0;
	
	if (progress <= 0.5) {
		// Sweeping in: black covers screen from one side
		float sweep_progress = progress * 2.0;  // Normalize to 0-1
		
		// Calculate the sweep edge position (extends past 1.0 to ensure full coverage)
		float edge_pos = sweep_progress * (1.0 + edge_softness * 2.0) - edge_softness;
		
		// Distance from the sweep edge
		float dist_from_edge = sweep_pos - edge_pos;
		
		// Normalize distance to 0-1 range for dithering
		float normalized_dist = clamp(-dist_from_edge / edge_softness, 0.0, 1.0);
		
		// Apply dithering: pixel is black if dither threshold is less than coverage
		if (dither_threshold < normalized_dist) {
			alpha = 1.0;
		}
		
		// Fully covered area (behind the dither edge)
		if (dist_from_edge < -edge_softness) {
			alpha = 1.0;
		}
	} else {
		// Sweeping out: black reveals screen from the SAME side (continues the motion)
		float sweep_progress = (progress - 0.5) * 2.0;  // Normalize to 0-1
		
		// The reveal edge starts at the beginning and sweeps across
		float edge_pos = sweep_progress * (1.0 + edge_softness * 2.0) - edge_softness;
		
		// Distance from the reveal edge
		float dist_from_edge = sweep_pos - edge_pos;
		
		// Normalize distance to 0-1 range for dithering
		float normalized_dist = clamp(dist_from_edge / edge_softness, 0.0, 1.0);
		
		// Apply dithering: pixel is black if dither threshold is less than remaining coverage
		if (dither_threshold < normalized_dist) {
			alpha = 1.0;
		}
		
		// Still covered area (ahead of the reveal edge)
		if (dist_from_edge > edge_softness) {
			alpha = 1.0;
		}
	}
	
	COLOR = vec4(color_black, alpha);
}
