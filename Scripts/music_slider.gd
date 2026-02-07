extends HSlider

func _ready() -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)

func _process(delta: float) -> void:
	var value_from_bus = AudioServer.get_bus_volume_linear(AudioServer.get_bus_index("Music"))
	if value_from_bus != value:
		set_value_no_signal(value_from_bus)

func _on_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)
