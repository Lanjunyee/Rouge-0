extends BaseWeapon

var bolt_scene: PackedScene = preload("res://scenes/projectiles/lightning_bolt.tscn")
var mastery_bounces: bool = false
var mastery_slow: bool = false

# Burst firing — projectile_count support
var burst_count: int = 0
var burst_total: int = 1
var burst_timer: float = 0.0


var burst_direction: Vector2 = Vector2.ZERO


func attack(direction: Vector2) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	burst_direction = direction
	
	if burst_count == 0 and cooldown_timer <= 0:
		burst_total = player_ref.projectile_count
		burst_count = burst_total
		burst_timer = 0.0
		var interval = (base_cooldown * cooldown_multiplier) / (1.0 + (level - 1) * 0.08)
		cooldown_timer = interval


func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	cooldown_timer = max(0.0, cooldown_timer - delta)
	
	if burst_count > 0:
		var interval = (base_cooldown * cooldown_multiplier) / (1.0 + (level - 1) * 0.08) * 0.5 / max(1, burst_total)
		burst_timer += delta
		while burst_timer >= interval and burst_count > 0:
			burst_timer -= interval
			_do_attack(burst_direction)
			burst_count -= 1


func _do_attack(dir: Vector2) -> void:
	if not player_ref:
		return
	
	if not get_nearest_enemy():
		return
	
	var bolt = bolt_scene.instantiate()
	bolt.global_position = player_ref.global_position
	bolt.damage = int(get_current_damage() * 0.5)
	bolt.speed = projectile_speed * (1.0 + (level - 1) * 0.08) * 3.0
	bolt.direction = dir
	
	# Base bounces: 3, mastery doubles to 6
	bolt.bounces_left = 6 if mastery_bounces else 3
	
	# Slow on hit if mastery
	bolt.slow_enemies = mastery_slow
	
	var world = get_tree().current_scene
	if world:
		world.add_child(bolt)
