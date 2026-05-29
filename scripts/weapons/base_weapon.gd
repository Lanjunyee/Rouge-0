extends Node2D

class_name BaseWeapon

var weapon_id: String = ""
var level: int = 1
var base_damage: int = 10
var base_cooldown: float = 1.0
var base_range: float = 200.0
var display_name: String = ""
var icon_color: Color = Color.WHITE
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var range_multiplier: float = 1.0
var projectile_speed: float = 300.0
var cooldown_timer: float = 0.0
var player_ref: Player = null

func setup(weapon_level: int, dmg_mult: float = 1.0, cd_mult: float = 1.0, rng_mult: float = 1.0) -> void:
	level = weapon_level
	damage_multiplier = dmg_mult
	cooldown_multiplier = cd_mult
	range_multiplier = rng_mult
	
	var data = DataManager.get_weapon_data(weapon_id)
	if data:
		base_damage = data.base_damage
		base_cooldown = data.base_cooldown
		base_range = data.base_range
		display_name = data.display_name
		icon_color = data.icon_color
		projectile_speed = data.projectile_speed
	
	player_ref = get_tree().get_first_node_in_group("player") as Player

func upgrade(new_level: int) -> void:
	level = new_level

func update_multipliers(dmg_mult: float, cd_mult: float, rng_mult: float = 1.0) -> void:
	damage_multiplier = dmg_mult
	cooldown_multiplier = cd_mult
	range_multiplier = rng_mult

func _process(delta: float) -> void:
	cooldown_timer = max(0.0, cooldown_timer - delta)

func attack(direction: Vector2) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	if cooldown_timer > 0:
		return
	
	cooldown_timer = base_cooldown * cooldown_multiplier / (1.0 + (level - 1) * 0.08)
	_do_attack(direction)

func _do_attack(_direction: Vector2) -> void:
	pass

func get_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null
	
	var nearest: Node2D = null
	var nearest_dist = base_range * range_multiplier
	
	for enemy in enemies:
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	return nearest

func get_current_damage() -> int:
	return int(base_damage * damage_multiplier * (1.0 + (level - 1) * 0.10))