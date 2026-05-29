extends BaseWeapon

var damage_tick_timer: float = 0.0
var damage_tick_interval: float = 0.4
var bodies_in_range: Array[Node2D] = []
var mastery_slow: bool = false
var _cached_shape: CircleShape2D

@onready var garlic_area: Area2D = $"GarlicArea"

func _ready() -> void:
	z_index = -1
	if garlic_area:
		garlic_area.body_entered.connect(_on_body_entered_garlic)
		garlic_area.body_exited.connect(_on_body_exited_garlic)
	_update_radius()

func _process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	if player_ref:
		global_position = player_ref.global_position
	
	super._process(delta)
	
	var effective_interval = damage_tick_interval / max(1, (player_ref.projectile_count if player_ref else 1))
	damage_tick_timer += delta
	if damage_tick_timer >= effective_interval:
		damage_tick_timer = 0.0
		for body in bodies_in_range:
			if is_instance_valid(body) and body.has_method("take_damage"):
				body.take_damage(get_current_damage())
	
	queue_redraw()

# Garlic doesn't use directional attack — persistent aura
func _do_attack(_direction: Vector2) -> void:
	pass

func upgrade(new_level: int) -> void:
	level = new_level
	_update_radius()

func _update_radius() -> void:
	var radius = (108.0 + (level - 1) * 10.0) * (player_ref.range_multiplier if player_ref else 1.0)
	if garlic_area:
		if not _cached_shape:
			_cached_shape = CircleShape2D.new()
		_cached_shape.radius = radius
		$"GarlicArea/CollisionShape2D".shape = _cached_shape

func _on_body_entered_garlic(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		bodies_in_range.append(body)
		if mastery_slow:
			body.current_speed *= 0.7

func _on_body_exited_garlic(body: Node2D) -> void:
	bodies_in_range.erase(body)
	if mastery_slow:
		body.current_speed /= 0.7

func _draw() -> void:
	var radius = (108.0 + (level - 1) * 10.0) * (player_ref.range_multiplier if player_ref else 1.0)
	var segments = 16
	for i in range(segments):
		var a1 = i * TAU / segments
		var a2 = (i + 1) * TAU / segments
		var alpha = 0.15 + sin(GameManager.game_time * 2.0 + i * 0.5) * 0.05
		draw_colored_polygon(
			PackedVector2Array([Vector2.ZERO,
				Vector2.RIGHT.rotated(a1) * radius,
				Vector2.RIGHT.rotated(a2) * radius]),
			Color(0.2, 0.9, 0.2, alpha)
		)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.3, 1.0, 0.3, 0.4), 2.0)
