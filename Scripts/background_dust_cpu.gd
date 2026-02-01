@tool
class_name BackgroundDustCPU extends CPUParticles2D
## Simple floating dust particles using CPU for potentially better performance.

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
	
	# Preprocess to establish particles
	preprocess = min(dust_lifetime * 0.5, 10.0)
	
	# Create atlas texture with the dust region
	_atlas_texture = AtlasTexture.new()
	_atlas_texture.atlas = preload("res://Assets/Sprites/decals-sm.png")
	_atlas_texture.region = atlas_region
	texture = _atlas_texture
	
	# Emission box
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(emission_width / 2.0, emission_height / 2.0)
	
	# Random directions, very slow speed
	direction = Vector2(0, 0)
	spread = 180.0
	initial_velocity_min = 0.5
	initial_velocity_max = 2.0
	
	# No gravity
	gravity = Vector2(0, 0)
	
	# Slow rotation
	angular_velocity_min = -10.0
	angular_velocity_max = 10.0
	
	# Scale
	scale_amount_min = min_scale
	scale_amount_max = max_scale
	
	# Color
	color = dust_color
	
	# Light damping
	damping_min = 0.5
	damping_max = 1.5


func _update_material() -> void:
	emission_rect_extents = Vector2(emission_width / 2.0, emission_height / 2.0)
	scale_amount_min = min_scale
	scale_amount_max = max_scale
	color = dust_color


func _update_texture() -> void:
	if _atlas_texture:
		_atlas_texture.region = atlas_region
