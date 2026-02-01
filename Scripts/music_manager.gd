extends Node

@onready var music_opt_1: AudioStreamPlayer = $MusicOpt1
@onready var music_opt_2: AudioStreamPlayer = $MusicOpt2
var music: AudioStreamPlayer
@export var crossfade_time: float = 2
@export var music_slow_time: float = 0.2

var battlers: int = 0

func _ready() -> void:
	music = music_opt_1
	music.play()
	crossfade_to_explore_music(true)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("_debug_music_battle"):
		crossfade_to_battle_music()
	elif Input.is_action_just_pressed("_debug_music_explore"):
		crossfade_to_explore_music()

func add_battler() -> void:
	battlers += 1
	if battlers > 0:
		crossfade_to_battle_music()

func remove_battler() -> void:
	battlers = max(0, battlers - 1)
	if battlers == 0:
		crossfade_to_explore_music()

func crossfade_to_battle_music(instant: bool = false) -> void:
	if instant:
		switch_song_track_instant(1)
	else:
		switch_song_track(1)

func crossfade_to_explore_music(instant: bool = false) -> void:
	if instant:
		switch_song_track_instant(2)
	else:
		switch_song_track(2)

var slowdown_tween: Tween

func slow_music() -> void:
	if slowdown_tween:
		slowdown_tween.kill
	slowdown_tween = create_tween()
	slowdown_tween.tween_property(music, "pitch_scale", 0.05, music_slow_time)

func normal_music() -> void:
	if slowdown_tween:
		slowdown_tween.kill
	slowdown_tween = create_tween()
	slowdown_tween.tween_property(music, "pitch_scale", 1.0, music_slow_time)

func switch_song_track_instant(idx: int) -> void:
	var current_stream: AudioStreamSynchronized = music.stream
	if current_stream:
		for i in current_stream.stream_count - 1:
			set_sync_stream_volume(0.0 if idx != i+1 else 1.0, i+1, current_stream)

func switch_song_track(idx: int) -> void:
	var current_stream: AudioStreamSynchronized = music.stream
	if current_stream:
		var tween = create_tween().set_parallel()
		for i in current_stream.stream_count - 1:
			var initial_track_volume = db_to_linear(current_stream.get_sync_stream_volume(i+1))
			tween.tween_method(set_sync_stream_volume.bind(i+1, current_stream), initial_track_volume, 0.0 if idx != i+1 else 1.0, crossfade_time)

func set_sync_stream_volume(linear_volume: float, stream_index: int, stream: AudioStreamSynchronized) -> void:
	stream.set_sync_stream_volume(stream_index, linear_to_db(linear_volume))


@onready var timer_footstep: Timer = $Timer_Footstep

func start_sound_footstep() -> void:
	if timer_footstep.is_stopped():
		timer_footstep.start()
		play_sound_footstep()

func stop_sound_footstep() -> void:
	timer_footstep.stop()
	
func _on_timer_footstep_timeout() -> void:
	play_sound_footstep()

func play_sound_footstep() -> void:
	$SFX_Footstep.play()

func play_sound_jump() -> void:
	$SFX_Jump.play()

func play_sound_thrust() -> void:
	$SFX_Thrust.play()

func play_sound_wallbounce() -> void:
	$SFX_Wallbounce.play()

func play_sound_doublejump() -> void:
	$SFX_Doublejump.play()

func play_sound_dive() -> void:
	$SFX_Dive.play()

func play_sound_divebounce() -> void:
	$SFX_Divebounce.play()

func play_sound_openmenu() -> void:
	$SFX_Openmenu.play()

func play_sound_select_up() -> void:
	$SFX_SelectUp.play()

func play_sound_select_side() -> void:
	$SFX_SelectSide.play()

func play_sound_select_down() -> void:
	$SFX_SelectDown.play()

func play_die() -> void:
	$SFX_Die.play()

func play_frogbounce() -> void:
	$SFX_Frogbounce.play()

func play_frogcroak() -> void:
	$SFX_Frogcroak.play()

func play_killenemy() -> void:
	$SFX_Killenemy.play()

func play_playerhurt() -> void:
	$SFX_Playerhurt.play()

func play_shoot() -> void:
	$SFX_Shoot.play()

func play_shroomscream() -> void:
	$SFX_Shroomscream.play()

func play_maskget() -> void:
	$SFX_Maskget.play()
