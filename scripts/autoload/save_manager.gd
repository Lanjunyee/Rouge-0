extends Node

## 设置键
const SETTINGS_PATH: String = "user://settings.cfg"
const GAME_DATA_PATH: String = "user://game_data.cfg"

## 当前音量 (0.0 ~ 1.0)
var bgm_volume: float = 0.8
var sfx_volume: float = 0.8
var fps: int = 60

## 游戏数据
var high_score: int = 0
var total_kills: int = 0
var total_play_time: float = 0.0
var pending_load: Dictionary = {}
var selected_weapon: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	load_game_data()

# ── 设置 ──────────────────────────────────────────

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("video", "fps", fps)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SETTINGS_PATH)
	if err != OK:
		# 首次运行，用默认值
		return
	bgm_volume = cfg.get_value("audio", "bgm_volume", 0.8)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 0.8)
	fps = cfg.get_value("video", "fps", 60)
	Engine.max_fps = fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	save_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	save_settings()

func set_fps(value: int) -> void:
	fps = value
	Engine.max_fps = value
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	save_settings()

# ── 游戏数据（仅存档，自动保存）──────────────────

func save_game_data() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("stats", "high_score", high_score)
	cfg.set_value("stats", "total_kills", total_kills)
	cfg.set_value("stats", "total_play_time", total_play_time)
	cfg.save(GAME_DATA_PATH)

func load_game_data() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(GAME_DATA_PATH)
	if err != OK:
		return
	high_score = cfg.get_value("stats", "high_score", 0)
	total_kills = cfg.get_value("stats", "total_kills", 0)
	total_play_time = cfg.get_value("stats", "total_play_time", 0.0)

func record_game_over(final_score: int, kills: int, time_played: float) -> void:
	high_score = max(high_score, final_score)
	total_kills += kills
	total_play_time += time_played
	save_game_data()

# ── 运行存档 ──────────────────────────────────────

const SAVE_PATH: String = "user://save_game.json"

func save_game(player_state: Dictionary, wave_state: Dictionary) -> void:
	var save = {
		"exists": true,
		"game_time": GameManager.game_time,
		"kill_count": GameManager.kill_count,
		"score": GameManager.score,
		"player": player_state,
		"wave": wave_state,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save, "\t"))
		f.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var text = f.get_as_text()
	f.close()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY or not data.get("exists", false):
		return {}
	
	# Validate required fields
	var required = ["game_time", "kill_count", "player", "wave"]
	for key in required:
		if not data.has(key):
			delete_save()
			return {}
	var player = data.player
	if typeof(player) != TYPE_DICTIONARY or not player.has("level"):
		delete_save()
		return {}
	
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func get_save_preview() -> String:
	var data = load_game()
	if data.is_empty():
		return ""
	var player = data.get("player", {})
	var lv = player.get("level", 1)
	var t = data.get("game_time", 0.0)
	var mins = int(t / 60.0)
	var secs = int(t) % 60
	var kills = data.get("kill_count", 0)
	return "继续 Lv.%d · %02d:%02d · %d杀" % [lv, mins, secs, kills]

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
