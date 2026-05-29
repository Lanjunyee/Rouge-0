extends Area2D

var damage: int = 10
var speed: float = 200.0
var direction: Vector2 = Vector2.ZERO
var lifetime: float = 5.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	var shape = CircleShape2D.new()
	shape.radius = 12.0
	$"CollisionShape2D".shape = shape

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody2D:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 12.0, Color(0.9, 0.2, 0.1))
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.3, 0.2))
