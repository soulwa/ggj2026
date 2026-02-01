class_name MaskItem extends Area2D

@export var is_downdash: bool = false
@export var is_doublejump: bool = false
@export var is_crying: bool = false

func _ready() -> void:
	if is_downdash and Globals.has_downdash:
		queue_free()
	
	if is_doublejump and Globals.has_double_jump:
		queue_free()
	
	if is_crying and Globals.has_crying:
		queue_free()
	
	body_entered.connect(_on_body_entered)


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
			MusicManager.play_maskget()
			Globals.currently_selected_action = Globals.Action.Cry
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
