@tool
extends ColorRect

## Test script for previewing transition shaders in the editor
## Loops the progress parameter continuously

@export var animation_speed: float = 0.5  ## Full cycles per second
@export var paused: bool = false
@export_range(0.0, 1.0) var manual_progress: float = 0.0:
	set(value):
		manual_progress = value
		if paused and material:
			material.set_shader_parameter("progress", value)

## For directional shaders (horizontal/vertical)
@export_range(-1.0, 1.0) var direction: float = 1.0:
	set(value):
		direction = value
		if material:
			material.set_shader_parameter("direction", value)

var _time: float = 0.0


func _process(delta: float) -> void:
	if paused:
		return
	
	_time += delta * animation_speed
	
	# Loop from 0 to 1
	var progress = fmod(_time, 1.0)
	
	if material:
		material.set_shader_parameter("progress", progress)
