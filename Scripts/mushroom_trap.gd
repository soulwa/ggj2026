class_name MushroomTrap extends Node2D

@onready var guy_spawn_point: Node2D = $GuySpawnPoint


var mushroom_guy_scene: PackedScene = preload("res://Scenes/mushroom_guy.tscn")
var mushroom_spores_scene: PackedScene = preload("res://Scenes/mushroom_spores.tscn")

var min_guys: int = 5
var max_guys: int = 7

var spore_delay: float = 0.1  ## Delay between spore burst and mushroom spawn
var spore_y_offset: float = 24.0  ## Lower offset for spore emission (positive = down)

var activated: bool = false

func _on_player_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		activate()


func activate() -> void:
	if !activated:
		activated = true
		
		# Emit spore burst effect before spawning mushrooms
		# Add to parent so it doesn't get hidden when the trap hides
		var spores: MushroomSpores = mushroom_spores_scene.instantiate()
		spores.z_index = -10  # Render behind enemies and trap
		get_parent().add_child(spores)
		var spore_pos = guy_spawn_point.global_position + Vector2(0, spore_y_offset)
		spores.emit_burst(spore_pos, Vector2.UP)
		
		# Wait for spore effect before spawning mushrooms
		await get_tree().create_timer(spore_delay).timeout
		
		# Spawn the mushroom guys
		for i in randi_range(min_guys, max_guys):
			var new_guy = mushroom_guy_scene.instantiate()
			new_guy.global_position = guy_spawn_point.global_position
			call_deferred("add_sibling", new_guy)
		hide()
