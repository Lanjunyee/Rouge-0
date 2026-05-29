extends Node2D

const MAX_OBSTACLES: int = 15
const SPAWN_DISTANCE: float = 800.0
const CULL_DISTANCE: float = 1000.0
const CHECK_INTERVAL: float = 5.0

var obstacle_scene: PackedScene = preload("res://scenes/obstacles/obstacle.tscn")
var obstacles: Array[Node2D] = []
var timer: float = 0.0
var player_ref: Node2D = null

func _ready() -> void:
	player_ref = get_tree().get_first_node_in_group("player")
	_spawn_initial()

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	timer += delta
	if timer >= CHECK_INTERVAL:
		timer = 0.0
		_cull_and_spawn()

func _spawn_initial() -> void:
	for i in range(MAX_OBSTACLES):
		_spawn_one()

func _cull_and_spawn() -> void:
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return
	
	var to_remove: Array = []
	for obs in obstacles:
		if not is_instance_valid(obs):
			to_remove.append(obs)
			continue
		var dist = obs.global_position.distance_squared_to(player_ref.global_position)
		if dist > CULL_DISTANCE * CULL_DISTANCE:
			to_remove.append(obs)
	
	for obs in to_remove:
		obstacles.erase(obs)
		if is_instance_valid(obs):
			obs.queue_free()
	
	while obstacles.size() < MAX_OBSTACLES:
		_spawn_one()

func _spawn_one() -> void:
	if not player_ref:
		return
	
	var obs = obstacle_scene.instantiate()
	var angle = randf() * TAU
	var dist = SPAWN_DISTANCE + randf() * 400.0
	obs.global_position = player_ref.global_position + Vector2.RIGHT.rotated(angle) * dist
	add_child(obs)
	obstacles.append(obs)
