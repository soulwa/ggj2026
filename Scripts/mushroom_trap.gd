class_name MushroomTrap extends Node2D

@onready var guy_spawn_point: Node2D = $GuySpawnPoint
@onready var sprite: Sprite2D = $Sprite2D  # Reference to the trap's sprite

var mushroom_guy_scene: PackedScene = preload("res://Scenes/mushroom_guy.tscn")
var mushroom_spores_scene: PackedScene = preload("res://Scenes/mushroom_spores.tscn")
var squash_stretch_shader: Shader = preload("res://Shaders/squash_stretch.gdshader")

var min_guys: int = 5
var max_guys: int = 6

var spore_delay: float = 0.1  ## Delay between spore burst and mushroom spawn
var spore_y_offset: float = 24.0  ## Lower offset for spore emission (positive = down)

var activated: bool = false

## ============== TRAP ANIMATION TUNING ==============
var anticipation_squash: float = -0.15  # How much to squash down (anticipation)
var anticipation_duration: float = 0.1
var launch_stretch: float = 0.2  # How much to stretch up
var launch_duration: float = 0.12
var bounce_height: float = -15.0  # Pixels to bounce up (negative = up)
var puff_duration: float = 0.1
## ===================================================

func _ready() -> void:
	# Apply squash stretch shader to trap sprite if it exists
	_setup_shader()

func _setup_shader() -> void:
	if sprite:
		var shader_material = ShaderMaterial.new()
		shader_material.shader = squash_stretch_shader
		shader_material.set_shader_parameter("squash_amount", 0.0)
		shader_material.set_shader_parameter("vertical_offset", 0.0)
		# Pivot at bottom of sprite (sprite is 192px, offset.y = -30, so bottom is at 96-30 = 66)
		shader_material.set_shader_parameter("pivot_offset_y", 20.0)
		sprite.material = shader_material

func _on_player_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		activate()


func activate() -> void:
	if !activated:
		activated = true
		
		# Play squash animation, then explode
		await _play_squash_animation()
		
		# EXPLODE! Emit spore burst and hide trap
		_emit_explosion()
		hide()
		MusicManager.play_shroomscream()
		
		# Spawn the mushroom guys immediately (they emerge from the explosion)
		var num_guys = randi_range(min_guys, max_guys)
		for i in num_guys:
			var new_guy = mushroom_guy_scene.instantiate()
			new_guy.global_position = guy_spawn_point.global_position
			new_guy.spawn_delay = i * 0.03  # Stagger spawn animations
			call_deferred("add_sibling", new_guy)
		hide()

func reset() -> void:
	show()
	activated = false
	# Reset shader parameters to default values
	if sprite and sprite.material is ShaderMaterial:
		var mat: ShaderMaterial = sprite.material
		mat.set_shader_parameter("squash_amount", 0.0)
		mat.set_shader_parameter("vertical_offset", 0.0)

func _emit_explosion() -> void:
	var spores: MushroomSpores = mushroom_spores_scene.instantiate()
	spores.z_index = -10  # Render behind enemies
	get_parent().add_child(spores)
	var spore_pos = guy_spawn_point.global_position + Vector2(0, spore_y_offset)
	spores.emit_burst(spore_pos, Vector2.UP)

func _play_squash_animation() -> void:
	if not sprite or not sprite.material is ShaderMaterial:
		return
	
	var mat: ShaderMaterial = sprite.material
	
	# Anticipation squash (compress down smoothly, then explode)
	var squash_tween = create_tween()
	squash_tween.set_ease(Tween.EASE_OUT)
	squash_tween.set_trans(Tween.TRANS_SINE)
	squash_tween.tween_method(
		func(val: float): mat.set_shader_parameter("squash_amount", val),
		0.0, anticipation_squash, anticipation_duration
	)
	await squash_tween.finished
