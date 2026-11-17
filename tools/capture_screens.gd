extends Node

const OUT_DIR := "/home/nikzad/.gemini/antigravity/brain/e77ee7da-9dcf-4c95-89f1-8c4d2146e090/scratch"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	call_deferred("_run_interactive_verification")

func _run_interactive_verification() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	var main := main_scene.instantiate()
	add_child(main)

	await _wait_frames(8)
	_save_shot("01_lobby.png")

	# --- TEST 1: MENCH INTERACTIVE PIECE MOVE VIA REAL MOUSE CLICK ---
	main._launch_game("mench")
	await _wait_frames(10)
	var mench: MenchGame = main._active_game
	# Simulate player rolling 6 so all 4 pawns become selectable & glowing!
	mench._rolled_val = 6
	mench._dice.set_face_immediate(6)
	mench._dice_badge_lbl.text = "تاس: 6"
	mench._legal_pawns = mench._get_legal_pawns(0, 6)
	mench._phase = MenchGame.Phase.WAIT_SELECT
	mench._status_lbl.text = "روی یکی از مهره‌های درخشان لمس کنید (6)"
	mench._highlight_legal_pawns(0, mench._legal_pawns)
	mench._update_hud()
	await _wait_frames(6)
	_save_shot("03_mench_selectable.png")

	# Synthesize real left-click on Pawn #0's projected screen coordinates inside _vp_container!
	var p0_world: Vector3 = mench._pawn_nodes[0][0]["root"].global_position + Vector3(0, 0.5, 0)
	var p0_vp: Vector2 = mench._camera.unproject_position(p0_world)
	var p0_local: Vector2 = (p0_vp / Vector2(mench._viewport.size)) * mench._vp_container.size
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	click_ev.position = p0_local
	mench._on_board_gui_input(click_ev)

	# Wait for hop animation to finish and verify Pawn #0 actually moved out to progress == 0!
	await get_tree().create_timer(0.55).timeout
	assert(mench._players[0]["pawns"][0] == 0, "FAIL: Mench pawn #0 did NOT move on click!")
	print("[INTERACTIVE TEST] Mench real click moved Pawn #0 -> progress=", mench._players[0]["pawns"][0])
	_save_shot("03_mench_moved.png")

	# --- TEST 2: TAKHTE NARD INTERACTIVE SELECT & MOVE VIA REAL MOUSE CLICKS ---
	main._launch_game("takhte")
	await _wait_frames(10)
	var takhte: TakhteNardGame = main._active_game
	takhte._dice_values = [5, 3]
	takhte._remaining_dice = [5, 3]
	takhte._dice_nodes[0].set_face_immediate(5)
	takhte._dice_nodes[1].set_face_immediate(3)
	takhte._phase = TakhteNardGame.Phase.PLAYER_MOVE
	takhte._auto_select_or_prompt()
	await _wait_frames(6)

	# Click Point 7 (White has 3 checkers there; 7-3=4 and 7-5=2 are both open!)
	var pt7_world: Vector3 = takhte._point_checker_pos(7, 2)
	var pt7_vp: Vector2 = takhte._camera.unproject_position(pt7_world)
	var pt7_local: Vector2 = (pt7_vp / Vector2(takhte._viewport.size)) * takhte._vp_container.size
	var c1 := InputEventMouseButton.new()
	c1.button_index = MOUSE_BUTTON_LEFT
	c1.pressed = true
	c1.position = pt7_local
	takhte._on_board_gui_input(c1)
	await _wait_frames(6)
	assert(takhte._selected_from == 7, "FAIL: Takhte Nard Point 7 did NOT select on click!")
	print("[INTERACTIVE TEST] Takhte Nard real click selected Point 7!")
	_save_shot("04_takhte_selected.png")

	# Now click destination Point 4 (7 - 3 = 4)!
	var pt4_base: Vector2 = takhte._point_base_xz(4)
	var pt4_world := Vector3(pt4_base.x, 0.12, pt4_base.y - 1.5)
	var pt4_vp: Vector2 = takhte._camera.unproject_position(pt4_world)
	var pt4_local: Vector2 = (pt4_vp / Vector2(takhte._viewport.size)) * takhte._vp_container.size
	var c2 := InputEventMouseButton.new()
	c2.button_index = MOUSE_BUTTON_LEFT
	c2.pressed = true
	c2.position = pt4_local
	takhte._on_board_gui_input(c2)
	await get_tree().create_timer(0.45).timeout
	assert(takhte._points[7] == 2 and takhte._points[4] == 1, "FAIL: Takhte Nard checker did NOT move from 7 to 4!")
	print("[INTERACTIVE TEST] Takhte Nard real click moved checker 7 -> 4! (remaining dice=", takhte._remaining_dice, ")")
	_save_shot("05_takhte_moved.png")

	print("=== ALL INTERACTIVE CLICK-TO-MOVE TESTS PASSED 100% ===")
	get_tree().quit(0)

func _wait_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save_shot(fname: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR + "/" + fname)
