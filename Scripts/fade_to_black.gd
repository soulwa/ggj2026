extends ColorRect

@onready var endtext: Label = $Endtext
@onready var restarttext: Label = $restarttext

var im_fading: bool = false
var tween: Tween

func _process(delta: float) -> void:
	if !Globals.begin_fade_out:
		modulate.a = 0.0
		endtext.modulate.a = 0.0
		restarttext.modulate.a = 0.0
	if Globals.begin_fade_out and !im_fading:
		im_fading = true
		fade_me_in()
	
	if Input.is_action_just_pressed("pause") and Globals.begin_fade_out and Globals.end_text_done:
		Globals.reset_game(true)

func fade_me_in() -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(false)
	tween.tween_interval(4.0)
	tween.tween_property(self, "modulate:a", 1.0, 10.0)
	tween.tween_property(endtext, "modulate:a", 1.0, 4.0)
	tween.tween_interval(2.0)
	tween.tween_property(restarttext, "modulate:a", 1.0, 1.0)
	await tween.finished
	Globals.end_text_done = true
