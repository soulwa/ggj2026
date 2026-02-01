class_name EnemyFrog extends CharacterBody2D

var spawn: Vector2
var player: Player

# frog:
# - wait
# - if player is close enough, get ready
# - if player is still close enough, jump towards it
# - during arc, shoot bubbles on a timer

## Colors used for impact particles when hitting this enemy
@export var particle_colors: Array[Color] = [
	Color(0.75, 0.35, 0.30, 1.0),  # Reddish (dominant)
	Color(0.35, 0.55, 0.28, 1.0),  # Darker green
]
## Weight for each color (should match particle_colors length). Higher = more particles of that color.
@export var particle_weights: Array[float] = [0.90, 0.10]

const DT := 0.016
const DOWN_DEGREES = 90.0
@export var player_detection_range := 1000
@export var telegraph_time := 1.0
@export var jumping_up_time := 0.65
@export var jumping_up_height := 200.0
@export var x_player_distance_fraction := 4.0
@export var gravity := 200.0
@export var min_dist_to_heatseek_early := 100.0
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
var current_state := State.IDLE
var dead := false

# telegraph
var telegraph_timer := 0.0

# jumping up
var bubbles_left := 3
var bubble_timer := 0.0
var jumping_up_timer := 0.0
var jump_dist_travelled := 0.0
var jump_start_y := 0.0

# attempting smoother
var jump_dy := 0.0

var aggroed := false


# jumping up and jumping down
var bounced_off_horz_wall := false
var bounced_off_ceiling := false

func _ready() -> void:
	# enemy position should be set when it's instantiated as a scene tile
	spawn = position

func _physics_process(delta: float) -> void:
	if player == null:
		# Tilemaplayer > Level
		player = get_parent().get_parent().find_child("Player")
	
	if dead:
		return
	
	if not Globals.has_downdash:
		current_state = State.IDLE
		return
	
	if (player.position.distance_to(position) < player_detection_range) and not aggroed:
		aggroed = true
		MusicManager.add_battler()
	elif (player.position.distance_to(position) >= player_detection_range) and aggroed:
		aggroed = false
		MusicManager.remove_battler()
	
	var bodies = $DamageRegion.get_overlapping_bodies()
	for body in bodies:
		if body is Player:
			body.take_hit(true)
	
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
			bounced_off_horz_wall = false
			
			var delta_position = player.position - position
			var dist_to_travel = delta_position.x / x_player_distance_fraction
			
			# trying to ease
			jump_start_y = position.y
			var jump_apex_y = position.y - jumping_up_height
			var effective_jumping_up_time = jumping_up_time
			jump_dy = jump_apex_y - jump_start_y
			
			velocity = Vector2(dist_to_travel / effective_jumping_up_time, 3.0 * jump_dy / effective_jumping_up_time)
			
			facedir = int(sign(velocity.x)) if velocity.x != 0 else facedir
			
			bubbles_left = num_bubbles
			bubble_timer = bubble_time
			jumping_up_timer = effective_jumping_up_time
			
	elif current_state == State.JUMPING_UP:
		bubble_timer -= delta
		if bubble_timer <= 0 and bubbles_left > 0:
			bubbles_left -= 1
			bubble_timer = bubble_time
			print("[FROG] SHOOT A BUBBLE")
		
		jumping_up_timer -= delta
		if not bounced_off_ceiling:
			var time_pct := clampf(jumping_up_timer / jumping_up_time, 0.0, 1.0)
			velocity.y = (3.0 * jump_dy / jumping_up_time) * time_pct * time_pct
		else:
			velocity.y -= gravity
		
		if (jumping_up_timer <= 0) or (is_on_ceiling() and jump_dist_travelled > min_dist_to_heatseek_early):
			var new_player_position = player.position
			var heatseek_angle: float
			if new_player_position.y < position.y:
				print("[FROG] player higher than frog; fallback angle")
				heatseek_angle = deg_to_rad(DOWN_DEGREES - heatseeking_fallback_angle * int(sign(new_player_position.x - position.x)))
			else:
				heatseek_angle = rad_to_deg((new_player_position - position).angle())
				if heatseek_angle < DOWN_DEGREES - heatseeking_max_range:
					heatseek_angle = DOWN_DEGREES - heatseeking_max_range
				if heatseek_angle > DOWN_DEGREES + heatseeking_max_range:
					heatseek_angle = DOWN_DEGREES + heatseeking_max_range
				heatseek_angle = deg_to_rad(heatseek_angle)
			
			velocity = Vector2.from_angle(heatseek_angle).normalized() * heatseeking_speed
			
			facedir = int(sign(player.position.x - position.x))
			
			print("[FROG] JUMPING UP -> JUMPING DOWN ", heatseek_angle, " ", velocity)
			
			bounced_off_horz_wall = false
			bounced_off_ceiling = false
			
			current_state = State.JUMPING_DOWN
		
		var xvel_before_move := velocity.x
		move_and_slide()
		var col = get_last_slide_collision()
		if col:
			var normal = col.get_normal()
			if normal.x != 0 and sign(normal.x) != sign(xvel_before_move):
				velocity.x = xvel_before_move * normal.x * wall_hit_decay
				bounced_off_horz_wall = true
			if normal.y == -1:
				bounced_off_ceiling = true
		
		jump_dist_travelled = position.y - jump_start_y
		
		if is_on_floor():
			print("[FROG] JUMPING UP -> IDLE")
			current_state = State.IDLE
			bounced_off_horz_wall = false
			bounced_off_ceiling = false
	
	elif current_state == State.JUMPING_DOWN:
		var xvel_before_move := velocity.x
		move_and_slide()
		var col = get_last_slide_collision()
		if col:
			var normal = col.get_normal()
			if normal.x != 0 and sign(normal.x) != sign(xvel_before_move):
				bounced_off_horz_wall = true
		
		if is_on_floor():
			print("[FROG] JUMPING DOWN -> IDLE")
			_add_ground_dent()
			current_state = State.IDLE
			bounced_off_horz_wall = false
	
	#region ANIMATION
	$AnimatedSprite2D.flip_h = facedir == 1
	if current_state == State.IDLE or current_state == State.READYING:
		$AnimatedSprite2D.play("idle")
	elif current_state == State.JUMPING_UP:
		$AnimatedSprite2D.play("jumping_up")
	elif current_state == State.JUMPING_DOWN:
		$AnimatedSprite2D.play("jumping_down")
	#endregion

func _add_ground_dent() -> void:
	# Find the WallDentManager in the level (parent is TileMapLayer, grandparent is Level)
	var tilemap = get_parent()
	if tilemap:
		var level = tilemap.get_parent()
		if level:
			for child in level.get_children():
				if child.has_method("add_temporary_dent"):
					# Position the dent at the frog's feet, slightly into the ground
					var dent_pos = position + Vector2(0, 16)
					child.add_temporary_dent(dent_pos, Vector2.DOWN, 48.0, 1.0)
					return


func die() -> void:
	visible = false
	dead = true
	$DamageRegion.monitoring = false
	$CollisionShape2D.disabled = true

func reset() -> void:
	visible = true
	dead = false
	$DamageRegion.monitoring = true
	$CollisionShape2D.disabled = false
	
	position = spawn
	current_state = State.IDLE
