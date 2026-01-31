class_name InvisibleEntity extends Sprite2D

func _ready() -> void:
	visible =  Engine.is_editor_hint()
