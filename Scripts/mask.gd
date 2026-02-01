class_name MaskItem extends Area2D

@export var is_downdash: bool = false
@export var is_doublejump: bool = false
@export var is_crying: bool = false
@onready var sprite: Sprite2D = $Sprite2D

@export var bob_amplitude: float = 6.0 # pixels
@export var bob_period: float = 2.0    # seconds
var _time := 0.0
var _base_sprite_y := 0.0

func _ready() -> void:
	if is_downdash and Globals.has_downdash:
		queue_free()
	
	if is_doublejump and Globals.has_double_jump:
		queue_free()
	
	if is_crying and Globals.has_crying:
		queue_free()
	
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	var omega := TAU / bob_period # angular frequency
	sprite.position.y = _base_sprite_y + sin(_time * omega) * bob_amplitude


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if is_downdash:
			Globals.has_downdash = true
			queue_free()
		if is_doublejump:
			Globals.has_double_jump = true
			queue_free()
		if is_crying:
			Globals.has_crying = true
			queue_free()
