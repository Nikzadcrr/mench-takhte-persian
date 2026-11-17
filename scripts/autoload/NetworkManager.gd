extends Node

## Online-ready networking & social transport layer.
## Currently runs in OFFLINE_LOCAL mode for full local testing & AI opponents.
## Phase 2 will plug WebSocketPeer / ENetMultiplayerPeer directly into this API
## without modifying MenchGame or TakhteNardGame logic.

enum Mode {
	OFFLINE_LOCAL,
	ONLINE_WEBSOCKET,
}

signal connection_state_changed(is_online: bool, status_text: String)
signal chat_message_received(channel: String, message: Dictionary)
signal emote_received(sender_name: String, emote: String, player_index: int)
signal game_action_received(action: Dictionary)

var current_mode: Mode = Mode.OFFLINE_LOCAL
var current_room_id: String = "OFFLINE-LOCAL"
var chat_history := {
	"lobby": [],
	"match": [],
}

const BOT_NAMES := ["آرش", "شیرین", "سهراب", "نیلوفر", "کاوه"]

const BOT_CHAT_REACTIONS := {
	"greeting": ["سلام به همه! آماده بازی هستید؟ 🎲", "خوش اومدی! بریم یه دست جذاب بزنیم 🔥", "سلام! موفق باشی دوست من 👋"],
	"captured": ["آخ! مهره‌ام رو زدی 😅", "ای بابا! جبران می‌کنم 💪", "عجب شانسی آوردی! 😮"],
	"big_roll": ["تاس جفت و عالی! 🎲✨", "ببین چه تاسی اومد! 🔥", "خدا رحم کنه به حریف 😄"],
	"win": ["بازی عالی بود! دستت درد نکنه 👏", "خسته نباشی! یه دست دیگه بزنیم؟ 🏆"],
	"reply": ["موافقم! 😄", "حله، بریم جلو 👍", "ایول به تو ✨", "الان نوبت من بشه می‌بینی 😉", "دمت گرم! 🎲"],
}


func _ready() -> void:
	# Seed welcoming offline lobby messages so the chat room feels alive immediately
	_push_system_chat("lobby", "به سالن کلاسیک منچ و تخته نرد خوش آمدید! (حالت آفلاین فعال است — آماده اتصال آنلاین در مرحله بعد)")
	_push_bot_chat("lobby", "شیرین نردباز", "سلام! کسی پایه یه دست تخته نرد یا منچ هست؟ 🎲")
	_push_bot_chat("lobby", "آرش کمانگیر", "لیدربورد این هفته خیلی داغه، رکورد منو نمی‌تونید بزنید 😄")


func is_online() -> bool:
	return current_mode == Mode.ONLINE_WEBSOCKET


func get_status_label() -> String:
	if is_online():
		return "آنلاین — متصل"
	return "آفلاین (قابل تست لوکال)"


func clear_match_chat() -> void:
	chat_history["match"] = []
	_push_system_chat("match", "بازی شروع شد! از اینجا می‌تونید چت کنید یا ایموجی بفرستید.")


func send_chat(channel: String, text: String) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	var msg := {
		"sender": str(GameState.player_profile["name"]),
		"avatar_id": int(GameState.player_profile["avatar_id"]),
		"text": clean,
		"is_local": true,
		"is_system": false,
		"time": _now_str(),
	}
	_store_and_emit_chat(channel, msg)

	# In offline mode, occasionally generate a playful bot reply after a brief delay
	if current_mode == Mode.OFFLINE_LOCAL:
		var delay := randf_range(0.9, 1.8)
		get_tree().create_timer(delay).timeout.connect(func():
			var bot: String = BOT_NAMES[randi() % BOT_NAMES.size()]
			var pool: Array = BOT_CHAT_REACTIONS["greeting"] if ("سلام" in clean) else BOT_CHAT_REACTIONS["reply"]
			var reply_text: String = pool[randi() % pool.size()]
			_push_bot_chat(channel, bot, reply_text)
		)


func send_emote(emote: String, player_index: int = 0) -> void:
	var sender := str(GameState.player_profile["name"])
	emote_received.emit(sender, emote, player_index)
	AudioManager.play("chat_ping", 0.08)


func trigger_bot_reaction(bot_name: String, event_key: String, player_index: int = 1) -> void:
	if current_mode != Mode.OFFLINE_LOCAL:
		return
	if randf() > 0.58 and event_key != "win":
		return
	var pool: Array = BOT_CHAT_REACTIONS.get(event_key, BOT_CHAT_REACTIONS["reply"])
	var text: String = pool[randi() % pool.size()]
	_push_bot_chat("match", bot_name, text)
	var emotes := {"captured": "😱", "big_roll": "🔥", "win": "🏆", "greeting": "👋"}
	if emotes.has(event_key):
		emote_received.emit(bot_name, emotes[event_key], player_index)


func send_game_action(action: Dictionary) -> void:
	# Serializable action packet ready for future WebSocket relay
	action["room_id"] = current_room_id
	action["sender_id"] = GameState.player_profile["id"]
	if current_mode == Mode.OFFLINE_LOCAL:
		game_action_received.emit(action)


func _push_system_chat(channel: String, text: String) -> void:
	var msg := {
		"sender": "سیستم",
		"avatar_id": -1,
		"text": text,
		"is_local": false,
		"is_system": true,
		"time": _now_str(),
	}
	_store_and_emit_chat(channel, msg)


func _push_bot_chat(channel: String, bot_name: String, text: String) -> void:
	var msg := {
		"sender": bot_name,
		"avatar_id": abs(bot_name.hash()) % GameState.AVATARS.size(),
		"text": text,
		"is_local": false,
		"is_system": false,
		"time": _now_str(),
	}
	_store_and_emit_chat(channel, msg)
	AudioManager.play("chat_ping", 0.05)


func _store_and_emit_chat(channel: String, msg: Dictionary) -> void:
	if not chat_history.has(channel):
		chat_history[channel] = []
	var arr: Array = chat_history[channel]
	arr.append(msg)
	if arr.size() > 60:
		arr.pop_front()
	chat_message_received.emit(channel, msg)


func _now_str() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d" % [int(t["hour"]), int(t["minute"])]
