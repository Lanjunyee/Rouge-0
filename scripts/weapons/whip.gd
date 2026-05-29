extends BaseWeapon

var is_swinging: bool = false
var swing_timer: float = 0.0
var swing_duration: float = 0.25
var current_swing_angle: float = 0.0
var swing_radius: float = 80.0
var mastery_lifesteal: bool = false
var _cached_shape: CircleShape2D

# ── 多次攻击：在冷却间隔的前半段分批挥击 ──
var _multi_count: int = 0
var _multi_total: int = 1
var _multi_timer: float = 0.0
var _multi_interval: float = 0.0
var _swing_dir: Vector2 = Vector2.RIGHT
var _hit_bodies: Array[Node2D] = []

@onready var whip_area: Area2D = $"WhipArea"

func _ready() -> void:
	if whip_area:
		whip_area.monitoring = false
		whip_area.body_entered.connect(_on_whip_hit)

func _do_attack(direction: Vector2) -> void:
	if is_swinging or _multi_count > 0 or not player_ref:
		return
	
	_swing_dir = direction
	_multi_total = player_ref.projectile_count if player_ref else 1
	_multi_count = _multi_total - 1
	
	# 冷却前半段内均分所有攻击次数
	var cooldown = (base_cooldown * cooldown_multiplier) / (1.0 + (level - 1) * 0.08)
	_multi_interval = cooldown * 0.5 / float(_multi_total)
	_multi_timer = _multi_interval
	
	_start_swing(direction)

func _start_swing(direction: Vector2) -> void:
	_hit_bodies.clear()
	is_swinging = true
	swing_timer = 0.0
	swing_radius = (126.0 + (level - 1) * 12.0) * player_ref.range_multiplier
	
	current_swing_angle = direction.angle()
	
	if whip_area:
		whip_area.global_position = player_ref.global_position + direction * swing_radius * 0.5
		if not _cached_shape:
			_cached_shape = CircleShape2D.new()
		_cached_shape.radius = swing_radius * 0.6
		$"WhipArea/CollisionShape2D".shape = _cached_shape
		whip_area.monitoring = true

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	# ── 多次挥击调度 ──
	if _multi_count > 0:
		_multi_timer -= delta
		if _multi_timer <= 0:
			_multi_count -= 1
			_multi_timer += _multi_interval
			_start_swing(_swing_dir)
	
	if is_swinging:
		swing_timer += delta
		if swing_timer >= swing_duration:
			is_swinging = false
			if whip_area:
				whip_area.monitoring = false
		queue_redraw()
	else:
		super._process(delta)

func _on_whip_hit(body: Node2D) -> void:
	if not body.is_in_group("enemies") or not body.has_method("take_damage"):
		return
	
	# 每次挥击内每个敌人只命中一次
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)
	
	var dmg = get_current_damage()
	body.take_damage(dmg)
	
	# 精通：造成伤害的 10% 转化为生命回复
	if mastery_lifesteal and player_ref:
		var heal = int(dmg * 0.1)
		if heal > 0:
			player_ref.current_hp = mini(player_ref.current_hp + heal, player_ref.max_hp)
			player_ref.hp_changed.emit(player_ref.current_hp, player_ref.max_hp)
			GameManager.notify_player_damaged(player_ref.current_hp, player_ref.max_hp)

func _draw() -> void:
	if not is_swinging or not player_ref:
		return
	
	var progress = swing_timer / swing_duration
	var alpha = 1.0 - progress
	var local_center = to_local(player_ref.global_position)
	
	draw_arc(local_center, swing_radius * 0.7,
		current_swing_angle - 0.7, current_swing_angle + 0.7,
		12, Color(1.0, 0.75, 0.15, alpha * 0.5), 4.0)
	draw_arc(local_center, swing_radius * 0.7,
		current_swing_angle - 0.7, current_swing_angle + 0.7,
		12, Color(1.0, 0.9, 0.5, alpha), 2.0)