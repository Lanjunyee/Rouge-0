extends BaseEnemy

## 治愈兵：每2秒移向敌人最密集处 → 周期性范围回血 → 红色光环显示
## 数值随难度（difficulty）增长
var base_heal_radius: float = 130.0         # 基础回血范围
var base_heal_amount: int = 3               # 基础每次回血量
var heal_interval: float = 1.5              # 回血间隔
var heal_timer: float = 0.0
var reposition_interval: float = 2.0        # 重新选位间隔
var reposition_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO # 目标移动位置
var min_player_dist: float = 150.0          # 与玩家的最小距离
var _difficulty: float = 1.0                # 难度系数
var _alpha: float = 0.0


func setup(difficulty: float = 1.0, elite: bool = false) -> void:
	super.setup(difficulty, elite)
	_difficulty = difficulty


func _ready() -> void:
	super._ready()
	_pick_dense_position()


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	if guard_idle:
		velocity = Vector2.ZERO
		return
	
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	if not player_ref or not player_ref.alive:
		velocity = Vector2.ZERO
		return
	
	# 每2秒重新选择敌人最密集位置
	reposition_timer += delta
	if reposition_timer >= reposition_interval:
		reposition_timer = 0.0
		_pick_dense_position()
	
	# 移向目标位置
	var to_target = target_position - global_position
	var dist_to_target = to_target.length()
	
	if dist_to_target > 20.0:
		var move_dir = to_target.normalized()
		
		# 不能离玩家太近：如果移向目标会让距离 < min_player_dist，则避开玩家
		var dist_to_player = global_position.distance_to(player_ref.global_position)
		var dir_to_player = (player_ref.global_position - global_position).normalized()
		
		if dist_to_player < min_player_dist:
			# 后退远离玩家
			velocity = -dir_to_player * current_speed
		else:
			# 正常移向目标，但如果目标方向会导致太靠近玩家则修正
			var next_pos = global_position + move_dir * current_speed * delta
			if next_pos.distance_to(player_ref.global_position) < min_player_dist:
				# 垂直于玩家方向滑开
				var perp = Vector2(dir_to_player.y, -dir_to_player.x)
				if perp.dot(move_dir) < 0:
					perp = -perp
				velocity = perp * current_speed
			else:
				velocity = move_dir * current_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# 回血（数值随难度增长）
	heal_timer += delta
	if heal_timer >= heal_interval:
		heal_timer = 0.0
		_heal_nearby_enemies()
	
	_alpha = move_toward(_alpha, 1.0, delta * 2.0)
	if _alpha > 0.01:
		queue_redraw()


func _pick_dense_position() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() <= 1:
		# 没有其他敌人，在玩家周围徘徊
		if player_ref:
			var offset = Vector2.RIGHT.rotated(randf() * TAU) * (min_player_dist + 100.0)
			target_position = player_ref.global_position + offset
		return
	
	# 找敌人最密集的位置：计算每个敌人的局部密度，选最高的
	var best_pos = global_position
	var best_density = 0
	var scan_radius = 200.0
	
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var count = 0
		for other in enemies:
			if other == enemy or not is_instance_valid(other):
				continue
			if enemy.global_position.distance_to(other.global_position) < scan_radius:
				count += 1
		if count > best_density:
			best_density = count
			best_pos = enemy.global_position
	
	target_position = best_pos


func _heal_nearby_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	# 回血量和范围随难度增长
	var effective_radius = base_heal_radius * (1.0 + (_difficulty - 1.0) * 0.3)
	var effective_amount = int(base_heal_amount * _difficulty)
	
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= effective_radius:
			if enemy.has_method("flash_heal"):
				enemy.current_hp = mini(enemy.current_hp + effective_amount, enemy.total_hp)
				enemy.flash_heal()


func _draw() -> void:
	if _alpha <= 0:
		return
	
	var effective_radius = base_heal_radius * (1.0 + (_difficulty - 1.0) * 0.3)
	var segments = 32
	var pulse = 1.0 + sin(GameManager.game_time * 3.0) * 0.08
	var r = effective_radius * pulse
	
	for i in range(segments):
		var a1 = i * TAU / segments
		var a2 = (i + 1) * TAU / segments
		var alpha = (0.08 + sin(GameManager.game_time * 2.0 + i * 0.5) * 0.03) * _alpha
		draw_colored_polygon(
			PackedVector2Array([Vector2.ZERO,
				Vector2.RIGHT.rotated(a1) * r,
				Vector2.RIGHT.rotated(a2) * r]),
			Color(1.0, 0.1, 0.1, alpha)
		)
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1.0, 0.15, 0.15, 0.35 * _alpha), 2.0)
