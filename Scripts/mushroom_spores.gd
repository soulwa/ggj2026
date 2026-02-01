class_name MushroomSpores extends GPUParticles2D
## Emits spore particles when a mushroom is triggered.
## Uses a flipbook texture for varied spore appearances.
## Call emit_burst() to trigger a poofy burst of spores.

@export_group("Burst Settings")
@export var particles_per_burst := 16  ## Gentle puff of spores
@export var burst_spread := 85.0  ## Wide, soft cloud spread

@export_group("Particle Physics")
@export var min_speed := 20.0  ## Lazy drift speed
@export var max_speed := 45.0  ## Gentle float
@export var gravity_strength := 25.0  ## Very light, floaty
@export var particle_lifetime := 2.5  ## Long, lingering fade

@export_group("Particle Appearance")
@export var min_scale := 0.3  ## Spore size
@export var max_scale := 0.65  ## Delicate size
@export var spore_color := Color(1.0, 1.0, 1.0, 0.75)  ## Softer, more transparent

@export_group("Shader Effects")
@export var wiggle_speed := 2.0  ## Slow, gentle wiggle
@export var wiggle_amount := 3.0  ## Subtle movement
@export var warble_amount := 0.08  ## Soft edge warble

# Cached static materials - shared across all instances to avoid shader recompilation
static var _cached_process_material: ParticleProcessMaterial
static var _cached_shader_material: ShaderMaterial
static var _cached_texture: Texture2D
static var _materials_initialized: bool = false


func _ready() -> void:
	_setup_particles()
	
	# Auto-emit when running this scene directly for testing
	if get_tree().current_scene == self:
		position = get_viewport_rect().size / 2
		emit_burst(position, Vector2.UP)


func _input(event: InputEvent) -> void:
	# Only handle input when testing this scene directly
	if get_tree().current_scene != self:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_burst(get_global_mouse_position(), Vector2.UP)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		emit_burst(position, Vector2.UP)


## Initialize the cached materials once (called on first instance)
static func _init_cached_materials() -> void:
	if _materials_initialized:
		return
	_materials_initialized = true
	
	# Load the mushroom spore texture
	_cached_texture = preload("res://Assets/Sprites/ParticleMush.png")
	
	# Create and configure the process material (shared)
	_cached_process_material = ParticleProcessMaterial.new()
	
	# Emission shape - very tight point source
	_cached_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_cached_process_material.emission_sphere_radius = 0.5
	
	# Direction - upward with wide spread for poofy effect
	_cached_process_material.direction = Vector3(0, -1, 0)  # Up in 2D
	_cached_process_material.spread = 85.0
	
	# Initial velocity
	_cached_process_material.initial_velocity_min = 20.0
	_cached_process_material.initial_velocity_max = 45.0
	
	# Gravity - light for floaty spores
	_cached_process_material.gravity = Vector3(0, 25.0, 0)
	
	# Angular velocity (very gentle rotation)
	_cached_process_material.angular_velocity_min = -30.0
	_cached_process_material.angular_velocity_max = 30.0
	
	# Scale with variation
	_cached_process_material.scale_min = 0.3
	_cached_process_material.scale_max = 0.65
	
	# Scale curve - spores grow slightly then shrink as they fade
	var scale_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.3))   # Start small
	curve.add_point(Vector2(0.15, 1.0))  # Quickly grow
	curve.add_point(Vector2(0.7, 0.9))   # Stay visible
	curve.add_point(Vector2(1.0, 0.0))   # Shrink away
	scale_curve.curve = curve
	_cached_process_material.scale_curve = scale_curve
	
	# Color and alpha
	_cached_process_material.color = Color(1.0, 1.0, 1.0, 0.75)
	
	# Alpha fade curve
	var alpha_curve = CurveTexture.new()
	var alpha = Curve.new()
	alpha.add_point(Vector2(0.0, 0.0))   # Fade in
	alpha.add_point(Vector2(0.1, 1.0))   # Full opacity
	alpha.add_point(Vector2(0.6, 0.8))   # Slight fade
	alpha.add_point(Vector2(1.0, 0.0))   # Fade out
	alpha_curve.curve = alpha
	_cached_process_material.alpha_curve = alpha_curve
	
	# Damping for quick slowdown to gentle drift
	_cached_process_material.damping_min = 40.0
	_cached_process_material.damping_max = 70.0
	
	# Create ShaderMaterial with wiggle/warble/dissipation effects (shared)
	_cached_shader_material = ShaderMaterial.new()
	_cached_shader_material.shader = preload("res://Shaders/mushroom_spore.gdshader")
	
	# Set shader parameters
	_cached_shader_material.set_shader_parameter("h_frames", 4)
	_cached_shader_material.set_shader_parameter("v_frames", 2)
	_cached_shader_material.set_shader_parameter("wiggle_speed", 2.0)
	_cached_shader_material.set_shader_parameter("wiggle_amount", 3.0)
	_cached_shader_material.set_shader_parameter("warble_amount", 0.08)


func _setup_particles() -> void:
	# Ensure cached materials exist
	_init_cached_materials()
	
	# Configure the GPUParticles2D node
	emitting = false
	one_shot = true
	explosiveness = 0.85  # Burst together, slight stagger
	amount = particles_per_burst
	lifetime = particle_lifetime
	
	# Pre-process to help warm shader pipeline
	preprocess = 0.1
	
	# Use the cached/shared materials
	texture = _cached_texture
	process_material = _cached_process_material
	material = _cached_shader_material


## Emit a burst of spore particles at the given position.
## [param emit_position] - World position to emit from
## [param burst_direction] - Optional: direction bias for the burst (default: up)
##                          Note: Uses node rotation since material is shared
func emit_burst(emit_position: Vector2, burst_direction: Vector2 = Vector2.UP) -> void:
	global_position = emit_position
	
	# Use node rotation to control burst direction (material direction is shared/fixed)
	rotation = burst_direction.angle() + PI / 2  # Offset since default is UP (-Y)
	
	# Restart emission
	restart()
	emitting = true


## Emit spores upward (default mushroom pop)
func emit_upward(emit_position: Vector2) -> void:
	emit_burst(emit_position, Vector2.UP)


## Update particle count at runtime
func set_particle_count(count: int) -> void:
	particles_per_burst = count
	amount = count
