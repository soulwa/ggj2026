shader_type canvas_item;

uniform float brightness : hint_range(-4, 4) = 0; // -1.0 to 1.0
uniform float contrast : hint_range(0, 5) = 1;   // 0.0 (no contrast) to 2.0+


void fragment() {
	
	vec3 new_color = (COLOR.rgb + brightness - 0.5) * contrast + 0.5;
	COLOR = vec4(new_color, COLOR.a);
}