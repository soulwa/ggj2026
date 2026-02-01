class_name MushroomGuy extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $Sprite
var pivoted: bool = false
@onready var pivot_timer: Timer = $PivotTimer

var max_speed: float = 225
var acceleration: float = 3000
var gravity: float = 1000

var player: Player

var bounce_timer_seconds: float = 0.5
var bounce_timer: float = 0.0

var jump_timer_seconds_min: float = 0.2
var jump_timer_seconds_max: float = 0.6
var jump_timer = 0.0

var should_double_jump: bool = false

const jump_height_pixels: float = 64
var jump_power: float = -sqrt(2 * gravity * jump_height_pixels)
const double_jump_height_pixels: float = 128
var double_jump_power: float = -sqrt(2 * gravity * double_jump_height_pixels)

var dead: bool = false

# Spawn animation parameters
var spawn_delay: float = 0.0  # Can be set by spawner for staggered spawns
var is_spawning: bool = true
var squash_stretch_shader: Shader = preload("res://Shaders/squash_stretch.gdshader")
var shader_material: ShaderMaterial

## ============== SQUASH/STRETCH TUNING ==============
## Adjust these values to change the animation intensity

# Pivot offset in pixels from sprite center (positive = down toward feet)
var pivot_offset_y: float = 20.0

# Spawn animation
var initial_squash: float = -0.25  # How flat they start (negative = squashed)
var spawn_duration: float = 0.35   # How long the spawn bounce takes

# Gameplay squash amounts (subtle!)
var landing_squash: float = -0.08  # Squash on landing
var jump_squash: float = -0.05     # Anticipation before jump
var jump_stretch: float = 0.06     # Stretch during jump
var wall_bounce_stretch: float = 0.08  # Stretch when bouncing off wall
var death_squash: float = -0.2     # Flatten on death

# Animation durations
var squash_duration: float = 0.2   # How long squash effects last
## ===================================================

var current_squash: float = 0.0  # Track current squash for smooth transitions


func _ready() -> void:
	sprite.animation = ["1", "2", "3"].pick_random()
	sprite.flip_h = randf() < 0.5
	pivoted = randf() < 0.5
	update_pivot_visual()
	pivot_timer.wait_time = randf_range(0.08, 0.12)
	position.x += randf_range(-24, 24)  # Horizontal spawn spread
	max_speed = randf_range(100, 400)
	acceleration = randf_range(100, 400)
	jump_timer = randf_range(jump_timer_seconds_min, jump_timer_seconds_max)
	
	# Setup shader and start spawn animation
	_setup_spawn_shader()
	_start_spawn_animation()

func _setup_spawn_shader() -> void:
	shader_material = ShaderMaterial.new()
	shader_material.shader = squash_stretch_shader
	shader_material.set_shader_parameter("squash_amount", initial_squash)
	shader_material.set_shader_parameter("vertical_offset", 0.0)
	shader_material.set_shader_parameter("pivot_offset_y", pivot_offset_y)
	shader_material.set_shader_parameter("wobble_amount", 0.0)
	sprite.material = shader_material

func _start_spawn_animation() -> void:
	# Disable collision during spawn
	$CollisionShape2D.disabled = true
	$DamageRegion.monitoring = false
	
	# Wait for spawn delay (for staggered spawns)
	if spawn_delay > 0:
		await get_tree().create_timer(spawn_delay).timeout
	
	# Smooth bounce animation
	var spawn_tween = create_tween()
	spawn_tween.set_ease(Tween.EASE_OUT)
	spawn_tween.set_trans(Tween.TRANS_QUAD)  # Smooth deceleration
	
	# Animate from squished to normal
	spawn_tween.tween_method(_set_squash, initial_squash, 0.0, spawn_duration)
	
	await spawn_tween.finished
	
	# Re-enable collision after spawn
	$CollisionShape2D.disabled = false
	$DamageRegion.monitoring = true
	is_spawning = false

func _set_squash(value: float) -> void:
	current_squash = value
	if shader_material:
		shader_material.set_shader_parameter("squash_amount", value)

var was_in_air: bool = false  # Track if we were airborne last frame for landing squash

func _physics_process(delta: float) -> void:
	if dead or is_spawning:
		return
	
	if player == null:
		# Tilemaplayer > Level
		player = get_parent().get_parent().find_child("Player")
	
	# Track if we're in the air before moving
	var in_air_before = not is_on_floor()
	
	# "input" in x dir to player
	var hmove: int = sign(player.global_position.x - global_position.x)
	velocity.x = move_toward(velocity.x, hmove * max_speed, acceleration * delta)
	# gravity
	velocity.y += gravity * delta
	
	move_and_slide()
	for idx in get_slide_collision_count():
		var collision = get_slide_collision(idx)
		if collision.get_normal().x != 0 and bounce_timer < 0:
			bounce_off_wall(collision.get_normal().normalized())
	
	bounce_timer -= delta
	
	if is_on_floor():
		# Landing squash effect
		if in_air_before and was_in_air:
			_play_landing_squash()
		
		if jump_timer <= 0:
			jump_timer = randf_range(jump_timer_seconds_min, jump_timer_seconds_max)
		else:
			jump_timer -= delta
			if jump_timer <= 0:
				jump()
	else:
		if velocity.y > 0 and should_double_jump:
			double_jump()
	
	was_in_air = not is_on_floor()
	
	var bodies = $DamageRegion.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			body.take_hit(true)

func _play_landing_squash() -> void:
	if not shader_material:
		return
	
	# Smooth squash on landing, then return to normal
	var land_tween = create_tween()
	land_tween.set_ease(Tween.EASE_OUT)
	land_tween.set_trans(Tween.TRANS_SINE)
	# Quick squash down
	land_tween.tween_method(_set_squash, current_squash, landing_squash, 0.04)
	# Smooth return to normal
	land_tween.tween_method(_set_squash, landing_squash, 0.0, squash_duration)
	


func bounce_off_wall(normal: Vector2) -> void:
	velocity = (normal + Vector2.UP) * max(velocity.length(), 400)
	bounce_timer = bounce_timer_seconds
	_play_bounce_squash()

func jump() -> void:
	velocity.y = jump_power
	should_double_jump = randf() < 0.333
	_play_jump_stretch()

func double_jump() -> void:
	velocity.y = double_jump_power
	should_double_jump = false
	_play_jump_stretch()

func _play_jump_stretch() -> void:
	if not shader_material:
		return
	
	# Smooth anticipation squash then stretch up
	var jump_tween = create_tween()
	jump_tween.set_ease(Tween.EASE_OUT)
	jump_tween.set_trans(Tween.TRANS_SINE)
	# Quick anticipation
	jump_tween.tween_method(_set_squash, current_squash, jump_squash, 0.03)
	# Stretch up
	jump_tween.tween_method(_set_squash, jump_squash, jump_stretch, 0.06)
	# Return to normal
	jump_tween.tween_method(_set_squash, jump_stretch, 0.0, squash_duration)

func _play_bounce_squash() -> void:
	if not shader_material:
		return
	
	# Smooth stretch when bouncing off wall
	var bounce_tween = create_tween()
	bounce_tween.set_ease(Tween.EASE_OUT)
	bounce_tween.set_trans(Tween.TRANS_SINE)
	# Quick stretch
	bounce_tween.tween_method(_set_squash, current_squash, wall_bounce_stretch, 0.05)
	# Return to normal
	bounce_tween.tween_method(_set_squash, wall_bounce_stretch, 0.0, squash_duration)


func _on_pivot_timer_timeout() -> void:
	pivoted = !pivoted
	update_pivot_visual()

func update_pivot_visual() -> void:
	if pivoted:
		sprite.rotation_degrees = 5
	else:
		sprite.rotation_degrees = -5


func die() -> void:
	dead = true
	$DamageRegion.monitoring = false
	$CollisionShape2D.disabled = true
	
	# Death squash effect - smooth flatten
	if shader_material:
		var death_tween = create_tween()
		death_tween.set_ease(Tween.EASE_OUT)
		death_tween.set_trans(Tween.TRANS_SINE)
		death_tween.tween_method(_set_squash, current_squash, death_squash, 0.12)
	
	sprite.play("death")
	await sprite.animation_finished
	hide()
