@tool
class_name BackgroundDust extends GPUParticles2D
## Simple floating dust particles - no shader, just basic particles.

@export_group("Emission Area")
@export var emission_width := 400.0:
	set(value):
		emission_width = value
		_update_material()
@export var emission_height := 240.0:
	set(value):
		emission_height = value
		_update_material()

@export_group("Particle Settings")
@export var particle_count := 50:
	set(value):
		particle_count = value
		amount = value
@export var dust_lifetime := 20.0:
	set(value):
		dust_lifetime = value
		lifetime = value

@export_group("Appearance")
@export var min_scale := 1.5:
	set(value):
		min_scale = value
		_update_material()
@export var max_scale := 3.0:
	set(value):
		max_scale = value
		_update_material()
@export var dust_color := Color(1.0, 1.0, 1.0, 0.3):
	set(value):
		dust_color = value
		_update_material()

@export_group("Texture Atlas")
@export var atlas_region := Rect2(192, 96, 64, 160):
	set(value):
		atlas_region = value
		_update_texture()
@export var frame_size := Vector2(32, 32):
	set(value):
		frame_size = value
		_update_texture()

var _process_material: ParticleProcessMaterial
var _atlas_texture: AtlasTexture


func _ready() -> void:
	_setup_particles()


func _setup_particles() -> void:
	# Basic setup
	emitting = true
	one_shot = false
	explosiveness = 0.0
	amount = particle_count
	lifetime = dust_lifetime
	
	# Preprocess to establish particles (not full lifetime to reduce load spike)
	preprocess = min(dust_lifetime * 0.5, 10.0)
	
	# Create atlas texture with the dust region
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = preload("res://Assets/Sprites/decals-sm.png")
	_atlas_texture.region = atlas_region
	texture = _atlas_texture
	
	# Calculate frames from region and frame size
	var h_frames := int(atlas_region.size.x / frame_size.x)
	var v_frames := int(atlas_region.size.y / frame_size.y)
	var total_frames := h_frames * v_frames
	
	# Create process material
	_process_material = ParticleProcessMaterial.new()
	process_material = _process_material
	
	# Enable animation to randomly pick frames
	_process_material.anim_speed_min = 0.0
	_process_material.anim_speed_max = 0.0
	_process_material.anim_offset_min = 0.0
	_process_material.anim_offset_max = 1.0
	
	# Set texture frames for animation
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	
	# Emission box
	_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_process_material.emission_box_extents = Vector3(emission_width / 2.0, emission_height / 2.0, 0)
	
	# Random directions, very slow speed to keep particles in area
	_process_material.direction = Vector3(0, 0, 0)
	_process_material.spread = 180.0
	_process_material.initial_velocity_min = 0.5
	_process_material.initial_velocity_max = 2.0
	
	# No gravity
	_process_material.gravity = Vector3(0, 0, 0)
	
	# Slow rotation
	_process_material.angular_velocity_min = -10.0
	_process_material.angular_velocity_max = 10.0
	
	# Scale
	_process_material.scale_min = min_scale
	_process_material.scale_max = max_scale
	
	# Color - bright pink for debug
	_process_material.color = dust_color
	
	# Simpler alpha fade - fewer curve points for better performance
	var alpha_curve = CurveTexture.new()
	var alpha = Curve.new()
	alpha.add_point(Vector2(0.0, 0.0))
	alpha.add_point(Vector2(0.2, 1.0))
	alpha.add_point(Vector2(0.8, 1.0))
	alpha.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = alpha
	_process_material.alpha_curve = alpha_curve
	
	# Light damping
	_process_material.damping_min = 0.5
	_process_material.damping_max = 1.5
	
	# No shader - just raw particles
	material = null
	


func _update_material() -> void:
	if _process_material:
		_process_material.emission_box_extents = Vector3(emission_width / 2.0, emission_height / 2.0, 0)
		_process_material.scale_min = min_scale
		_process_material.scale_max = max_scale
		_process_material.color = dust_color


func _update_texture() -> void:
	if _atlas_texture:
		_atlas_texture.region = atlas_region
