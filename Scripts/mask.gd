class_name MaskItem extends Area2D

var medal_doublejump_scene: PackedScene = load("res://Scenes/medal_doublejump.tscn")
var medal_downdash_scene: PackedScene = load("res://Scenes/medal_downdash.tscn")

@export var is_downdash: bool = false
@export var is_doublejump: bool = false
@export var is_crying: bool = false
@export var is_medal_downdash: bool = false
@export var is_medal_doublejump: bool = false
@onready var sprite: Sprite2D = $Sprite2D

@export var bob_amplitude: float = 6.0 # pixels
@export var bob_period: float = 2.0    # seconds
var _time := 0.0
var _base_sprite_y := 0.0

func _ready() -> void:
	if is_downdash and Globals.has_downdash:
		if Globals.is_ngp and !Globals.has_medal_downdash:
			var medal = medal_downdash_scene.instantiate()
			get_parent().add_child.call_deferred(medal)
			medal.global_position = global_position
		queue_free()
	
	if is_doublejump and Globals.has_double_jump:
		if Globals.is_ngp and !Globals.has_medal_doublejump:
			var medal = medal_doublejump_scene.instantiate()
			get_parent().add_child.call_deferred(medal)
			medal.global_position = global_position
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
			MusicManager.play_maskget()
			Globals.currently_selected_action = Globals.Action.Dive
			queue_free()
		if is_doublejump:
			Globals.has_double_jump = true
			MusicManager.play_maskget()
			Globals.currently_selected_action = Globals.Action.DoubleJump
			queue_free()
		if is_crying:
			Globals.has_crying = true
			MusicManager.play_maskget(true)
			Globals.currently_selected_action = Globals.Action.Cry
			MusicManager.stop_sound_footstep()
			PauseMenu.can_pause = false
			queue_free()
		if is_medal_downdash:
			Globals.has_medal_downdash = true
			MusicManager.play_maskget(false)
			queue_free()
		if is_medal_doublejump:
			Globals.has_medal_doublejump = true
			MusicManager.play_maskget(false)
			queue_free()
		
		match Globals.currently_selected_action:
			Globals.Action.Thrust:
				body.thrust_mask.show()
				body.dive_mask.hide()
				body.doublejump_mask.hide()
			Globals.Action.Dive:
				body.thrust_mask.hide()
				body.dive_mask.show()
				body.doublejump_mask.hide()
			Globals.Action.DoubleJump:
				body.thrust_mask.hide()
				body.dive_mask.hide()
				body.doublejump_mask.show()
			Globals.Action.Cry:
				body.thrust_mask.hide()
				body.dive_mask.hide()
				body.doublejump_mask.hide()
