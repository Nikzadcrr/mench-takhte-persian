class_name ChatPanel
extends PanelContainer

signal close_requested

var channel: String = "lobby"
var _msg_container: VBoxContainer
var _scroll: ScrollContainer
var _input: LineEdit
var _show_close_btn := false

const QUICK_PHRASES := [
	"سلام! 👋",
	"ایول! 🔥",
	"تاس عالی! 🎲",
	"شانس آوردی 😄",
	"عجب حرکتی 👏",
	"خسته نباشی 🤝",
]

const EMOTES := ["😄", "🔥", "👏", "😱", "🎲", "🏆"]


func setup(p_channel: String, show_close: bool = false) -> void:
	channel = p_channel
	_show_close_btn = show_close
	_build_ui()
	_reload_history()
	if not NetworkManager.chat_message_received.is_connected(_on_chat_received):
		NetworkManager.chat_message_received.connect(_on_chat_received)


func _build_ui() -> void:
	ThemeHelper.style_card(self, ThemeHelper.COL_PANEL_GLASS, ThemeHelper.COL_GOLD, 18)
	custom_minimum_size = Vector2(280, 320)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	if _show_close_btn:
		var close_btn := Button.new()
		close_btn.text = "✕"
		close_btn.custom_minimum_size = Vector2(38, 36)
		close_btn.pressed.connect(func():
			AudioManager.play("ui_click")
			close_requested.emit()
		)
		header.add_child(close_btn)

	var status_pill := Label.new()
	status_pill.text = "● آنلاین" if NetworkManager.is_online() else "● اتاق محلی"
	status_pill.add_theme_font_size_override("font_size", 12)
	status_pill.add_theme_color_override("font_color", Color(0.35, 0.90, 0.55) if NetworkManager.is_online() else ThemeHelper.COL_GOLD)
	header.add_child(status_pill)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var title := ThemeHelper.make_label(
		"💬 گفت‌وگوی سالن" if channel == "lobby" else "💬 چت مسابقه",
		16,
		ThemeHelper.COL_GOLD_BRIGHT,
		HORIZONTAL_ALIGNMENT_RIGHT
	)
	header.add_child(title)

	# Scrollable Messages
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_msg_container = VBoxContainer.new()
	_msg_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg_container.add_theme_constant_override("separation", 6)
	_scroll.add_child(_msg_container)

	# Emote Bar (Thumb-friendly)
	var emote_row := HBoxContainer.new()
	emote_row.alignment = BoxContainer.ALIGNMENT_CENTER
	emote_row.add_theme_constant_override("separation", 6)
	root.add_child(emote_row)
	for em in EMOTES:
		var eb := Button.new()
		eb.text = em
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eb.custom_minimum_size = Vector2(0, 38)
		eb.add_theme_font_size_override("font_size", 19)
		eb.add_theme_stylebox_override("normal", ThemeHelper.make_box(Color(0.20, 0.14, 0.10, 0.92), ThemeHelper.COL_GOLD_DIM, 1, 10, 4, 2))
		eb.pressed.connect(func():
			NetworkManager.send_emote(em, 0)
			NetworkManager.send_chat(channel, em)
		)
		emote_row.add_child(eb)

	# Quick Persian Phrases
	var quick_flow := HFlowContainer.new()
	quick_flow.add_theme_constant_override("h_separation", 6)
	quick_flow.add_theme_constant_override("v_separation", 6)
	root.add_child(quick_flow)
	for phrase in QUICK_PHRASES:
		var qb := Button.new()
		qb.text = phrase
		qb.add_theme_font_size_override("font_size", 12)
		qb.add_theme_stylebox_override("normal", ThemeHelper.make_box(Color(0.18, 0.13, 0.09, 0.95), ThemeHelper.COL_GOLD_DIM, 1, 12, 9, 5))
		qb.pressed.connect(func():
			AudioManager.play("ui_click")
			NetworkManager.send_chat(channel, phrase)
		)
		quick_flow.add_child(qb)

	# Input Row (44px tall for mobile thumb!)
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 6)
	root.add_child(input_row)

	var send_btn := Button.new()
	send_btn.text = "ارسال"
	send_btn.custom_minimum_size = Vector2(78, 44)
	ThemeHelper.style_primary_button(send_btn, ThemeHelper.COL_EMERALD)
	send_btn.add_theme_font_size_override("font_size", 15)
	send_btn.pressed.connect(_submit_input)
	input_row.add_child(send_btn)

	_input = LineEdit.new()
	_input.placeholder_text = "پیام خود را بنویسید..."
	_input.custom_minimum_size = Vector2(0, 44)
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_input.text_submitted.connect(func(_t): _submit_input())
	input_row.add_child(_input)


func _submit_input() -> void:
	if _input == null:
		return
	var txt := _input.text.strip_edges()
	if txt.is_empty():
		return
	_input.text = ""
	AudioManager.play("ui_click")
	NetworkManager.send_chat(channel, txt)


func _reload_history() -> void:
	if _msg_container == null:
		return
	for c in _msg_container.get_children():
		c.queue_free()
	var arr: Array = NetworkManager.chat_history.get(channel, [])
	for msg in arr:
		_append_bubble(msg)
	_scroll_to_bottom()


func _on_chat_received(ch: String, msg: Dictionary) -> void:
	if ch != channel:
		return
	_append_bubble(msg)
	_scroll_to_bottom()


func _append_bubble(msg: Dictionary) -> void:
	if _msg_container == null:
		return
	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_sys: bool = bool(msg.get("is_system", false))
	var is_local: bool = bool(msg.get("is_local", false))
	var bg := Color(0.14, 0.25, 0.20, 0.90) if is_local else Color(0.18, 0.13, 0.10, 0.92)
	if is_sys:
		bg = Color(0.24, 0.17, 0.08, 0.78)
	var border := ThemeHelper.COL_EMERALD if is_local else ThemeHelper.COL_GOLD_DIM
	bubble.add_theme_stylebox_override("panel", ThemeHelper.make_box(bg, border, 1, 12, 11, 7))

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	bubble.add_child(vb)

	if not is_sys:
		var top := HBoxContainer.new()
		vb.add_child(top)
		top.add_child(ThemeHelper.make_label(str(msg.get("time", "")), 11, ThemeHelper.COL_TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(sp)
		var av_icon := ""
		var av_id: int = int(msg.get("avatar_id", -1))
		if av_id >= 0:
			av_icon = str(GameState.get_avatar(av_id)["icon"]) + " "
		top.add_child(ThemeHelper.make_label(
			av_icon + str(msg.get("sender", "")),
			12,
			ThemeHelper.COL_GOLD_BRIGHT if is_local else ThemeHelper.COL_GOLD,
			HORIZONTAL_ALIGNMENT_RIGHT
		))

	var body := Label.new()
	body.text = str(msg.get("text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if is_sys else HORIZONTAL_ALIGNMENT_RIGHT
	body.add_theme_font_size_override("font_size", 13 if is_sys else 14)
	body.add_theme_color_override("font_color", ThemeHelper.COL_GOLD_BRIGHT if is_sys else ThemeHelper.COL_TEXT)
	vb.add_child(body)

	_msg_container.add_child(bubble)


func _scroll_to_bottom() -> void:
	if _scroll == null or not is_inside_tree():
		return
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
