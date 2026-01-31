extends Node

var death_count := 0
var time_spent := 0.0

var opposite_direction_from := Level.Direction.Left

var has_double_jump := false
var has_downdash := false
var has_crying := false

# 0 to 1 to fill screen, "cutscene" maybe.
# when its 1.0 you can swim
var waterworld := 0.0
