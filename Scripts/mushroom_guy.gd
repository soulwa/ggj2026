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


func _ready() -> void:
	sprite.animation = ["1", "2", "3"].pick_random()
	sprite.flip_h = randf() < 0.5
	pivoted = randf() < 0.5
	update_pivot_visual()
	pivot_timer.wait_time = randf_range(0.08, 0.12)
	position.x += randf_range(-8, 8)
	max_speed = randf_range(100, 400)
	acceleration = randf_range(100, 400)
	jump_timer = randf_range(jump_timer_seconds_min, jump_timer_seconds_max)

func _physics_process(delta: float) -> void:
	if dead:
		return
	
	if player == null:
		# Tilemaplayer > Level
		player = get_parent().get_parent().find_child("Player")
	
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
		if jump_timer <= 0:
			jump_timer = randf_range(jump_timer_seconds_min, jump_timer_seconds_max)
		else:
			jump_timer -= delta
			if jump_timer <= 0:
				jump()
	else:
		if velocity.y > 0 and should_double_jump:
			double_jump()
	
	var bodies = $DamageRegion.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			body.take_hit(true)
	


func bounce_off_wall(normal: Vector2) -> void:
	velocity = (normal + Vector2.UP) * max(velocity.length(), 400)
	bounce_timer = bounce_timer_seconds

func jump() -> void:
	velocity.y = jump_power
	should_double_jump = randf() < 0.333

func double_jump() -> void:
	velocity.y = double_jump_power
	should_double_jump = false


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
	sprite.play("death")
	await sprite.animation_finished
	hide()

func reset() -> void:
	queue_free()
