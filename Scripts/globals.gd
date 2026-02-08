extends Node

var active_controller_idx: int = 0

var death_count := 0
var time_spent := 0.0

var begin_fade_out: bool = false
var end_text_done: bool = false
var is_ngp: bool = false

func _ready() -> void:
	# Pre-warm mushroom spore shader by emitting particles during startup
	# This forces shader compilation before gameplay begins
	_prewarm_spore_shader()


func _prewarm_spore_shader() -> void:
	# Initialize the cached materials
	MushroomSpores._init_cached_materials()
	
	# Create a temporary GPUParticles2D to force shader compilation
	var warmup_particles := GPUParticles2D.new()
	warmup_particles.process_material = MushroomSpores._cached_process_material
	warmup_particles.material = MushroomSpores._cached_shader_material
	warmup_particles.texture = MushroomSpores._cached_texture
	warmup_particles.amount = 1
	warmup_particles.lifetime = 0.1
	warmup_particles.one_shot = true
	warmup_particles.explosiveness = 1.0
	
	# Add to tree so it renders
	add_child(warmup_particles)
	
	# Emit to force GPU shader compilation
	warmup_particles.emitting = true
	
	# Clean up after a short delay
	get_tree().create_timer(0.2).timeout.connect(warmup_particles.queue_free)

var ignore_spawn_direction := false
var opposite_direction_from := Level.Direction.Left

var has_double_jump := false
var has_downdash := false
var has_crying := false

var has_medal_downdash = false
var has_medal_doublejump = false

# 0 to 1 to fill screen, "cutscene" maybe.
# when its 1.0 you can swim
var waterworld := 0.0

enum Action {
	Thrust,
	DoubleJump,
	Dive,
	Cry,
}
var currently_selected_action: Action = Action.Thrust

const title_screen_path = "res://Scenes/title.tscn"
func reset_game(new_game_plus: bool = true) -> void:
	if !new_game_plus:
		has_double_jump = false
		has_downdash = false
	else:
		is_ngp = true
	has_crying = false
	has_medal_downdash = false
	has_medal_doublejump = false
	begin_fade_out = false
	end_text_done = false
	currently_selected_action = Action.Thrust
	get_tree().change_scene_to_file(title_screen_path)


func _input(event):
	if event is InputEventMouseMotion\
	or event is InputEventMouseButton\
	or (event is InputEventJoypadMotion and abs(event.axis_value) < 0.2):
		return
	
	var new_controller_idx: int
	if event is InputEventJoypadButton\
	or event is InputEventJoypadMotion:
		new_controller_idx = event.device
	elif event is InputEventKey:
		new_controller_idx = -1
	else:
		new_controller_idx = -1
	
	if new_controller_idx != active_controller_idx:
		active_controller_idx = new_controller_idx
