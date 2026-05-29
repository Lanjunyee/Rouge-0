extends Node

@export var base_spawn_interval: float = 2.5
@export var min_spawn_interval: float = 0.15
@export var spawn_interval_decay: float = 0.92
@export var max_enemies: int = 200
@export var spawn_distance: float = 800.0

# Wave system
@export var wave_interval: float = 60.0
var next_wave_time: float = 180.0
var wave_active: bool = false
var wave_ring_count: int = 0
var wave_ring_spawned: int = 0
var wave_ring_delay: float = 0.8
var wave_ring_timer: float = 0.0
var enemies_per_ring: int = 15

var enemy_scene: PackedScene = preload("res://scenes/enemies/base_enemy.tscn")
var ranged_enemy_scene: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")
var charger_enemy_scene: PackedScene = preload("res://scenes/enemies/charger_enemy.tscn")
var bomber_enemy_scene: PackedScene = preload("res://scenes/enemies/bomber_enemy.tscn")
var healer_enemy_scene: PackedScene = preload("res://scenes/enemies/healer_enemy.tscn")
var spawn_timer: float = 0.0
var current_enemy_count: int = 0
var difficulty_multiplier: float = 1.0
var elite_chance: float = 0.0
var screen_size: Vector2
var _cached_player: Node2D = null
var _cached_interval: float = 0.0
var _last_minute: int = -1
var _wave_ring_index: int = 0


func reset() -> void:
	spawn_timer = 0.0
	current_enemy_count = 0
	difficulty_multiplier = 1.0
	elite_chance = 0.0
	next_wave_time = wave_interval
	wave_active = false
	wave_ring_spawned = 0
	wave_ring_timer = 0.0
	wave_ring_count = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen_size = get_viewport().get_visible_rect().size

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	_cached_player = get_tree().get_first_node_in_group("player")
	
	var minutes = GameManager.game_time / 60.0
	difficulty_multiplier = pow(1.08, minutes)
	elite_chance = max(0.0, (minutes - 1.0) * 0.06)
	
	var minute_int = int(minutes)
	if minute_int != _last_minute:
		_last_minute = minute_int
		_cached_interval = max(min_spawn_interval,
			base_spawn_interval * pow(spawn_interval_decay, minutes))
	
	# Wave system
	if GameManager.game_time >= next_wave_time and not wave_active:
		_trigger_wave()
	
	if wave_active:
		# Ring in progress: spawn batch immediately each frame
		if _wave_ring_index > 0 and current_enemy_count < max_enemies:
			_spawn_wave_ring()
			if _wave_ring_index >= enemies_per_ring:
				_wave_ring_index = 0
				wave_ring_spawned += 1
				wave_ring_timer = 0.0
				if wave_ring_spawned >= wave_ring_count:
					wave_active = false
					next_wave_time += wave_interval
		else:
			wave_ring_timer += delta
			if wave_ring_timer >= wave_ring_delay and current_enemy_count < max_enemies:
				_spawn_wave_ring()  # starts first batch, sets _wave_ring_index > 0
	
	# Normal spawning (slower during waves)
	var spawn_modifier = 0.3 if wave_active else 1.0
	var current_interval = _cached_interval / spawn_modifier
	
	spawn_timer += delta
	if spawn_timer >= current_interval and current_enemy_count < max_enemies:
		spawn_timer = 0.0
		spawn_enemy()
		if difficulty_multiplier > 2.0 and randf() < 0.3:
			spawn_enemy()

func _trigger_wave() -> void:
	wave_active = true
	wave_ring_count = max(1, int(GameManager.game_time / 60.0))
	wave_ring_spawned = 0
	wave_ring_timer = 0.0
	_wave_ring_index = 0

func _spawn_wave_ring() -> void:
	if not _cached_player:
		return
	
	var ring_radius = sqrt(screen_size.x * screen_size.x + screen_size.y * screen_size.y) * 0.55
	var batch = mini(_wave_ring_index + 5, enemies_per_ring)
	
	var is_last_ring = GameManager.game_time >= 120.0 and wave_ring_spawned == wave_ring_count - 1
	
	for i in range(_wave_ring_index, batch):
		var angle = (float(i) / enemies_per_ring) * TAU + randf() * 0.3
		var pos = _cached_player.global_position + Vector2.RIGHT.rotated(angle) * ring_radius
		
		var enemy = ranged_enemy_scene.instantiate() if is_last_ring else _pick_enemy_scene().instantiate()
		enemy.global_position = pos
		enemy.setup(difficulty_multiplier, randf() < elite_chance)
		
		var world = get_tree().current_scene
		if world:
			world.add_child(enemy)
		
		current_enemy_count += 1
		enemy.tree_exiting.connect(_on_enemy_removed, CONNECT_ONE_SHOT)
	
	_wave_ring_index = batch

func spawn_enemy() -> void:
	if not _cached_player:
		return
	
	var enemy = _pick_enemy_scene().instantiate()
	enemy.global_position = _get_spawn_position(_cached_player.global_position)
	enemy.setup(difficulty_multiplier, randf() < elite_chance)
	
	var world = get_tree().current_scene
	if world:
		world.add_child(enemy)
	
	current_enemy_count += 1
	enemy.tree_exiting.connect(_on_enemy_removed)

func _pick_enemy_scene() -> PackedScene:
	var roll = randf()
	if roll < 0.04:
		return ranged_enemy_scene
	if roll < 0.10:
		return charger_enemy_scene
	if roll < 0.17:
		return bomber_enemy_scene
	if roll < 0.21:
		return healer_enemy_scene
	return enemy_scene

func _get_spawn_position(player_pos: Vector2) -> Vector2:
	var angle = randf() * TAU
	var dist = spawn_distance + randf() * 200.0
	return player_pos + Vector2.RIGHT.rotated(angle) * dist

func _on_enemy_removed() -> void:
	current_enemy_count = max(0, current_enemy_count - 1)

# ── 存档序列化 ───────────────────────────────────

func get_state() -> Dictionary:
	return {
		"difficulty_multiplier": difficulty_multiplier,
		"elite_chance": elite_chance,
		"next_wave_time": next_wave_time,
		"current_enemy_count": current_enemy_count,
	}

func restore_state(data: Dictionary) -> void:
	difficulty_multiplier = data.get("difficulty_multiplier", 1.0)
	elite_chance = data.get("elite_chance", 0.0)
	next_wave_time = data.get("next_wave_time", wave_interval)
	current_enemy_count = data.get("current_enemy_count", 0)
	spawn_timer = 0.0
	wave_active = false