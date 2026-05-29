extends Area2D

var xp_value: int = 5
var is_large: bool = false
var magnet_speed: float = 300.0
var player_ref: Player = null
var attracted: bool = false
var lifetime: float = 30.0
var bob_offset: float = 0.0
var bob_speed: float = 3.0
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	bob_offset = randf() * TAU
	# setup() 由 spawner 在设置 is_large/xp_value 后调用

func setup() -> void:
	if is_large:
		xp_value *= 3
		scale = Vector2.ONE * 1.8
	var shape = CircleShape2D.new()
	shape.radius = 10.0 if is_large else 8.0
	$"CollisionShape2D".shape = shape

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()
		return
	
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	if player_ref and player_ref.alive:
		var dist = global_position.distance_to(player_ref.global_position)
		var magnet_range = player_ref.pickup_radius * 1.5
		
		if dist < magnet_range:
			attracted = true
		
		if attracted:
			var dir = (player_ref.global_position - global_position).normalized()
			var spd = magnet_speed * (1.0 + (magnet_range - dist) / magnet_range)
			position += dir * spd * delta
	
	if sprite:
		sprite.position.y = sin(GameManager.game_time * bob_speed + bob_offset) * 2.0

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.alive:
		body.gain_exp(xp_value)
		AudioManager.play_sfx("pickup.mp3", 0.9, 1.1)
		queue_free()

