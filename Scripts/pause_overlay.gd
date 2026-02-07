extends CanvasLayer

var can_pause: bool = false
var paused: bool = false

func _ready() -> void:
	hide()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and !Globals.begin_fade_out:
		paused = !paused
		if paused:
			open_me()
		else:
			close_me()

func open_me() -> void:
	if can_pause:
		get_tree().paused = true
		show()

func close_me() -> void:
	get_tree().paused = false
	hide()

func _notification(what: int):
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		paused = true
		open_me()
