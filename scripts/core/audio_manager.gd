extends Node
## AudioManager - Handles all game audio (music and SFX)

signal music_changed(track_name: String)

# Audio buses
const MASTER_BUS = "Master"
const MUSIC_BUS = "Music"
const SFX_BUS = "SFX"

# Audio players
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 8

# Current state
var current_music: String = ""
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var is_muted: bool = false

# Music tracks (loaded on demand)
var music_tracks: Dictionary = {
	"menu": "res://assets/audio/music/menu_theme.ogg",
	"match": "res://assets/audio/music/match_theme.ogg",
	"match_intense": "res://assets/audio/music/match_intense.ogg",
	"victory": "res://assets/audio/music/victory.ogg",
	"defeat": "res://assets/audio/music/defeat.ogg",
	"training": "res://assets/audio/music/training.ogg",
	"story": "res://assets/audio/music/story_theme.ogg"
}

# SFX (preloaded for instant playback)
var sfx_cache: Dictionary = {}
var missing_music_tracks: Dictionary = {}
var missing_sfx_names: Dictionary = {}


func _ready() -> void:
	print("[AudioManager] Initialized")
	_setup_audio_players()
	_preload_common_sfx()


func _setup_audio_players() -> void:
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	music_player.finished.connect(_on_music_finished)
	
	# Create SFX player pool
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_players.append(player)


func _preload_common_sfx() -> void:
	var common_sfx = [
		"ui_click",
		"ui_hover",
		"ui_confirm",
		"ui_cancel",
		"whistle",
		"kick",
		"goal",
		"crowd_cheer",
		"crowd_groan"
	]
	
	for sfx_name in common_sfx:
		var path = "res://assets/audio/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			sfx_cache[sfx_name] = load(path)


func play_music(track_name: String, fade_duration: float = 1.0) -> void:
	if track_name == current_music:
		return
	
	if track_name not in music_tracks:
		push_warning("[AudioManager] Unknown music track: %s" % track_name)
		return

	if track_name in missing_music_tracks:
		return

	var path = music_tracks[track_name]
	if not ResourceLoader.exists(path):
		missing_music_tracks[track_name] = true
		return
	
	# Fade out current music
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(func(): _start_new_music(track_name, path, fade_duration))
	else:
		_start_new_music(track_name, path, fade_duration)


func _start_new_music(track_name: String, path: String, fade_duration: float) -> void:
	var stream = load(path)
	music_player.stream = stream
	music_player.volume_db = -40.0
	music_player.play()
	
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", linear_to_db(music_volume), fade_duration)
	
	current_music = track_name
	music_changed.emit(track_name)


func stop_music(fade_duration: float = 1.0) -> void:
	if music_player.playing:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_duration)
		tween.tween_callback(music_player.stop)
	
	current_music = ""


func play_sfx(sfx_name: String, volume_scale: float = 1.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream

	if sfx_name in missing_sfx_names:
		return

	# Check cache first
	if sfx_name in sfx_cache:
		stream = sfx_cache[sfx_name]
	else:
		var path = "res://assets/audio/sfx/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			stream = load(path)
			sfx_cache[sfx_name] = stream
		else:
			missing_sfx_names[sfx_name] = true
			return
	
	# Find available player
	var player = _get_available_sfx_player()
	if player:
		player.stream = stream
		player.volume_db = linear_to_db(sfx_volume * volume_scale)
		player.pitch_scale = pitch_scale
		player.play()


func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
	
	# All players busy, use the first one (interrupt oldest sound)
	return sfx_players[0]


func _on_music_finished() -> void:
	# Loop music by default
	if current_music != "":
		music_player.play()


func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	if music_player.playing:
		music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)


func set_muted(muted: bool) -> void:
	is_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MASTER_BUS), muted)


func toggle_mute() -> void:
	set_muted(not is_muted)


# UI convenience functions
func play_ui_click() -> void:
	play_sfx("ui_click", 0.5)


func play_ui_hover() -> void:
	play_sfx("ui_hover", 0.3, 1.1)


func play_ui_confirm() -> void:
	play_sfx("ui_confirm", 0.7)


func play_ui_cancel() -> void:
	play_sfx("ui_cancel", 0.5)
