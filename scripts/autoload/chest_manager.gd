extends Node

signal chest_spawned(chest_position: Vector2)
signal chest_collected

var chest_scene: PackedScene = preload("res://scenes/objects/treasure_chest.tscn")
var active_chest: Node2D = null
var active_chest_position: Vector2 = Vector2.ZERO

# Spawn probability — grows over time, resets after each spawn
var spawn_chance_base: float = 0.015
var spawn_chance_growth: float = 0.008  # per minute
var current_chance: float
var spawn_cooldown: float = 0.0
const MIN_SPAWN_INTERVAL: float = 30.0  # minimum seconds between chests

var _cached_player: Player = null
var _screen_diagonal: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset()


func reset() -> void:
	current_chance = spawn_chance_base
	spawn_cooldown = 0.0
	active_chest = null
	active_chest_position = Vector2.ZERO


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	# Don't spawn if a chest is already active
	if is_instance_valid(active_chest):
		return
	
	spawn_cooldown = max(0.0, spawn_cooldown - delta)
	if spawn_cooldown > 0:
		return
	
	_cached_player = get_tree().get_first_node_in_group("player") as Player
	if not _cached_player:
		return
	
	if _screen_diagonal <= 0:
		var vs = get_viewport().get_visible_rect().size
		_screen_diagonal = sqrt(vs.x * vs.x + vs.y * vs.y)
	
	# Grow spawn chance over time
	current_chance += spawn_chance_growth / 60.0 * delta
	
	# Roll for spawn
	if randf() < current_chance * delta:
		_spawn_chest()


func _spawn_chest() -> void:
	if not _cached_player:
		return
	
	# Reset chance after spawn
	current_chance = spawn_chance_base
	spawn_cooldown = MIN_SPAWN_INTERVAL
	
	# Pick position outside player view (screen diagonal distance away)
	var angle = randf() * TAU
	var dist = _screen_diagonal * 0.7 + randf() * _screen_diagonal * 0.3
	var pos = _cached_player.global_position + Vector2.RIGHT.rotated(angle) * dist
	
	var chest = chest_scene.instantiate()
	chest.global_position = pos
	var world = get_tree().current_scene
	if world:
		world.add_child(chest)
	
	active_chest = chest
	active_chest_position = pos
	chest_spawned.emit(pos)


func get_direction_to_chest(from_pos: Vector2) -> Vector2:
	if not is_instance_valid(active_chest):
		return Vector2.ZERO
	return (active_chest.global_position - from_pos).normalized()


func on_chest_collected() -> void:
	active_chest = null
	active_chest_position = Vector2.ZERO
	chest_collected.emit()
