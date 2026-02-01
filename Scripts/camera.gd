class_name NiceCamera extends Camera2D

var player: Player

@export var xvel_lookahead_scale := 200.0
@export var yvel_lookahead_scale := 1000.0
@export var lookahead_distance := 200.0
@export var lookahead_smoothing := 8.0
@export var vertical_offset := 64.0
@export var deadzone := Vector2(24.0, 32.0)
@export var follow_speed := Vector2(10.0, 8.0)

@export_group("Screen Shake")
@export var hit_shake_intensity := 8.0
@export var hit_shake_duration := 0.15
@export var death_shake_intensity := 16.0
@export var death_shake_duration := 0.4
@export var shake_decay_rate := 5.0

var _prev_target_pos: Vector2
var _lookahead_x := 0.0
var _lookahead_y := 0.0

var hpui: HpUI = preload("res://Scenes/hpUI.tscn").instantiate()
var mask_ui: MaskUI = preload("res://Scenes/maskui.tscn").instantiate()

# Screen shake state
var _shake_intensity := 0.0
var _shake_duration := 0.0
var _shake_timer := 0.0
var _shake_offset := Vector2.ZERO

func _ready() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	canvas.add_child(hpui)
	canvas.add_child(mask_ui)


## Trigger screen shake with specified intensity and duration
func shake(intensity: float, duration: float) -> void:
	_shake_intensity = intensity
	_shake_duration = duration
	_shake_timer = duration


## Trigger screen shake for player hit
func shake_hit() -> void:
	shake(hit_shake_intensity, hit_shake_duration)


## Trigger screen shake for player death
func shake_death() -> void:
	shake(death_shake_intensity, death_shake_duration)

func force_initial_position_stable(pos: Vector2, vel: Vector2) -> void:
	var player_pos := pos
	var player_vel := vel
	var desired_position := Vector2(player_pos.x, player_pos.y - vertical_offset)
	
	global_position = desired_position

# TODO (sam): better lerp speed smoothing (on top of lookahead x smoothing)
func _process(delta: float) -> void:
	if player == null:
		player = get_parent().find_child("Player")
	
	hpui.set_hp(player.hp)
	mask_ui.thrust_count(player.thrusts_remaining)
	mask_ui.dive_count(player.dives_remaining)
	mask_ui.djump_count(player.doublejumps_remaining)
	
	
	# move wrt player.
	var player_pos := player.global_position
	var player_vel := player.velocity
	
	var desired_lookahead: float = clampf(player_vel.x / xvel_lookahead_scale, -1.0, 1.0) * lookahead_distance
	_lookahead_x = lerp(_lookahead_x, desired_lookahead, 1.0 - exp(-lookahead_smoothing * delta))
	
	var desired_lookahead_y: float = 0
	if abs(player.velocity.y) > 500:
		desired_lookahead_y = clampf(player_vel.y / yvel_lookahead_scale, -1.0, 1.0) * lookahead_distance
		_lookahead_y = lerp(_lookahead_y, desired_lookahead_y, 1.0 - exp(-lookahead_smoothing * delta))
	
	
	var current_position := global_position
	var desired_position := Vector2(player_pos.x, player_pos.y - vertical_offset + _lookahead_y)
	if abs(desired_position.x - current_position.x) < deadzone.x:
		desired_position.x = current_position.x
	if abs(desired_position.y - current_position.y) < deadzone.y:
		desired_position.y = current_position.y
	
	global_position.x = lerp(global_position.x, desired_position.x, follow_speed.x * delta)
	global_position.y = lerp(global_position.y, desired_position.y, follow_speed.y * delta)
	
	# Apply screen shake
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if _shake_timer > 0:
		_shake_timer -= delta
		
		# Calculate shake progress (1.0 at start, 0.0 at end)
		var shake_progress := _shake_timer / _shake_duration
		# Apply decay for smooth falloff
		var current_intensity := _shake_intensity * shake_progress
		
		# Generate random offset
		_shake_offset = Vector2(
			randf_range(-current_intensity, current_intensity),
			randf_range(-current_intensity, current_intensity)
		)
		
		offset = _shake_offset
	else:
		# Smoothly return to zero offset
		offset = offset.lerp(Vector2.ZERO, shake_decay_rate * delta)
		if offset.length() < 0.1:
			offset = Vector2.ZERO
