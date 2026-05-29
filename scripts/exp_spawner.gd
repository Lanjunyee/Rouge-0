extends Node2D

@export var spawn_interval: float = 5.0
@export var gems_per_spawn: int = 3
@export var spawn_radius_min: float = 750.0
@export var spawn_radius_max: float = 1000.0
@export var xp_per_gem: int = 3

var timer: float = 0.0
var gem_scene: PackedScene = preload("res://scenes/pickups/exp_gem.tscn")

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	timer += delta
	if timer >= spawn_interval:
		timer -= spawn_interval
		spawn_gems()

func spawn_gems() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	var crit_chance = 0.1  # 固定 10% 暴击率
	
	for i in range(gems_per_spawn):
		var angle = randf() * TAU
		var dist = randf_range(spawn_radius_min, spawn_radius_max)
		var pos = player.global_position + Vector2.RIGHT.rotated(angle) * dist
		
		var gem = gem_scene.instantiate()
		gem.global_position = pos
		gem.is_large = randf() < crit_chance
		gem.xp_value = xp_per_gem
		gem.setup()
		get_tree().current_scene.add_child(gem)