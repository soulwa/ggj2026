class_name SmashParticles extends CPUParticles2D
## Emits debris/chunk particles when hitting walls or surfaces.
## Uses CPU particles to avoid GPU shader compilation stutter.
## Call emit_burst() to trigger a one-shot burst of particles at a position.

@export_group("Burst Settings")
@export var particles_per_burst := 16  ## How many particles per hit
@export var burst_spread := 65.0  ## Spread angle in degrees (from normal direction)

@export_group("Particle Physics")
@export var min_speed := 60.0  ## Minimum ejection speed
@export var max_speed := 180.0  ## Maximum ejection speed
@export var gravity_strength := 950.0  ## How fast particles fall (pulls downward)
@export var particle_lifetime := 1.0  ## How long particles live
@export var lifetime_randomness_amount := 0.5  ## Variation in particle lifetime (0-1)

@export_group("Particle Appearance")
@export var min_size := 3.0  ## Minimum particle size in pixels
@export var max_size := 8.0  ## Maximum particle size in pixels
@export var base_color := Color(0.22, 0.26, 0.35, 1.0)  ## Dark blue-black debris (brighter)
@export var color_variation := 0.1  ## Random color variation
@export var fade_out := true  ## Whether particles fade as they die

# Pre-create texture as static to share across instances
static var _shared_particle_texture: ImageTexture


func _ready() -> void:
	_setup_particles()


func _setup_particles() -> void:
	# Configure the CPUParticles2D node
	emitting = false
	one_shot = true
	explosiveness = 1.0  # All particles emit at once
	amount = particles_per_burst
	lifetime = particle_lifetime
	lifetime_randomness = lifetime_randomness_amount  # Particles die at different times
	
	# Emission shape - point source
	emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	
	# Direction - default upward spread, will be set per-burst
	direction = Vector2(0, -1)
	spread = burst_spread
	
	# Initial velocity
	initial_velocity_min = min_speed
	initial_velocity_max = max_speed
	
	# Gravity
	gravity = Vector2(0, gravity_strength)
	
	# Angular velocity (rotation)
	angular_velocity_min = -360.0
	angular_velocity_max = 360.0
	
	# Size
	scale_amount_min = min_size / 8.0  # Normalize to base texture size
	scale_amount_max = max_size / 8.0
	
	# Color
	color = base_color
	if fade_out:
		color_ramp = _create_color_ramp()
	
	# Damping (very low for smooth arcs)
	damping_min = 0.0
	damping_max = 8.0
	
	# Use shared texture
	texture = _get_shared_particle_texture()


func _create_color_ramp() -> Gradient:
	var gradient = Gradient.new()
	gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	# Very gradual fade spread across full lifetime
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.45, 0.65, 0.8, 0.92, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1.0),    # Full opacity at start
		Color(1, 1, 1, 0.92),   # Barely fading
		Color(1, 1, 1, 0.78),   # Slight fade
		Color(1, 1, 1, 0.55),   # Gentle mid fade
		Color(1, 1, 1, 0.32),   # Fading
		Color(1, 1, 1, 0.12),   # Getting faint
		Color(1, 1, 1, 0.0),    # Fully faded
	])
	return gradient


func _get_shared_particle_texture() -> ImageTexture:
	if not _shared_particle_texture:
		# Create an 8x8 white square texture for particles
		var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_shared_particle_texture = ImageTexture.create_from_image(img)
	return _shared_particle_texture


## Emit a burst of debris particles at the given position.
## [param emit_position] - World position to emit from
## [param surface_normal] - Normal of the surface hit (particles fly away from this)
## [param impact_velocity] - Optional: velocity at impact for more dynamic spread
func emit_burst(emit_position: Vector2, surface_normal: Vector2 = Vector2.UP, impact_velocity: Vector2 = Vector2.ZERO) -> void:
	global_position = emit_position
	
	# Minimal bias - let gravity do the work
	var downward_bias := Vector2(0, 0.1)
	var biased_normal = (surface_normal + downward_bias).normalized()
	
	# Set direction based on biased surface normal
	direction = biased_normal
	
	# Add some velocity influence - particles spread more in the direction of impact
	if impact_velocity.length() > 10:
		var impact_dir = impact_velocity.normalized()
		direction = (biased_normal * 0.6 + impact_dir * 0.4).normalized()
		
		# Increase speed based on impact velocity
		var speed_mult = clamp(impact_velocity.length() / 300.0, 1.0, 1.8)
		initial_velocity_min = min_speed * speed_mult
		initial_velocity_max = max_speed * speed_mult
	else:
		initial_velocity_min = min_speed
		initial_velocity_max = max_speed
	
	# Apply slight color variation per burst (blue-tinted variation)
	if color_variation > 0:
		var variation = randf_range(-color_variation, color_variation)
		color = Color(
			base_color.r + variation * 0.5,
			base_color.g + variation * 0.7,
			base_color.b + variation,  # More variation in blue channel
			base_color.a
		)
	
	# Restart emission
	restart()
	emitting = true


## Convenience function to emit towards a specific direction
func emit_towards(emit_position: Vector2, emit_direction: Vector2) -> void:
	emit_burst(emit_position, emit_direction.normalized())


## Emit a burst with a custom color (for enemy hits)
## [param emit_position] - World position to emit from
## [param surface_normal] - Normal of the surface hit (particles fly away from this)
## [param impact_velocity] - Optional: velocity at impact for more dynamic spread
## [param custom_color] - Color to use for this burst (overrides base_color temporarily)
func emit_burst_colored(emit_position: Vector2, surface_normal: Vector2, impact_velocity: Vector2, custom_color: Color) -> void:
	# Temporarily set the color for this burst
	var original_color = base_color
	base_color = custom_color
	color = custom_color
	
	# Emit the burst
	emit_burst(emit_position, surface_normal, impact_velocity)
	
	# Restore original color for future bursts
	base_color = original_color


## Emit a burst with weighted colors - particles are distributed across colors based on weights
## [param emit_position] - World position to emit from
## [param surface_normal] - Normal of the surface hit
## [param impact_velocity] - Velocity at impact
## [param color_palette] - Array of colors
## [param weights] - Array of weights (0.0-1.0) for each color. Should sum to 1.0. If empty, equal weights used.
func emit_burst_weighted(emit_position: Vector2, surface_normal: Vector2, impact_velocity: Vector2, color_palette: Array[Color], weights: Array[float] = []) -> void:
	if color_palette.is_empty():
		emit_burst(emit_position, surface_normal, impact_velocity)
		return
	
	var total_particles = particles_per_burst
	
	# Normalize weights or use equal weights
	var normalized_weights: Array[float] = []
	if weights.size() == color_palette.size():
		var weight_sum = 0.0
		for w in weights:
			weight_sum += w
		for w in weights:
			normalized_weights.append(w / weight_sum if weight_sum > 0 else 1.0 / weights.size())
	else:
		# Equal weights if not provided or mismatched
		var equal_weight = 1.0 / color_palette.size()
		for i in color_palette.size():
			normalized_weights.append(equal_weight)
	
	# Calculate particle counts for each color
	var particle_counts: Array[int] = []
	var assigned_particles = 0
	for i in range(normalized_weights.size()):
		var count = roundi(normalized_weights[i] * total_particles)
		particle_counts.append(count)
		assigned_particles += count
	
	# Distribute any remaining particles to the highest weighted color
	var remainder = total_particles - assigned_particles
	if remainder != 0 and particle_counts.size() > 0:
		var max_idx = 0
		for i in range(normalized_weights.size()):
			if normalized_weights[i] > normalized_weights[max_idx]:
				max_idx = i
		particle_counts[max_idx] += remainder
	
	# Pre-calculate direction and speed (shared across all mini-bursts)
	var downward_bias := Vector2(0, 0.1)
	var biased_normal = (surface_normal + downward_bias).normalized()
	var emit_direction = biased_normal
	
	var speed_min = min_speed
	var speed_max = max_speed
	if impact_velocity.length() > 10:
		var impact_dir = impact_velocity.normalized()
		emit_direction = (biased_normal * 0.6 + impact_dir * 0.4).normalized()
		var speed_mult = clamp(impact_velocity.length() / 300.0, 1.0, 1.8)
		speed_min = min_speed * speed_mult
		speed_max = max_speed * speed_mult
	
	# Spawn temporary particle emitters for each color (since one CPUParticles2D can only emit one color at a time)
	for i in range(color_palette.size()):
		if particle_counts[i] <= 0:
			continue
		
		# Apply color with slight variation
		var emit_color = color_palette[i]
		if color_variation > 0:
			var variation = randf_range(-color_variation, color_variation)
			emit_color = Color(
				emit_color.r + variation * 0.3,
				emit_color.g + variation * 0.3,
				emit_color.b + variation * 0.3,
				emit_color.a
			)
		
		# Create a temporary particle emitter for this color
		_spawn_temp_emitter(emit_position, emit_direction, speed_min, speed_max, emit_color, particle_counts[i])


## Spawns a temporary CPUParticles2D that auto-deletes after emission
func _spawn_temp_emitter(pos: Vector2, dir: Vector2, speed_min_val: float, speed_max_val: float, emit_color: Color, particle_count: int) -> void:
	var temp_particles = CPUParticles2D.new()
	get_parent().add_child(temp_particles)
	
	# Position and basic settings
	temp_particles.global_position = pos
	temp_particles.emitting = false
	temp_particles.one_shot = true
	temp_particles.explosiveness = 1.0
	temp_particles.amount = particle_count
	temp_particles.lifetime = particle_lifetime
	temp_particles.lifetime_randomness = lifetime_randomness_amount
	
	# Emission shape
	temp_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	
	# Direction and spread
	temp_particles.direction = dir
	temp_particles.spread = burst_spread
	
	# Velocity
	temp_particles.initial_velocity_min = speed_min_val
	temp_particles.initial_velocity_max = speed_max_val
	
	# Gravity
	temp_particles.gravity = Vector2(0, gravity_strength)
	
	# Angular velocity
	temp_particles.angular_velocity_min = -360.0
	temp_particles.angular_velocity_max = 360.0
	
	# Size
	temp_particles.scale_amount_min = min_size / 8.0
	temp_particles.scale_amount_max = max_size / 8.0
	
	# Color
	temp_particles.color = emit_color
	if fade_out:
		temp_particles.color_ramp = _create_color_ramp()
	
	# Damping
	temp_particles.damping_min = 0.0
	temp_particles.damping_max = 8.0
	
	# Texture
	temp_particles.texture = _get_shared_particle_texture()
	
	# Start emission
	temp_particles.emitting = true
	
	# Auto-delete after particles are done (lifetime + small buffer)
	var delete_timer = get_tree().create_timer(particle_lifetime + 0.5)
	delete_timer.timeout.connect(func(): 
		if is_instance_valid(temp_particles):
			temp_particles.queue_free()
	)


## Emit a burst with multiple colors using equal weights
## [param emit_position] - World position to emit from
## [param surface_normal] - Normal of the surface hit
## [param impact_velocity] - Velocity at impact
## [param color_palette] - Array of colors to distribute particles across
func emit_burst_palette(emit_position: Vector2, surface_normal: Vector2, impact_velocity: Vector2, color_palette: Array[Color]) -> void:
	emit_burst_weighted(emit_position, surface_normal, impact_velocity, color_palette, [])


## Update particle settings at runtime
func set_particle_color(new_color: Color) -> void:
	base_color = new_color
	color = new_color


func set_particle_count(count: int) -> void:
	particles_per_burst = count
	amount = count
