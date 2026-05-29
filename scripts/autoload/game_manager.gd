extends Node

enum GameState { RUNNING, PAUSED, GAME_OVER }
enum PauseSource { MANUAL, LEVEL_UP }

signal game_paused
signal game_resumed
signal game_over
signal player_damaged(current_hp: int, max_hp: int)
signal player_leveled_up(level: int)
signal player_xp_changed(current_xp: int, xp_to_next: int)
signal enemy_killed
signal experience_gained(amount: int)

var state: GameState = GameState.RUNNING
var pause_source: PauseSource = PauseSource.MANUAL
var game_time: float = 0.0
var kill_count: int = 0
var score: int = 0

var auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == GameState.RUNNING:
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("save_state"):
				SaveManager.save_game(player.save_state(), WaveManager.get_state())

func _process(delta: float) -> void:
	if state == GameState.RUNNING:
		game_time += delta
		auto_save_timer += delta
		if auto_save_timer >= AUTO_SAVE_INTERVAL:
			auto_save_timer = 0.0
			var player = get_tree().get_first_node_in_group("player")
			if player and player.has_method("save_state"):
				SaveManager.save_game(player.save_state(), WaveManager.get_state())

func pause_game() -> void:
	if state == GameState.RUNNING:
		state = GameState.PAUSED
		get_tree().paused = true
		game_paused.emit()

func resume_game() -> void:
	if state == GameState.PAUSED:
		state = GameState.RUNNING
		pause_source = PauseSource.MANUAL
		get_tree().paused = false
		game_resumed.emit()

func trigger_game_over() -> void:
	if state != GameState.GAME_OVER:
		state = GameState.GAME_OVER
		get_tree().paused = true
		game_over.emit()

func add_kill() -> void:
	kill_count += 1
	score += 10
	enemy_killed.emit()

func add_score(amount: int) -> void:
	score += amount

func notify_player_damaged(current_hp: int, max_hp: int) -> void:
	player_damaged.emit(current_hp, max_hp)

func notify_player_leveled_up(level: int) -> void:
	player_leveled_up.emit(level)

func notify_player_xp_changed(current_xp: int, xp_to_next: int) -> void:
	player_xp_changed.emit(current_xp, xp_to_next)

func notify_experience_gained(amount: int) -> void:
	experience_gained.emit(amount)

func restart_game() -> void:
	_reset()
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit_to_menu() -> void:
	_reset()
	SaveManager.delete_save()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func return_to_menu() -> void:
	_reset()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _reset() -> void:
	state = GameState.RUNNING
	pause_source = PauseSource.MANUAL
	game_time = 0.0
	kill_count = 0
	score = 0
	auto_save_timer = 0.0
	WaveManager.reset()
