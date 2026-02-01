class_name Checkpoint extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("GOT PLAYER")
		body.set_spawn($Marker2D.global_position)
