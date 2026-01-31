class_name LevelTransition extends Area2D

@export var direction: Level.Direction = Level.Direction.Left

func _on_body_entered(body: Node2D):
	if body is Player:
		body.switch_level(direction)
