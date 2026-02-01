@tool
class_name BackgroundDust extends GPUParticles2D
## Ambient floating dust particles for background atmosphere.
## Continuously emits gentle, drifting dust motes.

@export_group("Emission Area")
@export var emission_width := 400.0:  ## Width of emission rectangle
	set(value):
		emission_width = value
		_update_emission_area()
@export var emission_height := 240.0:  ## Height of emission rectangle
	set(value):
		emission_height = value
		_update_emission_area()

@export_group("Particle Settings")
@export var particle_count := 150:  ## Number of dust particles
	set(value):
		particle_count = value
		amount = value
@export var dust_lifetime := 20.0:  ## How long each particle lives
	set(value):
		dust_lifetime = value
		lifetime = value
@export var min_speed := 0.5:  ## Minimum drift speed
	set(value):
		min_speed = value
		_update_speed()
@export var max_speed := 2.0:  ## Maximum drift speed
	set(value):
		max_speed = value
		_update_speed()

@export_group("Appearance")
@export var min_scale := 1.5:  ## Minimum dust size
	set(value):
		min_scale = value
		_update_scale()
@export var max_scale := 3.0:  ## Maximum dust size
	set(value):
		max_scale = value
		_update_scale()
@export var dust_color := Color(1.0, 1.0, 1.0, 0.3):  ## Dust tint and opacity
	set(value):
		dust_color = value
		if _process_material:
			_process_material.color = value

@export_group("Movement")
@export var drift_speed := 0.3:  ## Speed of floating motion
	set(value):
		drift_speed = value
		_update_shader_params()
@export var drift_amount := 2.0:  ## Amount of horizontal drift
	set(value):
		drift_amount = value
		_update_shader_params()
@export var vertical_drift := 1.5:  ## Amount of vertical bobbing
	set(value):
		vertical_drift = value
		_update_shader_params()
@export var warble_amount := 0.03:  ## Edge warble intensity
	set(value):
		warble_amount = value
		_update_shader_params()

@export_group("Softness")
@export var blur_amount := 0.0:  ## Blur/softness of dust particles
	set(value):
		blur_amount = value
		_update_shader_params()
@export var edge_softness := 0.0:  ## How soft the particle edges are
	set(value):
		edge_softness = value
		_update_shader_params()
@export var glow_strength := 0.0:  ## Subtle inner glow
	set(value):
		glow_strength = value
		_update_shader_params()

@export_group("Texture Atlas")
## Region of the sprite sheet containing dust sprites (in pixels)
@export var atlas_region := Rect2(192, 96, 64, 160):  ## x, y, width, height
	set(value):
		atlas_region = value
		if _atlas_texture:
			_atlas_texture.region = value
@export var atlas_h_frames := 3:  ## Horizontal frames in the dust region
	set(value):
		atlas_h_frames = value
		_update_shader_params()
@export var atlas_v_frames := 4:  ## Vertical frames in the dust region
	set(value):
		atlas_v_frames = value
		_update_shader_params()

var _process_material: ParticleProcessMaterial
var _shader_material: ShaderMaterial
var _atlas_texture: AtlasTexture


func _ready() -> void:
	_setup_particles()


func _setup_particles() -> void:
	# Configure GPUParticles2D for continuous emission
	emitting = true
	one_shot = false
	explosiveness = 0.0  # Steady stream, not bursts
	amount = particle_count
	lifetime = dust_lifetime
	
	# Create atlas texture to extract just the dust region
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = preload("res://Assets/Sprites/decals-sm.png")
	_atlas_texture.region = atlas_region
	texture = _atlas_texture
	
	# Create and configure process material
	_process_material = ParticleProcessMaterial.new()
	process_material = _process_material
	
	# Emission shape - rectangle covering the area
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = Vector3(emission_width / 2.0, emission_height / 2.0, 0)
	
	# Direction - mostly random, very slow drift
	_process_material.direction = Vector3(0, 0, 0)
	_process_material.spread = 180.0  # Full spread for random directions
	
	# Very slow initial velocity
	_process_material.initial_velocity_min = min_speed
	_process_material.initial_velocity_max = max_speed
	
	# No gravity - dust just floats
	_process_material.gravity = Vector3(0, 0, 0)
	
	# Very slow angular velocity for gentle rotation
	_process_material.angular_velocity_min = -5.0
	_process_material.angular_velocity_max = 5.0
	
	# Scale variation
	_process_material.scale_min = min_scale
	_process_material.scale_max = max_scale
	
	# Scale curve - constant size (no zoom effect)
	var scale_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))    # Full size from start
	curve.add_point(Vector2(1.0, 1.0))    # Full size to end
	scale_curve.curve = curve
	_process_material.scale_curve = scale_curve
	
	# Color
	_process_material.color = dust_color
	
	# Alpha curve - smooth gradual fade in, hold, smooth fade out
	var alpha_curve = CurveTexture.new()
	var alpha = Curve.new()
	alpha.add_point(Vector2(0.0, 0.0))    # Start invisible
	alpha.add_point(Vector2(0.15, 0.5))   # Gradual fade in
	alpha.add_point(Vector2(0.3, 1.0))    # Full opacity
	alpha.add_point(Vector2(0.7, 1.0))    # Stay full
	alpha.add_point(Vector2(0.85, 0.5))   # Gradual fade out
	alpha.add_point(Vector2(1.0, 0.0))    # Gone
	alpha_curve.curve = alpha
	_process_material.alpha_curve = alpha_curve
	
	# Very light damping to keep particles floating
	_process_material.damping_min = 1.0
	_process_material.damping_max = 3.0
	
	# Create shader material for floating/warble effect
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = preload("res://Shaders/background_dust.gdshader")
	
	# Set shader parameters
	_shader_material.set_shader_parameter("h_frames", atlas_h_frames)
	_shader_material.set_shader_parameter("v_frames", atlas_v_frames)
	_shader_material.set_shader_parameter("drift_speed", drift_speed)
	_shader_material.set_shader_parameter("drift_amount", drift_amount)
	_shader_material.set_shader_parameter("vertical_drift", vertical_drift)
	_shader_material.set_shader_parameter("warble_amount", warble_amount)
	_shader_material.set_shader_parameter("blur_amount", blur_amount)
	_shader_material.set_shader_parameter("edge_softness", edge_softness)
	_shader_material.set_shader_parameter("glow_strength", glow_strength)
	
	material = _shader_material


func _update_emission_area() -> void:
	if _process_material:
		_process_material.emission_box_extents = Vector3(emission_width / 2.0, emission_height / 2.0, 0)


func _update_speed() -> void:
	if _process_material:
		_process_material.initial_velocity_min = min_speed
		_process_material.initial_velocity_max = max_speed


func _update_scale() -> void:
	if _process_material:
		_process_material.scale_min = min_scale
		_process_material.scale_max = max_scale


func _update_shader_params() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("h_frames", atlas_h_frames)
		_shader_material.set_shader_parameter("v_frames", atlas_v_frames)
		_shader_material.set_shader_parameter("drift_speed", drift_speed)
		_shader_material.set_shader_parameter("drift_amount", drift_amount)
		_shader_material.set_shader_parameter("vertical_drift", vertical_drift)
		_shader_material.set_shader_parameter("warble_amount", warble_amount)
		_shader_material.set_shader_parameter("blur_amount", blur_amount)
		_shader_material.set_shader_parameter("edge_softness", edge_softness)
		_shader_material.set_shader_parameter("glow_strength", glow_strength)


## Update emission area at runtime
func set_emission_area(width: float, height: float) -> void:
	emission_width = width
	emission_height = height
	if _process_material:
		_process_material.emission_box_extents = Vector3(width / 2.0, height / 2.0, 0)


## Update dust color/opacity at runtime
func set_dust_color(new_color: Color) -> void:
	dust_color = new_color
	if _process_material:
		_process_material.color = new_color


## Update particle count (requires restart)
func set_particle_count(count: int) -> void:
	particle_count = count
	amount = count


## Set the atlas region for dust sprites (in pixels)
func set_atlas_region(region: Rect2, h_frames: int = 3, v_frames: int = 4) -> void:
	atlas_region = region
	atlas_h_frames = h_frames
	atlas_v_frames = v_frames
	
	if _atlas_texture:
		_atlas_texture.region = region
	
	if _shader_material:
		_shader_material.set_shader_parameter("h_frames", h_frames)
		_shader_material.set_shader_parameter("v_frames", v_frames)
