extends BaseEnemy

## 自爆兵：出生即冲锋 → 追踪玩家 5 秒 → 自爆造成范围伤害
var charge_speed_mult: float = 2.8          # 冲刺速度倍率
var explosion_radius: float = 72.0          # 爆炸范围
var explosion_damage_mult: float = 2.5      # 爆炸伤害倍率
var charge_duration: float = 5.0            # 冲锋持续时间
var charge_timer: float = 0.0
var current_dir: Vector2 = Vector2.ZERO     # 当前移动方向（用于平滑追踪）
var is_dead: bool = false


func _ready() -> void:
	super._ready()
	# 出生即开始冲锋
	_start_charge()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
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
	
	charge_timer += delta
	
	# 追踪玩家方向（力度减半：lerp 平滑转向）
	var target_dir = (player_ref.global_position - global_position).normalized()
	if current_dir.length() < 0.01:
		current_dir = target_dir
	else:
		current_dir = lerp(current_dir, target_dir, 0.5).normalized()
	velocity = current_dir * current_speed * charge_speed_mult
	move_and_slide()
	
	# 撞墙 → 自爆
	for i in get_slide_collision_count():
		var collider = get_slide_collision(i).get_collider()
		if collider is StaticBody2D:
			_detonate()
			return
	
	# 接近玩家 → 自爆
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= size + explosion_radius * 0.5:
			_detonate()
			return
	
	# 冲锋超时 → 强制自爆
	if charge_timer >= charge_duration:
		_detonate()
		return


func _start_charge() -> void:
	charge_timer = 0.0
	# 初始方向指向玩家
	if player_ref:
		current_dir = (player_ref.global_position - global_position).normalized()
	modulate = Color(1.0, 0.2, 0.1)


func _detonate() -> void:
	if is_dead:
		return
	is_dead = true
	
	# 范围爆炸伤害
	if player_ref:
		var dist = global_position.distance_to(player_ref.global_position)
		if dist <= explosion_radius:
			var dmg = int(current_damage * explosion_damage_mult)
			# 距离越近伤害越高（衰减到 60%）
			var falloff = 1.0 - (dist / explosion_radius) * 0.4
			player_ref.take_damage(int(dmg * falloff))
	
	# 正常死亡流程（掉落经验、计数、音效）
	die()
