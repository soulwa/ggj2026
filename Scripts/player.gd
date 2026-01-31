class_name Player extends CharacterBody2D

# parameters for things:
# run acceleration, run top speed
# - run turn multiplier (eg. skidding)
# air acceleration, air top speed
# gravity (should be derived?)
# gravity on wall
# jump power (should be derived?)
# jump cancel power (eg. short hop jump)
# wall_jump_power_x and wall_jump_power_y
# wall stickiness
# max fall speed
# max fall speed on wall
# wall decay?
# jump buffer time
# coyote time
# -----
# 

const DT := 0.016
@export_group("Movement")
@export var run_accel := 50.0
@export var run_top_speed := 200.0
@export var air_accel := 50.0
@export var air_top_speed := 250.0
@export var gravity := 500.0
@export var gravity_on_wall := 150.0
@export var jump_power := -200.0
@export var jump_cancel_power := -100.0
@export var wall_jump_power_x := 200.0
@export var wall_jump_power_y := 150.0
@export var max_fall_speed := 250.0
@export var max_fall_speed_on_wall := 50.0

@export var jump_buffer := DT * 8
@export var coyote_time := DT * 4

@export_subgroup("Thrust")
@export var thrust_forward_speed := 50.0
@export var thrust_height := 5.0
@export var thrust_time := DT * 20

@export_subgroup("Double Jump")
@export var dj_startup_time := DT * 3
@export var double_jump_power := -400.0
@export var double_jump_arc := 0 # TODO (sam): i dont know how to model this yet.

@export_subgroup("Downdash")
@export var dash_startup_time := DT * 2
@export var dash_accel := -30.0
@export var dash_max_speed := -300.0

enum MoveState {
	RUN,
	JUMP,
	THRUST,
	DOUBLE_JUMP,
	DOWNDASH,
}

# NOTE (sam): stuff for character state here
var current_state: MoveState = MoveState.RUN
var facedir := 1

var last_tick_left: int
var last_tick_right: int
var last_tick_up: int
var last_tick_down: int

func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	#region INPUT
	var time = Time.get_ticks_msec()
	
	var input_move_left = Input.is_action_pressed("left")
	var input_move_right = Input.is_action_pressed("right")
	var input_move_up = Input.is_action_pressed("up")
	var input_move_down = Input.is_action_pressed("down")
	var input_initial_move_left = Input.is_action_just_pressed("left")
	var input_initial_move_right = Input.is_action_just_pressed("right")
	var input_initial_move_up = Input.is_action_just_pressed("up")
	var input_initial_move_down = Input.is_action_just_pressed("down")
	
	# resolve x move presses
	last_tick_left = time if input_initial_move_left else last_tick_left
	last_tick_right = time if input_initial_move_right else last_tick_right
	var x_input_priority = 0
	if input_move_left and input_move_right:
		x_input_priority = -1 if last_tick_left > last_tick_right else 1
	elif input_move_left:
		x_input_priority = -1
	elif input_move_right:
		x_input_priority = 1
		
	# resolve y move presses
	last_tick_up = time if input_initial_move_up else last_tick_up
	last_tick_down = time if input_initial_move_down else last_tick_down
	var y_input_priority = 0
	if input_move_up and input_move_down:
		x_input_priority = -1 if last_tick_up > last_tick_down else 1
	elif input_move_up:
		y_input_priority = -1
	elif input_move_down:
		y_input_priority = 1
	#endregion
	
	#region MOVEMENT
	#endregion
	
	#region ANIMATION
	#endregion
