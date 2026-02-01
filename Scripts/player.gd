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
@onready var sprites: Array[AnimatedSprite2D] = [$Body, $ThrustMask, $DiveMask, $DoublejumpMask, $Spear]
@onready var thrust_mask: AnimatedSprite2D = $ThrustMask
@onready var dive_mask: AnimatedSprite2D = $DiveMask
@onready var doublejump_mask: AnimatedSprite2D = $DoublejumpMask
@onready var spear_hitbox: Area2D = $SpearHitbox
@onready var shape_right: CollisionShape2D = $SpearHitbox/ShapeRight
@onready var shape_left: CollisionShape2D = $SpearHitbox/ShapeLeft
@onready var spear_hitbox_dive: Area2D = $SpearHitboxDive
@onready var spear_hitbox_dive_shape_left: CollisionShape2D = $SpearHitboxDive/ShapeLeft
@onready var spear_hitbox_dive_shape_right: CollisionShape2D = $SpearHitboxDive/ShapeRight

@onready var swapmask_ui_left: Node2D = $SwapmaskUILeft
@onready var swapmask_ui_right: Node2D = $SwapmaskUIRight

# particles
@onready var smash_particles: SmashParticles = $SmashParticles
@onready var weapon_tip: Marker2D = $WeaponTip

@export var disabled_mask_modulate: Color
var enabled_mask_modulate: Color = Color.WHITE


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
@export var wall_bounce_force_x := 100.0
@export var wall_bounce_height_pixels := 16*8
var wall_bounce_force_y: float

@export_subgroup("Double Jump")
@export var double_jump_pixels := 32*6
var double_jump_power: float

@export_subgroup("Downdash")
@export var dive_startup_time := DT * 2
@export var dive_gravity_multiplier := 2.0
@export var dive_initial_y_vel := 1000.0
@export var dive_bounce_boost_height := 32.0 * 4

@export_subgroup("Thrust Frog")
@export var frog_bounce_force_x := 700.0
@export var frog_bounce_height := 16 * 8
var frog_bounce_force_y: float

@export_subgroup("Thrust Mushroom")
@export var mushroom_bounce_force_x := 200.0
@export var mushroom_bounce_height := 16 * 8
var mushroom_bounce_force_y: float

enum MoveState {
	NORMAL,
	THRUST,
	THRUST_ACTIONABLE,
	DIVE,
	DIVE_BOUNCE,
	SWAPMASK,
}

# NOTE (sam): stuff for character state here
var current_state: MoveState = MoveState.NORMAL
var facedir := 1
var last_hmove := 0
var coyote_timer := coyote_time
var jump_buffer_timer := 0.0
var action_buffer_timer := 0.0
var was_in_air_last_frame: bool = false
var disable_jump_cancel: bool = false
var latest_direction := Vector2i.ZERO
var last_latest_direction := Vector2i.ZERO

var is_jump_animation: bool = false
var is_doublejump_animation: bool = false

var thrust_timer: float
var thrust_direction: int
var thrusts_remaining: int

var dive_height_fallen: float
var dives_remaining: int

var doublejumps_remaining: int

var last_tick_left: int
var last_tick_right: int
var last_tick_up: int
var last_tick_down: int
var dir_stack: Array[Vector2i] = []

var swapmask_target: Globals.Action


func _ready() -> void:
	jump_power = -sqrt(2 * gravity * jump_pixels)
	jump_cancel_power = -sqrt(2 * gravity * jump_cancel_pixels)
	thrust_forward_force = thrust_forward_pixels / thrust_time
	thrust_up_force = thrust_height_pixels / thrust_time
	wall_bounce_force_y = -sqrt(2 * gravity * wall_bounce_height_pixels)
	frog_bounce_force_y = -sqrt(2 * gravity * frog_bounce_height)
	mushroom_bounce_force_y = -sqrt(2 * gravity * mushroom_bounce_height)
	double_jump_power = -sqrt(2 * gravity * double_jump_pixels)
	swapmask_ui_left.hide()
	swapmask_ui_right.hide()

func _input(event: InputEvent) -> void:
	pass
	
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if hp < 0:
		return
	
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
		y_input_priority = -1 if last_tick_up > last_tick_down else 1
	elif input_move_up:
		y_input_priority = -1
	elif input_move_down:
		y_input_priority = 1
	
	
	
	last_latest_direction = latest_direction
	# presses
	if Input.is_action_just_pressed("left"):
		dir_stack.erase(Vector2i.LEFT)
		dir_stack.push_back(Vector2i.LEFT)
	if Input.is_action_just_pressed("right"):
		dir_stack.erase(Vector2i.RIGHT)
		dir_stack.push_back(Vector2i.RIGHT)
	if Input.is_action_just_pressed("up") and Globals.has_double_jump:
		dir_stack.erase(Vector2i.UP)
		dir_stack.push_back(Vector2i.UP)
	if Input.is_action_just_pressed("down") and Globals.has_downdash:
		dir_stack.erase(Vector2i.DOWN)
		dir_stack.push_back(Vector2i.DOWN)
	# releases
	if Input.is_action_just_released("left"):
		dir_stack.erase(Vector2i.LEFT)
	if Input.is_action_just_released("right"):
		dir_stack.erase(Vector2i.RIGHT)
	if Input.is_action_just_released("up"):
		dir_stack.erase(Vector2i.UP)
	if Input.is_action_just_released("down"):
		dir_stack.erase(Vector2i.DOWN)
	latest_direction = dir_stack.back() if dir_stack.size() > 0 else Vector2i.ZERO
	
	
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
		
	if iframe_timer > 0:
		iframe_timer -= delta
	#endregion
	
	if input_swapmask_pressed:
		enter_swapmask()
	
	
	#region MOVEMENT
	
	if current_state == MoveState.NORMAL or current_state == MoveState.SWAPMASK:
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
		
		if hmove != 0 and is_on_floor():
			MusicManager.start_sound_footstep()
		else:
			MusicManager.stop_sound_footstep()
		
		if current_state == MoveState.NORMAL:
			# jump from the floor
			# TODO (sam): fix dj w coyote time off of wall.
			if input_jump_pressed:
				jump_buffer_timer = jump_buffer
			# jump is buffered and on the floor, or just left it.
			if jump_buffer_timer > 0 and coyote_timer >= 0 and is_on_floor():
				jump()
			# wall jump
			#elif jump_buffer_timer > 0 and is_on_wall():
				#var walldir = get_wall_normal()
				#velocity.x = wall_jump_power_x * walldir.x
				#velocity.y = wall_jump_power_y
				#jump_buffer_timer = 0
			if input_jump_released and velocity.y < jump_cancel_power and !disable_jump_cancel:
				velocity.y = jump_cancel_power
			
			# prepare thrust direction as latest input dir in normal move
			if is_on_floor():
				thrusts_remaining = num_thrusts_per_jump
				dives_remaining = 1
				doublejumps_remaining = 1
			if input_action_pressed:
				action_buffer_timer = action_buffer
			match Globals.currently_selected_action:
				Globals.Action.Thrust:
					if action_buffer_timer > 0 and thrusts_remaining > 0:
						begin_thrust()
				Globals.Action.Dive:
					if action_buffer_timer > 0 and dives_remaining > 0:
						begin_dive()
				Globals.Action.DoubleJump:
					if action_buffer_timer > 0 and doublejumps_remaining > 0:
						double_jump()
			#if Input.is_action_just_pressed("_debug_dive") and dives_remaining > 0:
				#begin_dive()
		
		# SWAP MASK STATE input handling
		elif current_state == MoveState.SWAPMASK:
			# input handling
			match latest_direction:
				Vector2i.DOWN:
					show_swapmask_visual()
					swapmask_target = Globals.Action.Dive
					if latest_direction != last_latest_direction: MusicManager.play_sound_select_down()
				Vector2i.UP:
					show_swapmask_visual()
					swapmask_target = Globals.Action.DoubleJump
					if latest_direction != last_latest_direction: MusicManager.play_sound_select_up()
				Vector2i.LEFT:
					facedir = -1
					show_swapmask_visual()
					swapmask_target = Globals.Action.Thrust
					if latest_direction != last_latest_direction: MusicManager.play_sound_select_side()
				Vector2i.RIGHT:
					facedir = 1
					show_swapmask_visual()
					swapmask_target = Globals.Action.Thrust
					if latest_direction != last_latest_direction: MusicManager.play_sound_select_side()
			
			
			
			# exit menu
			if input_action_pressed:
				action_buffer_timer = action_buffer
				exit_swapmask()
			elif input_swapmask_released:
				exit_swapmask()
		
		
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
		check_thrust_hits()
	
	# thrust can be cancelled, gravity applies now
	elif current_state == MoveState.THRUST_ACTIONABLE:
		# apply gravity
		velocity.y += gravity * delta
		if sign(hmove) == -sign(velocity.x) or is_on_floor() or is_on_wall():
			end_thrust()
		check_thrust_hits()
	
	elif current_state == MoveState.DIVE:
		# apply gravity
		velocity.y += gravity * delta * dive_gravity_multiplier
		dive_height_fallen += velocity.y * delta
		# check to hit ground
		for body in spear_hitbox_dive.get_overlapping_bodies():
			if body is TileMapLayer:
				dive_bounce()
			if body is EnemyFrog:
				_emit_enemy_particles(body, body.global_position, Vector2.UP)
				body.die()
			if body is MushroomGuy:
				body.die()
	elif current_state == MoveState.DIVE_BOUNCE:
		end_dive() # TODO
	
	move_and_slide()
	var num_cols = get_slide_collision_count()
	for idx in num_cols:
		var collision = get_slide_collision(idx)
		# TODO (sam): do relevant stuff here if we need, like enemies, walls, spike
		var body = collision.get_collider()
		if body is EnemySpike:
			die()
	#endregion
	
	#region ANIMATION
	
	match Globals.currently_selected_action:
		Globals.Action.Thrust:
			thrust_mask.show()
			dive_mask.hide()
			doublejump_mask.hide()
		Globals.Action.Dive:
			thrust_mask.hide()
			dive_mask.show()
			doublejump_mask.hide()
		Globals.Action.DoubleJump:
			thrust_mask.hide()
			dive_mask.hide()
			doublejump_mask.show()
	
	for sprite in sprites:
		sprite.flip_h = facedir == -1
		if current_state == MoveState.NORMAL:
			if is_on_floor():
				if hmove != 0:
					sprite.play("run")
				else:
					if sprite.animation != "land": sprite.play("idle")
				if was_in_air_last_frame:
					sprite.play("land")
			else:
				if is_doublejump_animation and sprite.animation != "doublejump": sprite.play("doublejump")
				if is_jump_animation and sprite.animation != "jump": sprite.play("jump")
		elif current_state == MoveState.THRUST or current_state == MoveState.THRUST_ACTIONABLE and sprite.animation != "thrust":
			sprite.play("thrust")
		elif current_state == MoveState.DIVE:
			if sprite.animation != "dive": sprite.play("dive")
		
		if iframe_timer > 0:
			sprite.modulate.a = 0.3
		else:
			sprite.modulate.a = 1.0
			
	if !is_on_floor():
		was_in_air_last_frame = true
	else:
		was_in_air_last_frame = false
		is_jump_animation = false
		is_doublejump_animation = false
	
	#endregion

func _emit_wall_smash_particles() -> void:
	# Get the weapon tip position (flipped based on face direction)
	var tip_offset = weapon_tip.position
	if facedir == -1:
		tip_offset.x = -tip_offset.x
	var emit_pos = global_position + tip_offset
	
	# Get wall normal for particle direction
	var wall_normal = get_wall_normal()
	
	# Emit particles away from the wall
	if smash_particles:
		smash_particles.emit_burst(emit_pos, wall_normal, velocity)
	
	# Add wall dent at impact position - use facedir for hit direction
	var hit_direction = Vector2(facedir, 0).normalized()
	_add_wall_dent(emit_pos, hit_direction)


func _emit_dive_impact_dent() -> void:
	# For dive, the spear points down - use position below player at floor level
	var dent_pos = global_position + Vector2(0, 24)
	var particle_pos = global_position + Vector2(0, 60)
	
	# Emit particles upward (away from the ground)
	if smash_particles:
		smash_particles.emit_burst(particle_pos, Vector2.UP, velocity)
	
	# Add wall dent at impact position - downward direction with 2x strength
	_add_wall_dent(dent_pos, Vector2.DOWN, 1.5)


## Get emit position for thrust attacks (weapon tip + 16px inward toward enemy)
func _get_thrust_emit_pos() -> Vector2:
	var tip_offset = weapon_tip.position
	if facedir == -1:
		tip_offset.x = -tip_offset.x
	return global_position + tip_offset + Vector2(facedir * 16, 0)


## Emit particles when hitting an enemy. Uses enemy's color palette if available.
func _emit_enemy_particles(enemy: Node2D, emit_pos: Vector2, emit_direction: Vector2) -> void:
	if not smash_particles:
		return
	# Use enemy's colors if they have them, otherwise default
	if "particle_colors" in enemy and "particle_weights" in enemy:
		if enemy.particle_colors.size() > 0:
			smash_particles.emit_burst_weighted(emit_pos, emit_direction, velocity, enemy.particle_colors, enemy.particle_weights)
			return
	smash_particles.emit_burst(emit_pos, emit_direction, velocity)


func _add_wall_dent(hit_pos: Vector2, hit_direction: Vector2, strength_multiplier: float = 1.0) -> void:
	# Find the dent manager in the level
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child.has_method("add_dent_directed"):
				# Position the dent slightly into the wall
				var dent_pos = hit_pos + hit_direction * 12.0
				# Pass -1.0 for radius (use default), calculate strength with multiplier
				var strength = child.default_strength * strength_multiplier if strength_multiplier != 1.0 else -1.0
				child.add_dent_directed(dent_pos, hit_direction, -1.0, strength)
				return


func switch_level(direction: Level.Direction):
	var current_level: Level = get_parent()
	current_level.switch_level(direction)



func jump() -> void:
	disable_jump_cancel = false
	velocity.y = jump_power
	jump_buffer_timer = 0
	is_jump_animation = true
	MusicManager.play_sound_jump()

func begin_thrust() -> void:
	current_state = MoveState.THRUST
	thrust_timer = thrust_time
	thrusts_remaining -= 1
	action_buffer_timer = 0
	spear_hitbox.monitoring = true
	if facedir < 0:
		shape_right.disabled = true
		shape_left.disabled = false
	else:
		shape_right.disabled = false
		shape_left.disabled = true
	MusicManager.play_sound_thrust()

func end_thrust() -> void:
	spear_hitbox.monitoring = false
	shape_right.disabled = true
	shape_left.disabled = true
	current_state = MoveState.NORMAL

func check_thrust_hits() -> void:
	if spear_hitbox.monitoring:
		# check for hits
		for body in spear_hitbox.get_overlapping_bodies():
			if body is TileMapLayer:
				bounce_off_wall()
			if body is EnemyFrog:
				bounce_off_frog(body)
			if body is MushroomGuy:
				body.die()
				bounce_off_mushroom(body)
				return  # Only kill one mushroom at a time

func bounce_off_wall() -> void:
	# if we hit wall, bounce off
	velocity.x = -facedir * wall_bounce_force_x
	velocity.y = wall_bounce_force_y
	_emit_wall_smash_particles()
	end_thrust()
	disable_jump_cancel = true
	MusicManager.play_sound_wallbounce()

func bounce_off_frog(frog: EnemyFrog) -> void:
	velocity.x = -facedir * frog_bounce_force_x
	velocity.y = frog_bounce_force_y
	
	var _enable_frog_thrust_particles := false  # Toggle to enable/disable frog thrust hit particles
	if _enable_frog_thrust_particles:
		_emit_enemy_particles(frog, _get_thrust_emit_pos(), Vector2.RIGHT * -facedir)
	
	end_thrust()
	disable_jump_cancel = true
	thrusts_remaining = 1  # refund if you hit an enemy

func bounce_off_mushroom(mushroom: MushroomGuy) -> void:
	velocity.x = -facedir * mushroom_bounce_force_x
	velocity.y = mushroom_bounce_force_y
	
	_emit_enemy_particles(mushroom, _get_thrust_emit_pos(), Vector2.RIGHT * -facedir)
	
	end_thrust()
	disable_jump_cancel = true
	
	# refund if you hit an enemy
	thrusts_remaining = 1

func enter_swapmask() -> void:
	current_state = MoveState.SWAPMASK
	match latest_direction:
		Vector2i.UP:
			swapmask_target = Globals.Action.DoubleJump
		Vector2i.DOWN:
			swapmask_target = Globals.Action.Dive
		Vector2i.LEFT:
			swapmask_target = Globals.Action.Thrust
		Vector2i.RIGHT:
			swapmask_target = Globals.Action.Thrust
		Vector2i.ZERO:
			swapmask_target = Globals.currently_selected_action
	Engine.time_scale = 0.05
	show_swapmask_visual()
	MusicManager.slow_music()
	MusicManager.play_sound_openmenu()

func show_swapmask_visual() -> void:
	if facedir < 0:
		swapmask_ui_left.show()
		swapmask_ui_right.hide()
	else:
		swapmask_ui_right.show()
		swapmask_ui_left.hide()
	
	# update visuals
	match swapmask_target:
		Globals.Action.Thrust:
			swapmask_ui_left.get_node("ThrustMask").modulate = enabled_mask_modulate
			swapmask_ui_left.get_node("DiveMask").modulate = disabled_mask_modulate
			swapmask_ui_left.get_node("DoubleJumpMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("ThrustMask").modulate = enabled_mask_modulate
			swapmask_ui_right.get_node("DiveMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("DoubleJumpMask").modulate = disabled_mask_modulate
		Globals.Action.Dive:
			swapmask_ui_left.get_node("ThrustMask").modulate = disabled_mask_modulate
			swapmask_ui_left.get_node("DiveMask").modulate = enabled_mask_modulate
			swapmask_ui_left.get_node("DoubleJumpMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("ThrustMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("DiveMask").modulate = enabled_mask_modulate
			swapmask_ui_right.get_node("DoubleJumpMask").modulate = disabled_mask_modulate
		Globals.Action.DoubleJump:
			swapmask_ui_left.get_node("ThrustMask").modulate = disabled_mask_modulate
			swapmask_ui_left.get_node("DiveMask").modulate = disabled_mask_modulate
			swapmask_ui_left.get_node("DoubleJumpMask").modulate = enabled_mask_modulate
			swapmask_ui_right.get_node("ThrustMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("DiveMask").modulate = disabled_mask_modulate
			swapmask_ui_right.get_node("DoubleJumpMask").modulate = enabled_mask_modulate
	if Globals.has_downdash:
		swapmask_ui_left.get_node("DiveMask").show()
		swapmask_ui_right.get_node("DiveMask").show()
	else:
		swapmask_ui_left.get_node("DiveMask").hide()
		swapmask_ui_right.get_node("DiveMask").hide()
	if Globals.has_double_jump:
		swapmask_ui_left.get_node("DoubleJumpMask").show()
		swapmask_ui_right.get_node("DoubleJumpMask").show()
	else:
		swapmask_ui_left.get_node("DoubleJumpMask").hide()
		swapmask_ui_right.get_node("DoubleJumpMask").hide()


func exit_swapmask() -> void:
	Globals.currently_selected_action = swapmask_target
	if current_state == MoveState.SWAPMASK: current_state = MoveState.NORMAL
	Engine.time_scale = 1.0
	swapmask_ui_left.hide()
	swapmask_ui_right.hide()
	MusicManager.normal_music()

func begin_dive() -> void:
	current_state = MoveState.DIVE
	velocity.y = dive_initial_y_vel
	dive_height_fallen = 0
	dives_remaining -= 1
	spear_hitbox_dive.monitoring = true
	if facedir < 0:
		spear_hitbox_dive_shape_right.disabled = true
		spear_hitbox_dive_shape_left.disabled = false
	else:
		spear_hitbox_dive_shape_right.disabled = false
		spear_hitbox_dive_shape_left.disabled = true
	MusicManager.play_sound_dive()

func dive_bounce() -> void:
	print("dive bouncing from a fall of ", dive_height_fallen, " (", round(dive_height_fallen/16.0), " tiles)")
	velocity.y = -sqrt(2 * gravity * (dive_height_fallen + dive_bounce_boost_height))
	current_state = MoveState.DIVE_BOUNCE
	dives_remaining = 0
	thrusts_remaining = num_thrusts_per_jump
	doublejumps_remaining = 1
	spear_hitbox_dive.monitoring = false
	spear_hitbox_dive_shape_right.disabled = true
	spear_hitbox_dive_shape_left.disabled = true
	disable_jump_cancel = true
	is_doublejump_animation = false
	MusicManager.play_sound_divebounce()
	
	# Add wall dent at impact position with 2x strength
	_emit_dive_impact_dent()

func end_dive() -> void:
	current_state = MoveState.NORMAL

func double_jump() -> void:
	doublejumps_remaining -= 1
	velocity.y = double_jump_power
	disable_jump_cancel = true
	is_jump_animation = false
	is_doublejump_animation = true
	MusicManager.play_sound_doublejump()
	

#region DEATH AND RESPAWN
var iframes := DT * 60
var iframe_timer := 0.0

var dead: bool = false

const START_HP := 3
var hp := START_HP

var spawnpoint: Vector2

var kb_force_x := 500.0
var kb_force_y := -sqrt(2 * gravity * 4 * 10) # 32 px height

func take_hit(kb: bool) -> void:
	if dead:
		return
	if iframe_timer > 0.0:
		return
	hp -= 1
	print("Player HP: ", hp)
	if hp <= 0:
		die()
	else:
		# TODO (sam): update HP UI here.
		iframe_timer = iframes
		velocity.x = kb_force_x
		velocity.y = kb_force_y
		# TODO (sam): flickering on sprite for invuln.
		
		# Screen shake on hit
		_trigger_camera_shake_hit()
	

func die() -> void:
	if dead:
		return
	
	dead = true
	
	# Screen shake on death
	_trigger_camera_shake_death()
		
	print("Player died!")
	if current_state == MoveState.SWAPMASK:
		exit_swapmask()
		
	var level: Level = get_parent()
	
	visible = false # TODO (sam): animation??
	
	# TODO (sam): this is sort of ugly when used like this.. have to fix.
	TransitionOverlay.set_shader_dissolve()
	TransitionOverlay.play_transition()
	await TransitionOverlay.transition_midpoint
	
	level.reset_enemies()
	
	position = spawnpoint
	velocity = Vector2.ZERO
	current_state = MoveState.NORMAL
	hp = START_HP
	
	facedir = 1 if Globals.opposite_direction_from == -1 else -1 if Globals.opposite_direction_from == 1 else 1
	
	iframe_timer = 0
	coyote_timer = 0
	
	# TODO (sam): @zane more state to reset here? or maybe its okay.
	
	# TODO (sam): not sure if this works the way we want, stopping execution until it happens?
	visible = true
	
	await TransitionOverlay.transition_complete
	dead = false

func set_spawn(pos: Vector2) -> void:
	spawnpoint = pos


func _get_camera() -> NiceCamera:
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is NiceCamera:
				return child
	return null


func _trigger_camera_shake_hit() -> void:
	var camera = _get_camera()
	if camera:
		camera.shake_hit()


func _trigger_camera_shake_death() -> void:
	var camera = _get_camera()
	if camera:
		camera.shake_death()
#endregion
