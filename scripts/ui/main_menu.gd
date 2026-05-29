extends Control

@onready var continue_btn: Button = $"%ContinueBtn"
@onready var best_label: Label = $"%BestLabel"
@onready var settings_panel: Panel = $"%SettingsPanel"
@onready var bgm_slider: HSlider = $"%BgmSlider"
@onready var sfx_slider: HSlider = $"%SfxSlider"
@onready var bgm_value: Label = $"%BgmValue"
@onready var sfx_value: Label = $"%SfxValue"
@onready var fps_option: OptionButton = $"%FpsOption"
@onready var orientation_btn: Button = $"%OrientationBtn"
@onready var weapon_select_panel: Panel = $"%WeaponSelectPanel"
@onready var weapon_grid: GridContainer = $"%WeaponGrid"
@onready var start_btn: Button = $"%WeaponSelectPanel/WeaponSelectVBox/StartBtn"
@onready var back_btn: Button = $"%WeaponSelectPanel/WeaponSelectVBox/BackBtn"
var _is_landscape: bool = false
var _selected_weapon_id: String = ""
var _weapon_cards: Dictionary = {}  # weapon_id → Button
var _card_normal_style: StyleBoxFlat
var _card_selected_style: StyleBoxFlat

func _ready() -> void:
	settings_panel.visible = false
	weapon_select_panel.visible = false
	
	# 武器卡片样式
	_card_normal_style = StyleBoxFlat.new()
	_card_normal_style.bg_color = Color(0.141, 0.141, 0.165, 1)
	_card_normal_style.set_corner_radius_all(4)
	_card_normal_style.border_width_left = 2
	_card_normal_style.border_width_right = 2
	_card_normal_style.border_width_top = 2
	_card_normal_style.border_width_bottom = 2
	_card_normal_style.border_color = Color(0.25, 0.25, 0.3, 1)
	
	_card_selected_style = StyleBoxFlat.new()
	_card_selected_style.bg_color = Color(0.18, 0.18, 0.22, 1)
	_card_selected_style.set_corner_radius_all(4)
	_card_selected_style.border_width_left = 2
	_card_selected_style.border_width_right = 2
	_card_selected_style.border_width_top = 2
	_card_selected_style.border_width_bottom = 2
	_card_selected_style.border_color = Color(0.831, 0.702, 0.196, 1)  # 金色高亮
	
	_build_weapon_cards()
	
	var score = SaveManager.high_score
	var kills = SaveManager.total_kills
	if score > 0 or kills > 0:
		var t = SaveManager.total_play_time
		var h = int(t / 3600)
		var m = int(t / 60) % 60
		var s = int(t) % 60
		var time_str = "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]
		best_label.text = "最高分 %d  ·  击杀 %d  ·  %s" % [score, kills, time_str]
	else:
		best_label.visible = false

	var preview = SaveManager.get_save_preview()
	if preview.is_empty():
		continue_btn.disabled = true
	else:
		continue_btn.text = preview

	$"VBoxContainer/NewGameBtn".pressed.connect(_on_new_game_btn)
	continue_btn.pressed.connect(_on_continue)
	$"VBoxContainer/SettingsBtn".pressed.connect(_on_settings)
	$"VBoxContainer/QuitBtn".pressed.connect(_on_quit)
	
	start_btn.pressed.connect(_on_start_game)
	back_btn.pressed.connect(_on_back_from_weapon_select)

	bgm_slider.value_changed.connect(_on_bgm_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	$"SettingsPanel/SettingsVBox/CloseSettingsBtn".pressed.connect(_on_close_settings)
	
	fps_option.add_item("30", 0)
	fps_option.add_item("60", 1)
	fps_option.add_item("90", 2)
	fps_option.add_item("120", 3)
	_select_fps_item(SaveManager.fps)
	fps_option.item_selected.connect(_on_fps_changed)
	orientation_btn.pressed.connect(_on_orientation_toggled)

func _on_new_game_btn() -> void:
	# 显示武器选择面板，默认选中魔杖
	_selected_weapon_id = ""
	start_btn.disabled = true
	_clear_all_highlights()
	# 自动选中魔杖（与之前默认行为一致）
	var default_id = DataManager.characters.get("default", {}).get("starting_weapon", "magic_wand")
	_on_weapon_card_pressed(_weapon_cards.get(default_id), default_id)
	weapon_select_panel.visible = true

func _on_start_game() -> void:
	if _selected_weapon_id.is_empty():
		return
	SaveManager.selected_weapon = _selected_weapon_id
	weapon_select_panel.visible = false
	_on_new_game()

func _on_new_game() -> void:
	SaveManager.delete_save()
	SaveManager.pending_load = {}
	GameManager._reset()
	WaveManager.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_from_weapon_select() -> void:
	weapon_select_panel.visible = false

# ── 武器选择面板 ──────────────────────────────────

func _build_weapon_cards() -> void:
	var placeholder_tex = _create_placeholder_texture()
	for child in weapon_grid.get_children():
		child.queue_free()
	_weapon_cards.clear()
	
	for weapon_id in DataManager.weapons:
		var wdata: Dictionary = DataManager.weapons[weapon_id]
		var card = Button.new()
		card.custom_minimum_size = Vector2(130, 130)
		card.add_theme_stylebox_override("normal", _card_normal_style)
		card.add_theme_stylebox_override("hover", _card_normal_style)
		card.add_theme_stylebox_override("pressed", _card_selected_style)
		card.focus_mode = Control.FOCUS_NONE
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		# 武器图片占位 — 后续替换为 load("res://resources/weapons/{id}.png")
		var img_rect = TextureRect.new()
		img_rect.name = "WeaponImage"
		img_rect.custom_minimum_size = Vector2(56, 56)
		img_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img_rect.texture = placeholder_tex
		img_rect.self_modulate = wdata.get("icon_color", Color.WHITE)
		vbox.add_child(img_rect)
		
		var name_label = Label.new()
		name_label.text = wdata.get("display_name", weapon_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92, 1))
		name_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(name_label)
		
		var desc_label = Label.new()
		desc_label.text = wdata.get("description", "")
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_color_override("font_color", Color(0.588, 0.588, 0.627, 1))
		desc_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(desc_label)
		
		card.add_child(vbox)
		card.pressed.connect(_on_weapon_card_pressed.bind(card, weapon_id))
		
		weapon_grid.add_child(card)
		_weapon_cards[weapon_id] = card

func _create_placeholder_texture() -> ImageTexture:
	var img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _on_weapon_card_pressed(card: Button, weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	start_btn.disabled = false
	_clear_all_highlights()
	_highlight_card(card)

func _clear_all_highlights() -> void:
	for card in _weapon_cards.values():
		card.add_theme_stylebox_override("normal", _card_normal_style)

func _highlight_card(card: Button) -> void:
	card.add_theme_stylebox_override("normal", _card_selected_style)

func _on_continue() -> void:
	var save = SaveManager.load_game()
	if save.is_empty():
		return
	SaveManager.pending_load = save
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings() -> void:
	settings_panel.visible = true
	bgm_slider.value = AudioManager.get_bgm_volume()
	sfx_slider.value = AudioManager.get_sfx_volume()
	_update_labels()

func _on_close_settings() -> void:
	settings_panel.visible = false

func _on_bgm_changed(value: float) -> void:
	AudioManager.set_bgm_volume(value)
	_update_labels()

func _on_sfx_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)
	_update_labels()

func _update_labels() -> void:
	bgm_value.text = "%d%%" % int(bgm_slider.value * 100)
	sfx_value.text = "%d%%" % int(sfx_slider.value * 100)

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

func _on_quit() -> void:
	get_tree().quit()
