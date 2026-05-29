extends Area2D

var damage: int = 10
var speed: float = 300.0
var target: Node2D = null
var direction: Vector2 = Vector2.ZERO
var use_direction: bool = false
var size_multiplier: float = 1.0
var explode: bool = false
var explode_radius: float = 60.0
var explode_damage: float = 0.5
var lifetime: float = 5.0
var homing_strength: float = 6.0
var move_velocity: Vector2 = Vector2.ZERO
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var shape = CircleShape2D.new()
	shape.radius = 10.0 * size_multiplier
	$"CollisionShape2D".shape = shape

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	
	if use_direction and not direction.is_zero_approx():
		move_velocity = direction * speed
	elif is_instance_valid(target):
		var desired_dir = (target.global_position - global_position).normalized()
		var current_dir = move_velocity.normalized() if not move_velocity.is_zero_approx() else Vector2.RIGHT
		var new_dir = current_dir.lerp(desired_dir, homing_strength * delta).normalized()
		move_velocity = new_dir * speed
	else:
		if move_velocity.is_zero_approx():
			move_velocity = Vector2.RIGHT * speed
	
	position += move_velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		if explode:
			_explode()
		queue_free()
	elif body is StaticBody2D:
		queue_free()

func _explode() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= explode_radius and enemy.has_method("take_damage"):
			enemy.take_damage(int(damage * explode_damage))
