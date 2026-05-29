extends Area2D

var guard_activation_range: float = 200.0
var guards: Array[Node] = []
var collected: bool = false

const RANGED_ENEMY_SCENE = preload("res://scenes/enemies/ranged_enemy.tscn")
const CHARGER_ENEMY_SCENE = preload("res://scenes/enemies/charger_enemy.tscn")
const SLIME_ENEMY_SCENE = preload("res://scenes/enemies/base_enemy.tscn")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	# Collision shape
	var shape = CircleShape2D.new()
	shape.radius = 28.0
	$CollisionShape2D.shape = shape
	
	_spawn_guards()
	
	# Start inactive — guards don't chase until player enters range
	set_process(true)


func _process(_delta: float) -> void:
	if collected:
		return
	
	# Activate guards when player enters activation range
	var player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		return
	
	var dist = global_position.distance_to(player.global_position)
	if dist <= guard_activation_range:
		for guard in guards:
			if is_instance_valid(guard) and "guard_idle" in guard:
				guard.guard_idle = false


func _spawn_guards() -> void:
	var player = get_tree().get_first_node_in_group("player") as Player
	var difficulty = 1.0
	if player:
		difficulty = pow(1.08, GameManager.game_time / 60.0)
	
	# 1 elite slime (the charger) + 2 ranged enemies
	var world = get_tree().current_scene
	if not world:
		return
	
	var offsets = [
		Vector2(60, 0),
		Vector2(-40, -50),
		Vector2(-40, 50),
	]
	
	# Elite guard (charger enemy as melee elite)
	var elite = CHARGER_ENEMY_SCENE.instantiate()
	elite.global_position = global_position + offsets[0]
	elite.setup(difficulty, true)
	elite.guard_idle = true
	elite.guard_anchor = global_position
	world.add_child(elite)
	guards.append(elite)
	
	# 2 ranged guards
	for i in range(1, 3):
		var ranged = RANGED_ENEMY_SCENE.instantiate()
		ranged.global_position = global_position + offsets[i]
		ranged.setup(difficulty, false)
		ranged.guard_idle = true
		ranged.guard_anchor = global_position
		world.add_child(ranged)
		guards.append(ranged)


func _on_body_entered(body: Node2D) -> void:
	if collected:
		return
	if not body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return
	
	collected = true
	
	var player = body as Player
	# Restore 20% max HP
	player.current_hp = mini(player.max_hp, player.current_hp + int(player.max_hp * 0.2))
	player.hp_changed.emit(player.current_hp, player.max_hp)
	
	# Grant one level-up reward
	player.pending_level_ups += 1
	
	# Notify ChestManager
	ChestManager.on_chest_collected()
	
	# Clean up guards
	for guard in guards:
		if is_instance_valid(guard):
			guard.queue_free()
	guards.clear()
	
	queue_free()


func _draw() -> void:
	# Treasure chest visual — simple box with gold trim
	var chest_color = Color(0.35, 0.22, 0.08)
	var trim_color = Color(0.85, 0.7, 0.13)
	
	# Lid
	var lid_pts = PackedVector2Array()
	lid_pts.append(Vector2(-18, -16))
	lid_pts.append(Vector2(18, -16))
	lid_pts.append(Vector2(20, -12))
	lid_pts.append(Vector2(-20, -12))
	draw_colored_polygon(lid_pts, chest_color.lightened(0.2))
	draw_polyline(lid_pts, trim_color, 2.0, true)
	
	# Base
	var base_pts = PackedVector2Array()
	base_pts.append(Vector2(-18, -12))
	base_pts.append(Vector2(18, -12))
	base_pts.append(Vector2(16, 4))
	base_pts.append(Vector2(-16, 4))
	draw_colored_polygon(base_pts, chest_color)
	draw_polyline(base_pts, trim_color, 2.0, true)
	
	# Lock / highlight
	draw_circle(Vector2(0, -4), 4.0, trim_color)
	draw_rect(Rect2(Vector2(-3, -3), Vector2(6, 6)), Color.BLACK, false, 1.0)
	
	# Golden sparkle
	draw_circle(Vector2(0, -12), 2.5, Color(1.0, 0.95, 0.4))
