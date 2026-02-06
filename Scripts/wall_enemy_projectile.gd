class_name WallEnemyProjectile extends CharacterBody2D

@onready var damage_region: Area2D = $DamageRegion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_region_collision_shape: CollisionShape2D = $DamageRegion/CollisionShape2D

func init_me(init_velocity: Vector2):
	velocity = init_velocity

func _ready() -> void:
	sprite.play("default")

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
