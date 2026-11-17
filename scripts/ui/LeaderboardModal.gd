class_name LeaderboardModal
extends PanelContainer

signal closed

var embed_mode := true
var _category: String = "overall"
var _podium_row: HBoxContainer
var _list_box: VBoxContainer
var _tab_buttons := {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	ThemeHelper.style_card(self, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD, 18)
	_build_ui()
	_refresh()
	if not GameState.leaderboard_updated.is_connected(_refresh):
		GameState.leaderboard_updated.connect(_refresh)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	root.add_child(header)

	if not embed_mode:
		var close_btn := Button.new()
		close_btn.text = "✕"
		close_btn.custom_minimum_size = Vector2(38, 36)
		close_btn.pressed.connect(func():
			AudioManager.play("ui_click")
			closed.emit()
			queue_free()
		)
		header.add_child(close_btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)

	header.add_child(ThemeHelper.make_label("🏆 جدول رتبه‌بندی قهرمانان", 19, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	# Mobile Compact Category Tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	root.add_child(tabs)

	var defs := [
		{"key": "takhte", "label": "🪵 تخته نرد"},
		{"key": "mench", "label": "🎲 منچ"},
		{"key": "overall", "label": "👑 کلی"},
	]
	for d in defs:
		var btn := Button.new()
		btn.text = d["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 40)
		var key: String = d["key"]
		btn.pressed.connect(func():
			AudioManager.play("ui_click")
			_category = key
			_refresh()
		)
		tabs.add_child(btn)
		_tab_buttons[key] = btn

	# Top-3 Mobile Podium
	_podium_row = HBoxContainer.new()
	_podium_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_podium_row.add_theme_constant_override("separation", 8)
	root.add_child(_podium_row)

	# Scrollable Full List
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	scroll.add_child(_list_box)


func _refresh() -> void:
	if _podium_row == null:
		return
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		if k == _category:
			ThemeHelper.style_primary_button(b, ThemeHelper.COL_GOLD)
			b.add_theme_font_size_override("font_size", 14)
		else:
			b.add_theme_stylebox_override("normal", ThemeHelper.make_box(Color(0.20, 0.14, 0.10, 0.9), ThemeHelper.COL_GOLD_DIM, 1, 12, 8, 6))
			b.add_theme_font_size_override("font_size", 14)

	for c in _podium_row.get_children():
		c.queue_free()
	for c in _list_box.get_children():
		c.queue_free()

	var rows := GameState.get_leaderboard(_category)
	if rows.size() >= 3:
		_podium_row.add_child(_make_podium_card(rows[1], 2, Color(0.76, 0.80, 0.85), 132))
		_podium_row.add_child(_make_podium_card(rows[0], 1, ThemeHelper.COL_GOLD_BRIGHT, 152))
		_podium_row.add_child(_make_podium_card(rows[2], 3, Color(0.82, 0.52, 0.28), 124))

	for i in range(rows.size()):
		var entry := rows[i]
		var rank := i + 1
		var is_local: bool = bool(entry.get("is_local", false))
		var row := PanelContainer.new()
		var bg := Color(0.14, 0.30, 0.23, 0.94) if is_local else Color(0.16, 0.115, 0.085, 0.92)
		var bd := ThemeHelper.COL_GOLD_BRIGHT if is_local else ThemeHelper.COL_GOLD_DIM
		row.add_theme_stylebox_override("panel", ThemeHelper.make_box(bg, bd, 2 if is_local else 1, 12, 10, 8))

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		row.add_child(hb)

		var score_lbl := ThemeHelper.make_label("⭐ %d" % int(entry["score"]), 14, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_LEFT)
		score_lbl.custom_minimum_size = Vector2(76, 0)
		hb.add_child(score_lbl)

		var wins_lbl := ThemeHelper.make_label("🏆 %d" % int(entry["wins"]), 13, ThemeHelper.COL_TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		wins_lbl.custom_minimum_size = Vector2(56, 0)
		hb.add_child(wins_lbl)

		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(sp)

		var av := GameState.get_avatar(int(entry["avatar_id"]))
		var name_text := "%s %s%s" % [str(entry["name"]), str(av["icon"]), " (شما)" if is_local else ""]
		var name_lbl := ThemeHelper.make_label(name_text, 14, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		hb.add_child(name_lbl)

		var rank_str := "🥇" if rank == 1 else ("🥈" if rank == 2 else ("🥉" if rank == 3 else "#%d" % rank))
		var rank_lbl := ThemeHelper.make_label(rank_str, 15, ThemeHelper.COL_GOLD_BRIGHT if rank <= 3 else ThemeHelper.COL_TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		rank_lbl.custom_minimum_size = Vector2(36, 0)
		hb.add_child(rank_lbl)

		_list_box.add_child(row)


func _make_podium_card(entry: Dictionary, rank: int, medal_col: Color, height_px: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, height_px)
	p.size_flags_vertical = Control.SIZE_SHRINK_END
	p.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.18, 0.13, 0.095, 0.96), medal_col, 2, 14, 8, 8, 6))

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	p.add_child(vb)

	var crown := "🥇 اول" if rank == 1 else ("🥈 دوم" if rank == 2 else "🥉 سوم")
	vb.add_child(ThemeHelper.make_label(crown, 13, medal_col, HORIZONTAL_ALIGNMENT_CENTER))
	var av := GameState.get_avatar(int(entry["avatar_id"]))
	vb.add_child(ThemeHelper.make_label(str(av["icon"]), 30 if rank == 1 else 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var nm := ThemeHelper.make_label(str(entry["name"]), 13, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(nm)
	vb.add_child(ThemeHelper.make_label("⭐ %d" % int(entry["score"]), 12, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	return p
