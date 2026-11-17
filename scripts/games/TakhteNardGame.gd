class_name TakhteNardGame
extends Control

signal back_to_lobby
signal restart_requested

# Board state:
# points[0..23]: positive = Player 0 (White/Ivory, moves 23 -> 0), negative = Player 1 (Ruby-Ebony, moves 0 -> 23)
var _points: Array[int] = []
var _bar := [0, 0]
var _borne_off := [0, 0]

enum Phase { WAIT_ROLL, ROLLING, PLAYER_MOVE, AI_THINKING, ANIMATING, GAME_OVER }

var _phase: Phase = Phase.WAIT_ROLL
var _turn := 0
var _is_ai := [false, true]
var _player_names := ["", ""]
var _player_avatars := [0, 4]

var _dice_values: Array[int] = []
var _remaining_dice: Array[int] = []
var _turn_snapshots: Array[Dictionary] = []
var _selected_from := -99
var _camera_preset := 0
var _pulse_time := 0.0

# 3D Nodes
var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: OrbitCamera3D
var _dice_nodes: Array[Dice3D] = []
var _checker_scene: PackedScene
var _checker_mats: Array[StandardMaterial3D] = []
var _checkers_root: Node3D
var _highlights_root: Node3D
var _glow_tex: Texture2D

# Mobile HUD Refs
var _roll_btn: Button
var _undo_btn: Button
var _status_lbl: Label
var _dice_chips_box: HBoxContainer
var _p0_card: PanelContainer
var _p1_card: PanelContainer
var _p0_info: Label
var _p1_info: Label
var _chat_panel: ChatPanel
var _chat_btn: Button
var _unread_chat := 0
var _emote_layer: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_tex = load("res://assets/textures/glow_ring.png")
	_checker_scene = load("res://assets/models/backgammon_checker.glb")
	NetworkManager.clear_match_chat()

	var mode: String = str(GameState.match_config.get("mode", "vs_ai"))
	_is_ai = [false, mode == "vs_ai"]
	_player_names = [
		str(GameState.player_profile["name"]),
		"شیرین (ربات)" if _is_ai[1] else "بازیکن ۲",
	]
	_player_avatars = [int(GameState.player_profile["avatar_id"]), 4]

	_init_board_state()
	_build_3d_viewport()
	_build_mobile_hud()
	_rebuild_checkers_3d()
	_update_hud()

	if not NetworkManager.emote_received.is_connected(_on_emote_received):
		NetworkManager.emote_received.connect(_on_emote_received)
	if not NetworkManager.chat_message_received.is_connected(_on_chat_msg_badge):
		NetworkManager.chat_message_received.connect(_on_chat_msg_badge)

	_begin_turn()


func _init_board_state() -> void:
	_points.clear()
	for i in 24:
		_points.append(0)
	_points[23] = 2
	_points[12] = 5
	_points[7] = 3
	_points[5] = 5
	_points[0] = -2
	_points[11] = -5
	_points[16] = -3
	_points[18] = -5
	_bar = [0, 0]
	_borne_off = [0, 0]


func _build_3d_viewport() -> void:
	_vp_container = SubViewportContainer.new()
	_vp_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp_container.stretch = true
	_vp_container.gui_input.connect(_on_board_gui_input)
	add_child(_vp_container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_vp_container.add_child(_viewport)

	_world = Node3D.new()
	_viewport.add_child(_world)

	# AAA Persian Royal Lounge Atmosphere, Sky Reflections, SSAO, Lantern & Dust Motes
	VisualEffects3D.setup_lounge_environment(_world)

	# Portrait Walnut & Brass Backgammon Cabinet (12.4 x 13.6 + Bear-Off Tray)
	var frame_scene: PackedScene = load("res://assets/models/backgammon_board_frame.glb")
	if frame_scene:
		var frame := frame_scene.instantiate()
		VisualEffects3D.enhance_walnut_frame_pbr(frame)
		_world.add_child(frame)

	# High-Res Inlaid Khatamkari Surface with Normal Map + Lacquer Clearcoat
	var surf := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(12.4, 13.6)
	surf.mesh = sp
	surf.position = Vector3(0, 0.015, 0)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load("res://assets/textures/backgammon_board.png")
	if ResourceLoader.exists("res://assets/textures/backgammon_board_normal.png"):
		sm.normal_enabled = true
		sm.normal_texture = load("res://assets/textures/backgammon_board_normal.png")
		sm.normal_scale = 0.55
	sm.roughness = 0.26
	sm.metallic = 0.06
	sm.clearcoat_enabled = true
	sm.clearcoat = 0.45
	surf.material_override = sm
	_world.add_child(surf)

	# Mother-of-Pearl Ivory vs Glossy Ruby-Walnut Checkers (preserving Blender gold inlay ring!)
	var mat_white := StandardMaterial3D.new()
	mat_white.albedo_color = Color(0.96, 0.92, 0.80)
	mat_white.roughness = 0.16
	mat_white.metallic = 0.08
	mat_white.clearcoat_enabled = true
	mat_white.clearcoat = 0.68

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.36, 0.08, 0.09)
	mat_dark.roughness = 0.18
	mat_dark.metallic = 0.12
	mat_dark.clearcoat_enabled = true
	mat_dark.clearcoat = 0.72

	_checker_mats = [mat_white, mat_dark]

	_checkers_root = Node3D.new()
	_world.add_child(_checkers_root)

	_highlights_root = Node3D.new()
	_world.add_child(_highlights_root)

	for i in 2:
		var d := Dice3D.new()
		d.scale = Vector3.ONE * 0.96
		_world.add_child(d)
		d.set_rest_position(Vector3(2.4 + i * 1.1, 0.38, 0.0))
		_dice_nodes.append(d)

	# Portrait 9:16 Mobile Camera (KEEP_WIDTH guarantees entire board + velvet bear-off tray fits!)
	_camera = OrbitCamera3D.new()
	_world.add_child(_camera)
	_camera.configure(Vector3(0.66, 0.0, 0.25), 20.8, -72.0, 0.0, 44.0)


func _build_mobile_hud() -> void:
	_emote_layer = Control.new()
	_emote_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_emote_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_emote_layer)

	# 1. Compact Mobile Top Bar
	var top_bar := PanelContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 10
	top_bar.offset_right = -10
	top_bar.offset_top = 10
	top_bar.offset_bottom = 60
	top_bar.add_theme_stylebox_override("panel", ThemeHelper.make_box(ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD_DIM, 1, 14, 10, 6))
	add_child(top_bar)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	top_bar.add_child(hb)

	var back_btn := Button.new()
	back_btn.text = "← سالن"
	back_btn.custom_minimum_size = Vector2(74, 38)
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		back_to_lobby.emit()
	)
	hb.add_child(back_btn)

	var cam_btn := Button.new()
	cam_btn.text = "🎥"
	cam_btn.custom_minimum_size = Vector2(42, 38)
	cam_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		_camera_preset = (_camera_preset + 1) % 3
		_camera.apply_preset(_camera_preset, 20.8)
	)
	hb.add_child(cam_btn)

	var sfx_btn := Button.new()
	sfx_btn.text = "🔊" if GameState.settings["sfx_enabled"] else "🔇"
	sfx_btn.custom_minimum_size = Vector2(42, 38)
	sfx_btn.pressed.connect(func():
		GameState.settings["sfx_enabled"] = not bool(GameState.settings["sfx_enabled"])
		GameState.save_data()
		sfx_btn.text = "🔊" if GameState.settings["sfx_enabled"] else "🔇"
		AudioManager.play("ui_click")
	)
	hb.add_child(sfx_btn)

	_chat_btn = Button.new()
	_chat_btn.text = "💬 چت"
	_chat_btn.custom_minimum_size = Vector2(74, 38)
	_chat_btn.add_theme_font_size_override("font_size", 13)
	_chat_btn.pressed.connect(_toggle_chat)
	hb.add_child(_chat_btn)

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)

	hb.add_child(ThemeHelper.make_label("🪵 تخته نرد پارسی", 16, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	# 2. Compact Side-by-Side 2-Player Score Bar right under top bar
	var p_row := HBoxContainer.new()
	p_row.add_theme_constant_override("separation", 8)
	p_row.anchor_left = 0.0
	p_row.anchor_right = 1.0
	p_row.anchor_top = 0.0
	p_row.anchor_bottom = 0.0
	p_row.offset_left = 10
	p_row.offset_right = -10
	p_row.offset_top = 66
	p_row.offset_bottom = 132
	add_child(p_row)

	_p1_card = _make_player_pill(1)
	p_row.add_child(_p1_card)
	_p0_card = _make_player_pill(0)
	p_row.add_child(_p0_card)

	# 3. Bottom Thumb-Friendly Action Dock
	var dock := PanelContainer.new()
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_top = -142
	dock.offset_bottom = -14
	ThemeHelper.style_card(dock, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD, 20)
	add_child(dock)

	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 8)
	dock.add_child(dvb)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 8)
	dvb.add_child(status_row)

	_dice_chips_box = HBoxContainer.new()
	_dice_chips_box.add_theme_constant_override("separation", 5)
	status_row.add_child(_dice_chips_box)

	_status_lbl = ThemeHelper.make_label("آماده شروع...", 13, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_status_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	dvb.add_child(btn_row)

	_undo_btn = Button.new()
	_undo_btn.text = "↩ بازگشت"
	_undo_btn.custom_minimum_size = Vector2(106, 50)
	_undo_btn.add_theme_font_size_override("font_size", 14)
	_undo_btn.pressed.connect(_on_undo_pressed)
	btn_row.add_child(_undo_btn)

	_roll_btn = Button.new()
	_roll_btn.text = "🎲 ریختن تاس"
	_roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_btn.custom_minimum_size = Vector2(0, 50)
	ThemeHelper.style_primary_button(_roll_btn, ThemeHelper.COL_GOLD)
	_roll_btn.pressed.connect(_on_roll_pressed)
	btn_row.add_child(_roll_btn)

	# 4. Slide-up Bottom Sheet Chat Panel
	_chat_panel = ChatPanel.new()
	_chat_panel.anchor_left = 0.0
	_chat_panel.anchor_right = 1.0
	_chat_panel.anchor_top = 1.0
	_chat_panel.anchor_bottom = 1.0
	_chat_panel.offset_left = 12
	_chat_panel.offset_right = -12
	_chat_panel.offset_top = -460
	_chat_panel.offset_bottom = -14
	_chat_panel.visible = false
	add_child(_chat_panel)
	_chat_panel.setup("match", true)
	_chat_panel.close_requested.connect(func(): _chat_panel.visible = false)


func _make_player_pill(pid: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	vb.add_child(top)
	var disc := ColorRect.new()
	disc.custom_minimum_size = Vector2(13, 13)
	disc.color = Color(0.96, 0.92, 0.80) if pid == 0 else Color(0.58, 0.14, 0.14)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(disc)

	var av := GameState.get_avatar(_player_avatars[pid])
	var nm := ThemeHelper.make_label("%s %s" % [_player_names[pid], str(av["icon"])], 13, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(nm)

	var info := ThemeHelper.make_label("خال: ۱۶۷ • جمع: ۰", 12, ThemeHelper.COL_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	vb.add_child(info)
	if pid == 0:
		_p0_info = info
	else:
		_p1_info = info
	return card


func _toggle_chat() -> void:
	AudioManager.play("ui_click")
	_chat_panel.visible = not _chat_panel.visible
	if _chat_panel.visible:
		_unread_chat = 0
		_chat_btn.text = "💬 چت"


func _on_chat_msg_badge(ch: String, msg: Dictionary) -> void:
	if ch != "match" or _chat_panel == null or _chat_panel.visible:
		return
	if not bool(msg.get("is_local", false)):
		_unread_chat += 1
		_chat_btn.text = "💬 %d" % _unread_chat


func _on_emote_received(sender_name: String, emote: String, _pidx: int) -> void:
	if _emote_layer == null or not is_inside_tree():
		return
	var lbl := ThemeHelper.make_label("%s  %s" % [emote, sender_name], 24, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.position = Vector2(size.x * 0.5 - 100, size.y * 0.60)
	_emote_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 120.0, 1.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


# ============================================================
# 3D GEOMETRY (Portrait 12.4 x 13.6 Board + Right Tray at X=+7.0)
# ============================================================

func _point_base_xz(pt: int) -> Vector2:
	var left_start := -5.938
	var right_start := 0.40
	var pw := 5.538 / 6.0 # ~0.923
	if pt >= 12 and pt <= 17:
		var col := pt - 12
		return Vector2(left_start + (col + 0.5) * pw, -5.92)
	elif pt >= 18 and pt <= 23:
		var col := pt - 18
		return Vector2(right_start + (col + 0.5) * pw, -5.92)
	elif pt >= 6 and pt <= 11:
		var col := 11 - pt
		return Vector2(left_start + (col + 0.5) * pw, 5.92)
	else:
		var col := 5 - pt
		return Vector2(right_start + (col + 0.5) * pw, 5.92)


func _point_checker_pos(pt: int, stack_idx: int) -> Vector3:
	var base := _point_base_xz(pt)
	var dir_z := 1.0 if pt >= 12 else -1.0
	var layer := stack_idx / 5
	var slot := stack_idx % 5
	var z := base.y + dir_z * (slot * 0.84)
	var y := 0.02 + layer * 0.22
	return Vector3(base.x, y, z)


func _bar_checker_pos(player: int, stack_idx: int) -> Vector3:
	var z_base := 1.5 if player == 0 else -1.5
	var dir_z := 0.85 if player == 0 else -0.85
	var layer := stack_idx / 3
	var slot := stack_idx % 3
	return Vector3(0.0, 0.29 + layer * 0.22, z_base + dir_z * slot)


func _tray_checker_pos(player: int, idx: int) -> Vector3:
	var z_start := 5.6 if player == 0 else -5.6
	var dir_z := -0.62 if player == 0 else 0.62
	var layer := idx / 8
	var slot := idx % 8
	return Vector3(7.00, 0.05 + layer * 0.22, z_start + dir_z * slot)


func _rebuild_checkers_3d() -> void:
	for c in _checkers_root.get_children():
		c.queue_free()

	for pt in 24:
		var val := _points[pt]
		if val == 0:
			continue
		var owner := 0 if val > 0 else 1
		var cnt: int = absi(val)
		for k in cnt:
			_spawn_checker_mesh(owner, _point_checker_pos(pt, k))

	for owner in 2:
		for k in _bar[owner]:
			_spawn_checker_mesh(owner, _bar_checker_pos(owner, k))
		for k in _borne_off[owner]:
			_spawn_checker_mesh(owner, _tray_checker_pos(owner, k))


func _spawn_checker_mesh(owner: int, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	_checkers_root.add_child(node)
	if _checker_scene:
		var inst := _checker_scene.instantiate()
		inst.scale = Vector3.ONE * 0.96
		VisualEffects3D.apply_body_material_preserve_gold(inst, _checker_mats[owner])
		node.add_child(inst)
	return node


# ============================================================
# BACKGAMMON RULES ENGINE
# ============================================================

func _sign(player: int) -> int:
	return 1 if player == 0 else -1


func _all_in_home(player: int, pts: Array[int], bars: Array) -> bool:
	if bars[player] > 0:
		return false
	if player == 0:
		for pt in range(6, 24):
			if pts[pt] > 0:
				return false
	else:
		for pt in range(0, 18):
			if pts[pt] < 0:
				return false
	return true


func _is_open_for(player: int, dest: int, pts: Array[int]) -> bool:
	if dest < 0 or dest > 23:
		return false
	var v := pts[dest]
	return (v >= -1) if player == 0 else (v <= 1)


func _get_legal_single_moves(player: int, die: int, pts: Array[int], bars: Array) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if bars[player] > 0:
		var dest := (24 - die) if player == 0 else (die - 1)
		if _is_open_for(player, dest, pts):
			moves.append({"from": -1, "to": dest, "die": die})
		return moves

	var can_bear := _all_in_home(player, pts, bars)
	for pt in 24:
		var has_own := (pts[pt] > 0) if player == 0 else (pts[pt] < 0)
		if not has_own:
			continue

		var dest := (pt - die) if player == 0 else (pt + die)
		if dest >= 0 and dest <= 23:
			if _is_open_for(player, dest, pts):
				moves.append({"from": pt, "to": dest, "die": die})
		elif can_bear:
			if player == 0:
				if pt + 1 == die:
					moves.append({"from": pt, "to": -2, "die": die})
				elif die > pt + 1:
					var higher := false
					for hp in range(pt + 1, 6):
						if pts[hp] > 0:
							higher = true
							break
					if not higher:
						moves.append({"from": pt, "to": -2, "die": die})
			else:
				var needed := 24 - pt
				if needed == die:
					moves.append({"from": pt, "to": 24, "die": die})
				elif die > needed:
					var lower := false
					for lp in range(18, pt):
						if pts[lp] < 0:
							lower = true
							break
					if not lower:
						moves.append({"from": pt, "to": 24, "die": die})
	return moves


func _get_all_legal_moves_for_remaining(player: int) -> Array[Dictionary]:
	var unique_dice: Array[int] = []
	for d in _remaining_dice:
		if not (d in unique_dice):
			unique_dice.append(d)
	var all: Array[Dictionary] = []
	for d in unique_dice:
		var ms := _get_legal_single_moves(player, d, _points, _bar)
		for m in ms:
			all.append(m)
	return all


func _apply_move_to_state(player: int, mv: Dictionary, pts: Array[int], bars: Array, borne: Array) -> bool:
	var s := _sign(player)
	var from_pt: int = mv["from"]
	var to_pt: int = mv["to"]
	var did_hit := false

	if from_pt == -1:
		bars[player] -= 1
	else:
		pts[from_pt] -= s

	if to_pt == -2 or to_pt == 24:
		borne[player] += 1
	else:
		if (player == 0 and pts[to_pt] == -1) or (player == 1 and pts[to_pt] == 1):
			pts[to_pt] = 0
			bars[1 - player] += 1
			did_hit = true
		pts[to_pt] += s
	return did_hit


func _pip_count(player: int) -> int:
	var total: int = int(_bar[player]) * 25
	for pt in 24:
		if player == 0 and _points[pt] > 0:
			total += _points[pt] * (pt + 1)
		elif player == 1 and _points[pt] < 0:
			total += absi(_points[pt]) * (24 - pt)
	return total


# ============================================================
# TURN FLOW & AI
# ============================================================

func _begin_turn() -> void:
	if _phase == Phase.GAME_OVER:
		return
	_phase = Phase.WAIT_ROLL
	_selected_from = -99
	_remaining_dice.clear()
	_turn_snapshots.clear()
	_clear_highlights()
	_update_hud()

	if _is_ai[_turn]:
		_status_lbl.text = "نوبت %s..." % _player_names[_turn]
		await get_tree().create_timer(0.60).timeout
		if is_inside_tree() and _phase == Phase.WAIT_ROLL:
			_execute_roll()
	else:
		_status_lbl.text = "نوبت %s — تاس بریزید!" % _player_names[_turn]


func _on_roll_pressed() -> void:
	if _phase != Phase.WAIT_ROLL or _is_ai[_turn]:
		return
	_execute_roll()


func _execute_roll() -> void:
	_phase = Phase.ROLLING
	_update_hud()
	AudioManager.play("dice_roll", 0.08)

	var d1 := randi_range(1, 6)
	var d2 := randi_range(1, 6)
	_dice_values = [d1, d2]
	if d1 == d2:
		_remaining_dice = [d1, d1, d1, d1]
		if _is_ai[_turn]:
			NetworkManager.trigger_bot_reaction(_player_names[_turn], "big_roll", _turn)
	else:
		_remaining_dice = [d1, d2]

	NetworkManager.send_game_action({"game": "takhte", "type": "roll", "player": _turn, "dice": _dice_values})

	var x_base := 2.4 if _turn == 0 else -3.5
	_dice_nodes[0].set_rest_position(Vector3(x_base, 0.38, -0.42))
	_dice_nodes[1].set_rest_position(Vector3(x_base + 1.10, 0.38, 0.42))
	_dice_nodes[0].roll_to(d1, 0.58)
	await _dice_nodes[1].roll_to(d2, 0.64)
	if not is_inside_tree():
		return

	if d1 == d2:
		VisualEffects3D.spawn_spark_burst(_world, Vector3(x_base + 0.55, 0.4, 0.0), Color(1.0, 0.86, 0.30), 30)

	_update_hud()
	var legal := _get_all_legal_moves_for_remaining(_turn)
	if legal.is_empty():
		_status_lbl.text = "حرکت مجازی نیست! نوبت سوخت 😅"
		await get_tree().create_timer(1.05).timeout
		_end_turn()
		return

	if _is_ai[_turn]:
		_phase = Phase.AI_THINKING
		_status_lbl.text = "%s در حال بررسی..." % _player_names[_turn]
		await _run_ai_turn()
	else:
		_phase = Phase.PLAYER_MOVE
		_auto_select_or_prompt()


func _auto_select_or_prompt() -> void:
	_selected_from = -99
	var legal := _get_all_legal_moves_for_remaining(_turn)
	if legal.is_empty():
		_clear_highlights()
		_status_lbl.text = "حرکت مجازی باقی نماند — تغییر نوبت"
		await get_tree().create_timer(0.80).timeout
		_end_turn()
		return

	if _bar[_turn] > 0:
		_selected_from = -1
		_status_lbl.text = "مهره روی بار دارید — خانه سبز را لمس کنید"
	else:
		_status_lbl.text = "ستون طلایی را لمس و مقصد سبز را انتخاب کنید"

	_refresh_highlights()
	_update_hud()


func _execute_single_move(mv: Dictionary, save_undo: bool = true) -> void:
	if save_undo:
		_turn_snapshots.append({
			"points": _points.duplicate(),
			"bar": _bar.duplicate(),
			"borne_off": _borne_off.duplicate(),
			"remaining_dice": _remaining_dice.duplicate(),
		})

	var from_pt: int = mv["from"]
	var to_pt: int = mv["to"]
	var die_used: int = mv["die"]

	var start_pos := _bar_checker_pos(_turn, maxi(0, _bar[_turn] - 1)) if from_pt == -1 else _point_checker_pos(from_pt, maxi(0, absi(_points[from_pt]) - 1))
	var end_pos := _tray_checker_pos(_turn, _borne_off[_turn]) if (to_pt == -2 or to_pt == 24) else _point_checker_pos(to_pt, absi(_points[to_pt]) if ((_turn == 0 and _points[to_pt] > 0) or (_turn == 1 and _points[to_pt] < 0)) else 0)

	var did_hit := _apply_move_to_state(_turn, mv, _points, _bar, _borne_off)
	var d_idx := _remaining_dice.find(die_used)
	if d_idx != -1:
		_remaining_dice.remove_at(d_idx)

	NetworkManager.send_game_action({"game": "takhte", "type": "move", "player": _turn, "move": mv})

	_phase = Phase.ANIMATING
	_clear_highlights()
	var anim_checker := _spawn_checker_mesh(_turn, start_pos)
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var p := start_pos.lerp(end_pos, t)
		p.y += sin(t * PI) * 1.45
		anim_checker.position = p
	, 0.0, 1.0, 0.22)
	await tw.finished
	if not is_inside_tree():
		return

	if did_hit:
		AudioManager.play("capture")
		VisualEffects3D.spawn_spark_burst(_world, end_pos, Color(1.0, 0.32, 0.24), 26)
		if _is_ai[1 - _turn]:
			NetworkManager.trigger_bot_reaction(_player_names[1 - _turn], "captured", 1 - _turn)
	else:
		AudioManager.play("piece_move", 0.08)
		if to_pt == -2 or to_pt == 24:
			VisualEffects3D.spawn_spark_burst(_world, end_pos, Color(1.0, 0.88, 0.35), 18)

	_rebuild_checkers_3d()
	_update_hud()

	if _borne_off[_turn] >= 15:
		_on_game_won(_turn)
		return

	if _remaining_dice.is_empty():
		await get_tree().create_timer(0.32).timeout
		_end_turn()
		return

	if not _is_ai[_turn]:
		_phase = Phase.PLAYER_MOVE
		_auto_select_or_prompt()


func _on_undo_pressed() -> void:
	if _phase != Phase.PLAYER_MOVE or _turn_snapshots.is_empty():
		return
	AudioManager.play("ui_click")
	var snap: Dictionary = _turn_snapshots.pop_back()
	_points = snap["points"]
	_bar = snap["bar"]
	_borne_off = snap["borne_off"]
	_remaining_dice = snap["remaining_dice"]
	_rebuild_checkers_3d()
	_auto_select_or_prompt()


func _run_ai_turn() -> void:
	var difficulty: int = int(GameState.match_config.get("ai_difficulty", 1))
	while not _remaining_dice.is_empty() and _phase != Phase.GAME_OVER:
		await get_tree().create_timer(0.42).timeout
		if not is_inside_tree():
			return
		var legal := _get_all_legal_moves_for_remaining(_turn)
		if legal.is_empty():
			break
		var chosen := _choose_ai_move(legal, difficulty)
		await _execute_single_move(chosen, false)
	if is_inside_tree() and _phase != Phase.GAME_OVER and not _remaining_dice.is_empty():
		_end_turn()


func _choose_ai_move(legal: Array[Dictionary], difficulty: int) -> Dictionary:
	if difficulty == 0:
		return legal[randi() % legal.size()]

	var best_mv := legal[0]
	var best_score := -99999.0
	for mv in legal:
		var pts := _points.duplicate()
		var bars := _bar.duplicate()
		var borne := _borne_off.duplicate()
		var hit := _apply_move_to_state(_turn, mv, pts, bars, borne)
		var score := _evaluate_board_for_ai(_turn, pts, bars, borne, hit)
		score += randf_range(-5.0, 5.0) if difficulty == 1 else randf_range(-1.2, 1.2)
		if score > best_score:
			best_score = score
			best_mv = mv
	return best_mv


func _evaluate_board_for_ai(player: int, pts: Array[int], bars: Array, borne: Array, hit: bool) -> float:
	var score := 0.0
	if hit:
		score += 48.0
	score += borne[player] * 65.0
	score -= bars[player] * 55.0
	score += bars[1 - player] * 35.0

	for pt in 24:
		var v := pts[pt]
		var own := (v > 0) if player == 0 else (v < 0)
		if not own:
			continue
		var cnt: int = absi(v)
		var progress := (23 - pt) if player == 0 else pt
		score += progress * cnt * 0.9
		if cnt >= 2:
			score += 18.0
			var in_home := (pt <= 5) if player == 0 else (pt >= 18)
			if in_home:
				score += 14.0
		elif cnt == 1:
			score -= 14.0
	return score


func _end_turn() -> void:
	_turn = 1 - _turn
	_begin_turn()


# ============================================================
# 3D HIGHLIGHTS & TOUCH/MOUSE INTERACTION
# ============================================================

func _clear_highlights() -> void:
	for c in _highlights_root.get_children():
		c.queue_free()


func _refresh_highlights() -> void:
	_clear_highlights()
	if _phase != Phase.PLAYER_MOVE or _is_ai[_turn]:
		return

	var legal := _get_all_legal_moves_for_remaining(_turn)
	var sources := {}
	for mv in legal:
		sources[mv["from"]] = true

	for src in sources:
		var is_sel: bool = (src == _selected_from)
		var pos := _bar_checker_pos(_turn, maxi(0, _bar[_turn] - 1)) if src == -1 else _point_checker_pos(src, maxi(0, absi(_points[src]) - 1))
		pos.y += 0.14
		_spawn_highlight_ring(pos, Color(0.35, 1.0, 0.55, 0.98) if is_sel else Color(1.0, 0.86, 0.25, 0.92), 1.10 if is_sel else 0.94)

	if _selected_from != -99:
		var dests := {}
		for mv in legal:
			if mv["from"] == _selected_from:
				dests[mv["to"]] = true
		for dst in dests:
			var pos: Vector3
			if dst == -2 or dst == 24:
				pos = _tray_checker_pos(_turn, _borne_off[_turn]) + Vector3(0, 0.18, 0)
			else:
				var base := _point_base_xz(dst)
				var dir_z := 1.0 if dst >= 12 else -1.0
				pos = Vector3(base.x, 0.06, base.y + dir_z * 1.6)
			_spawn_highlight_ring(pos, Color(0.20, 0.98, 0.52, 0.98), 1.24, true)


func _spawn_highlight_ring(pos: Vector3, col: Color, sz: float, add_beacon: bool = false) -> void:
	var holder := Node3D.new()
	holder.position = pos
	_highlights_root.add_child(holder)

	var ring := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(sz, sz)
	ring.mesh = pl
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _glow_tex
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.4
	ring.material_override = mat
	holder.add_child(ring)

	if add_beacon:
		var orb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		orb.mesh = sm
		orb.position = Vector3(0, 0.55, 0)
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = col
		bmat.emission_enabled = true
		bmat.emission = col
		bmat.emission_energy_multiplier = 2.8
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		orb.material_override = bmat
		holder.add_child(orb)


func _process(delta: float) -> void:
	_pulse_time += delta * 5.2
	var s := 1.0 + sin(_pulse_time) * 0.15
	for c in _highlights_root.get_children():
		c.scale = Vector3(s, 1.0, s)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and _phase == Phase.WAIT_ROLL and not _is_ai[_turn]:
			_execute_roll()


func _local_to_vp(local_pos: Vector2) -> Vector2:
	var csz := _vp_container.size
	if csz.x <= 1.0 or csz.y <= 1.0:
		return local_pos
	return (local_pos / csz) * Vector2(_viewport.size)


func _on_board_gui_input(event: InputEvent) -> void:
	_camera.handle_orbit_input(event)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			if _phase != Phase.PLAYER_MOVE or _is_ai[_turn]:
				return
			var vp_pos := _local_to_vp(mb.position)
			var hit: Variant = _raycast_board_plane(vp_pos)
			if hit == null:
				return
			_handle_board_click(hit as Vector3)


func _raycast_board_plane(vp_pos: Vector2) -> Variant:
	var ray_origin := _camera.project_ray_origin(vp_pos)
	var ray_dir := _camera.project_ray_normal(vp_pos)
	if absf(ray_dir.y) < 0.001:
		return null
	var t := (0.12 - ray_origin.y) / ray_dir.y
	if t <= 0:
		return null
	return ray_origin + ray_dir * t


func _handle_board_click(hit: Vector3) -> void:
	var legal := _get_all_legal_moves_for_remaining(_turn)
	var clicked_id := _world_to_slot(hit)

	# 1. If a source is selected and user clicked a valid destination -> move there!
	if _selected_from != -99:
		var matching_moves: Array[Dictionary] = []
		for mv in legal:
			if mv["from"] == _selected_from and mv["to"] == clicked_id:
				matching_moves.append(mv)
		if not matching_moves.is_empty():
			matching_moves.sort_custom(func(a, b): return int(a["die"]) < int(b["die"]))
			AudioManager.play("ui_click")
			_execute_single_move(matching_moves[0], true)
			return

		# 2. Mobile 2-Tap Quick-Move: tapping the ALREADY selected source executes its primary legal move!
		if clicked_id == _selected_from:
			var from_moves: Array[Dictionary] = []
			for mv in legal:
				if mv["from"] == _selected_from:
					from_moves.append(mv)
			if not from_moves.is_empty():
				from_moves.sort_custom(func(a, b): return int(a["die"]) > int(b["die"]))
				AudioManager.play("ui_click")
				_execute_single_move(from_moves[0], true)
				return

	# 3. Select clicked valid source stack
	for mv in legal:
		if mv["from"] == clicked_id:
			AudioManager.play("ui_click")
			_selected_from = clicked_id
			_status_lbl.text = "مقصد سبز را لمس کنید (یا دوباره روی مهره بزنید)"
			_refresh_highlights()
			return

	if _bar[_turn] == 0:
		_selected_from = -99
		_refresh_highlights()


func _world_to_slot(hit: Vector3) -> int:
	# Right bear-off tray (x >= 6.25)
	if hit.x >= 6.25 and hit.x <= 8.4:
		return -2 if hit.z >= 0.0 else 24

	# Center bar (|x| < 0.48)
	if absf(hit.x) < 0.48:
		return -1

	var is_top := hit.z < 0.0
	var best_pt := -99
	var best_dx := 0.60
	var start_pt := 12 if is_top else 0
	var end_pt := 24 if is_top else 12
	for pt in range(start_pt, end_pt):
		var px := _point_base_xz(pt).x
		var dx: float = absf(hit.x - px)
		if dx < best_dx:
			best_dx = dx
			best_pt = pt
	return best_pt


func _update_hud() -> void:
	_roll_btn.disabled = (_phase != Phase.WAIT_ROLL) or _is_ai[_turn]
	_undo_btn.disabled = (_phase != Phase.PLAYER_MOVE) or _turn_snapshots.is_empty()

	var p0_turn := (_turn == 0)
	_p0_card.add_theme_stylebox_override("panel", ThemeHelper.make_box(
		Color(0.24, 0.17, 0.10, 0.96) if p0_turn else ThemeHelper.COL_PANEL_GLASS,
		ThemeHelper.COL_GOLD_BRIGHT if p0_turn else ThemeHelper.COL_GOLD_DIM,
		3 if p0_turn else 1, 12, 10, 6, 6 if p0_turn else 0
	))
	_p1_card.add_theme_stylebox_override("panel", ThemeHelper.make_box(
		Color(0.24, 0.17, 0.10, 0.96) if not p0_turn else ThemeHelper.COL_PANEL_GLASS,
		ThemeHelper.COL_GOLD_BRIGHT if not p0_turn else ThemeHelper.COL_GOLD_DIM,
		3 if not p0_turn else 1, 12, 10, 6, 6 if not p0_turn else 0
	))

	_p0_info.text = "خال:%d • بار:%d • جمع:%d" % [_pip_count(0), _bar[0], _borne_off[0]]
	_p1_info.text = "خال:%d • بار:%d • جمع:%d" % [_pip_count(1), _bar[1], _borne_off[1]]

	for c in _dice_chips_box.get_children():
		c.queue_free()
	for d in _remaining_dice:
		var chip := PanelContainer.new()
		chip.custom_minimum_size = Vector2(32, 32)
		chip.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.96, 0.92, 0.80), ThemeHelper.COL_GOLD, 2, 8, 2, 1))
		chip.add_child(ThemeHelper.make_label(str(d), 16, Color(0.12, 0.08, 0.05), HORIZONTAL_ALIGNMENT_CENTER))
		_dice_chips_box.add_child(chip)


func _on_game_won(winner: int) -> void:
	_phase = Phase.GAME_OVER
	AudioManager.play("win", 0.0)
	VisualEffects3D.spawn_spark_burst(_world, Vector3(0, 1.0, 0), Color(1.0, 0.88, 0.30), 60)
	var local_won := (winner == 0)
	var is_mars: bool = (int(_borne_off[1 - winner]) == 0)
	var reward := GameState.record_match_result("takhte", local_won)
	if not local_won and _is_ai[winner]:
		NetworkManager.trigger_bot_reaction(_player_names[winner], "win", winner)

	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.02, 0.015, 0.82)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(440, 320)
	ThemeHelper.style_card(card, ThemeHelper.COL_PANEL, ThemeHelper.COL_GOLD_BRIGHT, 22)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	card.add_child(vb)

	var win_title := "🏆 مارس! پیروزی باشکوه!" if is_mars else "🏆 پایان مسابقه تخته نرد!"
	vb.add_child(ThemeHelper.make_label(win_title, 23, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(ThemeHelper.make_label("برنده: %s" % _player_names[winner], 19, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var delta_sign := "+" if int(reward["rating_delta"]) >= 0 else ""
	vb.add_child(ThemeHelper.make_label(
		"🪙 +%d سکه  •  ✨ +%d تجربه  •  ⭐ %s%d" % [reward["coins"], reward["xp"], delta_sign, reward["rating_delta"]],
		15,
		ThemeHelper.COL_GOLD,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	var lobby_btn := Button.new()
	lobby_btn.text = "سالن اصلی"
	lobby_btn.custom_minimum_size = Vector2(160, 48)
	lobby_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		back_to_lobby.emit()
	)
	row.add_child(lobby_btn)

	var replay_btn := Button.new()
	replay_btn.text = "🎲 بازی مجدد"
	replay_btn.custom_minimum_size = Vector2(160, 48)
	ThemeHelper.style_primary_button(replay_btn, ThemeHelper.COL_EMERALD)
	replay_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		restart_requested.emit()
	)
	row.add_child(replay_btn)
