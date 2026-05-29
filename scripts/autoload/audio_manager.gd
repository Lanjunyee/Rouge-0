extends Node

const BUS_MASTER: String = "Master"
const BUS_BGM: String = "BGM"
const BUS_SFX: String = "SFX"

const SFX_DIR: String = "res://resources/audio/sfx/"
const BGM_DIR: String = "res://resources/audio/bgm/"

var bgm_player: AudioStreamPlayer
var bgm_path: String = ""
var _sfx_last_time: Dictionary = {}  # 同音效最小间隔 0.05s 防音爆

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_buses()
	_apply_volumes()

func _create_buses() -> void:
	var need_bgm = not _bus_exists(BUS_BGM)
	var need_sfx = not _bus_exists(BUS_SFX)

	if need_bgm:
		var bgm_idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(bgm_idx, BUS_BGM)
		AudioServer.set_bus_send(bgm_idx, BUS_MASTER)

	if need_sfx:
		var sfx_idx = AudioServer.bus_count
		AudioServer.add_bus()
		AudioServer.set_bus_name(sfx_idx, BUS_SFX)
		AudioServer.set_bus_send(sfx_idx, BUS_MASTER)

	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = BUS_BGM
	add_child(bgm_player)

func _bus_exists(bus_name: String) -> bool:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return true
	return false

func _apply_volumes() -> void:
	_apply_bgm_volume(SaveManager.bgm_volume)
	_apply_sfx_volume(SaveManager.sfx_volume)

func _apply_bgm_volume(linear: float) -> void:
	var idx = _get_bus_index(BUS_BGM)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _apply_sfx_volume(linear: float) -> void:
	var idx = _get_bus_index(BUS_SFX)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _get_bus_index(bus_name: String) -> int:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return i
	return -1

func play_bgm(path: String = "", _loop: bool = true) -> void:
	var actual_path = path if path else bgm_path
	if actual_path.is_empty():
		return

	if bgm_path != actual_path:
		bgm_path = actual_path
		var stream = load(actual_path)
		if not stream:
			return
		# 设为循环播放，避免 finished 信号间隙
		if "loop_mode" in stream:
			stream.loop_mode = 1  # LOOP_FORWARD
		bgm_player.stream = stream

	if not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	bgm_player.stop()

func play_sfx(sfx_name: String, pitch_min: float = 1.0, pitch_max: float = 1.0, volume_db: float = 0.0) -> void:
	# 同音效 50ms 内不再触发，防止音爆
	var now = Time.get_ticks_msec() / 1000.0
	var last = _sfx_last_time.get(sfx_name, -1.0)
	if now - last < 0.05:
		return
	_sfx_last_time[sfx_name] = now
	
	var path = SFX_DIR + sfx_name
	var stream = load(path)
	if not stream:
		return

	var player = AudioStreamPlayer.new()
	player.bus = BUS_SFX
	player.stream = stream
	player.volume_db = volume_db

	if pitch_max > pitch_min:
		player.pitch_scale = randf_range(pitch_min, pitch_max)
	else:
		player.pitch_scale = pitch_min

	add_child(player)
	player.play()
	player.finished.connect(_on_sfx_finished.bind(player))

func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.queue_free()

func set_bgm_volume(value: float) -> void:
	SaveManager.set_bgm_volume(value)
	_apply_bgm_volume(value)

func set_sfx_volume(value: float) -> void:
	SaveManager.set_sfx_volume(value)
	_apply_sfx_volume(value)

func get_bgm_volume() -> float:
	return SaveManager.bgm_volume

func get_sfx_volume() -> float:
	return SaveManager.sfx_volume

func mute_all() -> void:
	_apply_bgm_volume(0.0)
	_apply_sfx_volume(0.0)

func unmute_all() -> void:
	_apply_volumes()
