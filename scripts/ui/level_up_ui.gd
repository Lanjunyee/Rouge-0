extends CanvasLayer

var upgrades: Array = []
var player_ref: Player = null
var active: bool = false

@onready var container: HBoxContainer = $"%Container"
@onready var button1: Button = $"%Btn1"
@onready var button2: Button = $"%Btn2"
@onready var button3: Button = $"%Btn3"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("level_up_ui")
	container.visible = false
	
	button1.pressed.connect(_on_btn1)
	button2.pressed.connect(_on_btn2)
	button3.pressed.connect(_on_btn3)

func show_upgrades() -> void:
	player_ref = get_tree().get_first_node_in_group("player") as Player
	if not player_ref:
		_resolve(false)
		return
	
	upgrades = DataManager.get_random_upgrades(3, player_ref)
	if upgrades.is_empty():
		_resolve(false)
		return
	
	active = true
	container.visible = true
	
	_setup_button(button1, 0)
	_setup_button(button2, 1)
	_setup_button(button3, 2)

func _setup_button(btn: Button, index: int) -> void:
	if index < upgrades.size():
		var upgrade = upgrades[index]
		btn.visible = true
		var level_text = ""
		if player_ref:
			var next_level = player_ref.upgrade_counts.get(upgrade.id, 0) + 1
			if next_level <= 10:
				level_text = " Lv.%d" % next_level
		btn.text = "%s%s\n%s" % [upgrade.name, level_text, upgrade.description]
		btn.modulate = upgrade.icon_color
	else:
		btn.visible = false

func _on_btn1() -> void:
	_apply_upgrade(0)

func _on_btn2() -> void:
	_apply_upgrade(1)

func _on_btn3() -> void:
	_apply_upgrade(2)

func _apply_upgrade(index: int) -> void:
	if index >= upgrades.size():
		return
	
	if player_ref:
		player_ref.apply_upgrade(upgrades[index])
	
	_resolve(true)

func _resolve(applied: bool) -> void:
	active = false
	container.visible = false
	container.modulate.a = 1.0
	if player_ref and player_ref.has_method("on_upgrade_resolved"):
		player_ref.on_upgrade_resolved(applied)
