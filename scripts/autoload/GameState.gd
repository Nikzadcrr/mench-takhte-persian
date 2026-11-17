extends Node

signal profile_updated
signal leaderboard_updated

const SAVE_PATH := "user://save_data.json"

const AVATARS := [
	{"id": 0, "icon": "👑", "title": "تاج طلایی", "color": Color(0.85, 0.65, 0.22)},
	{"id": 1, "icon": "🦁", "title": "شیر پارسی", "color": Color(0.78, 0.26, 0.22)},
	{"id": 2, "icon": "🦅", "title": "عقاب", "color": Color(0.22, 0.52, 0.82)},
	{"id": 3, "icon": "🌙", "title": "ماه شب", "color": Color(0.48, 0.30, 0.78)},
	{"id": 4, "icon": "💎", "title": "فیروزه", "color": Color(0.14, 0.66, 0.60)},
	{"id": 5, "icon": "🔥", "title": "آتشین", "color": Color(0.86, 0.44, 0.16)},
]

var player_profile := {
	"id": "local_player",
	"name": "بازیکن پارسی",
	"avatar_id": 0,
	"coins": 1250,
	"xp": 140,
	"level": 2,
	"mench_wins": 0,
	"mench_games": 0,
	"mench_rating": 1200,
	"takhte_wins": 0,
	"takhte_games": 0,
	"takhte_rating": 1200,
	"win_streak": 0,
}

var settings := {
	"sfx_enabled": true,
	"sfx_volume": 0.85,
	"ai_difficulty": 1, # 0 = آسان, 1 = متوسط, 2 = حرفه‌ای
	"camera_preset": 0, # 0 = ایزومتریک, 1 = نمای بالا, 2 = زاویه نزدیک
}

# Offline NPC leaderboard entries (will be merged with server leaderboard when online mode is enabled)
var npc_leaderboard: Array[Dictionary] = [
	{"id": "npc_1", "name": "آرش کمانگیر", "avatar_id": 1, "mench_rating": 1680, "takhte_rating": 1740, "mench_wins": 42, "takhte_wins": 55, "level": 14},
	{"id": "npc_2", "name": "شیرین نردباز", "avatar_id": 4, "mench_rating": 1540, "takhte_rating": 1820, "mench_wins": 31, "takhte_wins": 64, "level": 16},
	{"id": "npc_3", "name": "سهراب قهرمان", "avatar_id": 0, "mench_rating": 1760, "takhte_rating": 1490, "mench_wins": 58, "takhte_wins": 29, "level": 15},
	{"id": "npc_4", "name": "نیلوفر", "avatar_id": 3, "mench_rating": 1480, "takhte_rating": 1530, "mench_wins": 27, "takhte_wins": 33, "level": 11},
	{"id": "npc_5", "name": "کاوه آهنگر", "avatar_id": 5, "mench_rating": 1410, "takhte_rating": 1610, "mench_wins": 24, "takhte_wins": 41, "level": 12},
	{"id": "npc_6", "name": "پارسا", "avatar_id": 2, "mench_rating": 1350, "takhte_rating": 1390, "mench_wins": 19, "takhte_wins": 22, "level": 9},
	{"id": "npc_7", "name": "مهسا", "avatar_id": 4, "mench_rating": 1290, "takhte_rating": 1310, "mench_wins": 16, "takhte_wins": 18, "level": 8},
	{"id": "npc_8", "name": "رضا شیرازی", "avatar_id": 1, "mench_rating": 1240, "takhte_rating": 1275, "mench_wins": 13, "takhte_wins": 15, "level": 6},
	{"id": "npc_9", "name": "سارا", "avatar_id": 3, "mench_rating": 1180, "takhte_rating": 1210, "mench_wins": 9, "takhte_wins": 11, "level": 5},
	{"id": "npc_10", "name": "امیرحسین", "avatar_id": 2, "mench_rating": 1120, "takhte_rating": 1160, "mench_wins": 7, "takhte_wins": 8, "level": 4},
]

# Active match configuration passed from Lobby to Game scenes
var match_config := {
	"game_type": "mench", # "mench" or "takhte"
	"player_count": 4,    # 2, 3, 4 for Mench
	"mode": "vs_ai",      # "vs_ai" or "local_pvp"
	"ai_difficulty": 1,
}


func _ready() -> void:
	load_data()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if parsed.has("profile") and typeof(parsed["profile"]) == TYPE_DICTIONARY:
		for k in player_profile.keys():
			if parsed["profile"].has(k):
				player_profile[k] = parsed["profile"][k]
	if parsed.has("settings") and typeof(parsed["settings"]) == TYPE_DICTIONARY:
		for k in settings.keys():
			if parsed["settings"].has(k):
				settings[k] = parsed["settings"][k]


func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	var payload := {
		"profile": player_profile,
		"settings": settings,
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func update_profile(new_name: String, new_avatar_id: int) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed.length() >= 2:
		player_profile["name"] = trimmed
	player_profile["avatar_id"] = clampi(new_avatar_id, 0, AVATARS.size() - 1)
	save_data()
	profile_updated.emit()
	leaderboard_updated.emit()


func record_match_result(game_type: String, did_win: bool) -> Dictionary:
	var coin_reward := 0
	var xp_reward := 0
	var rating_delta := 0

	if game_type == "mench":
		player_profile["mench_games"] = int(player_profile["mench_games"]) + 1
		if did_win:
			player_profile["mench_wins"] = int(player_profile["mench_wins"]) + 1
			rating_delta = 35
			coin_reward = 250
			xp_reward = 120
			player_profile["win_streak"] = int(player_profile["win_streak"]) + 1
		else:
			rating_delta = -12
			coin_reward = 60
			xp_reward = 45
			player_profile["win_streak"] = 0
		player_profile["mench_rating"] = maxi(800, int(player_profile["mench_rating"]) + rating_delta)
	else:
		player_profile["takhte_games"] = int(player_profile["takhte_games"]) + 1
		if did_win:
			player_profile["takhte_wins"] = int(player_profile["takhte_wins"]) + 1
			rating_delta = 40
			coin_reward = 300
			xp_reward = 140
			player_profile["win_streak"] = int(player_profile["win_streak"]) + 1
		else:
			rating_delta = -15
			coin_reward = 75
			xp_reward = 50
			player_profile["win_streak"] = 0
		player_profile["takhte_rating"] = maxi(800, int(player_profile["takhte_rating"]) + rating_delta)

	player_profile["coins"] = int(player_profile["coins"]) + coin_reward
	player_profile["xp"] = int(player_profile["xp"]) + xp_reward
	var needed_xp := int(player_profile["level"]) * 200
	while int(player_profile["xp"]) >= needed_xp:
		player_profile["xp"] = int(player_profile["xp"]) - needed_xp
		player_profile["level"] = int(player_profile["level"]) + 1
		needed_xp = int(player_profile["level"]) * 200

	save_data()
	profile_updated.emit()
	leaderboard_updated.emit()
	return {
		"coins": coin_reward,
		"xp": xp_reward,
		"rating_delta": rating_delta,
	}


func get_avatar(avatar_id: int) -> Dictionary:
	return AVATARS[clampi(avatar_id, 0, AVATARS.size() - 1)]


func get_leaderboard(category: String = "overall") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for npc in npc_leaderboard:
		entries.append(npc.duplicate())

	entries.append({
		"id": "local_player",
		"name": str(player_profile["name"]),
		"avatar_id": int(player_profile["avatar_id"]),
		"mench_rating": int(player_profile["mench_rating"]),
		"takhte_rating": int(player_profile["takhte_rating"]),
		"mench_wins": int(player_profile["mench_wins"]),
		"takhte_wins": int(player_profile["takhte_wins"]),
		"level": int(player_profile["level"]),
		"is_local": true,
	})

	for e in entries:
		if category == "mench":
			e["score"] = int(e["mench_rating"])
			e["wins"] = int(e["mench_wins"])
		elif category == "takhte":
			e["score"] = int(e["takhte_rating"])
			e["wins"] = int(e["takhte_wins"])
		else:
			e["score"] = int((int(e["mench_rating"]) + int(e["takhte_rating"])) / 2.0)
			e["wins"] = int(e["mench_wins"]) + int(e["takhte_wins"])

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"])
	)
	return entries
