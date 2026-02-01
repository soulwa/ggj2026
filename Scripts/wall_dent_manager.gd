class_name WallDentManager extends Node
## Manages wall dent data for the shader-based dent effect.
## Attach to a level or as an autoload. Call add_dent() when hitting walls.
## Also tracks damage to foreground tiles and shatters them after enough hits.

const MAX_DENTS := 100
const SHATTER_THRESHOLD := 3.0  ## Total damage needed to shatter a foreground tile
const SHATTER_CHECK_RADIUS := 2  ## Tile radius to check for damage

@export var default_radius := 56.0  ## Radius of dent effect in pixels (larger = smoother blend)
@export var default_strength := 1.15  ## Intensity of the dent
@export var enable_foreground_shatter := true  ## Whether foreground tiles can shatter

## Elastic bounce settings for temporary dents
@export var temp_dent_decay := 3.0  ## How fast the bounce dampens (higher = settles faster)
@export var temp_dent_frequency := 2.0  ## Bounce frequency (higher = faster oscillation)
@export var temp_dent_duration := 1.4  ## Total time before dent is removed

var _dents: Array[Dictionary] = []  ## Array of {position, radius, strength, direction}
var _temp_dents: Array[Dictionary] = []  ## Array of {position, radius, strength, direction, max_strength} - fade over time
var _data_texture: ImageTexture
var _data_image: Image
var _target_tilemaps: Array[TileMapLayer] = []  ## Multiple tilemaps can receive the dent effect

# Foreground shatter system
var _foreground_tilemap: TileMapLayer  ## Reference to ForegroundTiles specifically
var _foreground_damage: Dictionary = {}  ## Dictionary[Vector2i, float] - damage per cell (scales with distance)
var _shatter_particles: Node  ## ShatterParticles instance

signal dents_updated
signal tile_shattered(cell: Vector2i, world_pos: Vector2)  ## Emitted when a tile shatters


func _ready() -> void:
	_create_data_texture()
	_setup_shatter_particles()
	
	# Auto-find tilemaps in parent if not set
	await get_tree().process_frame
	_find_tilemaps()


func _process(delta: float) -> void:
	# Animate temporary dents with elastic bounce
	if _temp_dents.is_empty():
		return
	
	var needs_update := false
	var i := _temp_dents.size() - 1
	while i >= 0:
		var temp_dent = _temp_dents[i]
		temp_dent["time"] += delta
		var t: float = temp_dent["time"]
		
		# Remove dent after duration expires
		if t >= temp_dent_duration:
			_temp_dents.remove_at(i)
			needs_update = true
			i -= 1
			continue
		
		# Elastic/bouncy interpolation: damped cosine wave
		# Starts at max_strength, oscillates and settles toward 0
		var max_str: float = temp_dent["max_strength"]
		var envelope := exp(-temp_dent_decay * t)  # Exponential decay envelope
		var oscillation := cos(temp_dent_frequency * t)  # Bouncy oscillation
		temp_dent["strength"] = max_str * envelope * oscillation
		
		needs_update = true
		i -= 1
	
	if needs_update:
		_update_data_texture()
		dents_updated.emit()


func _create_data_texture() -> void:
	# Create a 30x2 float RGBA image for dent data
	# Row 0: pos.x, pos.y, radius, strength
	# Row 1: dir.x, dir.y, 0, 0
	_data_image = Image.create(MAX_DENTS, 2, false, Image.FORMAT_RGBAF)
	_data_image.fill(Color(0, 0, 0, 0))
	
	_data_texture = ImageTexture.create_from_image(_data_image)


func _setup_shatter_particles() -> void:
	# Create shatter particles instance
	var shatter_scene = preload("res://Scenes/shatter_particles.tscn")
	_shatter_particles = shatter_scene.instantiate()
	add_child(_shatter_particles)


## Names of tilemaps that should receive the dent effect
const DENT_TILEMAP_NAMES := ["TileMapLayer", "ForegroundTiles"]

func _find_tilemaps() -> void:
	# Look for specific TileMapLayers by name in parent's children
	var parent = get_parent()
	var found_any := false
	if parent:
		for child in parent.get_children():
			if child is TileMapLayer and child.name in DENT_TILEMAP_NAMES:
				add_target_tilemap(child)
				found_any = true
				# Track ForegroundTiles specifically for shatter system
				if child.name == "ForegroundTiles":
					_foreground_tilemap = child
	
	if not found_any:
		push_warning("WallDentManager: No matching TileMapLayer found. Expected: %s" % str(DENT_TILEMAP_NAMES))


## Add a tilemap that will receive the dent shader
func add_target_tilemap(tilemap: TileMapLayer) -> void:
	if tilemap in _target_tilemaps:
		return  # Already added
	_target_tilemaps.append(tilemap)
	_apply_shader_to_tilemap(tilemap)


## Set a single tilemap (clears existing and adds this one) - for backwards compatibility
func set_target_tilemap(tilemap: TileMapLayer) -> void:
	_target_tilemaps.clear()
	add_target_tilemap(tilemap)


func _apply_shader_to_tilemap(tilemap: TileMapLayer) -> void:
	if not tilemap:
		return
	
	# Create shader material if not already applied
	var mat = tilemap.material as ShaderMaterial
	if not mat:
		mat = ShaderMaterial.new()
		mat.shader = preload("res://Shaders/wall_dent.gdshader")
		tilemap.material = mat
	
	# Set the data texture uniform (shared across all tilemaps)
	mat.set_shader_parameter("dent_data", _data_texture)
	mat.set_shader_parameter("dent_count", _dents.size())


## Add a dent at the given world position with direction
func add_dent(world_position: Vector2, hit_direction: Vector2 = Vector2.RIGHT, radius: float = -1.0, strength: float = -1.0) -> void:
	if radius < 0:
		radius = default_radius
	if strength < 0:
		strength = default_strength
	
	# Normalize direction
	var dir = hit_direction.normalized() if hit_direction.length() > 0.001 else Vector2.RIGHT
	
	var dent := {
		"position": world_position,
		"radius": radius,
		"strength": strength,
		"direction": dir
	}
	
	_dents.append(dent)
	
	# FIFO removal if exceeds max
	while _dents.size() > MAX_DENTS:
		_dents.pop_front()
	
	_update_data_texture()
	dents_updated.emit()
	
	# Check for foreground tile damage
	if enable_foreground_shatter:
		_check_foreground_damage(world_position, radius, dir)


## Add a dent with direction influence (offsets position into the wall)
func add_dent_directed(world_position: Vector2, hit_direction: Vector2, radius: float = -1.0, strength: float = -1.0) -> void:
	# Offset position slightly in hit direction for more natural placement
	var offset_pos = world_position + hit_direction.normalized() * 8.0
	add_dent(offset_pos, hit_direction, radius, strength)


## Add a temporary dent that smoothly fades back to normal over time
func add_temporary_dent(world_position: Vector2, hit_direction: Vector2 = Vector2.DOWN, radius: float = -1.0, strength: float = -1.0) -> void:
	if radius < 0:
		radius = default_radius
	if strength < 0:
		strength = default_strength
	
	# Normalize direction
	var dir = hit_direction.normalized() if hit_direction.length() > 0.001 else Vector2.DOWN
	
	var temp_dent := {
		"position": world_position,
		"radius": radius,
		"strength": strength,
		"direction": dir,
		"max_strength": strength,  # Store original strength for elastic interpolation
		"time": 0.0  # Track elapsed time for bouncy animation
	}
	
	_temp_dents.append(temp_dent)
	
	# Limit temporary dents to avoid overwhelming the system
	while _temp_dents.size() > MAX_DENTS / 2:
		_temp_dents.pop_front()
	
	_update_data_texture()
	dents_updated.emit()


## Clear all dents (call on room transition)
func clear_dents() -> void:
	_dents.clear()
	_temp_dents.clear()
	_update_data_texture()
	dents_updated.emit()
	clear_foreground_damage()


## Get current dent count
func get_dent_count() -> int:
	return _dents.size()


func _update_data_texture() -> void:
	if not _data_image:
		return
	
	# Clear image
	_data_image.fill(Color(0, 0, 0, 0))
	
	var total_index := 0
	
	# Write permanent dent data to image pixels
	for i in range(_dents.size()):
		if total_index >= MAX_DENTS:
			break
		var dent = _dents[i]
		var pos: Vector2 = dent["position"]
		var radius: float = dent["radius"]
		var strength: float = dent["strength"]
		var dir: Vector2 = dent["direction"]
		
		# Row 0: position.x, position.y, radius, strength
		_data_image.set_pixel(total_index, 0, Color(pos.x, pos.y, radius, strength))
		# Row 1: direction.x, direction.y, 0, 0
		_data_image.set_pixel(total_index, 1, Color(dir.x, dir.y, 0.0, 0.0))
		total_index += 1
	
	# Write temporary dent data to image pixels (after permanent dents)
	for i in range(_temp_dents.size()):
		if total_index >= MAX_DENTS:
			break
		var dent = _temp_dents[i]
		var pos: Vector2 = dent["position"]
		var radius: float = dent["radius"]
		var strength: float = dent["strength"]
		var dir: Vector2 = dent["direction"]
		
		# Row 0: position.x, position.y, radius, strength
		_data_image.set_pixel(total_index, 0, Color(pos.x, pos.y, radius, strength))
		# Row 1: direction.x, direction.y, 0, 0
		_data_image.set_pixel(total_index, 1, Color(dir.x, dir.y, 0.0, 0.0))
		total_index += 1
	
	# Update texture
	_data_texture.update(_data_image)
	
	# Update shader uniform for count on all tilemaps
	for tilemap in _target_tilemaps:
		if tilemap and tilemap.material:
			var mat = tilemap.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("dent_count", total_index)


# ============================================================================
# FOREGROUND SHATTER SYSTEM
# ============================================================================

## Check if any foreground tiles near the dent position should take damage
func _check_foreground_damage(dent_pos: Vector2, radius: float, hit_direction: Vector2) -> void:
	if not _foreground_tilemap:
		return
	
	# Convert world position to tile coordinates
	var center_cell = _foreground_tilemap.local_to_map(_foreground_tilemap.to_local(dent_pos))
	
	# Check cells in a radius around the dent
	for dx in range(-SHATTER_CHECK_RADIUS, SHATTER_CHECK_RADIUS + 1):
		for dy in range(-SHATTER_CHECK_RADIUS, SHATTER_CHECK_RADIUS + 1):
			var cell = center_cell + Vector2i(dx, dy)
			
			# Skip empty cells
			if _foreground_tilemap.get_cell_source_id(cell) == -1:
				continue
			
			# Check if cell center is within dent radius
			var cell_world = _foreground_tilemap.to_global(_foreground_tilemap.map_to_local(cell))
			var distance = cell_world.distance_to(dent_pos)
			
			if distance <= radius:
				# Calculate damage based on distance (1.5 at center, 1.0 at edge)
				# This gives 2 hits to break at center, 3 hits at edge
				var distance_factor = 1.0 - (distance / radius)
				var damage = lerp(1.0, 1.5, distance_factor)
				_add_damage_to_cell(cell, cell_world, hit_direction, damage)


## Add damage to a specific cell and check if it should shatter
func _add_damage_to_cell(cell: Vector2i, cell_world: Vector2, hit_direction: Vector2, damage: float = 1.0) -> void:
	# Get current damage (default 0)
	var current_damage: float = _foreground_damage.get(cell, 0.0)
	current_damage += damage
	_foreground_damage[cell] = current_damage
	
	# Check if threshold reached
	if current_damage >= SHATTER_THRESHOLD:
		_shatter_tile(cell, cell_world, hit_direction)


## Shatter a foreground tile - spawn particles and remove it
func _shatter_tile(cell: Vector2i, world_pos: Vector2, hit_direction: Vector2) -> void:
	if not _foreground_tilemap:
		return
	
	# Get colors from the tile before removing it
	var colors = _get_tile_colors(cell)
	
	# Spawn shatter particles
	if _shatter_particles and _shatter_particles.has_method("emit_shatter"):
		_shatter_particles.emit_shatter(world_pos, colors, hit_direction)
	
	# Remove the tile
	_foreground_tilemap.erase_cell(cell)
	
	# Clean up damage tracking
	_foreground_damage.erase(cell)
	
	# Emit signal
	tile_shattered.emit(cell, world_pos)


## Sample colors from a tile's texture for the particle effect
func _get_tile_colors(cell: Vector2i) -> Array[Color]:
	var colors: Array[Color] = []
	
	if not _foreground_tilemap:
		return colors
	
	var source_id = _foreground_tilemap.get_cell_source_id(cell)
	if source_id == -1:
		return colors
	
	var tileset = _foreground_tilemap.tile_set
	if not tileset:
		return colors
	
	var source = tileset.get_source(source_id)
	if not source is TileSetAtlasSource:
		return colors
	
	var atlas_source = source as TileSetAtlasSource
	var atlas_coords = _foreground_tilemap.get_cell_atlas_coords(cell)
	var texture = atlas_source.texture
	
	if not texture:
		return colors
	
	# Get the tile region in the atlas
	var tile_size = tileset.tile_size
	var region_pos = Vector2(atlas_coords) * Vector2(tile_size)
	
	# Sample colors from the tile's texture
	var img = texture.get_image()
	if not img:
		return colors
	
	# Sample a few points from the tile (corners and center)
	var sample_points = [
		Vector2i(tile_size.x / 4, tile_size.y / 4),
		Vector2i(tile_size.x * 3 / 4, tile_size.y / 4),
		Vector2i(tile_size.x / 2, tile_size.y / 2),
		Vector2i(tile_size.x / 4, tile_size.y * 3 / 4),
		Vector2i(tile_size.x * 3 / 4, tile_size.y * 3 / 4),
	]
	
	for offset in sample_points:
		var px = int(region_pos.x) + offset.x
		var py = int(region_pos.y) + offset.y
		
		# Bounds check
		if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
			var sampled_color = img.get_pixel(px, py)
			# Only add non-transparent colors
			if sampled_color.a > 0.5:
				colors.append(sampled_color)
	
	# Remove duplicates and limit to 3 colors
	var unique_colors: Array[Color] = []
	for c in colors:
		var is_unique := true
		for existing in unique_colors:
			if c.is_equal_approx(existing):
				is_unique = false
				break
		if is_unique:
			unique_colors.append(c)
		if unique_colors.size() >= 3:
			break
	
	return unique_colors


## Clear foreground damage tracking (call on room transition)
func clear_foreground_damage() -> void:
	_foreground_damage.clear()


## Get damage for a specific cell (for debugging/UI)
func get_cell_damage(cell: Vector2i) -> float:
	return _foreground_damage.get(cell, 0.0)
