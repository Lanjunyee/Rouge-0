extends BaseWeapon

var projectile_scene: PackedScene = preload("res://scenes/projectiles/projectile.tscn")

var burst_count: int = 0
var burst_total: int = 1
var burst_timer: float = 0.0
var burst_direction: Vector2 = Vector2.ZERO
var mastery_explode: bool = false

func attack(direction: Vector2) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	burst_direction = direction
	
	# Only start a new burst when cooldown is ready
	if burst_count == 0 and cooldown_timer <= 0:
		burst_total = player_ref.projectile_count
		burst_count = burst_total
		burst_timer = 0.0
		var interval = (base_cooldown * cooldown_multiplier) / (1.0 + (level - 1) * 0.08)
		cooldown_timer = interval

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	# Ticking base cooldown
	cooldown_timer = max(0.0, cooldown_timer - delta)
	
	# Burst firing
	if burst_count > 0:
		var interval = (base_cooldown * cooldown_multiplier) / (1.0 + (level - 1) * 0.08) * 0.5 / max(1, burst_total)
		burst_timer += delta
		while burst_timer >= interval and burst_count > 0:
			burst_timer -= interval
			_fire(burst_direction)
			burst_count -= 1

func _fire(direction: Vector2) -> void:
	if not player_ref:
		return
	
	var proj = projectile_scene.instantiate()
	proj.global_position = player_ref.global_position
	proj.damage = get_current_damage()
	proj.speed = projectile_speed * (1.0 + (level - 1) * 0.1)
	proj.size_multiplier = player_ref.range_multiplier
	proj.explode = mastery_explode
	proj.direction = direction
	proj.use_direction = true
	
	var world = get_tree().current_scene
	if world:
		world.add_child(proj)
