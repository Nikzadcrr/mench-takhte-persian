extends Node

func _ready() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	assert(main_scene != null, "Main.tscn failed to load")
	var main := main_scene.instantiate()
	add_child(main)
	await get_tree().process_frame

	# 1. Verify GameState & Leaderboard
	var lb: Array = GameState.get_leaderboard("overall")
	assert(lb.size() >= 10, "Leaderboard should have entries")
	print("[TEST] Lobby + Leaderboard OK (", lb.size(), " entries)")

	# 2. Verify Chat & NetworkManager
	NetworkManager.send_chat("lobby", "تست چت فارسی")
	assert(NetworkManager.chat_history["lobby"].size() >= 4, "Chat history updated")
	print("[TEST] ChatPanel / NetworkManager OK")

	# 3. Verify MenchGame launch, rules, AI choice
	main._launch_game("mench")
	await get_tree().process_frame
	var mench: MenchGame = main._active_game
	assert(mench != null, "MenchGame failed to mount")
	var legal6 := mench._get_legal_pawns(0, 6)
	assert(legal6.size() == 4, "Rolling 6 at start should allow all 4 yard pawns")
	var legal3 := mench._get_legal_pawns(0, 3)
	assert(legal3.size() == 0, "Rolling 3 at start should allow 0 yard pawns")
	print("[TEST] MenchGame 3D & rules OK")

	# 4. Verify TakhteNardGame launch, pip counts, legal moves, AI evaluation
	main._launch_game("takhte")
	await get_tree().process_frame
	var takhte: TakhteNardGame = main._active_game
	assert(takhte != null, "TakhteNardGame failed to mount")
	assert(takhte._pip_count(0) == 167, "White starting pip count must be 167")
	assert(takhte._pip_count(1) == 167, "Dark starting pip count must be 167")
	var moves_d6 := takhte._get_legal_single_moves(0, 6, takhte._points, takhte._bar)
	assert(moves_d6.size() >= 3, "White should have legal moves on roll 6")
	var ai_pick := takhte._choose_ai_move(moves_d6, 2)
	assert(ai_pick.has("from") and ai_pick.has("to"), "AI picked a valid Backgammon move")
	print("[TEST] TakhteNardGame 3D & rules OK (pips=167/167, legal_6=", moves_d6.size(), ")")

	# 5. Verify LeaderboardModal & Return to Lobby
	main._return_to_lobby()
	await get_tree().process_frame
	var lb_modal := LeaderboardModal.new()
	main.add_child(lb_modal)
	await get_tree().process_frame
	lb_modal.queue_free()
	print("[TEST] LeaderboardModal + Lobby return OK")

	print("=== ALL RUNTIME SMOKE TESTS PASSED ===")
	get_tree().quit(0)
