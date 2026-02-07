class_name Title extends Node2D

func _ready() -> void:
	PauseMenu.can_pause = false

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		var tween := create_tween()
		tween.tween_property($MaskSelectors, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property($Label2, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property($Sprite2D, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property($Label3, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property($AudioControls, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://Scenes/Levels/intro.tscn")
		)
