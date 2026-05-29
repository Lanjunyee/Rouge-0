extends CanvasLayer

@onready var panel: Panel = $"%Panel"
@onready var overlay: ColorRect = $"%Overlay"
@onready var bgm_slider: HSlider = $"%BgmSlider"
@onready var sfx_slider: HSlider = $"%SfxSlider"
@onready var bgm_value_label: Label = $"%BgmValue"
@onready var sfx_value_label: Label = $"%SfxValue"
@onready var fps_option: OptionButton = $"%FpsOption"
@onready var orientation_btn: Button = $"%OrientationBtn"
var _is_landscape: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	overlay.visible = false
	
	GameManager.game_paused.connect(_on_game_paused)
	GameManager.game_resumed.connect(_on_game_resumed)
	
	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	
	$"%ResumeBtn".pressed.connect(_on_resume_pressed)
	$"%RestartBtn".pressed.connect(_on_restart_pressed)
	$"%SaveQuitBtn".pressed.connect(_on_save_quit_pressed)
	
	fps_option.add_item("30", 0)
	fps_option.add_item("60", 1)
	fps_option.add_item("90", 2)
	fps_option.add_item("120", 3)
	fps_option.item_selected.connect(_on_fps_changed)
	orientation_btn.pressed.connect(_on_orientation_toggled)

func _on_game_paused() -> void:
	overlay.visible = true
	panel.visible = true
	# Sync sliders with current volumes
	bgm_slider.value = AudioManager.get_bgm_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()
	_select_fps_item(SaveManager.fps)
	_update_labels()

func _on_game_resumed() -> void:
	overlay.visible = false
	panel.visible = false

func _on_bgm_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)
	_update_labels()

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_update_labels()

func _update_labels() -> void:
	bgm_value_label.text = "%d%%" % int(bgm_slider.value * 100)
	sfx_value_label.text = "%d%%" % int(sfx_slider.value * 100)

func _on_resume_pressed() -> void:
	GameManager.resume_game()

func _on_restart_pressed() -> void:
	GameManager.resume_game()
	GameManager.restart_game()

func _on_fps_changed(idx: int) -> void:
	var vals = [30, 60, 90, 120]
	SaveManager.set_fps(vals[idx])

func _select_fps_item(target: int) -> void:
	for i in fps_option.item_count:
		if int(fps_option.get_item_text(i)) == target:
			fps_option.select(i)
			return

func _on_orientation_toggled() -> void:
	_is_landscape = not _is_landscape
	if _is_landscape:
		DisplayServer.screen_set_orientation(4)  # SCREEN_SENSOR_LANDSCAPE
		get_window().content_scale_size = Vector2(1280, 720)
		orientation_btn.text = "切换竖屏"
	else:
		DisplayServer.screen_set_orientation(5)  # SCREEN_SENSOR_PORTRAIT
		get_window().content_scale_size = Vector2(720, 1280)
		orientation_btn.text = "切换横屏"
	# 桌面端兜底：交换窗口尺寸
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		var win = get_window()
		var old = win.size
		win.size = Vector2(old.y, old.x)

func _on_save_quit_pressed() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		SaveManager.save_game(player.save_state(), WaveManager.get_state())
	GameManager.resume_game()
	GameManager.return_to_menu()
