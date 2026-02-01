class_name AfterimageTrail extends Node2D
## Spawns fading afterimage sprites behind a character during special actions.
## Trail activates only during thrusts, dives, and double jumps - not normal movement.

@export var enabled := true
@export var max_images := 30  ## Max concurrent afterimages (for z-layering)

@export_group("Spawn Rate")
@export var spawn_distance := 12.0  ## Pixels between afterimages

@export_group("Fade")
@export var fade_duration := 0.35  ## How long each afterimage lasts
@export var cleanup_fade_time := 0.12  ## Time for afterimages to catch up when landing
@export var cleanup_catch_up := true  ## Afterimages move towards player when stopping

@export_group("Colors")
@export var start_color := Color(0.5, 0.4, 0.9, 0.6)  ## Blue-purple
@export var mid_color := Color(0.6, 0.2, 0.8, 0.4)    ## Deeper purple
@export var end_color := Color(0.7, 0.1, 0.6, 0.0)    ## Dark magenta, faded

var _z_offset := 0
var _sprites: Array[AnimatedSprite2D] = []
var _player: Player
var _active_afterimages: Array[Node2D] = []
var _is_trailing := false  ## Currently showing trail
var _last_spawn_pos := Vector2.ZERO
var _distance_accumulated := 0.0


func _ready() -> void:
	_player = get_parent() as Player
	if not _player:
		push_warning("AfterimageTrail: Parent must be a Player")
		return
	
	for child in _player.get_children():
		if child is AnimatedSprite2D:
			_sprites.append(child)
	
	if _sprites.is_empty():
		push_warning("AfterimageTrail: No AnimatedSprite2D siblings found")


func _physics_process(delta: float) -> void:
	if not enabled or not _player or _sprites.is_empty():
		return
	
	var on_surface = _player.is_on_floor() or _player.is_on_wall()
	
	# Check if player is performing a special action that should show trail
	var in_special_action = _is_in_trail_action()
	
	# Trail state machine:
	# - Start trailing when performing thrust, dive, or double jump
	# - Stop trailing when touching floor/wall or action ends
	
	if not _is_trailing:
		# Check if we should START trailing
		if in_special_action and not on_surface:
			_start_trailing()
	else:
		# Check if we should STOP trailing (landed on surface or action ended)
		if on_surface or not in_special_action:
			_stop_trailing()
		else:
			# Continue trailing - spawn afterimages based on distance
			_update_trail()


## Returns true if the player is performing an action that should show trail
func _is_in_trail_action() -> bool:
	# Trail during thrust states
	if _player.current_state == Player.MoveState.THRUST:
		return true
	if _player.current_state == Player.MoveState.THRUST_ACTIONABLE:
		return true
	
	# Trail during dive
	if _player.current_state == Player.MoveState.DIVE:
		return true
	
	# Trail during double jump animation (set when double jumping, cleared on landing)
	if _player.is_doublejump_animation:
		return true
	
	return false


func _start_trailing() -> void:
	_is_trailing = true
	_last_spawn_pos = _player.global_position
	_distance_accumulated = 0.0
	_z_offset = 0


func _stop_trailing() -> void:
	_is_trailing = false
	_cleanup_afterimages()
	_distance_accumulated = 0.0


## Public method to immediately clear all trails (e.g., on death)
func clear_all_trails() -> void:
	_is_trailing = false
	_distance_accumulated = 0.0
	# Immediately free all afterimages without fade animation
	for afterimage in _active_afterimages:
		if is_instance_valid(afterimage):
			var tween = afterimage.get_meta("tween", null)
			if tween and tween is Tween:
				tween.kill()
			afterimage.queue_free()
	_active_afterimages.clear()


func _update_trail() -> void:
	var current_pos = _player.global_position
	_distance_accumulated += current_pos.distance_to(_last_spawn_pos)
	_last_spawn_pos = current_pos
	
	# Spawn afterimages at regular distance intervals
	while _distance_accumulated >= spawn_distance:
		_distance_accumulated -= spawn_distance
		_spawn_afterimage()


func _cleanup_afterimages() -> void:
	var target_pos = _player.global_position
	
	for afterimage in _active_afterimages:
		if is_instance_valid(afterimage):
			var tweens = afterimage.get_meta("tween", null)
			if tweens and tweens is Tween:
				tweens.kill()
			
			var cleanup_tween = afterimage.create_tween()
			cleanup_tween.set_parallel(true)
			cleanup_tween.tween_property(afterimage, "modulate:a", 0.0, cleanup_fade_time)
			
			if cleanup_catch_up:
				cleanup_tween.tween_property(afterimage, "global_position", target_pos, cleanup_fade_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			
			cleanup_tween.set_parallel(false)
			cleanup_tween.tween_callback(afterimage.queue_free)
	
	_active_afterimages.clear()


func _spawn_afterimage() -> void:
	_z_offset += 1
	if _z_offset > max_images:
		_z_offset = 1
	
	var container = Node2D.new()
	container.global_position = _player.global_position
	container.z_index = _player.z_index - (max_images - _z_offset + 1)
	
	for sprite in _sprites:
		var afterimage = Sprite2D.new()
		afterimage.texture = sprite.sprite_frames.get_frame_texture(
			sprite.animation, 
			sprite.frame
		)
		afterimage.flip_h = sprite.flip_h
		afterimage.position = sprite.position
		afterimage.scale = sprite.scale
		afterimage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		container.add_child(afterimage)
	
	container.modulate = start_color
	_player.get_parent().add_child(container)
	_active_afterimages.append(container)
	
	# Animate: start -> mid -> end color with slight shrink
	var tween = container.create_tween()
	container.set_meta("tween", tween)
	
	tween.set_parallel(true)
	tween.tween_property(container, "modulate", mid_color, fade_duration * 0.4)
	tween.tween_property(container, "scale", container.scale * 0.95, fade_duration * 0.4)
	tween.set_parallel(false)
	
	tween.set_parallel(true)
	tween.tween_property(container, "modulate", end_color, fade_duration * 0.6)
	tween.tween_property(container, "scale", container.scale * 0.85, fade_duration * 0.6)
	tween.set_parallel(false)
	
	tween.tween_callback(_remove_afterimage.bind(container))


func _remove_afterimage(afterimage: Node2D) -> void:
	_active_afterimages.erase(afterimage)
	afterimage.queue_free()
