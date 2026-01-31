class_name Level extends Node2D

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

func _ready() -> void:
	for child in get_children():
		if child is PlayerSpawn and child.direction == Globals.opposite_direction_from:
			print("[SPAWN] %s" % child.position)
			$Player.position = child.position

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
