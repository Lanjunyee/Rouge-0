extends CharacterBody2D

class_name Player

signal hp_changed(current_hp: int, max_hp: int)
signal xp_changed(current_xp: int, xp_to_next: int)
signal level_up(level: int)
signal died

@export var move_speed: float = 200.0
@export var max_hp: int = 100
@export var pickup_radius: float = 80.0
@export var damage_multiplier: float = 1.0
@export var cooldown_multiplier: float = 1.0
@export var range_multiplier: float = 1.0
var projectile_count: int = 1

var current_hp: int
var current_xp: int = 0
var xp_to_next: int = 30
var level: int = 1
var weapons: Array[Node] = []
var weapon_levels: Dictionary = {}
var alive: bool = true
var invincible: bool = false
var invincible_timer: float = 0.0
var invincible_duration: float = 1.0
# ── 双摇杆：移动（左半屏）+ 攻击（右半屏） ──
var move_joystick_active: bool = false
var move_joystick_center: Vector2 = Vector2.ZERO
var move_joystick_direction: Vector2 = Vector2.ZERO
var move_touch_index: int = -1

var attack_joystick_active: bool = false
var attack_joystick_center: Vector2 = Vector2.ZERO
var attack_joystick_direction: Vector2 = Vector2.ZERO
var attack_touch_index: int = -1

var joystick_radius: float = 80.0
var facing_direction: Vector2 = Vector2.RIGHT
var pending_level_ups: int = 0
var upgrade_active: bool = false
var upgrade_counts: Dictionary = {}

# Chest alert
var _chest_alert_active: bool = false
var _chest_alert_flash_count: int = 0
var _chest_alert_timer: float = 0.0
var _chest_alert_visible: bool = true
const CHEST_ALERT_FLASH_INTERVAL: float = 0.2
const CHEST_ALERT_FLASH_TOTAL: int = 6  # 3 on/off cycles

@onready var weapon_container: Node2D = $"WeaponContainer"
@onready var hand_sprite: Sprite2D = $"HandSprite"

func _ready() -> void:
	add_to_group("player")
	current_hp = max_hp
	
	ChestManager.chest_spawned.connect(_on_chest_spawned)
	ChestManager.chest_collected.connect(_on_chest_collected)
	
	if not SaveManager.pending_load.is_empty():
		_restore_from_save()
	else:
		add_starting_weapon()

func add_starting_weapon() -> void:
	var weapon_id = SaveManager.selected_weapon
	if weapon_id.is_empty():
		weapon_id = "magic_wand"  # 兜底
	add_weapon(weapon_id)
	SaveManager.selected_weapon = ""  # 用完清理
	AudioManager.play_bgm("res://resources/audio/bgm/bgm_loop.ogg")

func _restore_from_save() -> void:
	var save = SaveManager.pending_load
	restore_state(save.get("player", {}))
	WaveManager.restore_state(save.get("wave", {}))
	GameManager.game_time = save.get("game_time", 0.0)
	GameManager.kill_count = save.get("kill_count", 0)
	SaveManager.pending_load = {}
	AudioManager.play_bgm("res://resources/audio/bgm/bgm_loop.ogg")

func _input(event: InputEvent) -> void:
	if not alive or GameManager.state != GameManager.GameState.RUNNING:
		return
	
	if event is InputEventScreenTouch:
		var half_width = get_viewport().get_visible_rect().size.x / 2.0
		if event.pressed:
			if event.position.x < half_width:
				# 左半屏 → 移动轮盘
				move_joystick_active = true
				move_joystick_center = event.position
				move_joystick_direction = Vector2.ZERO
				move_touch_index = event.index
			else:
				# 右半屏 → 攻击轮盘
				attack_joystick_active = true
				attack_joystick_center = event.position
				attack_joystick_direction = Vector2.ZERO
				attack_touch_index = event.index
		else:
			if event.index == move_touch_index:
				move_joystick_active = false
				move_joystick_direction = Vector2.ZERO
				move_touch_index = -1
			if event.index == attack_touch_index:
				attack_joystick_active = false
				attack_joystick_direction = Vector2.ZERO
				attack_touch_index = -1
	
	elif event is InputEventScreenDrag:
		if event.index == move_touch_index:
			var offset = event.position - move_joystick_center
			if offset.length() > joystick_radius:
				offset = offset.normalized() * joystick_radius
			move_joystick_direction = offset / joystick_radius
		elif event.index == attack_touch_index:
			var offset = event.position - attack_joystick_center
			if offset.length() > joystick_radius:
				offset = offset.normalized() * joystick_radius
			attack_joystick_direction = offset / joystick_radius

func _physics_process(delta: float) -> void:
	if not alive or GameManager.state != GameManager.GameState.RUNNING:
		return
	
	# ── 移动方向（左轮盘优先，键盘兜底） ──
	var move_dir = Vector2.ZERO
	if move_joystick_active and move_joystick_direction.length() > 0.1:
		move_dir = move_joystick_direction
	else:
		move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	velocity = move_dir * move_speed
	move_and_slide()
	
	# ── 攻击方向（右轮盘优先，移动方向兜底） ──
	var attack_dir = move_dir
	if attack_joystick_active and attack_joystick_direction.length() > 0.1:
		attack_dir = attack_joystick_direction
	
	if attack_dir.length() > 0.1:
		facing_direction = attack_dir.normalized()
	
	# 手部围绕玩家，指向攻击方向
	if hand_sprite:
		var hand_orbit: float = 34.0
		hand_sprite.position = facing_direction * hand_orbit
		hand_sprite.rotation = facing_direction.angle() + deg_to_rad(38)
	
	for weapon in weapons:
		weapon.attack(facing_direction)
	
	if invincible:
		invincible_timer -= delta
		if invincible_timer <= 0:
			invincible = false
		modulate.a = 0.4 if fmod(invincible_timer * 10, 1.0) < 0.5 else 1.0
	else:
		modulate.a = 1.0
	
	# Chest alert flash timer
	if _chest_alert_active:
		_chest_alert_timer -= delta
		if _chest_alert_timer <= 0:
			_chest_alert_timer = CHEST_ALERT_FLASH_INTERVAL
			_chest_alert_visible = not _chest_alert_visible
			_chest_alert_flash_count += 1
			if _chest_alert_flash_count >= CHEST_ALERT_FLASH_TOTAL:
				_chest_alert_active = false
	
	queue_redraw()
	
	if pending_level_ups > 0 and not upgrade_active:
		_show_upgrade()

func take_damage(amount: int) -> void:
	if not alive or invincible:
		return
	
	current_hp -= amount
	hp_changed.emit(current_hp, max_hp)
	GameManager.notify_player_damaged(current_hp, max_hp)
	AudioManager.play_sfx("hit.wav", 0.9, 1.1)
	
	if current_hp <= 0:
		current_hp = 0
		die()
	else:
		invincible = true
		invincible_timer = invincible_duration

func die() -> void:
	alive = false
	died.emit()
	AudioManager.play_sfx("hit.wav", 0.5, 0.6)
	AudioManager.stop_bgm()
	GameManager.trigger_game_over()

func gain_exp(amount: int) -> void:
	current_xp += amount
	GameManager.notify_experience_gained(amount)
	
	while current_xp >= xp_to_next:
		current_xp -= xp_to_next
		level_up_player()
	
	xp_changed.emit(current_xp, xp_to_next)
	GameManager.notify_player_xp_changed(current_xp, xp_to_next)

func level_up_player() -> void:
	level += 1
	xp_to_next = level * level + 30
	level_up.emit(level)
	GameManager.notify_player_leveled_up(level)
	AudioManager.play_sfx("level_up.mp3", 1.0, 1.0, -8.0)
	pending_level_ups += 1

func add_weapon(weapon_id: String) -> void:
	if weapon_levels.has(weapon_id):
		weapon_levels[weapon_id] += 1
		for weapon in weapons:
			if weapon.weapon_id == weapon_id:
				weapon.upgrade(weapon_levels[weapon_id])
				return
	else:
		weapon_levels[weapon_id] = 1
		if not upgrade_counts.has(weapon_id):
			upgrade_counts[weapon_id] = 1
		var weapon_scene_path = "res://scenes/weapons/" + weapon_id + ".tscn"
		var weapon_scene = load(weapon_scene_path)
		if weapon_scene:
			var weapon = weapon_scene.instantiate()
			weapon.weapon_id = weapon_id
			weapon_container.add_child(weapon)
			weapons.append(weapon)
			weapon.setup(1, damage_multiplier, cooldown_multiplier, range_multiplier)

func get_weapon_level(weapon_id: String) -> int:
	return weapon_levels.get(weapon_id, 0)

func apply_upgrade(upgrade: Dictionary) -> void:
	var id = upgrade.id
	var count = upgrade_counts.get(id, 0)
	if count >= 10:
		return
	upgrade_counts[id] = count + 1
	var new_count = count + 1
	
	match upgrade.type:
		"weapon":
			add_weapon(upgrade.id)
			if new_count == 10:
				_apply_weapon_mastery(id)
		"stat":
			match upgrade.id:
				"max_hp":
					max_hp += upgrade.value
					current_hp = mini(current_hp + upgrade.value, max_hp)
					hp_changed.emit(current_hp, max_hp)
					GameManager.notify_player_damaged(current_hp, max_hp)
				"move_speed":
					move_speed *= upgrade.value
				"damage":
					damage_multiplier *= upgrade.value
					for weapon in weapons:
						weapon.update_multipliers(damage_multiplier, cooldown_multiplier, range_multiplier)
				"cooldown":
					cooldown_multiplier *= upgrade.value
					for weapon in weapons:
						weapon.update_multipliers(damage_multiplier, cooldown_multiplier, range_multiplier)
				"range":
					range_multiplier *= upgrade.value
					for weapon in weapons:
						weapon.update_multipliers(damage_multiplier, cooldown_multiplier, range_multiplier)
				"projectile_count":
					projectile_count += upgrade.value

func _show_upgrade() -> void:
	var ui = get_tree().get_first_node_in_group("level_up_ui")
	if ui and ui.has_method("show_upgrades"):
		upgrade_active = true
		ui.show_upgrades()

func on_upgrade_resolved(_applied: bool) -> void:
	pending_level_ups = max(0, pending_level_ups - 1)
	upgrade_active = false

func _apply_weapon_mastery(weapon_id: String) -> void:
	match weapon_id:
		"magic_wand":
			for w in weapons:
				if w.weapon_id == "magic_wand":
					w.mastery_explode = true
		"whip":
			for w in weapons:
				if w.weapon_id == "whip":
					w.mastery_lifesteal = true
		"garlic":
			for w in weapons:
				if w.weapon_id == "garlic":
					w.mastery_slow = true
		"thunder_rod":
			for w in weapons:
				if w.weapon_id == "thunder_rod":
					w.mastery_bounces = true
					w.mastery_slow = true

func _on_chest_spawned(_pos: Vector2) -> void:
	_chest_alert_active = true
	_chest_alert_flash_count = 0
	_chest_alert_timer = CHEST_ALERT_FLASH_INTERVAL
	_chest_alert_visible = true


func _on_chest_collected() -> void:
	_chest_alert_active = false


func update_display() -> void:
	queue_redraw()

func _draw() -> void:
	# Chest alert — flashing exclamation above hat
	if _chest_alert_active and _chest_alert_visible:
		var alert_color = Color(1.0, 0.85, 0.15)
		var ex = Vector2(0, -54)
		draw_circle(ex, 8.0, alert_color.darkened(0.3))
		draw_circle(ex, 6.5, alert_color)
		# "!" stem
		draw_rect(Rect2(ex.x - 2, ex.y - 4, 4, 7), Color.BLACK)
		# "!" dot
		draw_rect(Rect2(ex.x - 2, ex.y + 4, 4, 2), Color.BLACK)
	
	# Direction arrow toward chest — orbits player, always points to chest
	if is_instance_valid(ChestManager.active_chest):
		var dir = (ChestManager.active_chest.global_position - global_position).normalized()
		var orbit_dist = 55.0
		var arrow_size = 16.0
		var perp = Vector2(dir.y, -dir.x)
		var base = dir * orbit_dist
		
		var arrow_pts = PackedVector2Array()
		arrow_pts.append(base + dir * arrow_size)
		arrow_pts.append(base - dir * arrow_size * 0.35 + perp * arrow_size * 0.55)
		arrow_pts.append(base - dir * arrow_size * 0.35 - perp * arrow_size * 0.55)
		
		var arrow_color = Color(1.0, 0.85, 0.15, 0.9)
		draw_colored_polygon(arrow_pts, arrow_color)
		draw_polyline(arrow_pts, Color.BLACK, 1.0, true)

# ── 存档序列化 ───────────────────────────────────

func save_state() -> Dictionary:
	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"current_xp": current_xp,
		"xp_to_next": xp_to_next,
		"level": level,
		"weapon_levels": weapon_levels.duplicate(true),
		"damage_multiplier": damage_multiplier,
		"cooldown_multiplier": cooldown_multiplier,
		"range_multiplier": range_multiplier,
		"move_speed": move_speed,
		"pickup_radius": pickup_radius,
		"projectile_count": projectile_count,
		"upgrade_counts": upgrade_counts.duplicate(true),
	}

func restore_state(data: Dictionary) -> void:
	current_hp = data.get("current_hp", max_hp)
	max_hp = data.get("max_hp", max_hp)
	current_xp = data.get("current_xp", 0)
	xp_to_next = data.get("xp_to_next", 30)
	level = data.get("level", 1)
	damage_multiplier = data.get("damage_multiplier", 1.0)
	cooldown_multiplier = data.get("cooldown_multiplier", 1.0)
	range_multiplier = data.get("range_multiplier", 1.0)
	move_speed = data.get("move_speed", 200.0)
	pickup_radius = data.get("pickup_radius", 80.0)
	projectile_count = data.get("projectile_count", 1)
	upgrade_counts = data.get("upgrade_counts", {}).duplicate(true)
	if data.has("pos_x"):
		global_position = Vector2(data.pos_x, data.pos_y)
	
	# Rebuild weapons from saved levels
	var saved_levels: Dictionary = data.get("weapon_levels", {})
	for w in weapons:
		w.queue_free()
	weapons.clear()
	weapon_levels = saved_levels.duplicate(true)
	for wid in weapon_levels:
		_add_weapon_instance(wid, weapon_levels[wid])
	
	hp_changed.emit(current_hp, max_hp)
	xp_changed.emit(current_xp, xp_to_next)
	GameManager.notify_player_damaged(current_hp, max_hp)
	GameManager.notify_player_xp_changed(current_xp, xp_to_next)

func _add_weapon_instance(weapon_id: String, weapon_level: int) -> void:
	var weapon_scene_path = "res://scenes/weapons/" + weapon_id + ".tscn"
	var weapon_scene = load(weapon_scene_path)
	if weapon_scene:
		var weapon = weapon_scene.instantiate()
		weapon.weapon_id = weapon_id
		weapon_container.add_child(weapon)
		weapons.append(weapon)
		weapon.setup(weapon_level, damage_multiplier, cooldown_multiplier, range_multiplier)