extends ColorRect

@onready var endtext: Label = $Endtext

var im_fading: bool = false

func _process(delta: float) -> void:
	if Globals.begin_fade_out and !im_fading:
		im_fading = true
		fade_me_in()

func fade_me_in() -> void:
	var wait_tween = create_tween()
	wait_tween.tween_interval(4.0)
	await wait_tween.finished
	
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 10.0)
	await fade_tween.finished
	
	var text_fade_tween = create_tween()
	text_fade_tween.tween_property(endtext, "modulate:a", 1.0, 4.0)
