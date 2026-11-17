class_name ThemeHelper
extends RefCounted

const FONT_PATH := "res://assets/fonts/Vazirmatn.ttf"

const COL_BG_DEEP := Color(0.08, 0.052, 0.036, 1.0)
const COL_PANEL := Color(0.13, 0.09, 0.068, 0.95)
const COL_PANEL_GLASS := Color(0.11, 0.078, 0.058, 0.90)
const COL_CARD := Color(0.16, 0.115, 0.085, 0.96)
const COL_GOLD := Color(0.88, 0.70, 0.28, 1.0)
const COL_GOLD_BRIGHT := Color(0.99, 0.86, 0.48, 1.0)
const COL_GOLD_DIM := Color(0.58, 0.45, 0.20, 0.88)
const COL_EMERALD := Color(0.10, 0.58, 0.42, 1.0)
const COL_CRIMSON := Color(0.76, 0.16, 0.22, 1.0)
const COL_SAPPHIRE := Color(0.18, 0.42, 0.72, 1.0)
const COL_TEXT := Color(0.98, 0.95, 0.89, 1.0)
const COL_TEXT_MUTED := Color(0.78, 0.72, 0.62, 1.0)

static var _cached_theme: Theme = null
static var _cached_font: FontFile = null
static var _sb_cache := {}


static func get_font() -> FontFile:
	if _cached_font == null and ResourceLoader.exists(FONT_PATH):
		_cached_font = load(FONT_PATH)
	return _cached_font


static func make_tex_box(tex_name: String, margin_h: float = 24.0, margin_v: float = 22.0, pad_x: float = 14.0, pad_y: float = 10.0) -> StyleBox:
	var key := "%s_%d_%d_%d_%d" % [tex_name, int(margin_h), int(margin_v), int(pad_x), int(pad_y)]
	if _sb_cache.has(key):
		return _sb_cache[key]
	var path := "res://assets/ui/%s.png" % tex_name
	if ResourceLoader.exists(path):
		var sb := StyleBoxTexture.new()
		sb.texture = load(path)
		sb.texture_margin_left = margin_h
		sb.texture_margin_right = margin_h
		sb.texture_margin_top = margin_v
		sb.texture_margin_bottom = margin_v
		sb.content_margin_left = pad_x
		sb.content_margin_right = pad_x
		sb.content_margin_top = pad_y
		sb.content_margin_bottom = pad_y
		_sb_cache[key] = sb
		return sb
	return make_box(COL_CARD, COL_GOLD_DIM, 2, 14, int(pad_x), int(pad_y))


static func get_theme() -> Theme:
	if _cached_theme != null:
		return _cached_theme

	var t := Theme.new()
	var font := get_font()
	if font:
		t.default_font = font
	t.default_font_size = 16

	# Tactile 3D Glossy Dark Walnut Buttons by default
	t.set_stylebox("normal", "Button", make_tex_box("btn_dark", 24, 22, 12, 8))
	t.set_stylebox("hover", "Button", make_tex_box("btn_dark_hover", 24, 22, 12, 8))
	t.set_stylebox("pressed", "Button", make_tex_box("btn_dark_pressed", 24, 22, 12, 10))
	t.set_stylebox("disabled", "Button", make_box(Color(0.14, 0.11, 0.09, 0.55), Color(0.35, 0.28, 0.20, 0.35), 1, 14, 12, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", COL_GOLD_BRIGHT)
	t.set_color("font_pressed_color", "Button", COL_GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.50, 0.45, 0.65))
	t.set_color("font_outline_color", "Button", Color(0.05, 0.03, 0.02, 0.85))
	t.set_constant("outline_size", "Button", 2)

	# Labels with crisp subtle shadow for AAA mobile legibility
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0.02, 0.01, 0.005, 0.72))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)

	# PanelContainer
	t.set_stylebox("panel", "PanelContainer", make_tex_box("panel_glass", 26, 26, 14, 12))

	# LineEdit
	t.set_stylebox("normal", "LineEdit", make_box(Color(0.08, 0.055, 0.04, 0.96), COL_GOLD_DIM, 1, 12, 12, 8))
	t.set_stylebox("focus", "LineEdit", make_box(Color(0.11, 0.075, 0.055, 1.0), COL_GOLD_BRIGHT, 2, 12, 12, 8))
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(0.64, 0.58, 0.50, 0.82))
	t.set_color("caret_color", "LineEdit", COL_GOLD_BRIGHT)

	# OptionButton (crisp bevelled dark walnut dropdown without 9-slice pinch on compact height)
	t.set_stylebox("normal", "OptionButton", make_box(Color(0.20, 0.14, 0.095, 0.96), COL_GOLD_DIM, 2, 11, 10, 6, 3))
	t.set_stylebox("hover", "OptionButton", make_box(Color(0.27, 0.19, 0.13, 1.0), COL_GOLD_BRIGHT, 2, 11, 10, 6, 4))
	t.set_stylebox("pressed", "OptionButton", make_box(Color(0.15, 0.10, 0.07, 1.0), COL_GOLD, 2, 11, 10, 6, 1))
	t.set_color("font_color", "OptionButton", COL_TEXT)

	# PopupMenu
	t.set_stylebox("panel", "PopupMenu", make_tex_box("panel_card", 24, 24, 8, 8))
	t.set_color("font_color", "PopupMenu", COL_TEXT)
	t.set_color("font_hover_color", "PopupMenu", COL_GOLD_BRIGHT)

	_cached_theme = t
	return t


static func make_box(
	bg: Color,
	border: Color = Color(0, 0, 0, 0),
	border_w: int = 0,
	radius: int = 12,
	pad_x: int = 12,
	pad_y: int = 10,
	shadow_size: int = 0
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	if shadow_size > 0:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = shadow_size
		sb.shadow_offset = Vector2(0, 4)
	return sb


static func style_primary_button(btn: Button, accent: Color = COL_GOLD) -> void:
	var prefix := "btn_gold"
	if accent.is_equal_approx(COL_EMERALD):
		prefix = "btn_emerald"
	elif accent.is_equal_approx(COL_CRIMSON):
		prefix = "btn_crimson"

	btn.add_theme_stylebox_override("normal", make_tex_box(prefix, 24, 22, 16, 9))
	btn.add_theme_stylebox_override("hover", make_tex_box(prefix + "_hover", 24, 22, 16, 9))
	btn.add_theme_stylebox_override("pressed", make_tex_box(prefix + "_pressed", 24, 22, 16, 11))
	btn.add_theme_stylebox_override("disabled", make_box(Color(0.20, 0.16, 0.13, 0.65), Color(0.42, 0.35, 0.26, 0.45), 1, 16, 16, 9))

	var txt_col := Color(0.14, 0.08, 0.02) if prefix == "btn_gold" else Color(1, 0.98, 0.94)
	var out_col := Color(1.0, 0.94, 0.72, 0.55) if prefix == "btn_gold" else Color(0.05, 0.02, 0.01, 0.85)
	btn.add_theme_color_override("font_color", txt_col)
	btn.add_theme_color_override("font_hover_color", txt_col)
	btn.add_theme_color_override("font_pressed_color", txt_col)
	btn.add_theme_color_override("font_outline_color", out_col)
	btn.add_theme_constant_override("outline_size", 2)
	btn.add_theme_font_size_override("font_size", 17)


static func style_card(panel: PanelContainer, bg: Color = COL_CARD, border: Color = COL_GOLD_DIM, _radius: int = 18) -> void:
	if border.is_equal_approx(COL_GOLD_BRIGHT):
		panel.add_theme_stylebox_override("panel", make_tex_box("panel_active", 26, 26, 14, 12))
	elif bg.is_equal_approx(COL_PANEL_GLASS):
		panel.add_theme_stylebox_override("panel", make_tex_box("panel_glass", 26, 26, 14, 12))
	else:
		panel.add_theme_stylebox_override("panel", make_tex_box("panel_card", 26, 26, 14, 12))


static func make_label(text: String, font_size: int = 16, color: Color = COL_TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = align
	lbl.text_direction = Control.TEXT_DIRECTION_AUTO
	return lbl
