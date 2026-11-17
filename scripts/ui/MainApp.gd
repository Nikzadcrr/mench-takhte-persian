extends Control

var _lobby_root: Control
var _active_game: Control = null

# Lobby dynamic refs
var _profile_lbl: Label
var _coins_lbl: Label
var _backdrop_pivot: Node3D
var _lobby_vp: SubViewport

# Mobile Tab Navigation
var _tab_pages := {}
var _nav_buttons := {}
var _active_tab := "play"

# Game Config Selectors
var _mench_players_opt: OptionButton
var _mench_mode_opt: OptionButton
var _mench_diff_opt: OptionButton
var _takhte_mode_opt: OptionButton
var _takhte_diff_opt: OptionButton
var _profile_stats_lbl: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeHelper.get_theme()
	_build_mobile_lobby()
	GameState.profile_updated.connect(_refresh_profile_ui)
	_refresh_profile_ui()
	_switch_tab("play")


func _build_mobile_lobby() -> void:
	_lobby_root = Control.new()
	_lobby_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_lobby_root)

	# 1. AAA 3D Lounge Backdrop
	_build_3d_lobby_backdrop(_lobby_root)

	# Rich warm vignette veil
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.045, 0.025, 0.018, 0.60)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby_root.add_child(veil)

	# 2. Mobile Vertical App Shell (Top Bar | Tab Content | Bottom Nav Bar)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_lobby_root.add_child(margin)

	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	margin.add_child(shell)

	shell.add_child(_build_mobile_top_bar())

	# Tab Content Host
	var content_host := Control.new()
	content_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(content_host)

	var play_page := _build_play_tab()
	var lb_page := LeaderboardModal.new()
	lb_page.embed_mode = true
	var chat_page := ChatPanel.new()
	var profile_page := _build_profile_tab()

	var pages := {
		"play": play_page,
		"leaderboard": lb_page,
		"chat": chat_page,
		"profile": profile_page,
	}
	for k in pages:
		var ctrl: Control = pages[k]
		ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content_host.add_child(ctrl)
		_tab_pages[k] = ctrl

	chat_page.setup("lobby", false)

	# Bottom Mobile Navigation Dock
	shell.add_child(_build_bottom_nav_bar())


func _build_mobile_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 56)
	ThemeHelper.style_card(bar, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD_DIM, 16)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	bar.add_child(hb)

	var rules_btn := Button.new()
	rules_btn.text = "📖"
	rules_btn.tooltip_text = "راهنمای قوانین"
	rules_btn.custom_minimum_size = Vector2(40, 38)
	rules_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		_open_rules_modal()
	)
	hb.add_child(rules_btn)

	var coin_pill := PanelContainer.new()
	coin_pill.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.22, 0.16, 0.08, 0.92), ThemeHelper.COL_GOLD, 1, 12, 10, 4))
	_coins_lbl = ThemeHelper.make_label("🪙 ۱۲۵۰", 14, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	coin_pill.add_child(_coins_lbl)
	hb.add_child(coin_pill)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)

	_profile_lbl = ThemeHelper.make_label("بازیکن پارسی 👑", 15, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	hb.add_child(_profile_lbl)

	return bar


func _build_bottom_nav_bar() -> PanelContainer:
	var nav := PanelContainer.new()
	nav.custom_minimum_size = Vector2(0, 66)
	ThemeHelper.style_card(nav, Color(0.11, 0.075, 0.055, 0.96), ThemeHelper.COL_GOLD, 18)

	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	nav.add_child(hb)

	var defs := [
		{"key": "profile", "label": "👤 پروفایل"},
		{"key": "chat", "label": "💬 گفت‌وگو"},
		{"key": "leaderboard", "label": "🏆 رتبه‌بندی"},
		{"key": "play", "label": "🏠 بازی‌ها"},
	]
	for d in defs:
		var b := Button.new()
		b.text = d["label"]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 14)
		var key: String = d["key"]
		b.pressed.connect(func():
			AudioManager.play("ui_click")
			_switch_tab(key)
		)
		hb.add_child(b)
		_nav_buttons[key] = b

	return nav


func _switch_tab(key: String) -> void:
	_active_tab = key
	for k in _tab_pages:
		_tab_pages[k].visible = (k == key)
	for k in _nav_buttons:
		var b: Button = _nav_buttons[k]
		if k == key:
			ThemeHelper.style_primary_button(b, ThemeHelper.COL_GOLD)
			b.add_theme_font_size_override("font_size", 14)
		else:
			b.add_theme_stylebox_override("normal", ThemeHelper.make_box(Color(0.16, 0.11, 0.08, 0.65), Color(0, 0, 0, 0), 0, 12, 6, 6))
			b.add_theme_color_override("font_color", ThemeHelper.COL_TEXT_MUTED)
			b.add_theme_font_size_override("font_size", 13)


func _build_play_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 12)
	scroll.add_child(vb)

	# Hero Title Banner (transparent enough to show the rotating 3D scene!)
	var hero := PanelContainer.new()
	ThemeHelper.style_card(hero, Color(0.14, 0.095, 0.065, 0.78), ThemeHelper.COL_GOLD, 18)
	vb.add_child(hero)
	var hvb := VBoxContainer.new()
	hvb.add_theme_constant_override("separation", 3)
	hero.add_child(hvb)
	hvb.add_child(ThemeHelper.make_label("✨ سالن کلاسیک منچ و تخته نرد ✨", 20, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	hvb.add_child(ThemeHelper.make_label("گرافیک سه‌بعدی با نورپردازی لوکس • حالت آفلاین و آماده آنلاین", 12, ThemeHelper.COL_TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	# Game Card 1: Mench 3D
	vb.add_child(_build_mench_mobile_card())

	# Game Card 2: Takhte Nard 3D
	vb.add_child(_build_takhte_mobile_card())

	# Online Phase 2 Banner
	var online := PanelContainer.new()
	online.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.14, 0.10, 0.18, 0.88), Color(0.62, 0.48, 0.88, 0.85), 1, 16, 12, 10))
	vb.add_child(online)
	var ohb := HBoxContainer.new()
	ohb.add_theme_constant_override("separation", 8)
	online.add_child(ohb)

	var obtn := Button.new()
	obtn.text = "جزئیات 🌐"
	obtn.custom_minimum_size = Vector2(92, 38)
	obtn.add_theme_font_size_override("font_size", 13)
	obtn.pressed.connect(func():
		AudioManager.play("ui_click")
		_show_info_modal(
			"🌐 حالت آنلاین (مرحله بعدی)",
			"لایه شبکه (NetworkManager) آماده اتصال به سرور آنلاین است.\nفعلاً هر دو بازی، لیدربورد، چت و پروفایل به‌صورت آفلاین در ابعاد موبایل قابل تست هستند!"
		)
	)
	ohb.add_child(obtn)

	var olbl := ThemeHelper.make_label("اتاق آنلاین و رقابت جهانی (آماده فاز ۲)", 13, Color(0.88, 0.82, 0.98), HORIZONTAL_ALIGNMENT_RIGHT)
	olbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ohb.add_child(olbl)

	return scroll


func _build_mench_mobile_card() -> PanelContainer:
	var card := PanelContainer.new()
	ThemeHelper.style_card(card, Color(0.16, 0.11, 0.08, 0.92), ThemeHelper.COL_GOLD, 20)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	# Header Row: Thumbnail + Title/Desc
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)

	var thumb_box := PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(104, 104)
	thumb_box.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.08, 0.05, 0.03), ThemeHelper.COL_GOLD_BRIGHT, 2, 14, 3, 3))
	var tr := TextureRect.new()
	tr.texture = load("res://assets/textures/ludo_board.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_box.add_child(tr)
	top.add_child(thumb_box)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vb.add_theme_constant_override("separation", 4)
	top.add_child(info_vb)
	info_vb.add_child(ThemeHelper.make_label("🎲 منچ پارسی ۳بعدی", 19, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var desc := Label.new()
	desc.text = "مهره‌های طلاکوب، صفحه شمسه‌دار، خانه‌های امن ستاره‌دار و هوش مصنوعی پیشرفته"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", ThemeHelper.COL_TEXT_MUTED)
	info_vb.add_child(desc)

	# Compact 3-pill Options Row
	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 6)
	vb.add_child(opt_row)

	_mench_diff_opt = OptionButton.new()
	_mench_diff_opt.add_item("ربات: آسان", 0)
	_mench_diff_opt.add_item("ربات: متوسط", 1)
	_mench_diff_opt.add_item("ربات: حرفه‌ای", 2)
	_mench_diff_opt.selected = 1
	_mench_diff_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mench_diff_opt.add_theme_font_size_override("font_size", 12)
	opt_row.add_child(_mench_diff_opt)

	_mench_mode_opt = OptionButton.new()
	_mench_mode_opt.add_item("با ربات 🤖", 0)
	_mench_mode_opt.add_item("دوستانه 👥", 1)
	_mench_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mench_mode_opt.add_theme_font_size_override("font_size", 12)
	opt_row.add_child(_mench_mode_opt)

	_mench_players_opt = OptionButton.new()
	_mench_players_opt.add_item("۲ نفره", 2)
	_mench_players_opt.add_item("۳ نفره", 3)
	_mench_players_opt.add_item("۴ نفره", 4)
	_mench_players_opt.selected = 2
	_mench_players_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mench_players_opt.add_theme_font_size_override("font_size", 12)
	opt_row.add_child(_mench_players_opt)

	var play_btn := Button.new()
	play_btn.text = "▶ شروع بازی منچ"
	play_btn.custom_minimum_size = Vector2(0, 50)
	ThemeHelper.style_primary_button(play_btn, ThemeHelper.COL_CRIMSON)
	play_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		GameState.match_config = {
			"game_type": "mench",
			"player_count": _mench_players_opt.get_selected_id(),
			"mode": "vs_ai" if _mench_mode_opt.selected == 0 else "local_pvp",
			"ai_difficulty": _mench_diff_opt.selected,
		}
		_launch_game("mench")
	)
	vb.add_child(play_btn)
	return card


func _build_takhte_mobile_card() -> PanelContainer:
	var card := PanelContainer.new()
	ThemeHelper.style_card(card, Color(0.16, 0.11, 0.08, 0.92), ThemeHelper.COL_EMERALD, 20)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	vb.add_child(top)

	var thumb_box := PanelContainer.new()
	thumb_box.custom_minimum_size = Vector2(104, 104)
	thumb_box.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.08, 0.05, 0.03), ThemeHelper.COL_GOLD_BRIGHT, 2, 14, 3, 3))
	var tr := TextureRect.new()
	tr.texture = load("res://assets/textures/backgammon_board.png")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb_box.add_child(tr)
	top.add_child(thumb_box)

	var info_vb := VBoxContainer.new()
	info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vb.add_theme_constant_override("separation", 4)
	top.add_child(info_vb)
	info_vb.add_child(ThemeHelper.make_label("🪵 تخته نرد پارسی ۳بعدی", 19, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))
	var desc := Label.new()
	desc.text = "تخته خاتم‌کاری گردو عمودی مخصوص موبایل، مهره‌های صدفی و یاقوتی طلاکوب و قوانین کامل"
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", ThemeHelper.COL_TEXT_MUTED)
	info_vb.add_child(desc)

	var opt_row := HBoxContainer.new()
	opt_row.add_theme_constant_override("separation", 8)
	vb.add_child(opt_row)

	_takhte_diff_opt = OptionButton.new()
	_takhte_diff_opt.add_item("ربات: آسان", 0)
	_takhte_diff_opt.add_item("ربات: متوسط", 1)
	_takhte_diff_opt.add_item("ربات: حرفه‌ای", 2)
	_takhte_diff_opt.selected = 1
	_takhte_diff_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_takhte_diff_opt.add_theme_font_size_override("font_size", 13)
	opt_row.add_child(_takhte_diff_opt)

	_takhte_mode_opt = OptionButton.new()
	_takhte_mode_opt.add_item("در برابر ربات 🤖", 0)
	_takhte_mode_opt.add_item("۲ نفره لوکال 👥", 1)
	_takhte_mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_takhte_mode_opt.add_theme_font_size_override("font_size", 13)
	opt_row.add_child(_takhte_mode_opt)

	var play_btn := Button.new()
	play_btn.text = "▶ شروع بازی تخته نرد"
	play_btn.custom_minimum_size = Vector2(0, 50)
	ThemeHelper.style_primary_button(play_btn, ThemeHelper.COL_EMERALD)
	play_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		GameState.match_config = {
			"game_type": "takhte",
			"mode": "vs_ai" if _takhte_mode_opt.selected == 0 else "local_pvp",
			"ai_difficulty": _takhte_diff_opt.selected,
		}
		_launch_game("takhte")
	)
	vb.add_child(play_btn)
	return card


func _build_profile_tab() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ThemeHelper.style_card(panel, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD, 18)
	scroll.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	vb.add_child(ThemeHelper.make_label("👤 پروفایل و تنظیمات بازیکن", 19, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	_profile_stats_lbl = ThemeHelper.make_label("", 14, ThemeHelper.COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(_profile_stats_lbl)

	vb.add_child(ThemeHelper.make_label("نام نمایشی:", 14, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	var name_edit := LineEdit.new()
	name_edit.text = str(GameState.player_profile["name"])
	name_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_edit.custom_minimum_size = Vector2(0, 44)
	vb.add_child(name_edit)

	vb.add_child(ThemeHelper.make_label("آواتار شما:", 14, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	var selected_av := [int(GameState.player_profile["avatar_id"])]
	var av_row := HBoxContainer.new()
	av_row.alignment = BoxContainer.ALIGNMENT_CENTER
	av_row.add_theme_constant_override("separation", 6)
	vb.add_child(av_row)

	var av_btns: Array[Button] = []
	for av in GameState.AVATARS:
		var b := Button.new()
		b.text = str(av["icon"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		b.add_theme_font_size_override("font_size", 24)
		var aid: int = av["id"]
		b.pressed.connect(func():
			AudioManager.play("ui_click")
			selected_av[0] = aid
			for j in range(av_btns.size()):
				var active := (j == aid)
				av_btns[j].add_theme_stylebox_override("normal", ThemeHelper.make_box(
					Color(0.28, 0.20, 0.10) if active else Color(0.16, 0.12, 0.09),
					ThemeHelper.COL_GOLD_BRIGHT if active else ThemeHelper.COL_GOLD_DIM,
					3 if active else 1, 14, 4, 4
				))
		)
		av_row.add_child(b)
		av_btns.append(b)
	av_btns[selected_av[0]].pressed.emit()

	var save_btn := Button.new()
	save_btn.text = "💾 ذخیره تغییرات پروفایل"
	save_btn.custom_minimum_size = Vector2(0, 48)
	ThemeHelper.style_primary_button(save_btn, ThemeHelper.COL_EMERALD)
	save_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		GameState.update_profile(name_edit.text, selected_av[0])
	)
	vb.add_child(save_btn)

	# Audio Settings inside Profile Tab
	vb.add_child(HSeparator.new())
	vb.add_child(ThemeHelper.make_label("⚙️ تنظیمات صدا", 17, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	var sfx_check := CheckButton.new()
	sfx_check.text = "افکت‌های صوتی تاس، مهره و چت"
	sfx_check.button_pressed = bool(GameState.settings["sfx_enabled"])
	sfx_check.toggled.connect(func(v: bool):
		GameState.settings["sfx_enabled"] = v
		GameState.save_data()
		if v:
			AudioManager.play("ui_click")
	)
	vb.add_child(sfx_check)

	var slider := HSlider.new()
	slider.min_value = 0.05
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(GameState.settings["sfx_volume"])
	slider.value_changed.connect(func(val: float):
		GameState.settings["sfx_volume"] = val
		GameState.save_data()
	)
	vb.add_child(slider)

	var test_btn := Button.new()
	test_btn.text = "🎲 تست صدای تاس"
	test_btn.custom_minimum_size = Vector2(0, 42)
	test_btn.pressed.connect(func(): AudioManager.play("dice_roll"))
	vb.add_child(test_btn)

	return scroll


func _build_3d_lobby_backdrop(parent: Control) -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(svc)

	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)
	_lobby_vp = vp

	var world := Node3D.new()
	vp.add_child(world)

	VisualEffects3D.setup_lounge_environment(world)

	_backdrop_pivot = Node3D.new()
	world.add_child(_backdrop_pivot)

	var bg_frame: PackedScene = load("res://assets/models/backgammon_board_frame.glb")
	if bg_frame:
		var inst := bg_frame.instantiate()
		inst.scale = Vector3.ONE * 0.56
		VisualEffects3D.enhance_walnut_frame_pbr(inst)
		_backdrop_pivot.add_child(inst)

	var surf := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12.4 * 0.56, 13.6 * 0.56)
	surf.mesh = pm
	surf.position = Vector3(0, 0.02, 0)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load("res://assets/textures/backgammon_board.png")
	if ResourceLoader.exists("res://assets/textures/backgammon_board_normal.png"):
		sm.normal_enabled = true
		sm.normal_texture = load("res://assets/textures/backgammon_board_normal.png")
	sm.roughness = 0.25
	sm.clearcoat_enabled = true
	sm.clearcoat = 0.45
	surf.material_override = sm
	_backdrop_pivot.add_child(surf)

	var dice_scene: PackedScene = load("res://assets/models/dice.glb")
	if dice_scene:
		for i in 2:
			var d := dice_scene.instantiate()
			d.position = Vector3(-0.7 + i * 1.4, 0.45, 0.2 - i * 0.4)
			d.rotation_degrees = Vector3(0, 22 + i * 40, 0)
			_backdrop_pivot.add_child(d)

	var pawn_scene: PackedScene = load("res://assets/models/ludo_pawn.glb")
	var pawn_colors := [Color(0.84, 0.14, 0.22), Color(0.10, 0.60, 0.34), Color(0.92, 0.66, 0.10), Color(0.14, 0.42, 0.84)]
	if pawn_scene:
		for i in 4:
			var pw := pawn_scene.instantiate()
			pw.position = Vector3(-2.1 + i * 1.4, 0.03, 2.2)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = pawn_colors[i]
			mat.roughness = 0.16
			mat.metallic = 0.14
			mat.clearcoat_enabled = true
			mat.clearcoat = 0.72
			VisualEffects3D.apply_body_material_preserve_gold(pw, mat)
			_backdrop_pivot.add_child(pw)

	var cam := Camera3D.new()
	cam.fov = 44.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 8.8, 10.6), Vector3(0, 0, 0.2), Vector3.UP)


func _process(delta: float) -> void:
	if _backdrop_pivot != null and _lobby_root.visible:
		_backdrop_pivot.rotate_y(delta * 0.16)


func _refresh_profile_ui() -> void:
	var p := GameState.player_profile
	var av := GameState.get_avatar(int(p["avatar_id"]))
	_profile_lbl.text = "%s %s  •  سطح %d" % [str(p["name"]), str(av["icon"]), int(p["level"])]
	_coins_lbl.text = "🪙 %d" % int(p["coins"])
	if _profile_stats_lbl != null:
		_profile_stats_lbl.text = "🏆 برد منچ: %d (امتیاز %d)  |  برد نرد: %d (امتیاز %d)" % [
			int(p["mench_wins"]), int(p["mench_rating"]),
			int(p["takhte_wins"]), int(p["takhte_rating"]),
		]


func _launch_game(game_type: String) -> void:
	if _active_game != null:
		_active_game.queue_free()
		_active_game = null

	_lobby_root.visible = false
	if _lobby_vp:
		_lobby_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if game_type == "mench":
		var g := MenchGame.new()
		g.back_to_lobby.connect(_return_to_lobby)
		g.restart_requested.connect(func(): _launch_game("mench"))
		_active_game = g
		add_child(g)
	else:
		var g := TakhteNardGame.new()
		g.back_to_lobby.connect(_return_to_lobby)
		g.restart_requested.connect(func(): _launch_game("takhte"))
		_active_game = g
		add_child(g)


func _return_to_lobby() -> void:
	if _active_game != null:
		_active_game.queue_free()
		_active_game = null
	_lobby_root.visible = true
	if _lobby_vp:
		_lobby_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refresh_profile_ui()


func _open_rules_modal() -> void:
	var txt := (
		"🎲 قوانین منچ:\n"
		+ "• با عدد ۶ مهره از خانه بیرون می‌آید و تاس جایزه می‌گیرید.\n"
		+ "• با زدن مهره حریف (خارج از ستاره‌های امن)، تاس جایزه می‌گیرید.\n"
		+ "• اولین نفری که هر ۴ مهره را به مرکز برساند برنده است.\n\n"
		+ "🪵 قوانین تخته نرد:\n"
		+ "• مهره‌های سفید به سمت پایین‌راست و تیره به بالا‌راست حرکت می‌کنند.\n"
		+ "• جفت آوردن ۴ حرکت می‌دهد.\n"
		+ "• با زدن مهره تکی حریف، مهره روی بار می‌رود.\n"
		+ "• پس از ورود هر ۱۵ مهره به خانه خودی، سینی مخملی سمت راست را لمس کنید تا جمع شوند!\n\n"
		+ "🎥 با دکمه دوربین زاویه را عوض کنید یا با کلیک راست بچرخانید."
	)
	_show_info_modal("📖 راهنمای بازی", txt)


func _show_info_modal(title: String, body_text: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.015, 0.80)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(460, 420)
	ThemeHelper.style_card(card, ThemeHelper.COL_PANEL, ThemeHelper.COL_GOLD, 20)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	card.add_child(vb)

	var hdr := HBoxContainer.new()
	vb.add_child(hdr)
	var close_btn := Button.new()
	close_btn.text = "✕ بستن"
	close_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		overlay.queue_free()
	)
	hdr.add_child(close_btn)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(sp)
	hdr.add_child(ThemeHelper.make_label(title, 18, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	var lbl := Label.new()
	lbl.text = body_text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	scroll.add_child(lbl)
