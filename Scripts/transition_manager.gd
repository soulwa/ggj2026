class_name TransitionManager extends CanvasLayer

## Emitted when the transition reaches the midpoint (screen fully covered)
## This is the ideal time to switch scenes
signal transition_midpoint
## Emitted when the transition completes
signal transition_complete

@onready var transition_rect: ColorRect = $ColorRect

## Shader variants
var _shader_horizontal: Shader = preload("res://Shaders/screen_transition_horizontal.gdshader")
var _shader_vertical: Shader = preload("res://Shaders/screen_transition_vertical.gdshader")

## Duration of the full transition in seconds
@export var transition_duration: float = 1.0

## Whether a transition is currently playing
var is_transitioning: bool = false

var _tween: Tween
var _progress: float = 0.0


func _ready() -> void:
	# Ensure we're on a high layer to render above everything
	layer = 100
	# Start fully transparent
	_set_progress(0.0)


## Sets the shader to horizontal (left-right to center) sweep
func set_shader_horizontal() -> void:
	if transition_rect and transition_rect.material:
		transition_rect.material.shader = _shader_horizontal


## Sets the shader to vertical (top-bottom to center) sweep
func set_shader_vertical() -> void:
	if transition_rect and transition_rect.material:
		transition_rect.material.shader = _shader_vertical


## Plays the full transition animation (in and out)
## If a transition is already running, it will be interrupted and restarted
func play_transition() -> void:
	# Kill any existing tween and reset state
	if _tween and _tween.is_valid():
		_tween.kill()
	
	is_transitioning = true
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	
	# Animate from 0 to 1
	_tween.tween_method(_set_progress, 0.0, 1.0, transition_duration)
	
	# Emit midpoint signal partway through
	# The midpoint is when the screen is most covered (around 40-50% progress)
	await get_tree().create_timer(transition_duration * 0.4).timeout
	transition_midpoint.emit()
	
	# Wait for completion
	await _tween.finished
	
	is_transitioning = false
	transition_complete.emit()


## Plays just the "in" part of the transition (covers screen)
## Useful for manual control of scene switching
func play_transition_in() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_SINE)
	
	# Only go to midpoint
	_tween.tween_method(_set_progress, 0.0, 0.5, transition_duration * 0.5)
	
	await _tween.finished
	transition_midpoint.emit()


## Plays just the "out" part of the transition (reveals screen)
## Call this after switching scenes
func play_transition_out() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_SINE)
	
	# Continue from midpoint to end
	_tween.tween_method(_set_progress, 0.5, 1.0, transition_duration * 0.5)
	
	await _tween.finished
	is_transitioning = false
	transition_complete.emit()


## Sets the transition progress directly (0.0 to 1.0)
func _set_progress(value: float) -> void:
	_progress = value
	if transition_rect and transition_rect.material:
		transition_rect.material.set_shader_parameter("progress", value)


## Gets the current transition progress
func get_progress() -> float:
	return _progress
