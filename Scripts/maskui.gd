class_name MaskUI extends Control

var enabled_modulate := Color.WHITE
var disabled_modulate: Color = Color(0.29, 0.29, 0.29, 0.39)

func _ready() -> void:
	if not Globals.has_downdash:
		$MaskDive.hide()
	if not Globals.has_double_jump:
		$MaskDoubleJump.hide()

func _process(delta: float) -> void:
	if Globals.has_downdash:
		$MaskDive.show()
	if Globals.has_double_jump:
		$MaskDoubleJump.show()
		
func thrust_count(n: int) -> void:
	if n > 0:
		$MaskDash.modulate = enabled_modulate
	else:
		$MaskDash.modulate = disabled_modulate

func dive_count(n: int) -> void:
	if n > 0:
		$MaskDive.modulate = enabled_modulate
	else:
		$MaskDive.modulate = disabled_modulate

func djump_count(n: int) -> void:
	if n > 0:
		$MaskDoubleJump.modulate = enabled_modulate
	else:
		$MaskDoubleJump.modulate = disabled_modulate
