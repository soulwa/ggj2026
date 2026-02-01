class_name NiceCamera extends Camera2D

var player: Player

@export var xvel_lookahead_scale := 200.0
@export var yvel_lookahead_scale := 1000.0
@export var lookahead_distance := 200.0
@export var lookahead_smoothing := 8.0
@export var vertical_offset := 64.0
@export var deadzone := Vector2(24.0, 32.0)
@export var follow_speed := Vector2(10.0, 8.0)


var _prev_target_pos: Vector2
var _lookahead_x := 0.0
# var _lookahead_y := 0.0

func _ready() -> void:
	pass

func force_initial_position_stable(pos: Vector2, vel: Vector2) -> void:
	var player_pos := pos
	var player_vel := vel
	var desired_position := Vector2(player_pos.x, player_pos.y - vertical_offset)
	
	global_position = desired_position

# TODO (sam): better lerp speed smoothing (on top of lookahead x smoothing)
func _process(delta: float) -> void:
	if player == null:
		player = get_parent().find_child("Player")
	
	# move wrt player.
	var player_pos := player.global_position
	var player_vel := player.velocity
	
	var desired_lookahead: float = clampf(player_vel.x / xvel_lookahead_scale, -1.0, 1.0) * lookahead_distance
	_lookahead_x = lerp(_lookahead_x, desired_lookahead, 1.0 - exp(-lookahead_smoothing * delta))
	
	#var desired_lookahead_y: float = clampf(player_vel.y / yvel_lookahead_scale, -1.0, 1.0) * lookahead_distance
	#_lookahead_y = lerp(_lookahead_y, desired_lookahead_y, 1.0 - exp(-lookahead_smoothing * delta))
	
	
	var current_position := position
	var desired_position := Vector2(player_pos.x, player_pos.y - vertical_offset) #+ _lookahead_y)
	if abs(desired_position.x - current_position.x) < deadzone.x:
		desired_position.x = current_position.x
	if abs(desired_position.y - current_position.y) < deadzone.y:
		desired_position.y = current_position.y
	
	global_position.x = lerp(global_position.x, desired_position.x, follow_speed.x * delta)
	global_position.y = lerp(global_position.y, desired_position.y, follow_speed.y * delta)
