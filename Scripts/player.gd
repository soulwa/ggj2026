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

# sprites
@onready var sprites: Array[AnimatedSprite2D] = [$Body, $Mask, $Spear]


const DT := 0.016

@export_group("Movement")
@export var run_accel := 6000.0
@export var run_top_speed := 250.0
@export var ground_friction := 5000.0 # called friction but really just a restoring force to 0
@export var air_accel := 2000.0
@export var air_top_speed := 300.0
@export var air_friction := 500.0 # called friction but really just a restoring force to 0
@export var turnaround_multiplier := 0.5
@export var gravity := 2000.0
#@export var gravity_on_wall := 1600.0
@export var jump_pixels := 64+32+8
var jump_power: float
@export var jump_cancel_pixels := 32
var jump_cancel_power: float
#@export var wall_jump_power_x := 400.0
#@export var wall_jump_power_y := -400.0
@export var max_fall_speed := 2000.0
#@export var max_fall_speed_on_wall := 200.0

#@export var wall_stickiness := DT * 10
@export var jump_buffer := DT * 10
@export var coyote_time := DT * 6
@export var action_buffer := DT * 6

@export_subgroup("Thrust")
@export var thrust_forward_pixels := 16 * 8 # 4 tiles
var thrust_forward_force: float
@export var thrust_height_pixels := 18
var thrust_up_force: float
@export var thrust_time := DT * 10
@export var num_thrusts_per_jump := 1
@export var wall_bounce_force_x := 250.0
@export var wall_bounce_height_pixels := 16*8
var wall_bounce_force_y: float

@export_subgroup("Double Jump")
@export var dj_startup_time := DT * 3
@export var double_jump_power := -400.0
@export var double_jump_arc := 0 # TODO (sam): i dont know how to model this yet.

@export_subgroup("Downdash")
@export var dive_startup_time := DT * 2
@export var dive_accel := -30.0
@export var dive_max_speed := -300.0

enum MoveState {
	NORMAL,
	THRUST,
	THRUST_ACTIONABLE,
	DOWNDASH,
	SWAPMASK,
}

# NOTE (sam): stuff for character state here
var current_state: MoveState = MoveState.NORMAL
var facedir := 1
var last_hmove := 0
var coyote_timer := coyote_time
var jump_buffer_timer := 0.0
var action_buffer_timer := 0.0

var thrust_timer: float
var thrust_direction: int
var thrusts_remaining: int

var last_tick_left: int
var last_tick_right: int
var last_tick_up: int
var last_tick_down: int

enum Action {
	Thrust,
	DoubleJump,
	Downdash,
}
var currently_selected_action: Action = Action.Thrust
var has_double_jump := false
var has_downdash := false


func _ready() -> void:
	jump_power = -sqrt(2 * gravity * jump_pixels)
	jump_cancel_power = -sqrt(2 * gravity * jump_cancel_pixels)
	thrust_forward_force = thrust_forward_pixels / thrust_time
	thrust_up_force = thrust_height_pixels / thrust_time
	wall_bounce_force_y = -sqrt(2 * gravity * wall_bounce_height_pixels)

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
	
	var input_jump_pressed = Input.is_action_just_pressed("jump")
	var input_jump_held = Input.is_action_pressed("jump")
	var input_jump_released = Input.is_action_just_released("jump")
	
	var input_action_pressed = Input.is_action_just_pressed("action")
	var input_action_held = Input.is_action_pressed("action")
	var input_action_released = Input.is_action_just_released("action")
	
	var input_swapmask_pressed = Input.is_action_just_pressed("switch_mask")
	var input_swapmask_held = Input.is_action_pressed("switch_mask")
	var input_swapmask_released = Input.is_action_just_released("switch_mask")
	
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
	
	
	var hmove = x_input_priority
	#endregion
	
	#region MOVEMENT TIMERS
	# if coyote_timer >= 0, we can still jump.
	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta
	# tick down jump buffer timer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	if action_buffer_timer > 0:
		action_buffer_timer -= delta
	#endregion
	
	#region MOVEMENT
	
	if current_state == MoveState.NORMAL:
		facedir = x_input_priority if x_input_priority != 0 else facedir
		
		var effective_accel = run_accel if is_on_floor() else air_accel
		var effective_top_speed = run_top_speed if is_on_floor() else air_top_speed
		var effective_friction = ground_friction if is_on_floor() else air_friction
		var turning = sign(hmove) == -sign(velocity.x)
		if turning:
			effective_accel *= turnaround_multiplier
		
		if hmove == 0:
			velocity.x = move_toward(velocity.x, 0, effective_friction * delta)
		elif abs(velocity.x) <= effective_top_speed or turning:
			velocity.x = move_toward(velocity.x, hmove * effective_top_speed, effective_accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, effective_friction * delta)
		
		
		# jump from the floor
		# TODO (sam): fix dj w coyote time off of wall.
		if input_jump_pressed:
			jump_buffer_timer = jump_buffer
		# jump is buffered and on the floor, or just left it.
		if jump_buffer_timer > 0 and coyote_timer >= 0 and is_on_floor():
			velocity.y = jump_power
			jump_buffer_timer = 0
		# wall jump
		#elif jump_buffer_timer > 0 and is_on_wall():
			#var walldir = get_wall_normal()
			#velocity.x = wall_jump_power_x * walldir.x
			#velocity.y = wall_jump_power_y
			#jump_buffer_timer = 0
		if input_jump_released and velocity.y < jump_cancel_power:
			velocity.y = jump_cancel_power
		
		# prepare thrust direction as latest input dir in normal move
		if is_on_floor():
			thrusts_remaining = num_thrusts_per_jump
		if input_action_pressed:
			action_buffer_timer = action_buffer
		if action_buffer_timer > 0 and thrusts_remaining > 0:
			current_state = MoveState.THRUST
			thrust_timer = thrust_time
			thrusts_remaining -= 1
		
		# compute maximums (unless we want to bypass), gravity as final pass on "physics"
		#velocity.x = clamp(velocity.x, -effective_top_speed, effective_top_speed)
		
		velocity.y += gravity * delta
		
		
		var effective_max_fall_speed = max_fall_speed #if not is_on_wall() else max_fall_speed_on_wall
		if velocity.y > effective_max_fall_speed:
			velocity.y = effective_max_fall_speed
	
	# handle thrust movement
	elif current_state == MoveState.THRUST:
		velocity.x = thrust_forward_force * facedir
		velocity.y = -thrust_up_force
		thrust_timer -= delta
		if thrust_timer < 0:
			current_state = MoveState.THRUST_ACTIONABLE
		# if we hit wall, bounce off
		if is_on_wall():
			# TODO: check via spear hitbox
			velocity.x = -facedir * wall_bounce_force_x
			velocity.y = wall_bounce_force_y
			current_state = MoveState.NORMAL
	# thrust can be cancelled, gravity applies now
	elif current_state == MoveState.THRUST_ACTIONABLE:
		# apply gravity
		velocity.y += gravity * delta
		if sign(hmove) == -sign(velocity.x) or is_on_floor() or is_on_wall():
			current_state = MoveState.NORMAL
	
	print(MoveState.keys()[current_state])
	
	move_and_slide()
	var num_cols = get_slide_collision_count()
	for idx in num_cols:
		var collision = get_slide_collision(idx)
		# TODO (sam): do relevant stuff here if we need, like enemies, walls, spike
	#endregion
	
	#region ANIMATION
	for sprite in sprites:
		sprite.flip_h = facedir == -1
		if current_state == MoveState.NORMAL:
			if hmove != 0:
				sprite.play("run")
			else:
				sprite.play("idle")
		elif current_state == MoveState.THRUST or current_state == MoveState.THRUST_ACTIONABLE and sprite.animation != "thrust":
			sprite.play("thrust")
	#endregion

func switch_level(direction: Level.Direction):
	var current_level: Level = get_parent()
	current_level.switch_level(direction)
