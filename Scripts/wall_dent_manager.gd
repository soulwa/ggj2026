class_name WallDentManager extends Node
## Manages wall dent data for the shader-based dent effect.
## Attach to a level or as an autoload. Call add_dent() when hitting walls.

const MAX_DENTS := 100

@export var default_radius := 56.0  ## Radius of dent effect in pixels (larger = smoother blend)
@export var default_strength := 1.15  ## Intensity of the dent

var _dents: Array[Dictionary] = []  ## Array of {position, radius, strength, direction}
var _data_texture: ImageTexture
var _data_image: Image
var _target_tilemaps: Array[TileMapLayer] = []  ## Multiple tilemaps can receive the dent effect

signal dents_updated


func _ready() -> void:
	_create_data_texture()
	
	# Auto-find tilemaps in parent if not set
	await get_tree().process_frame
	_find_tilemaps()


func _create_data_texture() -> void:
	# Create a 30x2 float RGBA image for dent data
	# Row 0: pos.x, pos.y, radius, strength
	# Row 1: dir.x, dir.y, 0, 0
	_data_image = Image.create(MAX_DENTS, 2, false, Image.FORMAT_RGBAF)
	_data_image.fill(Color(0, 0, 0, 0))
	
	_data_texture = ImageTexture.create_from_image(_data_image)


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


## Add a dent with direction influence (offsets position into the wall)
func add_dent_directed(world_position: Vector2, hit_direction: Vector2, radius: float = -1.0, strength: float = -1.0) -> void:
	# Offset position slightly in hit direction for more natural placement
	var offset_pos = world_position + hit_direction.normalized() * 8.0
	add_dent(offset_pos, hit_direction, radius, strength)


## Clear all dents (call on room transition)
func clear_dents() -> void:
	_dents.clear()
	_update_data_texture()
	dents_updated.emit()


## Get current dent count
func get_dent_count() -> int:
	return _dents.size()


func _update_data_texture() -> void:
	if not _data_image:
		return
	
	# Clear image
	_data_image.fill(Color(0, 0, 0, 0))
	
	# Write dent data to image pixels
	for i in range(_dents.size()):
		var dent = _dents[i]
		var pos: Vector2 = dent["position"]
		var radius: float = dent["radius"]
		var strength: float = dent["strength"]
		var dir: Vector2 = dent["direction"]
		
		# Row 0: position.x, position.y, radius, strength
		_data_image.set_pixel(i, 0, Color(pos.x, pos.y, radius, strength))
		# Row 1: direction.x, direction.y, 0, 0
		_data_image.set_pixel(i, 1, Color(dir.x, dir.y, 0.0, 0.0))
	
	# Update texture
	_data_texture.update(_data_image)
	
	# Update shader uniform for count on all tilemaps
	for tilemap in _target_tilemaps:
		if tilemap and tilemap.material:
			var mat = tilemap.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("dent_count", _dents.size())
