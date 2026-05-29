extends CanvasLayer

@onready var panel: Panel = $"Panel"
@onready var time_label: Label = $"Panel/VBoxContainer/TimeLabel"
@onready var kill_label: Label = $"Panel/VBoxContainer/KillLabel"
@onready var level_label: Label = $"Panel/VBoxContainer/LevelLabel"
@onready var menu_button: Button = $"Panel/VBoxContainer/MenuButton"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	GameManager.game_over.connect(_on_game_over)
	menu_button.pressed.connect(_on_menu_pressed)

func _on_game_over() -> void:
	panel.visible = true
	SaveManager.record_game_over(GameManager.score, GameManager.kill_count, GameManager.game_time)
	
	var player = get_tree().get_first_node_in_group("player")
	var final_level = 1
	if player:
		final_level = player.level
	
	var t = GameManager.game_time
	var mins = int(t / 60.0)
	var secs = int(t) % 60
	
	time_label.text = "存活时间: %02d:%02d" % [mins, secs]
	kill_label.text = "击杀数: %d" % GameManager.kill_count
	level_label.text = "最终等级: %d" % final_level

func _on_menu_pressed() -> void:
	GameManager.quit_to_menu()
