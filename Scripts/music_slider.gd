extends HSlider

func _ready() -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)

func _on_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Music"), value)
