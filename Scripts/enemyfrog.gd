class_name EnemyFrog extends CharacterBody2D

var spawn: Vector2
var player: Player

# frog:
# - wait
# - if player is close enough, get ready
# - if player is still close enough, jump towards it
# - during arc, shoot bubbles on a timer

const DT := 0.016
const DOWN_DEGREES = 90.0
@export var player_detection_range := 1000
@export var telegraph_time := 1.0
@export var jumping_up_time := 0.75
@export var jumping_up_height := 200.0
@export var x_player_distance_fraction := 4.0
@export var gravity := 200.0
@export var bubble_time := DT * 20
@export var num_bubbles := 3
@export var wall_hit_decay := 0.8
@export var heatseeking_speed := 800.0
@export var heatseeking_fallback_angle := 30.0
@export var heatseeking_max_range := 60.0

enum State {
	IDLE,
	READYING,
	JUMPING_UP,
	JUMPING_DOWN
}

var facedir = 1

var telegraph_timer := 0.0
var current_state := State.IDLE
var bubbles_left := 3
var bubble_timer := 0.0
var jumping_up_timer := 0.0
var bounced_off_horz_wall := false

func _ready() -> void:
	# enemy position should be set when it's instantiated as a scene tile
	spawn = position

func _physics_process(delta: float) -> void:
	if player == null:
		# Tilemaplayer > Level
		player = get_parent().get_parent().find_child("Player")
	
	if current_state == State.IDLE:
		var new_facedir = int(sign(player.position.x - position.x))
		facedir = new_facedir if new_facedir != 0 else facedir
		
		if (player.position.distance_to(position) < player_detection_range):
			print("[FROG] IDLE -> READYING")
			current_state = State.READYING
			telegraph_timer = telegraph_time
	elif current_state == State.READYING:
		var new_facedir = int(sign(player.position.x - position.x))
		facedir = new_facedir if new_facedir != 0 else facedir
		
		telegraph_timer -= delta
		
		# return to prev. state if player left.
		if (player.position.distance_to(position) > player_detection_range):
			print("[FROG] READYING -> IDLE")
			current_state = State.IDLE
		
		if telegraph_timer <= 0.0:
			print("[FROG] READYING -> JUMPING UP")
			current_state = State.JUMPING_UP
			var delta_position = player.position - position
			var dist_to_travel = delta_position.x / x_player_distance_fraction
			var upwards_target = Vector2(position.x + dist_to_travel, position.y - jumping_up_height)
			velocity = ((upwards_target - position) - 0.5 * Vector2(0, gravity) * jumping_up_time * jumping_up_time) / jumping_up_time
			
			facedir = int(sign(velocity.x)) if velocity.x != 0 else facedir
			
			bubbles_left = 3
			bubble_timer = bubble_time
			jumping_up_timer = jumping_up_time
			
	elif current_state == State.JUMPING_UP:
		bubble_timer -= delta
		if bubble_timer <= 0 and bubbles_left > 0:
			bubbles_left -= 1
			bubble_timer = bubble_time
			print("[FROG] SHOOT A BUBBLE")
		
		jumping_up_timer -= delta
		if (jumping_up_timer <= 0 and not bounced_off_horz_wall) or is_on_ceiling():
			var new_player_position = player.position
			var heatseek_angle: float
			if new_player_position.y < position.y:
				print("[FROG] player higher than frog; fallback angle")
				heatseek_angle = deg_to_rad(DOWN_DEGREES + heatseeking_fallback_angle * sign(velocity.x))
			else:
				heatseek_angle = rad_to_deg((new_player_position - position).angle())
				if heatseek_angle < DOWN_DEGREES - heatseeking_max_range:
					heatseek_angle = DOWN_DEGREES - heatseeking_max_range
				if heatseek_angle > DOWN_DEGREES + heatseeking_max_range:
					heatseek_angle = DOWN_DEGREES + heatseeking_max_range
				heatseek_angle = deg_to_rad(heatseek_angle)
			
			velocity = Vector2.from_angle(heatseek_angle).normalized() * heatseeking_speed
			
			facedir = int(sign(velocity.x)) if velocity.x != 0 else facedir
			
			print("[FROG] JUMPING UP -> JUMPING DOWN ", heatseek_angle, " ", velocity)
			current_state = State.JUMPING_DOWN
		
		velocity.y += gravity * delta
		var xvel_before_move := velocity.x
		move_and_slide()
		var col = get_last_slide_collision()
		if col:
			var normal = col.get_normal()
			if normal.x != 0 and sign(normal.x) != sign(xvel_before_move):
				velocity.x = xvel_before_move * normal.x * wall_hit_decay
				bounced_off_horz_wall = true
		
		if is_on_floor():
			print("[FROG] JUMPING UP -> IDLE")
			current_state = State.IDLE
			bounced_off_horz_wall = false
	
	elif current_state == State.JUMPING_DOWN:
		var xvel_before_move := velocity.x
		move_and_slide()
		var col = get_last_slide_collision()
		if col:
			var normal = col.get_normal()
			if normal.x != 0 and sign(normal.x) != sign(xvel_before_move):
				velocity.x = 0
				bounced_off_horz_wall = true
		
		if is_on_floor():
			print("[FROG] JUMPING DOWN -> IDLE")
			current_state = State.IDLE
	
	#region ANIMATION
	$AnimatedSprite2D.flip_h = facedir == 1
	if current_state == State.IDLE or current_state == State.READYING:
		$AnimatedSprite2D.play("idle")
	elif current_state == State.JUMPING_UP:
		$AnimatedSprite2D.play("jumping_up")
	elif current_state == State.JUMPING_DOWN:
		$AnimatedSprite2D.play("jumping_down")
	#endregion
			

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("DAMAGED PLAYER")
