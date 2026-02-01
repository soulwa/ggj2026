class_name Helptext extends Label

@export var after_frogmask := false
@export var after_mushmask := false
@export var after_cry := false
@export var fade_in_time := 0.25

# gpt slop
var _show_tween: Tween
var _shown := false

func show_fade_in(time) -> void:
	if _shown:
		return
	_shown = true

	if _show_tween:
		_show_tween.kill()

	visible = true
	modulate.a = 0.0

	_show_tween = create_tween()
	_show_tween.tween_property(self, "modulate:a", 1.0, time) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _ready() -> void:
	if not Globals.has_downdash and after_frogmask:
		visible = false
	if not Globals.has_double_jump and after_mushmask:
		visible = false
	if not Globals.has_crying and after_cry:
		visible = false

func _process(delta: float) -> void:
	if Globals.has_downdash and after_frogmask:
		show_fade_in(fade_in_time)
	if Globals.has_double_jump and after_mushmask:
		show_fade_in(fade_in_time)
	if Globals.has_crying and after_cry:
		show_fade_in(fade_in_time)
