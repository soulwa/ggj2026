class_name ShatterParticles extends CPUParticles2D
## Emits sparkly crystal shatter particles when foreground tiles break.
## Supports multiple colors sampled from the shattered tile.
## Call emit_shatter() to trigger a burst with custom colors.

@export_group("Burst Settings")
@export var particles_per_burst := 24  ## How many particles per shatter
@export var burst_spread := 180.0  ## Full spread for explosion effect

@export_group("Particle Physics")
@export var min_speed := 80.0  ## Minimum ejection speed
@export var max_speed := 200.0  ## Maximum ejection speed
@export var gravity_strength := 400.0  ## Lighter gravity for floaty crystal feel
@export var particle_lifetime := 0.8  ## How long particles live
@export var lifetime_randomness_amount := 0.4  ## Variation in particle lifetime

@export_group("Particle Appearance")
@export var min_size := 2.0  ## Minimum particle size in pixels
@export var max_size := 6.0  ## Maximum particle size in pixels
@export var fallback_color := Color(0.4, 0.7, 0.8, 1.0)  ## Default crystal color if none provided

# Pre-create texture as static to share across instances
static var _shared_particle_texture: ImageTexture

# Store colors for the color ramp
var _shatter_colors: Array[Color] = []


func _ready() -> void:
	_setup_particles()


func _setup_particles() -> void:
	# Configure the CPUParticles2D node
	emitting = false
	one_shot = true
	explosiveness = 0.9  # Mostly simultaneous with slight spread
	amount = particles_per_burst
	lifetime = particle_lifetime
	lifetime_randomness = lifetime_randomness_amount
	
	# Emission shape - point source
	emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	
	# Direction - radial burst
	direction = Vector2(0, -1)
	spread = burst_spread
	
	# Initial velocity
	initial_velocity_min = min_speed
	initial_velocity_max = max_speed
	
	# Gravity - lighter for floaty shards
	gravity = Vector2(0, gravity_strength)
	
	# Angular velocity (spinning shards)
	angular_velocity_min = -540.0
	angular_velocity_max = 540.0
	
	# Size variation
	scale_amount_min = min_size / 8.0
	scale_amount_max = max_size / 8.0
	
	# Default color
	color = fallback_color
	
	# Damping for slight air resistance
	damping_min = 10.0
	damping_max = 30.0
	
	# Use shared texture
	texture = _get_shared_particle_texture()


func _create_color_ramp_with_colors(colors: Array[Color]) -> Gradient:
	var gradient = Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	
	if colors.is_empty():
		colors = [fallback_color]
	
	# Create a ramp that cycles through colors and fades out
	# Use the colors at different points, ending with fade to transparent
	var num_colors = min(colors.size(), 3)
	var offsets: PackedFloat32Array = []
	var gradient_colors: PackedColorArray = []
	
	# Start with first color at full opacity
	offsets.append(0.0)
	gradient_colors.append(Color(colors[0].r, colors[0].g, colors[0].b, 1.0))
	
	# Add color variations in the middle
	if num_colors >= 2:
		offsets.append(0.3)
		gradient_colors.append(Color(colors[1 % colors.size()].r, colors[1 % colors.size()].g, colors[1 % colors.size()].b, 0.9))
	
	if num_colors >= 3:
		offsets.append(0.5)
		gradient_colors.append(Color(colors[2 % colors.size()].r, colors[2 % colors.size()].g, colors[2 % colors.size()].b, 0.7))
	
	# Fade out
	offsets.append(0.75)
	gradient_colors.append(Color(colors[0].r, colors[0].g, colors[0].b, 0.4))
	
	offsets.append(1.0)
	gradient_colors.append(Color(colors[0].r, colors[0].g, colors[0].b, 0.0))
	
	gradient.offsets = offsets
	gradient.colors = gradient_colors
	
	return gradient


func _get_shared_particle_texture() -> ImageTexture:
	if not _shared_particle_texture:
		# Create a small diamond/shard-like texture
		var size := 8
		var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		
		# Draw a simple diamond shape
		var center = size / 2
		for y in range(size):
			for x in range(size):
				var dx = abs(x - center + 0.5)
				var dy = abs(y - center + 0.5)
				if dx + dy <= center:
					img.set_pixel(x, y, Color.WHITE)
		
		_shared_particle_texture = ImageTexture.create_from_image(img)
	return _shared_particle_texture


## Emit a shatter burst with custom colors sampled from the tile.
## [param emit_position] - World position to emit from
## [param colors] - Array of colors to use for particles (sampled from tile)
## [param impact_direction] - Optional direction the impact came from
func emit_shatter(emit_position: Vector2, colors: Array[Color] = [], impact_direction: Vector2 = Vector2.ZERO) -> void:
	global_position = emit_position
	
	# Store colors and create color ramp
	if colors.is_empty():
		_shatter_colors = [fallback_color]
	else:
		_shatter_colors = colors
	
	# Set up color ramp with the tile's colors
	color_ramp = _create_color_ramp_with_colors(_shatter_colors)
	color = _shatter_colors[0]
	
	# Set direction - bias slightly upward for nice visual, but mostly radial
	if impact_direction.length() > 0.1:
		# Particles fly away from impact
		direction = -impact_direction.normalized()
		spread = 120.0  # Narrower spread in impact direction
	else:
		direction = Vector2(0, -1)
		spread = burst_spread
	
	# Restart emission
	restart()
	emitting = true


## Simple emit with a single color
func emit_shatter_simple(emit_position: Vector2, main_color: Color) -> void:
	var colors: Array[Color] = [main_color]
	emit_shatter(emit_position, colors)
