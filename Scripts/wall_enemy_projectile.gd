class_name WallEnemyProjectile extends CharacterBody2D

@onready var damage_region: Area2D = $DamageRegion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_region_collision_shape: CollisionShape2D = $DamageRegion/CollisionShape2D

@export var init_size: float = 0.1
@export var final_size: float = 1.0
@export var scale_time: float = 0.5
var scale_tween: Tween

func init_me(init_velocity: Vector2, parent_rotation_degrees: float):
	velocity = init_velocity
	rotation_degrees = 360 - parent_rotation_degrees

func _ready() -> void:
	sprite.play("default")
	scale = Vector2.ONE * init_size
	scale_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	scale_tween.tween_property(self, "scale", Vector2.ONE * final_size, scale_time)

func _physics_process(delta: float) -> void:
	var collision = move_and_collide(velocity * delta)
	if collision:
		pop_me()
	
	var bodies = damage_region.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			body.take_hit(true)
			pop_me()

func pop_me() -> void:
	velocity = Vector2.ZERO
	collision_shape.disabled = true
	damage_region_collision_shape.disabled = true
	
	sprite.play("pop")
	await sprite.animation_finished
	queue_free()
