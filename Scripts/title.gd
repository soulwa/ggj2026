class_name Title extends Node2D

func _process(delta: float) -> void:
	if Input.is_anything_pressed():
		var tween := create_tween()
		tween.tween_property($Label, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.parallel().tween_property($Label2, "modulate:a", 0.0, 2.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://Scenes/Levels/intro.tscn")
		)
