class_name Helptext extends Label

@export var after_frogmask := false
@export var after_mushmask := false
@export var after_cry := false

func _ready() -> void:
	if not Globals.has_downdash and after_frogmask:
		visible = false
	if not Globals.has_double_jump and after_mushmask:
		visible = false
	if not Globals.has_crying and after_cry:
		visible = false

func _process(delta: float) -> void:
	if Globals.has_downdash and after_frogmask:
		visible = true
	if Globals.has_double_jump and after_mushmask:
		visible = true
	if Globals.has_crying and after_cry:
		visible = true
