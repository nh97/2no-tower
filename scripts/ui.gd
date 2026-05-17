extends CanvasLayer

var _money_label: Label
var _lives_label: Label
var _wave_label: Label
var _message_label: Label
var _message_container: CenterContainer
var _restart_button: Button
var _tower_buttons: Array[Button] = []
var _boss_container: CenterContainer
var _boss_bar: ProgressBar
var _boss_label: Label
var _sell_container: CenterContainer
var _sell_confirm_btn: Button
var _difficulty_container: CenterContainer

func _ready() -> void:
	_build_hud()
	GameManager.money_changed.connect(_on_money_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.selected_tower_changed.connect(_on_selected_tower_changed)
	GameManager.sell_request_changed.connect(_on_sell_request_changed)
	GameManager.boss_appeared.connect(_on_boss_appeared)
	GameManager.boss_hp_changed.connect(_on_boss_hp_changed)
	GameManager.boss_defeated.connect(_on_boss_defeated)
	_on_money_changed(GameManager.money)
	_on_lives_changed(GameManager.lives)
	_on_wave_changed(GameManager.wave)
	_on_state_changed(GameManager.state)
	_on_selected_tower_changed(GameManager.selected_tower_kind)

func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	# Top bar: money / lives / wave
	var top_bar := HBoxContainer.new()
	top_bar.name = "TopBar"
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 20
	top_bar.offset_top = 16
	top_bar.offset_right = -20
	top_bar.offset_bottom = 56
	top_bar.add_theme_constant_override("separation", 40)
	hud.add_child(top_bar)

	_money_label = _make_label("Money: 0", 24)
	_lives_label = _make_label("Lives: 0", 24)
	_wave_label = _make_label("Wave: 0", 24)
	top_bar.add_child(_money_label)
	top_bar.add_child(_lives_label)
	top_bar.add_child(_wave_label)

	# Bottom bar: tower selection
	var bottom_bar := HBoxContainer.new()
	bottom_bar.name = "TowerBar"
	bottom_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_bar.offset_left = -400
	bottom_bar.offset_right = 400
	bottom_bar.offset_top = -110
	bottom_bar.offset_bottom = -20
	bottom_bar.add_theme_constant_override("separation", 16)
	hud.add_child(bottom_bar)

	for k in Tower.Kind.values():
		var btn := _make_tower_button(k)
		bottom_bar.add_child(btn)
		_tower_buttons.append(btn)

	# Center message + restart button
	_message_container = CenterContainer.new()
	_message_container.name = "MessageContainer"
	_message_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_container.visible = false
	hud.add_child(_message_container)

	var msg_box := VBoxContainer.new()
	msg_box.alignment = BoxContainer.ALIGNMENT_CENTER
	msg_box.add_theme_constant_override("separation", 20)
	_message_container.add_child(msg_box)

	_message_label = _make_label("", 72)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_box.add_child(_message_label)

	_restart_button = Button.new()
	_restart_button.text = "リスタート"
	_restart_button.custom_minimum_size = Vector2(180, 60)
	_restart_button.add_theme_font_size_override("font_size", 22)
	_restart_button.pressed.connect(_on_restart_pressed)
	msg_box.add_child(_restart_button)

	_build_boss_bar(hud)
	_build_sell_popup(hud)
	_build_difficulty_popup(hud)

func _build_boss_bar(parent: Control) -> void:
	_boss_container = CenterContainer.new()
	_boss_container.name = "BossBar"
	_boss_container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_container.offset_top = 60
	_boss_container.offset_bottom = 110
	_boss_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_container.visible = false
	parent.add_child(_boss_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	_boss_container.add_child(vbox)

	_boss_label = _make_label("BOSS  0 / 0", 18)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_boss_label)

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(420, 18)
	_boss_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.9, 0.2, 0.2)
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.05, 0.05, 0.85)
	bg.set_corner_radius_all(4)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	_boss_bar.add_theme_stylebox_override("background", bg)
	vbox.add_child(_boss_bar)

func _build_sell_popup(parent: Control) -> void:
	_sell_container = CenterContainer.new()
	_sell_container.name = "SellPopup"
	_sell_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sell_container.visible = false
	parent.add_child(_sell_container)

	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	pstyle.border_color = Color(0.95, 0.85, 0.3)
	pstyle.set_border_width_all(3)
	pstyle.set_corner_radius_all(10)
	pstyle.content_margin_left = 24
	pstyle.content_margin_right = 24
	pstyle.content_margin_top = 18
	pstyle.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", pstyle)
	_sell_container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var title := _make_label("塔を売却しますか?", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	_sell_confirm_btn = Button.new()
	_sell_confirm_btn.text = "売却 +0G"
	_sell_confirm_btn.custom_minimum_size = Vector2(150, 50)
	_sell_confirm_btn.add_theme_font_size_override("font_size", 18)
	_sell_confirm_btn.pressed.connect(func() -> void: GameManager.confirm_sell())
	hbox.add_child(_sell_confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "キャンセル"
	cancel_btn.custom_minimum_size = Vector2(120, 50)
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.pressed.connect(func() -> void: GameManager.cancel_sell())
	hbox.add_child(cancel_btn)

func _build_difficulty_popup(parent: Control) -> void:
	_difficulty_container = CenterContainer.new()
	_difficulty_container.name = "DifficultyPopup"
	_difficulty_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_difficulty_container.visible = false
	parent.add_child(_difficulty_container)

	var panel := PanelContainer.new()
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	pstyle.border_color = Color(0.5, 0.85, 1.0)
	pstyle.set_border_width_all(3)
	pstyle.set_corner_radius_all(10)
	pstyle.content_margin_left = 32
	pstyle.content_margin_right = 32
	pstyle.content_margin_top = 24
	pstyle.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", pstyle)
	_difficulty_container.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var title := _make_label("難易度を選択", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(hbox)

	for d in GameManager.Difficulty.values():
		var cfg: Dictionary = GameManager.DIFFICULTY_CONFIG[d]
		var btn := Button.new()
		btn.text = "%s\nG %d  Life %d\n敵HP×%.1f" % [cfg.label, cfg.money, cfg.lives, cfg.hp_mult]
		btn.custom_minimum_size = Vector2(170, 110)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(func() -> void: GameManager.start_game(d))
		hbox.add_child(btn)

func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	return l

func _make_tower_button(kind: int) -> Button:
	var cfg: Dictionary = Tower.CONFIG[kind]
	var btn := Button.new()
	btn.text = "%s\n%dG" % [cfg.label, cfg.cost]
	btn.custom_minimum_size = Vector2(140, 80)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func() -> void: GameManager.select_tower(kind))
	return btn

func _on_money_changed(value: int) -> void:
	_money_label.text = "G: %d" % value

func _on_lives_changed(value: int) -> void:
	_lives_label.text = "Life: %d" % value

func _on_wave_changed(value: int) -> void:
	_wave_label.text = "Wave: %d / %d" % [value, GameManager.TOTAL_WAVES]

func _on_state_changed(new_state: int) -> void:
	_difficulty_container.visible = (new_state == GameManager.State.SELECTING_DIFFICULTY)
	match new_state:
		GameManager.State.GAME_OVER:
			_show_message("GAME OVER", Color(1, 0.4, 0.4))
		GameManager.State.VICTORY:
			_show_message("VICTORY!", Color(0.9, 0.9, 0.4))
		_:
			_message_container.visible = false

func _on_selected_tower_changed(kind: int) -> void:
	for i in _tower_buttons.size():
		var b: Button = _tower_buttons[i]
		if i == kind:
			b.add_theme_color_override("font_color", Color(1, 0.92, 0.4))
			b.add_theme_stylebox_override("normal", _make_selected_stylebox())
			b.add_theme_stylebox_override("hover", _make_selected_stylebox())
			b.add_theme_stylebox_override("pressed", _make_selected_stylebox())
		else:
			b.remove_theme_color_override("font_color")
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_stylebox_override("pressed")

func _make_selected_stylebox() -> StyleBoxFlat:
	var sbf := StyleBoxFlat.new()
	sbf.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	sbf.border_color = Color(1, 0.92, 0.4)
	sbf.set_border_width_all(3)
	sbf.set_corner_radius_all(8)
	return sbf

func _show_message(text: String, color: Color) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", color)
	_message_container.visible = true

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_sell_request_changed(slot: PlacementSlot, refund: int) -> void:
	if slot == null:
		_sell_container.visible = false
	else:
		_sell_confirm_btn.text = "売却 +%dG" % refund
		_sell_container.visible = true

func _on_boss_appeared(max_hp: int) -> void:
	_boss_bar.max_value = max_hp
	_boss_bar.value = max_hp
	_boss_label.text = "BOSS  %d / %d" % [max_hp, max_hp]
	_boss_container.visible = true

func _on_boss_hp_changed(hp: int, max_hp: int) -> void:
	_boss_bar.value = hp
	_boss_label.text = "BOSS  %d / %d" % [hp, max_hp]

func _on_boss_defeated() -> void:
	_boss_container.visible = false
