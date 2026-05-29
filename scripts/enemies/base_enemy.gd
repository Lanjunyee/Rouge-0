extends CharacterBody2D

class_name BaseEnemy

signal enemy_died

const GEM_SCENE = preload("res://scenes/pickups/exp_gem.tscn")

@export var enemy_id: String = "slime"
var base_hp: int = 20
var base_speed: float = 80.0
var base_damage: int = 10
var base_exp_value: int = 5
var color: Color = Color(0.2, 0.8, 0.3)
var size: float = 14.0
var attack_cooldown: float = 0.8

var current_hp: int
var current_speed: float
var current_damage: int
var current_exp_value: int
var is_elite: bool = false
var guard_idle: bool = false
var guard_anchor: Vector2 = Vector2.ZERO
var attack_timer: float = 0.0
var player_ref: Player = null
var total_hp: int
@onready var body_sprite: Sprite2D = $BodySprite
@onready var face_sprite: Sprite2D = $FaceSprite

func _ready() -> void:
	add_to_group("enemies")

func setup(difficulty: float = 1.0, elite: bool = false) -> void:
	is_elite = elite
	
	var data = DataManager.get_enemy_data(enemy_id)
	if data:
		base_hp = data.hp
		base_speed = data.speed
		base_damage = data.damage
		base_exp_value = data.exp_value
		color = data.color
		size = data.size
	
	if is_elite:
		size *= 2.0
		color = Color(0.9, 0.25, 0.2)
		base_hp = int(base_hp * 3.5)
		base_speed *= 1.4
		base_damage = int(base_damage * 2.0)
		base_exp_value *= 3
	
	current_hp = int(base_hp * difficulty)
	total_hp = current_hp
	current_speed = base_speed * (1.0 + (difficulty - 1.0) * 0.2)
	current_damage = int(base_damage * difficulty)
	current_exp_value = int(base_exp_value * difficulty)
	
	var shape = CircleShape2D.new()
	shape.radius = size
	$"CollisionShape2D".shape = shape
	
	var s = size / 64.0
	if body_sprite:
		body_sprite.scale = Vector2(s, s)
	if face_sprite:
		face_sprite.scale = Vector2(s, s)

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.GameState.RUNNING:
		return
	
	if guard_idle:
		velocity = Vector2.ZERO
		return
	
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as Player
	
	if not player_ref or not player_ref.alive:
		return
	
	var player_pos = player_ref.global_position
	var direction = (player_pos - global_position).normalized()
	var contact_dist = size + 18.0
	var dist = global_position.distance_to(player_pos)
	
	# Stop moving when in contact range to prevent sticking
	var stop_dist = contact_dist + 5.0
	if dist > stop_dist:
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Recalculate distance after movement
	dist = global_position.distance_to(player_pos)
	
	# Damage at same range as stop (enemy in contact)
	if dist <= stop_dist + 1.0:
		if attack_timer <= 0:
			player_ref.take_damage(current_damage)
			attack_timer = attack_cooldown
	
	if attack_timer > 0:
		attack_timer -= delta

func take_damage(amount: int) -> void:
	current_hp -= amount
	_flash_color(Color.RED, 0.06)
	
	if current_hp <= 0:
		die()


## 被治愈时的绿色闪烁反馈（供 HealerEnemy 调用）
func flash_heal() -> void:
	_flash_color(Color.GREEN, 0.3)


func _flash_color(c: Color, duration: float) -> void:
	modulate = c
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, duration)

func die() -> void:
	enemy_died.emit()
	GameManager.add_kill()
	if is_elite:
		GameManager.add_score(20)
	AudioManager.play_sfx("kill.mp3", 0.85, 1.15)
	
	var gem = GEM_SCENE.instantiate()
	gem.global_position = global_position
	gem.xp_value = current_exp_value
	if is_elite:
		gem.xp_value *= 2
		gem.scale = Vector2.ONE * 1.6
	gem.setup()
	var world = get_tree().current_scene
	if world:
		world.add_child(gem)
	
	queue_free()
