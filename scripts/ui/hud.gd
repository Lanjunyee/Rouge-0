extends CanvasLayer

@onready var hp_bar: ProgressBar = $"%HPBar"
@onready var xp_bar: ProgressBar = $"%XPBar"
@onready var hp_label: Label = $"%HPText"
@onready var xp_label: Label = $"%XPText"
@onready var level_label: Label = $"%LevelLabel"
@onready var time_label: Label = $"%TimeLabel"
@onready var kill_label: Label = $"%KillLabel"
@onready var pause_btn: Button = $"%PauseBtn"
@onready var joystick_draw: Control = $"%JoystickDraw"
var _player: Player = null
var _last_time: int = -1

func _ready() -> void:
	GameManager.player_damaged.connect(_on_player_damaged)
	GameManager.player_xp_changed.connect(_on_xp_changed)
	GameManager.player_leveled_up.connect(_on_level_up)
	GameManager.enemy_killed.connect(_on_kill)
	pause_btn.pressed.connect(_on_pause_pressed)
	joystick_draw.draw.connect(_on_joystick_draw)
	
	# Sync with current state (may already be restored from save)
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_on_player_damaged(_player.current_hp, _player.max_hp)
		_on_xp_changed(_player.current_xp, _player.xp_to_next)
		_on_level_up(_player.level)
	else:
		hp_bar.max_value = 100
		hp_bar.value = 100
		hp_label.text = "100/100"
		xp_bar.max_value = 30
		xp_bar.value = 0
		xp_label.text = "0/30"
		level_label.text = "Lv.1"
	kill_label.text = "击杀: %d" % GameManager.kill_count

func _process(_delta: float) -> void:
	if _player and (_player.move_joystick_active or _player.attack_joystick_active):
		joystick_draw.queue_redraw()
	if GameManager.state == GameManager.GameState.RUNNING:
		var t = int(GameManager.game_time)
		if t != _last_time:
			_last_time = t
			var mins = t / 60
			var secs = t % 60
			time_label.text = "%02d:%02d" % [mins, secs]

func _on_player_damaged(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, max_hp]

func _on_xp_changed(current_xp: int, xp_to_next: int) -> void:
	xp_bar.max_value = xp_to_next
	xp_bar.value = current_xp
	xp_label.text = "%d/%d" % [current_xp, xp_to_next]

func _on_level_up(level: int) -> void:
	level_label.text = "Lv.%d" % level

func _on_kill() -> void:
	kill_label.text = "击杀: %d" % GameManager.kill_count

func _on_joystick_draw() -> void:
	if not _player:
		return
	
	var radius = _player.joystick_radius
	
	# 左半屏 — 移动轮盘（蓝灰色）
	if _player.move_joystick_active:
		_draw_one_joystick(_player.move_joystick_center, radius, _player.move_joystick_direction,
			Color(0.35, 0.55, 0.85, 0.35), Color(0.35, 0.55, 0.85, 0.6))
	
	# 右半屏 — 攻击轮盘（金红色）
	if _player.attack_joystick_active:
		_draw_one_joystick(_player.attack_joystick_center, radius, _player.attack_joystick_direction,
			Color(0.9, 0.5, 0.2, 0.35), Color(0.9, 0.5, 0.2, 0.6))

func _draw_one_joystick(center: Vector2, radius: float, dir: Vector2, ring_color: Color, knob_color: Color) -> void:
	joystick_draw.draw_arc(center, radius, 0, TAU, 48, ring_color, 3.0)
	var knob_pos = center + dir * radius * 0.7
	joystick_draw.draw_circle(knob_pos, radius * 0.35, ring_color.darkened(0.15))
	joystick_draw.draw_circle(knob_pos, radius * 0.2, knob_color)

func _on_pause_pressed() -> void:
	GameManager.pause_game()
