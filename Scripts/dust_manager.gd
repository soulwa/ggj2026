extends Node
## Manages background dust particles across level transitions.
## Caches emitters and repositions them instead of recreating.

const BackgroundDustScene = preload("res://Scenes/background_dust_cpu.tscn")

var _dust_emitters: Array[CPUParticles2D] = []
var _dust_containers: Array[Parallax2D]
var _current_cluster_count: int = 0


func _ready() -> void:
	# Create a container that persists across scenes
	var new_dust_container0 = Parallax2D.new()
	new_dust_container0.name = "DustContainer0"
	new_dust_container0.z_index = -7
	new_dust_container0.scroll_scale = Vector2.ONE * 0.7
	add_child(new_dust_container0)
	_dust_containers.append(new_dust_container0)
	var new_dust_container1 = Parallax2D.new()
	new_dust_container1.name = "DustContainer1"
	new_dust_container1.z_index = -6
	new_dust_container1.scroll_scale = Vector2.ONE * 0.8
	add_child(new_dust_container1)
	_dust_containers.append(new_dust_container1)
	var new_dust_container2 = Parallax2D.new()
	new_dust_container2.name = "DustContainer2"
	new_dust_container2.z_index = -5
	new_dust_container2.scroll_scale = Vector2.ONE * 0.9
	add_child(new_dust_container2)
	_dust_containers.append(new_dust_container2)
	var new_dust_container3 = Parallax2D.new()
	new_dust_container3.name = "DustContainer3"
	new_dust_container3.z_index = 5
	new_dust_container3.scroll_scale = Vector2.ONE * 1.1
	add_child(new_dust_container3)
	_dust_containers.append(new_dust_container3)
	var new_dust_container4 = Parallax2D.new()
	new_dust_container4.name = "DustContainer4"
	new_dust_container4.z_index = 6
	new_dust_container4.scroll_scale = Vector2.ONE * 1.2
	add_child(new_dust_container4)
	_dust_containers.append(new_dust_container4)


## Call this when a level loads to position dust throughout it
func setup_for_level(camera: Camera2D) -> void:
	var level_width: float = camera.limit_right - camera.limit_left
	var level_height: float = camera.limit_bottom - camera.limit_top
	
	# Calculate cluster grid - tighter spacing for better coverage
	var cluster_spacing: float = 600.0
	var clusters_x: int = max(1, int(level_width / cluster_spacing) + 1)
	var clusters_y: int = max(1, int(level_height / cluster_spacing) + 1)
	var total_clusters: int = clusters_x * clusters_y
	
	# Ensure we have enough emitters (create more if needed, hide extras if too many)
	_ensure_emitter_count(total_clusters)
	
	# Position each emitter
	var emitter_index: int = 0
	for i in range(clusters_x):
		for j in range(clusters_y):
			if emitter_index >= _dust_emitters.size():
				break
				
			var dust: CPUParticles2D = _dust_emitters[emitter_index]
			
			# Position in grid with randomness
			var base_x: float = camera.limit_left + (i + 0.5) * (level_width / clusters_x)
			var base_y: float = camera.limit_top + (j + 0.5) * (level_height / clusters_y)
			var rand_offset := Vector2(randf_range(-50, 50), randf_range(-50, 50))
			
			dust.position = Vector2(base_x, base_y) + rand_offset
			dust.visible = true
			dust.emitting = true
			
			emitter_index += 1
	
	# Hide any extra emitters
	#for i in range(emitter_index, _dust_emitters.size()):
		#_dust_emitters[i].visible = false
		#_dust_emitters[i].emitting = false
	
	_current_cluster_count = total_clusters


func _ensure_emitter_count(count: int) -> void:
	# Cap maximum emitters to prevent runaway creation
	var max_emitters: int = 100
	count = min(count, max_emitters)
	
	# Create more emitters if needed
	while _dust_emitters.size() < count:
		var dust: CPUParticles2D = BackgroundDustScene.instantiate()
		
		# Configure for large area coverage (+25% from original)
		dust.emission_width = 2500.0
		dust.emission_height = 2500.0
		dust.particle_count = 32
		
		var target_container = _dust_containers.pick_random()
		dust.scale_amount_max *= target_container.scroll_scale.x
		dust.scale_amount_min *= target_container.scroll_scale.x
		target_container.add_child(dust)
		_dust_emitters.append(dust)




## Temporarily hide all dust (useful during transitions)
func hide_all() -> void:
	for dust in _dust_emitters:
		dust.visible = false


## Show all active dust
func show_all() -> void:
	for i in range(_current_cluster_count):
		if i < _dust_emitters.size():
			_dust_emitters[i].visible = true
