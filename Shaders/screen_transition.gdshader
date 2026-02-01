shader_type canvas_item;

// Main animation progress (0 = hidden, 1 = fully transitioned and faded out)
uniform float progress : hint_range(0.0, 1.0) = 0.0;

// Grid configuration
uniform vec2 grid_size = vec2(9.0, 6.0);
uniform float rhombus_size = 0.42;
uniform float rhombus_height_ratio = 1.6;

// Wave configuration
uniform float wave_spread = 0.55;
uniform float outline_wave_spread = 0.20;  // Faster/tighter wave for outline appearance

// Colors
uniform vec3 color_orange : source_color = vec3(0.78, 0.38, 0.18);
uniform vec3 color_yellow : source_color = vec3(0.82, 0.68, 0.22);
uniform vec3 color_rhombus_bg : source_color = vec3(0.16, 0.22, 0.20);
uniform vec3 color_screen_bg : source_color = vec3(0.18, 0.22, 0.28);
uniform float outline_thickness = 0.018;

// Easing functions for more organic motion
float ease_out_cubic(float t) {
	return 1.0 - pow(1.0 - t, 3.0);
}

float ease_in_out_quad(float t) {
	return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0;
}

float ease_in_quad(float t) {
	return t * t;
}

float ease_out_quad(float t) {
	return 1.0 - (1.0 - t) * (1.0 - t);
}

// Single continuous easing that slows dramatically for the final portion
// t: 0-1 progress, slow_start: when to start slowing (e.g. 0.7 = slow last 30%)
float ease_with_slow_finish(float t) {
	t = clamp(t, 0.0, 1.0);
	// Use a high-power ease-out that really slows at the end
	// ease_out_quint: 1 - (1-t)^5 - very slow finish
	return 1.0 - pow(1.0 - t, 5.0);
}

// SDF for rhombus with aspect ratio
float diamond_sdf(vec2 p, float size, float aspect) {
	p.y /= aspect;
	p = abs(p);
	return (p.x + p.y - size) / 1.41421356;
}

// Calculate wave-offset progress for a given cell position
float get_wave_progress(float cell_x, float center_x, float wave_sprd, float prog) {
	float cell_dist = abs(cell_x - center_x) / center_x;
	cell_dist = clamp(cell_dist, 0.0, 1.0);
	
	// Apply easing to the wave spread for smoother motion
	float wave_offset = ease_in_out_quad(1.0 - cell_dist) * wave_sprd;
	float scaled_prog = prog * (1.0 + wave_sprd);
	float local_prog = scaled_prog - wave_offset;
	return clamp(local_prog, 0.0, 1.0);
}

// Render a single rhombus and return its color contribution
// outline_wave_progress: fast wave for outline appearance (edges first, quick sweep)
// wave_progress: slower wave for fills (edges first, center last)
// bg_fade: background fade value to sync inner fill with background
vec4 render_rhombus(vec2 local_uv, float outline_wave_progress, float wave_progress, float bg_fade, vec2 screen_uv, float aa) {
	// Skip if completely outside animation range (use 0.99 to avoid floating point issues)
	if (outline_wave_progress <= 0.0 || wave_progress >= 0.99) {
		return vec4(0.0);
	}
	
	float d = diamond_sdf(local_uv, rhombus_size, rhombus_height_ratio);
	
	// Skip if outside rhombus bounds
	if (d > rhombus_size + outline_thickness + 0.05) {
		return vec4(0.0);
	}
	
	vec4 rhombus_color = vec4(0.0);
	
	// ============================================
	// OUTLINE - Uses fast wave (quick sweep from edges)
	// ============================================
	float outline_appear = ease_out_cubic(smoothstep(0.0, 0.35, outline_wave_progress));
	
	if (outline_appear > 0.0 && bg_fade > 0.0) {
		// Start from near-zero so it grows smoothly into existence
		float outline_pos = mix(0.01, rhombus_size, outline_appear);
		float outline_d = diamond_sdf(local_uv, outline_pos, rhombus_height_ratio);
		float outline = 1.0 - smoothstep(0.0, outline_thickness + aa, abs(outline_d));
		rhombus_color = mix(rhombus_color, vec4(1.0, 1.0, 1.0, bg_fade), outline);
	}
	
	// ============================================
	// FILLS - Use wave_progress (edges first, center last)
	// Single continuous animation with strong ease-out (slows dramatically at end)
	// Extended to 0.92 to time with background fadeout
	// ============================================
	
	// White fill: 0.0-0.92 with heavy ease-out
	float white_progress = smoothstep(0.0, 0.92, wave_progress);
	float white_appear = ease_with_slow_finish(white_progress);
	
	if (white_appear > 0.0 && bg_fade > 0.0) {
		float white_size = white_appear * rhombus_size;
		float white_d = diamond_sdf(local_uv, white_size, rhombus_height_ratio);
		float white_fill = 1.0 - smoothstep(-aa, aa, white_d);
		rhombus_color = mix(rhombus_color, vec4(1.0, 1.0, 1.0, bg_fade), white_fill);
	}
	
	// Gradient fill: 0.15-0.92 with heavy ease-out
	float grad_progress = smoothstep(0.15, 0.92, wave_progress);
	float grad_appear = ease_with_slow_finish(grad_progress);
	
	if (grad_appear > 0.0 && bg_fade > 0.0) {
		float grad_size = grad_appear * (rhombus_size - 0.025);
		float grad_d = diamond_sdf(local_uv, grad_size, rhombus_height_ratio);
		float grad_fill = 1.0 - smoothstep(-aa, aa, grad_d);
		vec3 gradient_color = mix(color_yellow, color_orange, screen_uv.y);
		rhombus_color = mix(rhombus_color, vec4(gradient_color, bg_fade), grad_fill);
	}
	
	// Inner fill: 0.35-0.92 with heavy ease-out
	float inner_progress = smoothstep(0.35, 0.92, wave_progress);
	float inner_appear = ease_with_slow_finish(inner_progress);
	
	if (inner_appear > 0.0 && bg_fade > 0.0) {
		// Inner fill grows to full rhombus size
		float inner_size = inner_appear * rhombus_size;
		float inner_d = diamond_sdf(local_uv, inner_size, rhombus_height_ratio);
		float inner_fill = 1.0 - smoothstep(-aa, aa, inner_d);
		rhombus_color = mix(rhombus_color, vec4(color_screen_bg, bg_fade), inner_fill);
	}
	
	return rhombus_color;
}

void fragment() {
	vec2 uv = UV;
	float aa = 0.01;
	
	// ============================================
	// BACKGROUND LAYER - Smooth wave, holds longer
	// ============================================
	float smooth_dist = abs(uv.x - 0.5) * 2.0;
	float bg_wave_offset = ease_in_out_quad(1.0 - smooth_dist) * wave_spread;
	float bg_scaled_progress = progress * (1.0 + wave_spread);
	float bg_local_progress = bg_scaled_progress - bg_wave_offset;
	bg_local_progress = clamp(bg_local_progress, 0.0, 1.0);
	
	// Background fades in quickly, holds, then fades out after rhombus animation completes
	float bg_fade_in = ease_out_cubic(smoothstep(0.0, 0.15, bg_local_progress));
	float bg_fade_out = 1.0 - ease_in_quad(smoothstep(0.82, 1.0, bg_local_progress));
	float bg_alpha = bg_fade_in * bg_fade_out;
	
	vec4 final_color = vec4(color_screen_bg, bg_alpha);
	
	// ============================================
	// RHOMBUS GRID - Check multiple cells for overlap
	// ============================================
	vec2 base_scaled_uv = uv * grid_size;
	float center_x = grid_size.x * 0.5;
	
	// Check current cell and neighbors for overlapping rhombuses
	vec2 base_cell = floor(base_scaled_uv);
	
	// We need to check neighboring cells because rhombuses can overlap
	for (float dy = -1.0; dy <= 1.0; dy += 1.0) {
		for (float dx = -1.0; dx <= 1.0; dx += 1.0) {
			vec2 check_cell = base_cell + vec2(dx, dy);
			
			// Calculate the row offset for this cell (stagger pattern)
			float row_offset = mod(check_cell.y, 2.0) * 0.5;
			
			// Calculate local UV with stagger applied
			vec2 staggered_uv = base_scaled_uv;
			staggered_uv.x += row_offset;
			vec2 local_uv = staggered_uv - (check_cell + vec2(0.5, 0.5));
			
			// Get the visual center X position for wave calculation
			// Cell center is at check_cell.x + 0.5, but stagger shifts it visually
			float visual_center_x = check_cell.x + 0.5 - row_offset;
			
			// Get fast wave progress for outline (quick sweep from edges)
			float outline_prog = get_wave_progress(visual_center_x, center_x, outline_wave_spread, progress);
			
			// Get slower wave progress for fills
			float wave_progress = get_wave_progress(visual_center_x, center_x, wave_spread, progress);
			
			// Calculate per-cell background fade - starts slightly earlier than background to avoid clipping
			float cell_bg_fade_out = 1.0 - ease_in_quad(smoothstep(0.78, 0.98, wave_progress));
			
			// Render rhombus with outline wave, fill wave, and background fade
			vec4 rhombus_color = render_rhombus(local_uv, outline_prog, wave_progress, cell_bg_fade_out, uv, aa);
			
			if (rhombus_color.a > 0.0) {
				final_color = mix(final_color, rhombus_color, rhombus_color.a);
			}
		}
	}
	
	COLOR = final_color;
}
