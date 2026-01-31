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
@export var run_accel := 2000.0
@export var run_top_speed := 200.0
@export var air_accel := 1000.0
@export var air_top_speed := 250.0
@export var turnaround_multiplier := 6.0
@export var gravity := 1600.0
@export var gravity_on_wall := 200.0
@export var jump_power := -500.0
@export var jump_cancel_power := -100.0
@export var wall_jump_power_x := 100.0
@export var wall_jump_power_y := -150.0
@export var max_fall_speed := 2000.0
@export var max_fall_speed_on_wall := 50.0

@export var wall_stickiness := DT * 10
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
var last_hmove := 0
var coyote_timer := coyote_time
var jump_buffer_timer := 0.0

var last_tick_left: int
var last_tick_right: int
var last_tick_up: int
var last_tick_down: int

enum Action {
	Thrust,
	DoubleJump,
	Downdash
}
var currently_selected_action: Action = Action.Thrust
var has_double_jump := false
var has_downdash := false


func _ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	#region INPUT
	print(coyote_timer)
	var time = Time.get_ticks_msec()
	
	var input_move_left = Input.is_action_pressed("left")
	var input_move_right = Input.is_action_pressed("right")
	var input_move_up = Input.is_action_pressed("up")
	var input_move_down = Input.is_action_pressed("down")
	var input_initial_move_left = Input.is_action_just_pressed("left")
	var input_initial_move_right = Input.is_action_just_pressed("right")
	var input_initial_move_up = Input.is_action_just_pressed("up")
	var input_initial_move_down = Input.is_action_just_pressed("down")
	
	var input_jump_pressed = Input.is_action_just_pressed("jump")
	var input_jump_held = Input.is_action_pressed("jump")
	var input_jump_released = Input.is_action_just_released("jump")
	
	var input_action_pressed = Input.is_action_just_pressed("action")
	var input_action_held = Input.is_action_pressed("action")
	var input_action_released = Input.is_action_just_released("action")
	
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
	
	
	facedir = x_input_priority if x_input_priority != 0 else facedir
	var hmove = x_input_priority
	#endregion
	
	#region MOVEMENT TIMERS
	# if coyote_timer >= 0, we can still jump.
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	#endregion
	
	#region MOVEMENT
	if is_on_floor():
		current_state = MoveState.RUN
	
	# TODO (sam): turnarounds
	var effective_accel = run_accel if is_on_floor() else air_accel
	var effective_top_speed = run_top_speed if is_on_floor() else air_top_speed
	var turning = sign(hmove) == -sign(velocity.x)
	if turning:
		effective_accel *= turnaround_multiplier
	velocity.x = move_toward(velocity.x, hmove * effective_top_speed, effective_accel * delta)
	
	
	# jump from the floor
	# TODO (sam): fix dj w coyote time off of wall.
	if input_jump_pressed:
		# on the floor, or just left it.
		if is_on_floor() or not (is_on_floor() or is_on_wall()) and coyote_timer >= 0:
				current_state = MoveState.JUMP
				velocity.y = jump_power
		elif is_on_wall():
			var walldir = get_wall_normal()
			velocity.x = wall_jump_power_x * walldir.x
			velocity.y = wall_jump_power_y
	if input_jump_released and velocity.y < jump_cancel_power:
		velocity.y = jump_cancel_power
	
	# compute maximums (unless we want to bypass), gravity as final pass on "physics"
	velocity.x = clamp(velocity.x, -effective_top_speed, effective_top_speed)
	
	var effective_gravity = gravity if not (is_on_wall() and velocity.y > 0) else gravity_on_wall
	velocity.y += effective_gravity * delta
	
	var effective_max_fall_speed = max_fall_speed if not is_on_wall() else max_fall_speed_on_wall
	if velocity.y > effective_max_fall_speed:
		velocity.y = effective_max_fall_speed
	
	move_and_slide()
	var num_cols = get_slide_collision_count()
	for idx in num_cols:
		var collision = get_slide_collision(idx)
		# TODO (sam): do relevant stuff here if we need, like enemies, walls, spike
	#endregion
	
	#region ANIMATION
	$AnimatedSprite2D.flip_h = facedir == -1
	if hmove != 0:
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")
	#endregion
