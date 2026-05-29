extends Area2D

var damage: int = 10
var speed: float = 450.0
var direction: Vector2 = Vector2.ZERO
var bounces_left: int = 3
var bounce_range: float = 200.0
var damage_decay: float = 0.8
var hit_enemies: Array = []
var slow_enemies: bool = false
var slow_amount: float = 0.7
var slow_duration: float = 2.0
var lifetime: float = 3.0
var move_velocity: Vector2 = Vector2.ZERO
var _locked_target: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var shape = CircleShape2D.new()
	shape.radius = 6.0
	$"CollisionShape2D".shape = shape
	
	if not direction.is_zero_approx():
		move_velocity = direction * speed
	else:
		move_velocity = Vector2.RIGHT * speed


func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	
	# Lock onto nearest enemy — only re-select on spawn or target death
	if not is_instance_valid(_locked_target):
		_locked_target = _find_nearest_enemy()
	
	var current_dir = move_velocity.normalized() if not move_velocity.is_zero_approx() else direction
	if current_dir.is_zero_approx():
		current_dir = Vector2.RIGHT
	
	if is_instance_valid(_locked_target):
		var desired_dir = (_locked_target.global_position - global_position).normalized()
		var new_dir = current_dir.lerp(desired_dir, 20.0 * delta).normalized()
		move_velocity = new_dir * speed
	else:
		move_velocity = current_dir * speed
	
	position += move_velocity * delta
	queue_redraw()


func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = 9999.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


func _on_body_entered(body: Node2D) -> void:
	if body is StaticBody2D:
		queue_free()
		return
	
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		if body in hit_enemies:
			return
		
		hit_enemies.append(body)
		body.take_damage(damage)
		
		# Apply slow if mastery active
		if slow_enemies and "current_speed" in body:
			body.current_speed *= slow_amount
			var _body_ref = body  # capture for tween callback
			var tween = create_tween()
			tween.tween_callback(func():
				if is_instance_valid(_body_ref) and "current_speed" in _body_ref:
					_body_ref.current_speed /= slow_amount
			).set_delay(slow_duration)
		
		# Chain to next enemy if bounces remain
		if bounces_left > 0:
			_chain_to_next()
		
		queue_free()


func _chain_to_next() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist = bounce_range
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	
	if nearest:
		var bolt_scene = load("res://scenes/projectiles/lightning_bolt.tscn")
		var new_bolt = bolt_scene.instantiate()
		new_bolt.global_position = global_position
		new_bolt.damage = int(damage * damage_decay)
		new_bolt.bounces_left = bounces_left - 1
		new_bolt.hit_enemies = hit_enemies.duplicate()
		new_bolt.slow_enemies = slow_enemies
		new_bolt.slow_amount = slow_amount
		new_bolt.slow_duration = slow_duration
		new_bolt.direction = (nearest.global_position - global_position).normalized()
		var world = get_tree().current_scene
		if world:
			world.add_child(new_bolt)


func _draw() -> void:
	# Bright yellow core with glow
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.9, 0.15, 0.3))
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.8, 0.05))
	draw_circle(Vector2.ZERO, 2.5, Color(1.0, 1.0, 0.7))
	
	# Small trail opposite to movement
	if not move_velocity.is_zero_approx():
		var trail = -move_velocity.normalized() * 8.0
		draw_line(Vector2.ZERO, trail, Color(1.0, 0.85, 0.2, 0.5), 1.5)
