class_name MushroomTrap extends Node2D

@onready var guy_spawn_point: Node2D = $GuySpawnPoint


var mushroom_guy_scene: PackedScene = preload("uid://c8vt2srwf1vb4")

var min_guys: int = 5
var max_guys: int = 7

var activated: bool = false

func _on_player_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		activate()


func activate() -> void:
	if !activated:
		activated = true
		for i in randi_range(min_guys, max_guys):
			var new_guy = mushroom_guy_scene.instantiate()
			new_guy.global_position = guy_spawn_point.global_position
			call_deferred("add_sibling", new_guy)
		hide()
