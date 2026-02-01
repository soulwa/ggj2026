shader_type canvas_item;

// Squash-stretch parameters
uniform float squash_amount : hint_range(-1.0, 1.0) = 0.0;  // Negative = squash, Positive = stretch
uniform float vertical_offset : hint_range(-100.0, 100.0) = 0.0;  // Offset for bounce effect

// Pivot offset from sprite center in pixels (positive Y = down)
// Set this to match where you want the "feet" to stay planted
uniform float pivot_offset_y : hint_range(-200.0, 200.0) = 60.0;

// Optional wobble for extra juice
uniform float wobble_amount : hint_range(0.0, 0.2) = 0.0;
uniform float wobble_speed : hint_range(0.0, 20.0) = 8.0;

void vertex() {
	// Calculate scale based on squash amount
	// Squash (negative) = compress vertically, expand horizontally
	// Stretch (positive) = expand vertically, compress horizontally
	float scale_y = 1.0 + squash_amount;
	float scale_x = 1.0 / scale_y;  // Inverse for volume preservation
	
	// Clamp to prevent extreme values
	scale_x = clamp(scale_x, 0.3, 3.0);
	scale_y = clamp(scale_y, 0.3, 3.0);
	
	// Add subtle wobble if enabled
	if (wobble_amount > 0.001) {
		float wobble = sin(TIME * wobble_speed) * wobble_amount;
		scale_x += wobble;
		scale_y -= wobble * 0.5;
	}
	
	// Scale X around center (X stays centered)
	VERTEX.x *= scale_x;
	
	// Scale Y around the pivot point (offset from center)
	// Move to pivot-relative space, scale, then move back
	float y_relative_to_pivot = VERTEX.y - pivot_offset_y;
	VERTEX.y = pivot_offset_y + (y_relative_to_pivot * scale_y);
	
	// Apply vertical offset for bounce effect
	VERTEX.y += vertical_offset;
}

void fragment() {
	// Pure pass-through - no color modification, deformation is in vertex shader only
	vec4 tex = texture(TEXTURE, UV);
	COLOR.rgb = tex.rgb;
	COLOR.a = tex.a * COLOR.a;  // Only use vertex alpha for fade effects
}
