class_name WallEnemy extends Node2D

const projectile_scene: PackedScene = preload("uid://d04mouxrarkp4")

@onready var projectile_origin: Marker2D = $ProjectileOrigin
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var player: Player

var should_shoot: bool = false

@export var projectile_speed: float = 100

@export var shoot_seconds: float = 5
@export var shoot_on_sight_seconds: float = 1
var shoot_timer: float = 0


@export var angle_variance: float = 10


func _ready() -> void:
	#shoot_timer = shoot_seconds
	sprite.play("idle")


func _process(delta: float) -> void:
	if player == null:
		# Tilemaplayer > Level
		player = get_parent().get_parent().find_child("Player")
	
	
	shoot_timer -= delta
	if shoot_timer <= 0:
		shoot_timer = shoot_seconds
		shoot()


func _on_player_detect_area_body_entered(body: Node2D) -> void:
	should_shoot = true
	#shoot_timer = shoot_on_sight_seconds


func _on_player_detect_area_body_exited(body: Node2D) -> void:
	should_shoot = false


func shoot() -> void:
	sprite.play("shoot")
	MusicManager.play_barnacle_shoot()
	await sprite.animation_finished
	
	var new_projectile: WallEnemyProjectile = projectile_scene.instantiate()
	var shoot_dir: Vector2 = Vector2.UP.rotated(rotation)
	if should_shoot:
		shoot_dir = (player.global_position - projectile_origin.global_position).normalized()
	else:
		shoot_dir = shoot_dir.rotated(deg_to_rad(randf_range(-angle_variance, angle_variance)))
	new_projectile.init_me(shoot_dir * projectile_speed, rotation_degrees)
	projectile_origin.add_child(new_projectile)
	
	sprite.play("retract")

func reset() -> void:
	for child in projectile_origin.get_children():
		child.reset()
