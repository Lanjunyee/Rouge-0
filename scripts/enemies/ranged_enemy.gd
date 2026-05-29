extends BaseEnemy

const PROJECTILE_SCENE = preload("res://scenes/enemies/enemy_projectile.tscn")

var shoot_timer: float = 0.0
var base_shoot_cooldown: float = 5.0
var min_shoot_cooldown: float = 1.0
var preferred_distance: float = 350.0
var facing_direction: Vector2 = Vector2.DOWN

# setup() 在 _ready() 之前调用，所以此处不用 @onready；
# _ready() 中统一获取引用
var sprite: Sprite2D


func _ready() -> void:
	super._ready()
	sprite = $Sprite2D
	sprite.rotation = facing_direction.angle() - PI / 2.0


func setup(difficulty: float = 1.0, elite: bool = false) -> void:
	super.setup(difficulty, elite)
	# setup() 在节点入树前调用，直接通过路径获取 Sprite2D
	var spr = $Sprite2D
	var s = size / 64.0
	spr.scale = Vector2(s, s)
	spr.rotation = facing_direction.angle() - PI / 2.0


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
	facing_direction = direction
	sprite.rotation = direction.angle() - PI / 2.0
	var dist = global_position.distance_to(player_pos)
	
	# Maintain distance: move away if too close, move closer if too far
	if dist < preferred_distance - 100.0:
		velocity = -direction * current_speed * 0.6
	elif dist > preferred_distance + 100.0:
		velocity = direction * current_speed
	else:
		velocity = Vector2.ZERO
	
	move_and_slide()
	
	# Shoot — 随时间推移攻速越来越快
	var current_cooldown = max(min_shoot_cooldown, base_shoot_cooldown - GameManager.game_time * 0.03)
	shoot_timer += delta
	if shoot_timer >= current_cooldown:
		shoot_timer = 0.0
		_shoot(direction)


func _shoot(dir: Vector2) -> void:
	var proj = PROJECTILE_SCENE.instantiate()
	proj.global_position = global_position
	proj.damage = current_damage
	proj.direction = dir
	var world = get_tree().current_scene
	if world:
		world.add_child(proj)


func _draw() -> void:
	pass  # 已改用 Sprite2D 图像素材，空壳防止基类绘制
