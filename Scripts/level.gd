class_name Level extends Node2D

const WallDentManagerScript = preload("res://Scripts/wall_dent_manager.gd")

@export_file var left: String
@export_file var right: String
@export_file var up: String
@export_file var down: String

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
	# Setup wall dent manager
	_setup_dent_manager()
	
	for child in get_children():
		if child is PlayerSpawn and child.direction == Globals.opposite_direction_from:
			print("[SPAWN] %s" % child.position)
			$Player.position = child.position


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

# TODO: wipe screen

func switch_level(transition_dir: Direction):
	var opposite = opposite_dir(transition_dir)
	var scene: String
	match transition_dir:
		Direction.Left: scene = left
		Direction.Right: scene = right
		Direction.Up: scene = up
		Direction.Down: scene = down
		_: scene = left
	Globals.opposite_direction_from = opposite
	get_tree().change_scene_to_file(scene)
	# TODO (sam): check if this makes sense.
