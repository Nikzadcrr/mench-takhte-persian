class_name MenchGame
extends Control

signal back_to_lobby
signal restart_requested

const TRACK_CELLS: Array[Vector2i] = [
	Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6), Vector2i(4, 6), Vector2i(5, 6),
	Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3), Vector2i(6, 2), Vector2i(6, 1), Vector2i(6, 0),
	Vector2i(7, 0), Vector2i(8, 0),
	Vector2i(8, 1), Vector2i(8, 2), Vector2i(8, 3), Vector2i(8, 4), Vector2i(8, 5),
	Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6),
	Vector2i(14, 7), Vector2i(14, 8),
	Vector2i(13, 8), Vector2i(12, 8), Vector2i(11, 8), Vector2i(10, 8), Vector2i(9, 8),
	Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11), Vector2i(8, 12), Vector2i(8, 13), Vector2i(8, 14),
	Vector2i(7, 14), Vector2i(6, 14),
	Vector2i(6, 13), Vector2i(6, 12), Vector2i(6, 11), Vector2i(6, 10), Vector2i(6, 9),
	Vector2i(5, 8), Vector2i(4, 8), Vector2i(3, 8), Vector2i(2, 8), Vector2i(1, 8), Vector2i(0, 8),
	Vector2i(0, 7), Vector2i(0, 6),
]

const START_OFFSETS := [0, 13, 26, 39]
const SAFE_TRACK_INDICES := [0, 8, 13, 21, 26, 34, 39, 47]

const HOME_PATHS := [
	[Vector2i(1, 7), Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)],
	[Vector2i(7, 1), Vector2i(7, 2), Vector2i(7, 3), Vector2i(7, 4), Vector2i(7, 5)],
	[Vector2i(13, 7), Vector2i(12, 7), Vector2i(11, 7), Vector2i(10, 7), Vector2i(9, 7)],
	[Vector2i(7, 13), Vector2i(7, 12), Vector2i(7, 11), Vector2i(7, 10), Vector2i(7, 9)],
]

const YARD_ORIGINS := [Vector2(0, 0), Vector2(9, 0), Vector2(9, 9), Vector2(0, 9)]
const YARD_SLOTS := [Vector2(1.85, 1.85), Vector2(4.15, 1.85), Vector2(1.85, 4.15), Vector2(4.15, 4.15)]
const HOME_FINISH_CENTERS := [Vector2(6.55, 7.5), Vector2(7.5, 6.55), Vector2(8.45, 7.5), Vector2(7.5, 8.45)]

const TEAM_COLORS := [
	Color(0.84, 0.14, 0.22), # قرمز یاقوتی
	Color(0.10, 0.60, 0.34), # سبز زمردی
	Color(0.92, 0.66, 0.10), # طلایی کهربایی
	Color(0.14, 0.42, 0.84), # آبی لاجوردی
]
const TEAM_NAMES := ["قرمز", "سبز", "زرد", "آبی"]
const BOT_POOL := ["آرش", "شیرین", "سهراب", "نیلوفر"]

enum Phase { WAIT_ROLL, ROLLING, WAIT_SELECT, ANIMATING, GAME_OVER }

var _vp_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node3D
var _camera: OrbitCamera3D
var _dice: Dice3D

var _players: Array[Dictionary] = []
var _active_player_indices: Array[int] = []
var _turn_ptr := 0
var _phase: Phase = Phase.WAIT_ROLL
var _rolled_val := 0
var _consecutive_sixes := 0
var _legal_pawns: Array[int] = []
var _camera_preset := 0

var _pawn_nodes := {}

# Mobile Portrait UI Refs
var _roll_btn: Button
var _status_lbl: Label
var _dice_badge_lbl: Label
var _player_cards := {}
var _chat_panel: ChatPanel
var _chat_btn: Button
var _unread_chat := 0
var _emote_layer: Control
var _glow_tex: Texture2D
var _pulse_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_tex = load("res://assets/textures/glow_ring.png")
	NetworkManager.clear_match_chat()
	_setup_players()
	_build_3d_viewport()
	_build_mobile_hud()
	_spawn_pawns()
	_refresh_all_pawn_transforms(false)
	_update_hud()

	if not NetworkManager.emote_received.is_connected(_on_emote_received):
		NetworkManager.emote_received.connect(_on_emote_received)
	if not NetworkManager.chat_message_received.is_connected(_on_chat_msg_badge):
		NetworkManager.chat_message_received.connect(_on_chat_msg_badge)

	_begin_turn()


func _setup_players() -> void:
	var count: int = clampi(int(GameState.match_config.get("player_count", 4)), 2, 4)
	var mode: String = str(GameState.match_config.get("mode", "vs_ai"))

	if count == 2:
		_active_player_indices = [0, 2]
	elif count == 3:
		_active_player_indices = [0, 1, 2]
	else:
		_active_player_indices = [0, 1, 2, 3]

	_players.clear()
	for i in 4:
		var is_active := i in _active_player_indices
		var is_ai := (mode == "vs_ai") and (i != 0)
		var pname := ""
		var av_id := i % GameState.AVATARS.size()
		if i == 0:
			pname = str(GameState.player_profile["name"])
			av_id = int(GameState.player_profile["avatar_id"])
		elif is_ai:
			pname = BOT_POOL[i % BOT_POOL.size()]
		else:
			pname = "بازیکن %s" % TEAM_NAMES[i]

		_players.append({
			"id": i,
			"name": pname,
			"avatar_id": av_id,
			"active": is_active,
			"is_ai": is_ai,
			"color": TEAM_COLORS[i],
			"pawns": [-1, -1, -1, -1],
		})


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

	# Upgraded Blender 3D Walnut & Brass Frame
	var frame_scene: PackedScene = load("res://assets/models/ludo_board_frame.glb")
	if frame_scene:
		var frame := frame_scene.instantiate()
		VisualEffects3D.enhance_walnut_frame_pbr(frame)
		_world.add_child(frame)

	# High-Res Ludo Surface with Normal Map + Glossy Clearcoat
	var board_surf := MeshInstance3D.new()
	var b_plane := PlaneMesh.new()
	b_plane.size = Vector2(15.0, 15.0)
	board_surf.mesh = b_plane
	board_surf.position = Vector3(0, 0.015, 0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_texture = load("res://assets/textures/ludo_board.png")
	if ResourceLoader.exists("res://assets/textures/ludo_board_normal.png"):
		b_mat.normal_enabled = true
		b_mat.normal_texture = load("res://assets/textures/ludo_board_normal.png")
		b_mat.normal_scale = 0.45
	b_mat.roughness = 0.28
	b_mat.metallic = 0.05
	b_mat.clearcoat_enabled = true
	b_mat.clearcoat = 0.35
	board_surf.material_override = b_mat
	_world.add_child(board_surf)

	# Luxury 3D Dice
	_dice = Dice3D.new()
	_dice.scale = Vector3.ONE * 1.25
	_world.add_child(_dice)
	_dice.set_rest_position(Vector3(0.0, 0.46, 0.0))

	# Portrait 9:16 Mobile Camera (KEEP_WIDTH guarantees entire 15x15 board + walnut frame fits!)
	_camera = OrbitCamera3D.new()
	_world.add_child(_camera)
	_camera.configure(Vector3(0, 0, 0.35), 23.2, -68.0, 0.0, 44.0)


func _spawn_pawns() -> void:
	var pawn_scene: PackedScene = load("res://assets/models/ludo_pawn.glb")
	for p in _players:
		var pid: int = p["id"]
		if not p["active"]:
			continue
		_pawn_nodes[pid] = []
		var mat := StandardMaterial3D.new()
		mat.albedo_color = p["color"]
		mat.roughness = 0.16
		mat.metallic = 0.14
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.72
		mat.clearcoat_roughness = 0.12

		for idx in 4:
			var root := Node3D.new()
			_world.add_child(root)

			var mesh_holder := Node3D.new()
			root.add_child(mesh_holder)
			if pawn_scene:
				var inst := pawn_scene.instantiate()
				inst.scale = Vector3.ONE * 0.96
				VisualEffects3D.apply_body_material_preserve_gold(inst, mat)
				mesh_holder.add_child(inst)

			var ring := MeshInstance3D.new()
			var r_plane := PlaneMesh.new()
			r_plane.size = Vector2(1.26, 1.26)
			ring.mesh = r_plane
			ring.position = Vector3(0, 0.05, 0)
			var r_mat := StandardMaterial3D.new()
			r_mat.albedo_texture = _glow_tex
			r_mat.albedo_color = Color(1.0, 0.94, 0.42, 0.98)
			r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			r_mat.emission_enabled = true
			r_mat.emission = Color(1.0, 0.88, 0.30)
			r_mat.emission_energy_multiplier = 2.4
			ring.material_override = r_mat
			ring.visible = false
			root.add_child(ring)

			# Floating golden beacon orb above crown when selectable
			var beacon := MeshInstance3D.new()
			var b_mesh := SphereMesh.new()
			b_mesh.radius = 0.14
			b_mesh.height = 0.28
			beacon.mesh = b_mesh
			beacon.position = Vector3(0, 1.55, 0)
			var b_mat := StandardMaterial3D.new()
			b_mat.albedo_color = Color(1.0, 0.92, 0.35)
			b_mat.emission_enabled = true
			b_mat.emission = Color(1.0, 0.86, 0.25)
			b_mat.emission_energy_multiplier = 2.8
			b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			beacon.material_override = b_mat
			beacon.visible = false
			root.add_child(beacon)

			_pawn_nodes[pid].append({"root": root, "mesh": mesh_holder, "ring": ring, "beacon": beacon})


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
	cam_btn.tooltip_text = "تغییر زاویه دوربین"
	cam_btn.custom_minimum_size = Vector2(42, 38)
	cam_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		_camera_preset = (_camera_preset + 1) % 3
		_camera.apply_preset(_camera_preset, 23.2)
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

	hb.add_child(ThemeHelper.make_label("🎲 منچ پارسی", 16, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_RIGHT))

	# 2. Mobile 2x2 Compact Player Grid right below top bar
	var p_grid := GridContainer.new()
	p_grid.columns = 2
	p_grid.add_theme_constant_override("h_separation", 8)
	p_grid.add_theme_constant_override("v_separation", 6)
	p_grid.anchor_left = 0.0
	p_grid.anchor_right = 1.0
	p_grid.anchor_top = 0.0
	p_grid.anchor_bottom = 0.0
	p_grid.offset_left = 10
	p_grid.offset_right = -10
	p_grid.offset_top = 66
	p_grid.offset_bottom = 166
	add_child(p_grid)

	for p in _players:
		var pid: int = p["id"]
		if not p["active"]:
			continue
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(0, 46)
		p_grid.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		card.add_child(row)

		var prog_lbl := ThemeHelper.make_label("۰/۴", 13, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_LEFT)
		prog_lbl.custom_minimum_size = Vector2(36, 0)
		row.add_child(prog_lbl)

		var av := GameState.get_avatar(int(p["avatar_id"]))
		var nm := ThemeHelper.make_label("%s %s" % [str(p["name"]), str(av["icon"])], 13, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nm)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = p["color"]
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)

		_player_cards[pid] = {"panel": card, "prog": prog_lbl}

	# 3. Bottom Thumb-Friendly Action Dock
	var dock := PanelContainer.new()
	dock.anchor_left = 0.0
	dock.anchor_right = 1.0
	dock.anchor_top = 1.0
	dock.anchor_bottom = 1.0
	dock.offset_left = 12
	dock.offset_right = -12
	dock.offset_top = -128
	dock.offset_bottom = -14
	ThemeHelper.style_card(dock, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD, 20)
	add_child(dock)

	var dvb := VBoxContainer.new()
	dvb.add_theme_constant_override("separation", 8)
	dock.add_child(dvb)

	_status_lbl = ThemeHelper.make_label("آماده شروع...", 14, ThemeHelper.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	dvb.add_child(_status_lbl)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 10)
	dvb.add_child(action_row)

	var badge_box := PanelContainer.new()
	badge_box.custom_minimum_size = Vector2(96, 52)
	badge_box.add_theme_stylebox_override("panel", ThemeHelper.make_box(Color(0.20, 0.14, 0.09, 0.96), ThemeHelper.COL_GOLD, 2, 14, 8, 4))
	_dice_badge_lbl = ThemeHelper.make_label("تاس: —", 17, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	badge_box.add_child(_dice_badge_lbl)
	action_row.add_child(badge_box)

	_roll_btn = Button.new()
	_roll_btn.text = "🎲 ریختن تاس"
	_roll_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_roll_btn.custom_minimum_size = Vector2(0, 52)
	ThemeHelper.style_primary_button(_roll_btn, ThemeHelper.COL_GOLD)
	_roll_btn.pressed.connect(_on_roll_pressed)
	action_row.add_child(_roll_btn)

	# 4. Slide-up Bottom Sheet Chat Panel (Mobile Ergonomic)
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
	lbl.position = Vector2(size.x * 0.5 - 100, size.y * 0.62)
	_emote_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 120.0, 1.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


func _current_player() -> Dictionary:
	return _players[_active_player_indices[_turn_ptr]]


func _begin_turn() -> void:
	if _phase == Phase.GAME_OVER:
		return
	_phase = Phase.WAIT_ROLL
	_legal_pawns.clear()
	_clear_highlights()
	_update_hud()

	var p := _current_player()
	if p["is_ai"]:
		_status_lbl.text = "نوبت %s..." % str(p["name"])
		await get_tree().create_timer(0.60).timeout
		if is_inside_tree() and _phase == Phase.WAIT_ROLL:
			_execute_roll()
	else:
		_status_lbl.text = "نوبت %s — تاس بریزید!" % str(p["name"])


func _on_roll_pressed() -> void:
	if _phase != Phase.WAIT_ROLL or _current_player()["is_ai"]:
		return
	_execute_roll()


func _execute_roll() -> void:
	_phase = Phase.ROLLING
	_update_hud()
	AudioManager.play("dice_roll", 0.08)

	_rolled_val = randi_range(1, 6)
	NetworkManager.send_game_action({"game": "mench", "type": "roll", "player": _current_player()["id"], "value": _rolled_val})
	await _dice.roll_to(_rolled_val, 0.60)
	if not is_inside_tree():
		return

	_dice_badge_lbl.text = "تاس: %d" % _rolled_val
	var p := _current_player()

	if _rolled_val == 6:
		VisualEffects3D.spawn_spark_burst(_world, _dice.position, Color(1.0, 0.86, 0.30), 26)
		_consecutive_sixes += 1
		if p["is_ai"]:
			NetworkManager.trigger_bot_reaction(str(p["name"]), "big_roll", int(p["id"]))
		if _consecutive_sixes >= 3:
			_status_lbl.text = "سه تا ۶ پشت سر هم! نوبت سوخت 😅"
			_consecutive_sixes = 0
			await get_tree().create_timer(1.05).timeout
			_advance_turn()
			return
	else:
		_consecutive_sixes = 0

	_legal_pawns = _get_legal_pawns(int(p["id"]), _rolled_val)
	if _legal_pawns.is_empty():
		_status_lbl.text = "حرکت مجازی وجود ندارد (%d)" % _rolled_val
		await get_tree().create_timer(0.90).timeout
		_advance_turn()
		return

	if p["is_ai"]:
		_phase = Phase.WAIT_SELECT
		_status_lbl.text = "%s در حال انتخاب..." % str(p["name"])
		await get_tree().create_timer(0.50).timeout
		var chosen := _choose_ai_pawn(int(p["id"]), _legal_pawns, _rolled_val)
		_execute_move(int(p["id"]), chosen)
	elif _legal_pawns.size() == 1:
		_status_lbl.text = "حرکت خودکار تنها مهره مجاز..."
		await get_tree().create_timer(0.28).timeout
		_execute_move(int(p["id"]), _legal_pawns[0])
	else:
		_phase = Phase.WAIT_SELECT
		_status_lbl.text = "روی یکی از مهره‌های درخشان لمس کنید (%d)" % _rolled_val
		_highlight_legal_pawns(int(p["id"]), _legal_pawns)
		_update_hud()


func _get_legal_pawns(pid: int, roll: int) -> Array[int]:
	var res: Array[int] = []
	var pawns: Array = _players[pid]["pawns"]
	for i in 4:
		var prog: int = pawns[i]
		if prog == -1:
			if roll == 6:
				res.append(i)
		elif prog < 56:
			if prog + roll <= 56:
				res.append(i)
	return res


func _choose_ai_pawn(pid: int, legal: Array[int], roll: int) -> int:
	var difficulty: int = int(GameState.match_config.get("ai_difficulty", 1))
	if difficulty == 0:
		return legal[randi() % legal.size()]

	var best_idx := legal[0]
	var best_score := -9999.0
	var pawns: Array = _players[pid]["pawns"]

	for idx in legal:
		var prog: int = pawns[idx]
		var score := 0.0
		if prog == -1:
			score += 65.0
		else:
			var next_prog := prog + roll
			if next_prog == 56:
				score += 120.0
			elif next_prog >= 51:
				score += 80.0
			else:
				var next_track: int = (int(START_OFFSETS[pid]) + next_prog) % 52
				if next_track in SAFE_TRACK_INDICES:
					score += 42.0
				if _would_capture(pid, next_track):
					score += 105.0
				score += next_prog * 0.75
		score += randf_range(-4.0, 4.0) if difficulty == 1 else randf_range(-1.0, 1.0)
		if score > best_score:
			best_score = score
			best_idx = idx
	return best_idx


func _would_capture(pid: int, track_idx: int) -> bool:
	if track_idx in SAFE_TRACK_INDICES:
		return false
	for other in _players:
		if not other["active"] or other["id"] == pid:
			continue
		for op in other["pawns"]:
			if op >= 0 and op <= 50:
				var ot: int = (int(START_OFFSETS[int(other["id"])]) + int(op)) % 52
				if ot == track_idx:
					return true
	return false


func _execute_move(pid: int, pawn_idx: int) -> void:
	_phase = Phase.ANIMATING
	_clear_highlights()
	_update_hud()

	var pawns: Array = _players[pid]["pawns"]
	var old_prog: int = pawns[pawn_idx]
	var new_prog: int = 0 if old_prog == -1 else (old_prog + _rolled_val)

	NetworkManager.send_game_action({"game": "mench", "type": "move", "player": pid, "pawn": pawn_idx, "to": new_prog})

	var pawn_root: Node3D = _pawn_nodes[pid][pawn_idx]["root"]
	if old_prog == -1:
		pawns[pawn_idx] = 0
		var dest := _progress_to_world(pid, 0, pawn_idx)
		await _hop_node(pawn_root, dest, 0.28, 1.15)
		AudioManager.play("piece_move")
	else:
		for step in range(old_prog + 1, new_prog + 1):
			pawns[pawn_idx] = step
			var dest := _progress_to_world(pid, step, pawn_idx)
			await _hop_node(pawn_root, dest, 0.15, 0.65)
			AudioManager.play("piece_move", 0.09)

	var captured_any := false
	if new_prog >= 0 and new_prog <= 50:
		var landing_track: int = (int(START_OFFSETS[pid]) + new_prog) % 52
		if not (landing_track in SAFE_TRACK_INDICES):
			for other in _players:
				if not other["active"] or other["id"] == pid:
					continue
				var o_pawns: Array = other["pawns"]
				for j in 4:
					if o_pawns[j] >= 0 and o_pawns[j] <= 50:
						var ot: int = (int(START_OFFSETS[int(other["id"])]) + int(o_pawns[j])) % 52
						if ot == landing_track:
							o_pawns[j] = -1
							captured_any = true
							AudioManager.play("capture")
							VisualEffects3D.spawn_spark_burst(_world, pawn_root.position, Color(1.0, 0.35, 0.25), 28)
							var cap_node: Node3D = _pawn_nodes[other["id"]][j]["root"]
							var yard_pos := _progress_to_world(other["id"], -1, j)
							_hop_node(cap_node, yard_pos, 0.38, 1.8)
							if other["is_ai"]:
								NetworkManager.trigger_bot_reaction(str(other["name"]), "captured", int(other["id"]))

	if new_prog == 56:
		VisualEffects3D.spawn_spark_burst(_world, pawn_root.position, Color(1.0, 0.90, 0.35), 34)

	_refresh_all_pawn_transforms(true)
	_update_hud()

	var finished_count := 0
	for pr in pawns:
		if pr == 56:
			finished_count += 1
	if finished_count == 4:
		_on_game_won(pid)
		return

	if _rolled_val == 6 or captured_any or new_prog == 56:
		_status_lbl.text = "جایزه! یک تاس اضافه برای %s 🎉" % str(_players[pid]["name"])
		await get_tree().create_timer(0.50).timeout
		_begin_turn()
	else:
		_advance_turn()


func _hop_node(node: Node3D, target_pos: Vector3, dur: float, arc_h: float) -> void:
	var start_pos := node.position
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var pos := start_pos.lerp(target_pos, t)
		pos.y += sin(t * PI) * arc_h
		node.position = pos
	, 0.0, 1.0, dur)
	await tw.finished
	node.position = target_pos


func _advance_turn() -> void:
	_consecutive_sixes = 0
	_turn_ptr = (_turn_ptr + 1) % _active_player_indices.size()
	_begin_turn()


func _progress_to_world(pid: int, prog: int, pawn_idx: int) -> Vector3:
	if prog == -1:
		var base: Vector2 = YARD_ORIGINS[pid] + YARD_SLOTS[pawn_idx]
		return Vector3(-7.5 + base.x, 0.03, -7.5 + base.y)
	elif prog <= 50:
		var t_idx: int = (int(START_OFFSETS[pid]) + prog) % 52
		var cell: Vector2i = TRACK_CELLS[t_idx]
		return Vector3(-7.5 + cell.x + 0.5, 0.03, -7.5 + cell.y + 0.5)
	elif prog <= 55:
		var cell: Vector2i = HOME_PATHS[pid][prog - 51]
		return Vector3(-7.5 + cell.x + 0.5, 0.03, -7.5 + cell.y + 0.5)
	else:
		var c: Vector2 = HOME_FINISH_CENTERS[pid]
		var offs := [Vector2(-0.24, -0.24), Vector2(0.24, -0.24), Vector2(-0.24, 0.24), Vector2(0.24, 0.24)]
		var fpos: Vector2 = c + offs[pawn_idx]
		return Vector3(-7.5 + fpos.x, 0.03, -7.5 + fpos.y)


func _refresh_all_pawn_transforms(smooth: bool) -> void:
	var buckets := {}
	for p in _players:
		if not p["active"]:
			continue
		var pid: int = p["id"]
		for idx in 4:
			var prog: int = p["pawns"][idx]
			var key := ""
			if prog == -1:
				key = "yard_%d_%d" % [pid, idx]
			elif prog <= 50:
				key = "track_%d" % ((int(START_OFFSETS[pid]) + prog) % 52)
			elif prog <= 55:
				key = "home_%d_%d" % [pid, prog]
			else:
				key = "fin_%d_%d" % [pid, idx]
			if not buckets.has(key):
				buckets[key] = []
			buckets[key].append({"pid": pid, "idx": idx, "prog": prog})

	var fan_offsets := [
		Vector3(-0.22, 0, -0.22),
		Vector3(0.22, 0, -0.22),
		Vector3(-0.22, 0, 0.22),
		Vector3(0.22, 0, 0.22),
	]

	for key in buckets:
		var group: Array = buckets[key]
		for k in range(group.size()):
			var item: Dictionary = group[k]
			var pid: int = item["pid"]
			var idx: int = item["idx"]
			var prog: int = item["prog"]
			var base_pos := _progress_to_world(pid, prog, idx)
			var offset := Vector3.ZERO
			var sc := 1.0
			if group.size() > 1:
				offset = fan_offsets[k % 4]
				sc = 0.82
			var root: Node3D = _pawn_nodes[pid][idx]["root"]
			if smooth:
				var tw := create_tween()
				tw.set_parallel(true)
				tw.tween_property(root, "position", base_pos + offset, 0.16)
				tw.tween_property(root, "scale", Vector3.ONE * sc, 0.16)
			else:
				root.position = base_pos + offset
				root.scale = Vector3.ONE * sc


func _highlight_legal_pawns(pid: int, legal: Array[int]) -> void:
	_clear_highlights()
	for idx in legal:
		_pawn_nodes[pid][idx]["ring"].visible = true
		_pawn_nodes[pid][idx]["beacon"].visible = true


func _clear_highlights() -> void:
	for pid in _pawn_nodes:
		for item in _pawn_nodes[pid]:
			item["ring"].visible = false
			item["beacon"].visible = false
			item["mesh"].position.y = 0.0


func _process(delta: float) -> void:
	_pulse_time += delta * 5.6
	if _phase == Phase.WAIT_SELECT:
		var pid: int = _current_player()["id"]
		for idx in _legal_pawns:
			var item: Dictionary = _pawn_nodes[pid][idx]
			var ring: MeshInstance3D = item["ring"]
			var s := 1.0 + sin(_pulse_time) * 0.18
			ring.scale = Vector3(s, 1.0, s)
			item["mesh"].position.y = absf(sin(_pulse_time * 0.85)) * 0.24
			item["beacon"].position.y = 1.55 + sin(_pulse_time * 1.2) * 0.16


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and _phase == Phase.WAIT_ROLL and not _current_player()["is_ai"]:
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
			_handle_board_tap(_local_to_vp(mb.position))


func _handle_board_tap(vp_pos: Vector2) -> void:
	if _phase != Phase.WAIT_SELECT or _current_player()["is_ai"]:
		return
	var pid: int = _current_player()["id"]

	# 1. Exact 2D screen-space match against every legal pawn's projected pixel position
	var best_idx := -1
	var best_px_dist := 64.0 * (float(_viewport.size.x) / 540.0)
	for idx in _legal_pawns:
		var ppos: Vector3 = _pawn_nodes[pid][idx]["root"].global_position + Vector3(0, 0.55, 0)
		var screen_pt := _camera.unproject_position(ppos)
		var d := vp_pos.distance_to(screen_pt)
		if d < best_px_dist:
			best_px_dist = d
			best_idx = idx

	# 2. Board-plane raycast fallback
	if best_idx == -1:
		var ray_origin := _camera.project_ray_origin(vp_pos)
		var ray_dir := _camera.project_ray_normal(vp_pos)
		if absf(ray_dir.y) > 0.001:
			var t := (0.35 - ray_origin.y) / ray_dir.y
			if t > 0.0:
				var hit := ray_origin + ray_dir * t
				var best_d := 1.45
				for idx in _legal_pawns:
					var ppos2: Vector3 = _pawn_nodes[pid][idx]["root"].global_position
					var d2 := Vector2(hit.x - ppos2.x, hit.z - ppos2.z).length()
					if d2 < best_d:
						best_d = d2
						best_idx = idx

	if best_idx != -1:
		AudioManager.play("ui_click")
		_execute_move(pid, best_idx)


func _update_hud() -> void:
	var cur_pid: int = _current_player()["id"]
	_roll_btn.disabled = (_phase != Phase.WAIT_ROLL) or bool(_current_player()["is_ai"])

	for pid in _player_cards:
		var c: Dictionary = _player_cards[pid]
		var panel: PanelContainer = c["panel"]
		var is_turn: bool = (pid == cur_pid)
		var bg := Color(0.24, 0.17, 0.10, 0.96) if is_turn else ThemeHelper.COL_PANEL_GLASS
		var bd: Color = _players[pid]["color"].lightened(0.28) if is_turn else ThemeHelper.COL_GOLD_DIM
		panel.add_theme_stylebox_override("panel", ThemeHelper.make_box(bg, bd, 3 if is_turn else 1, 12, 10, 6, 6 if is_turn else 0))

		var fin := 0
		for pr in _players[pid]["pawns"]:
			if pr == 56:
				fin += 1
		c["prog"].text = "%d/۴" % fin


func _on_game_won(winner_pid: int) -> void:
	_phase = Phase.GAME_OVER
	AudioManager.play("win", 0.0)
	VisualEffects3D.spawn_spark_burst(_world, Vector3(0, 1.0, 0), Color(1.0, 0.88, 0.30), 60)
	var winner: Dictionary = _players[winner_pid]
	var local_won := (winner_pid == 0)
	var reward := GameState.record_match_result("mench", local_won)
	if not local_won and winner["is_ai"]:
		NetworkManager.trigger_bot_reaction(str(winner["name"]), "win", winner_pid)

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

	vb.add_child(ThemeHelper.make_label("🏆 پایان مسابقه منچ!", 23, ThemeHelper.COL_GOLD_BRIGHT, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(ThemeHelper.make_label("برنده: %s" % str(winner["name"]), 19, winner["color"].lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER))
	var delta_sign := "+" if int(reward["rating_delta"]) >= 0 else ""
	vb.add_child(ThemeHelper.make_label(
		"🪙 +%d سکه  •  ✨ +%d تجربه  •  ⭐ %s%d" % [reward["coins"], reward["xp"], delta_sign, reward["rating_delta"]],
		15,
		ThemeHelper.COL_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vb.add_child(btn_row)

	var lobby_btn := Button.new()
	lobby_btn.text = "سالن اصلی"
	lobby_btn.custom_minimum_size = Vector2(160, 48)
	lobby_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		back_to_lobby.emit()
	)
	btn_row.add_child(lobby_btn)

	var replay_btn := Button.new()
	replay_btn.text = "🎲 بازی مجدد"
	replay_btn.custom_minimum_size = Vector2(160, 48)
	ThemeHelper.style_primary_button(replay_btn, ThemeHelper.COL_EMERALD)
	replay_btn.pressed.connect(func():
		AudioManager.play("ui_click")
		restart_requested.emit()
	)
	btn_row.add_child(replay_btn)
