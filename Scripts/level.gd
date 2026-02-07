class_name Level extends Node2D

const WallDentManagerScript = preload("res://Scripts/wall_dent_manager.gd")

@export_file var left: String
@export_file var right: String
@export_file var up: String
@export_file var down: String

@export var override_dont_use_spawn := false

enum Direction {
	Left,
	Right,
	Up,
	Down
}

func opposite_dir(d: Direction) -> Direction:
	match d:
		Direction.Left: return Direction.Right
		Direction.Right: return Direction.Left
		Direction.Up: return Direction.Down
		Direction.Down: return Direction.Up
		_: return Direction.Right

var opposite_came_from: Direction
var spawn: Vector2
var _dent_manager: Node  # WallDentManager

func _ready() -> void:
	PauseMenu.can_pause = true
	
	# Setup wall dent manager
	_setup_dent_manager()
	
	var level_bounds: Rect2i = $TileMapLayer.get_used_rect()
	var worldspace_topleft = $TileMapLayer.map_to_local(level_bounds.position) - Vector2(16, 16)
	$Camera2D.limit_left = worldspace_topleft.x + 32
	$Camera2D.limit_right = worldspace_topleft.x + level_bounds.size.x * 32 - 32
	$Camera2D.limit_top = worldspace_topleft.y + 32
	$Camera2D.limit_bottom = worldspace_topleft.y + level_bounds.size.y * 32 - 32
	
	# Setup background dust particles
	_setup_background_dust()
	
	#print($Camera2D.limit_right)
	
	if not override_dont_use_spawn:
		for child in get_children():
			if child is PlayerSpawn and child.direction == Globals.opposite_direction_from:
				print("[SPAWN] %s" % child.position)
				$Player.position = child.position
				$Player.spawnpoint = child.position
	
	reset_camera()

func _setup_dent_manager() -> void:
	# Check if dent manager already exists
	for child in get_children():
		if child.get_script() == WallDentManagerScript:
			_dent_manager = child
			return
	
	# Create one if not present
	_dent_manager = Node.new()
	_dent_manager.set_script(WallDentManagerScript)
	_dent_manager.name = "WallDentManager"
	add_child(_dent_manager)


func _setup_background_dust() -> void:
	# Use the cached DustManager instead of creating new emitters each time
	DustManager.setup_for_level($Camera2D)
	
var _is_switching_level: bool = false

func reset_enemies() -> void:
	for entity in $TileMapLayer.get_children():
		if entity is EnemyFrog:
			entity.reset()
		elif entity is MushroomGuy:
			entity.reset()
		elif entity is MushroomTrap:
			entity.reset()

func reset_camera() -> void:
	$Camera2D.force_initial_position_stable($Player.position, $Player.velocity)

func switch_level(transition_dir: Direction):
	# deregister shit
	MusicManager.battlers = 0
	MusicManager.crossfade_to_explore_music()
	
	# Prevent triggering multiple transitions from this level
	if _is_switching_level:
		return
	_is_switching_level = true
	
	var opposite = opposite_dir(transition_dir)
	var scene: String
	match transition_dir:
		Direction.Left: scene = left
		Direction.Right: scene = right
		Direction.Up: scene = up
		Direction.Down: scene = down
		_: scene = left
	
	# Choose shader based on transition direction
	# Left/Right = horizontal sweep, Up/Down = vertical sweep
	# Sweep follows the player's movement direction
	match transition_dir:
		Direction.Left:
			TransitionOverlay.set_shader_horizontal(1.0)   # Left to right (player going left)
		Direction.Right:
			TransitionOverlay.set_shader_horizontal(-1.0)  # Right to left (player going right)
		Direction.Up:
			TransitionOverlay.set_shader_vertical(1.0)     # Top to bottom (player going up)
		Direction.Down:
			TransitionOverlay.set_shader_vertical(-1.0)    # Bottom to top (player going down)
	
	# Store opposite direction for spawn positioning in new scene
	Globals.opposite_direction_from = opposite
	
	# Start the transition and change scene at midpoint
	_do_transition(scene)


func _do_transition(scene_path: String) -> void:
	# Play the full transition
	TransitionOverlay.play_transition()
	
	# Wait for the midpoint (screen fully covered)
	await TransitionOverlay.transition_midpoint
	
	# stop player walking at this point
	MusicManager.stop_sound_footstep()
	
	# Small delay to ensure screen is fully covered before scene switch
	await get_tree().create_timer(0.1).timeout
	
	# Change the scene while covered
	get_tree().change_scene_to_file(scene_path)
	
	await TransitionOverlay.transition_complete
