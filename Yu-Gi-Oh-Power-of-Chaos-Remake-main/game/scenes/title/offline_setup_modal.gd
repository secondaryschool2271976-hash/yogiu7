extends CanvasLayer
## Offline duel setup overlay & modal: opponent difficulty & ready-made preset decks per character.
## Uses touch-safe in-scene selection modals (never native OptionButton popups that freeze on Android).

signal closed

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")

const CHAR_NAMES := {
	"yugi": {"a": "يوغي (Yugi)", "s": "Yugi", "e": "Yugi"},
	"kaiba": {"a": "كايبا (Kaiba)", "s": "Kaiba", "e": "Kaiba"},
	"joey": {"a": "جوي (Joey)", "s": "Joey", "e": "Joey"},
}

const DIFFICULTY_OPTIONS := [
	{"id": "auto", "a": "تلقائي (التدرج الأصلي)", "s": "Automático (Original)", "e": "Auto (Classic Progression)"},
	{"id": "easy", "a": "سهل (مبتدئ)", "s": "Fácil (Principiante)", "e": "Easy (Beginner)"},
	{"id": "normal", "a": "متوسط (عادي)", "s": "Normal", "e": "Normal"},
	{"id": "hard", "a": "صعب (محترف)", "s": "Difícil (Pro)", "e": "Hard (Pro)"},
	{"id": "expert", "a": "أسطوري (أقصى صعوبة)", "s": "Experto (Máximo)", "e": "Expert (Master)"},
]

var _game := "joey"
var _modal_open := false
var _allow_trigger := false
var _trigger_pressed := false
var _trigger_btn := Button.new()
var _trigger_normal: StyleBoxFlat
var _trigger_hover: StyleBoxFlat
var _trigger_press: StyleBoxFlat
var _backdrop: ColorRect
var _panel: PanelContainer
var _title_lbl: Label
var _subtitle_lbl: Label
var _diff_lbl: Label
var _diff_btn: Button
var _rival_lbl: Label
var _rival_btn: Button
var _player_lbl: Label
var _player_btn: Button
var _note_lbl: Label
var _reset_btn: Button
var _save_btn: Button
var _close_btn: Button

var _diff_items: Array[Dictionary] = []
var _rival_items: Array[Dictionary] = []
var _player_items: Array[Dictionary] = []
var _diff_selected := 0
var _rival_selected := 0
var _player_selected := 0

# Touch-safe in-scene picker overlay (replaces OptionButton popup that freezes Android).
var _picker_layer: CanvasLayer = null
var _picker_backdrop: ColorRect = null
var _picker_panel: PanelContainer = null
var _picker_title: Label = null
var _picker_list: VBoxContainer = null
var _picker_open := false
var _picker_kind := ""


func setup(game_id: String) -> void:
	_game = game_id if game_id in ["yugi", "kaiba", "joey"] else "joey"
	_refresh_trigger_label()


func _ready() -> void:
	layer = 96
	_build_trigger()
	_build_modal()
	_build_picker_overlay()
	_refresh_trigger_label()
	if get_viewport() != null:
		get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	if _picker_layer != null and is_instance_valid(_picker_layer):
		_picker_layer.queue_free()
		_picker_layer = null


func _lang() -> String:
	var l: String = Assets.lang if is_instance_valid(Assets) else "e"
	return l if l in ["a", "s", "e"] else "e"


func _tr(a: String, s: String, e: String) -> String:
	var l := _lang()
	if l == "a":
		return a
	if l == "s":
		return s
	return e


func _style_box(bg: Color, border: Color, radius := 10, border_w := 2, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb


func _style_button(btn: Button, primary := false) -> void:
	var bg := Color(0.16, 0.24, 0.44, 0.98) if primary else DialogTheme.SURFACE
	var bg_hover := Color(0.22, 0.34, 0.58, 1.0) if primary else DialogTheme.SURFACE_HOVER
	var border := DialogTheme.GOLD if primary else Color(DialogTheme.CYAN, 0.58)
	btn.add_theme_stylebox_override("normal", _style_box(bg, border, 8, 2 if primary else 1, 8))
	btn.add_theme_stylebox_override("hover", _style_box(bg_hover, DialogTheme.GOLD, 8, 2, 8))
	btn.add_theme_stylebox_override("pressed", _style_box(bg.darkened(0.15), DialogTheme.GOLD, 8, 2, 8))
	btn.add_theme_stylebox_override("focus", _style_box(bg_hover, DialogTheme.GOLD, 8, 2, 8))
	btn.add_theme_font_override("font", Assets.ui_font(700))
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.focus_mode = Control.FOCUS_NONE


func _style_selector_button(btn: Button) -> void:
	_style_button(btn, false)
	btn.custom_minimum_size = Vector2(490, 42)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT if _lang() == "a" else HORIZONTAL_ALIGNMENT_LEFT
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_trigger() -> void:
	var mobile: bool = OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"
	_trigger_btn.focus_mode = Control.FOCUS_NONE
	_trigger_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trigger_btn.size = Vector2(218, 44) if mobile else Vector2(204, 36)
	_trigger_btn.add_theme_font_override("font", Assets.ui_font(700))
	_trigger_btn.add_theme_font_size_override("font_size", 15 if mobile else 14)
	_trigger_btn.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_trigger_normal = _style_box(Color(0.08, 0.11, 0.22, 0.94), Color(0.95, 0.78, 0.34, 0.95), 9, 2, 6)
	_trigger_hover = _style_box(Color(0.14, 0.20, 0.36, 0.98), Color(1.0, 0.88, 0.48, 1.0), 9, 2, 6)
	_trigger_press = _style_box(Color(0.06, 0.08, 0.16, 0.98), Color(1.0, 0.90, 0.54, 1.0), 9, 2, 6)
	_trigger_btn.add_theme_stylebox_override("normal", _trigger_normal)
	_trigger_btn.add_theme_stylebox_override("hover", _trigger_hover)
	_trigger_btn.add_theme_stylebox_override("pressed", _trigger_press)
	_trigger_btn.hide()
	add_child(_trigger_btn)


func _refresh_trigger_label() -> void:
	if _trigger_btn == null:
		return
	var custom_active := false
	if is_instance_valid(LauncherSettings):
		custom_active = LauncherSettings.get_offline_difficulty(_game) != "auto" \
			or LauncherSettings.get_offline_rival_deck(_game) != "" \
			or LauncherSettings.get_offline_player_deck(_game) != ""
	var prefix := "★ " if custom_active else "⚙ "
	_trigger_btn.text = prefix + _tr("الصعوبة والمجموعات", "Dificultad y Mazos", "Difficulty & Decks")


func _build_modal() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.01, 0.015, 0.04, 0.80)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			close_modal())
	_backdrop.hide()
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_sb := _style_box(DialogTheme.BACKGROUND, DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.65), 14, 2, 20)
	panel_sb.shadow_color = Color(0, 0, 0, 0.72)
	panel_sb.shadow_size = 20
	panel_sb.shadow_offset = Vector2(0, 8)
	_panel.add_theme_stylebox_override("panel", panel_sb)
	_panel.hide()
	add_child(_panel)

	var root_box := VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 12)
	_panel.add_child(root_box)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	root_box.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.custom_minimum_size = Vector2(440, 0)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_lbl.add_theme_font_override("font", Assets.ui_font(700))
	_title_lbl.add_theme_font_size_override("font_size", 20)
	_title_lbl.add_theme_color_override("font_color", DialogTheme.GOLD)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title_lbl.add_theme_constant_override("outline_size", 4)
	header.add_child(_title_lbl)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(40, 40)
	_style_button(_close_btn, false)
	_close_btn.pressed.connect(close_modal)
	header.add_child(_close_btn)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.custom_minimum_size = Vector2(500, 0)
	_subtitle_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_lbl.add_theme_font_override("font", Assets.ui_font(400))
	_subtitle_lbl.add_theme_font_size_override("font_size", 14)
	_subtitle_lbl.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	root_box.add_child(_subtitle_lbl)

	var sep := HSeparator.new()
	sep.modulate = Color(DialogTheme.GOLD, 0.35)
	root_box.add_child(sep)

	_diff_lbl = _make_field_label()
	root_box.add_child(_diff_lbl)
	_diff_btn = Button.new()
	_style_selector_button(_diff_btn)
	_diff_btn.pressed.connect(func() -> void: _open_picker("diff"))
	root_box.add_child(_diff_btn)

	_rival_lbl = _make_field_label()
	root_box.add_child(_rival_lbl)
	_rival_btn = Button.new()
	_style_selector_button(_rival_btn)
	_rival_btn.pressed.connect(func() -> void: _open_picker("rival"))
	root_box.add_child(_rival_btn)

	_player_lbl = _make_field_label()
	root_box.add_child(_player_lbl)
	_player_btn = Button.new()
	_style_selector_button(_player_btn)
	_player_btn.pressed.connect(func() -> void: _open_picker("player"))
	root_box.add_child(_player_btn)

	_note_lbl = Label.new()
	_note_lbl.custom_minimum_size = Vector2(500, 0)
	_note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_lbl.add_theme_font_override("font", Assets.ui_font(400))
	_note_lbl.add_theme_font_size_override("font_size", 13)
	_note_lbl.add_theme_color_override("font_color", Color(0.84, 0.88, 0.96, 0.85))
	root_box.add_child(_note_lbl)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	root_box.add_child(actions)

	_reset_btn = Button.new()
	_reset_btn.custom_minimum_size = Vector2(150, 42)
	_style_button(_reset_btn, false)
	_reset_btn.pressed.connect(_on_reset)
	actions.add_child(_reset_btn)

	_save_btn = Button.new()
	_save_btn.custom_minimum_size = Vector2(160, 42)
	_style_button(_save_btn, true)
	_save_btn.pressed.connect(_on_save)
	actions.add_child(_save_btn)


func _build_picker_overlay() -> void:
	_picker_layer = CanvasLayer.new()
	_picker_layer.layer = 98
	add_child(_picker_layer)

	_picker_backdrop = ColorRect.new()
	_picker_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker_backdrop.color = Color(0.01, 0.015, 0.04, 0.72)
	_picker_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_picker())
	_picker_backdrop.hide()
	_picker_layer.add_child(_picker_backdrop)

	_picker_panel = PanelContainer.new()
	_picker_panel.custom_minimum_size = Vector2(520, 0)
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := _style_box(DialogTheme.BACKGROUND, DialogTheme.GOLD, 14, 2, 16)
	sb.shadow_color = Color(0, 0, 0, 0.78)
	sb.shadow_size = 24
	_picker_panel.add_theme_stylebox_override("panel", sb)
	_picker_panel.hide()
	_picker_layer.add_child(_picker_panel)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	_picker_panel.add_child(vbox)

	var hdr := HBoxContainer.new()
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_theme_constant_override("separation", 8)
	vbox.add_child(hdr)

	_picker_title = Label.new()
	_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_picker_title.add_theme_font_override("font", Assets.ui_font(700))
	_picker_title.add_theme_font_size_override("font_size", 18)
	_picker_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	hdr.add_child(_picker_title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	_style_button(close_btn, false)
	close_btn.pressed.connect(_close_picker)
	hdr.add_child(close_btn)

	var sep := HSeparator.new()
	sep.modulate = Color(DialogTheme.GOLD, 0.35)
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 320)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_picker_list = VBoxContainer.new()
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_picker_list)


func _open_picker(kind: String) -> void:
	_picker_kind = kind
	var items: Array[Dictionary] = []
	var selected := 0
	if kind == "diff":
		items = _diff_items
		selected = _diff_selected
		_picker_title.text = _diff_lbl.text
	elif kind == "rival":
		items = _rival_items
		selected = _rival_selected
		_picker_title.text = _rival_lbl.text
	else:
		items = _player_items
		selected = _player_selected
		_picker_title.text = _player_lbl.text

	var rtl := _lang() == "a"
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	for child in _picker_list.get_children():
		child.queue_free()

	var radio_on := DialogTheme.radio_icon(true)
	var radio_off := DialogTheme.radio_icon(false)
	for i in items.size():
		var is_sel: bool = i == selected
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size = Vector2(0, 46)
		row.text = str(items[i].get("label", ""))
		row.icon = radio_on if is_sel else radio_off
		row.alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
		row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_theme_font_override("font", Assets.ui_font(700))
		row.add_theme_font_size_override("font_size", 15)
		row.add_theme_color_override("font_color", Color.WHITE if is_sel else DialogTheme.GOLD_LIGHT)
		row.add_theme_color_override("font_hover_color", Color.WHITE)
		var bg := Color(0.14, 0.25, 0.44, 0.98) if is_sel else DialogTheme.SURFACE
		var border := DialogTheme.GOLD if is_sel else Color(DialogTheme.CYAN, 0.45)
		row.add_theme_stylebox_override("normal", _style_box(bg, border, 9, 2 if is_sel else 1, 10))
		row.add_theme_stylebox_override("hover", _style_box(DialogTheme.SURFACE_HOVER, DialogTheme.GOLD, 9, 2, 10))
		row.add_theme_stylebox_override("pressed", _style_box(bg.darkened(0.12), DialogTheme.GOLD, 9, 2, 10))
		row.pressed.connect(_on_picker_item_chosen.bind(i))
		_picker_list.add_child(row)

	_picker_open = true
	_picker_backdrop.show()
	_picker_panel.show()
	_center_picker()
	_center_picker.call_deferred()


func _on_picker_item_chosen(index: int) -> void:
	if _picker_kind == "diff":
		_diff_selected = clampi(index, 0, maxi(0, _diff_items.size() - 1))
	elif _picker_kind == "rival":
		_rival_selected = clampi(index, 0, maxi(0, _rival_items.size() - 1))
	elif _picker_kind == "player":
		_player_selected = clampi(index, 0, maxi(0, _player_items.size() - 1))
	if is_instance_valid(Audio):
		Audio.play_sfx("%s/voice/internal/decide.wav" % _game)
	_refresh_selector_texts()
	_close_picker()


func _close_picker() -> void:
	if not _picker_open:
		return
	_picker_open = false
	_picker_backdrop.hide()
	_picker_panel.hide()


func _center_picker() -> void:
	if _picker_panel == null or not is_instance_valid(_picker_panel):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var target_w := minf(520.0, vp_size.x - 24.0)
	var target_h := minf(440.0, vp_size.y - 36.0)
	_picker_panel.custom_minimum_size = Vector2(target_w, 0.0)
	_picker_panel.size = Vector2(target_w, target_h)
	_picker_panel.position = Vector2(
		roundf((vp_size.x - target_w) * 0.5),
		roundf((vp_size.y - target_h) * 0.5)
	)


func _on_viewport_resized() -> void:
	_center_panel()
	if _picker_open:
		_center_picker()


func _make_field_label() -> Label:
	var lbl := Label.new()
	lbl.custom_minimum_size = Vector2(500, 0)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_override("font", Assets.ui_font(700))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	return lbl


func set_trigger_allowed(allowed: bool) -> void:
	_allow_trigger = allowed


func button_visible() -> bool:
	return not _modal_open and _trigger_btn.visible


func button_rect() -> Rect2:
	return _trigger_btn.get_global_rect()


func is_open() -> bool:
	return _modal_open


func open_for_game(game_id := "") -> void:
	if game_id in ["yugi", "kaiba", "joey"]:
		_game = game_id
	_populate()
	_modal_open = true
	_trigger_pressed = false
	_trigger_btn.hide()
	_backdrop.show()
	_panel.show()
	_center_panel()
	_center_panel.call_deferred()


func close_modal() -> void:
	_close_picker()
	if not _modal_open:
		return
	_modal_open = false
	_backdrop.hide()
	_panel.hide()
	_refresh_trigger_label()
	closed.emit()


func _refresh_selector_texts() -> void:
	var arrow := "▼  " if _lang() == "a" else "  ▼"
	if _diff_selected >= 0 and _diff_selected < _diff_items.size():
		var label := str(_diff_items[_diff_selected].get("label", ""))
		_diff_btn.text = (arrow + label) if _lang() == "a" else (label + arrow)
	if _rival_selected >= 0 and _rival_selected < _rival_items.size():
		var label := str(_rival_items[_rival_selected].get("label", ""))
		_rival_btn.text = (arrow + label) if _lang() == "a" else (label + arrow)
	if _player_selected >= 0 and _player_selected < _player_items.size():
		var label := str(_player_items[_player_selected].get("label", ""))
		_player_btn.text = (arrow + label) if _lang() == "a" else (label + arrow)


func _populate() -> void:
	var l := _lang()
	var rtl := l == "a"
	var align := HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT
	var char_map: Dictionary = CHAR_NAMES.get(_game, CHAR_NAMES["joey"])
	var char_name := str(char_map.get(l, char_map.get("e", _game)))

	_title_lbl.text = _tr(
		"⚔ الصعوبة والمجموعات الجاهزة · %s" % char_name,
		"⚔ Dificultad y Mazos · %s" % char_name,
		"⚔ Offline Difficulty & Decks · %s" % char_name
	)
	_subtitle_lbl.text = _tr(
		"اختر مستوى قوة الخصم، أو حدد مجموعة جاهزة للخصم أو لنفسك في المبارزات الأوفلاين.",
		"Elige la dificultad del rival o selecciona un mazo predefinido para ti o el rival en modo offline.",
		"Pick the AI difficulty or choose ready-made preset decks for the rival or yourself in offline duels."
	)
	_diff_lbl.text = _tr("1. مستوى صعوبة الخصم:", "1. Dificultad del rival:", "1. Opponent Difficulty:")
	_rival_lbl.text = _tr("2. مجموعة الخصم الجاهزة:", "2. Mazo predefinido del rival:", "2. Opponent Preset Deck:")
	_player_lbl.text = _tr("3. مجموعتك الجاهزة في الأوفلاين:", "3. Tu mazo predefinido (Offline):", "3. Your Ready-Made Offline Deck:")
	_note_lbl.text = _tr(
		"ملاحظة: اختيار مجموعة جاهزة لك ينطبق على المبارزات الأوفلاين فقط ولا يغيّر مجموعتك المحفوظة أو بطاقات الأونلاين.",
		"Nota: Tu mazo predefinido solo aplica en modo offline y no modifica tu mazo guardado ni el modo Online.",
		"Note: Preset player decks apply to offline duels only and never alter your saved deck or Online mode."
	)
	_reset_btn.text = _tr("إعادة للافتراضي", "Restablecer", "Reset Default")
	_save_btn.text = _tr("حفظ وإغلاق", "Guardar", "Save & Close")

	for lbl in [_title_lbl, _subtitle_lbl, _diff_lbl, _rival_lbl, _player_lbl, _note_lbl]:
		lbl.horizontal_alignment = align

	_style_selector_button(_diff_btn)
	_style_selector_button(_rival_btn)
	_style_selector_button(_player_btn)

	var saved_diff := LauncherSettings.get_offline_difficulty(_game) if is_instance_valid(LauncherSettings) else "auto"
	var saved_rival := LauncherSettings.get_offline_rival_deck(_game) if is_instance_valid(LauncherSettings) else ""
	var saved_player := LauncherSettings.get_offline_player_deck(_game) if is_instance_valid(LauncherSettings) else ""

	# 1. Difficulty
	_diff_items.clear()
	_diff_selected = 0
	for i in DIFFICULTY_OPTIONS.size():
		var opt: Dictionary = DIFFICULTY_OPTIONS[i]
		_diff_items.append({"id": str(opt["id"]), "label": str(opt.get(l, opt["e"]))})
		if str(opt["id"]) == saved_diff:
			_diff_selected = i

	var preset_key := "ar" if l == "a" else ("es" if l == "s" else "en")

	# 2. Rival preset decks
	_rival_items.clear()
	_rival_items.append({"path": "", "label": _tr("عشوائي حسب مستوى الصعوبة", "Aleatorio según dificultad", "Random by difficulty")})
	_rival_selected = 0
	for entry: Dictionary in RivalDeckChoice.available_presets(_game, true):
		var p := str(entry.get("path", ""))
		var label := str(entry.get(preset_key, entry.get("en", p.get_file())))
		var idx := _rival_items.size()
		_rival_items.append({"path": p, "label": label})
		if p == saved_rival:
			_rival_selected = idx

	# 3. Player ready-made decks
	_player_items.clear()
	_player_items.append({"path": "", "label": _tr("مجموعتي الخاصة (من محرر المجموعات)", "Mi mazo personalizado (Editor)", "My Custom Deck (Deck Editor)")})
	_player_selected = 0
	for entry: Dictionary in RivalDeckChoice.available_presets(_game, false):
		var p := str(entry.get("path", ""))
		var label := str(entry.get(preset_key, entry.get("en", p.get_file())))
		var idx := _player_items.size()
		_player_items.append({"path": p, "label": label})
		if p == saved_player:
			_player_selected = idx

	_refresh_selector_texts()


func _on_reset() -> void:
	_diff_selected = 0
	_rival_selected = 0
	_player_selected = 0
	_refresh_selector_texts()
	if is_instance_valid(LauncherSettings):
		LauncherSettings.set_offline_setup(_game, "auto", "", "")
	if is_instance_valid(Audio):
		Audio.play_sfx("%s/voice/internal/return.wav" % _game)
	_refresh_trigger_label()


func _on_save() -> void:
	var diff_idx := clampi(_diff_selected, 0, maxi(0, _diff_items.size() - 1))
	var diff_id := str(_diff_items[diff_idx].get("id", "auto")) if diff_idx < _diff_items.size() else "auto"
	var rival_idx := clampi(_rival_selected, 0, maxi(0, _rival_items.size() - 1))
	var rival_path := str(_rival_items[rival_idx].get("path", "")) if rival_idx < _rival_items.size() else ""
	var player_idx := clampi(_player_selected, 0, maxi(0, _player_items.size() - 1))
	var player_path := str(_player_items[player_idx].get("path", "")) if player_idx < _player_items.size() else ""
	if is_instance_valid(LauncherSettings):
		LauncherSettings.set_offline_setup(_game, diff_id, rival_path, player_path)
	if is_instance_valid(Audio):
		Audio.play_sfx("%s/voice/internal/decide.wav" % _game)
	close_modal()


func _center_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size := vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return
	var target_w := minf(560.0, vp_size.x - 24.0)
	_panel.custom_minimum_size = Vector2(target_w, 0.0)
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	sz.x = clampf(maxf(sz.x, target_w), 300.0, vp_size.x - 16.0)
	sz.y = minf(sz.y, vp_size.y - 24.0)
	_panel.size = sz
	_panel.position = Vector2(
		roundf((vp_size.x - sz.x) * 0.5),
		roundf((vp_size.y - sz.y) * 0.5)
	)


func _process(_delta: float) -> void:
	var vp := get_viewport()
	if vp != null:
		var bounds: Rect2 = vp.get_visible_rect()
		_trigger_btn.position = Vector2(bounds.end.x - _trigger_btn.size.x - 12.0, bounds.position.y + 10.0)
	_trigger_btn.visible = _allow_trigger and not _modal_open and not Game.has_active_root_dialog()


func _input(event: InputEvent) -> void:
	if _modal_open:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if _picker_open:
				_close_picker()
			else:
				close_modal()
		return
	if not _trigger_btn.visible or bool(event.get_meta("platform_touch", false)):
		return
	if event is InputEventMouseMotion:
		var over: bool = _trigger_btn.get_global_rect().has_point(event.position)
		_trigger_btn.add_theme_stylebox_override("normal", _trigger_press if _trigger_pressed else (_trigger_hover if over else _trigger_normal))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var over: bool = _trigger_btn.get_global_rect().has_point(event.position)
		if event.pressed:
			if over:
				_trigger_pressed = true
				_trigger_btn.add_theme_stylebox_override("normal", _trigger_press)
				get_viewport().set_input_as_handled()
		elif _trigger_pressed:
			_trigger_pressed = false
			_trigger_btn.add_theme_stylebox_override("normal", _trigger_hover if over else _trigger_normal)
			get_viewport().set_input_as_handled()
			if _trigger_btn.get_global_rect().grow(4.0).has_point(event.position):
				if is_instance_valid(Audio):
					Audio.play_sfx("%s/voice/internal/decide.wav" % _game)
				open_for_game(_game)
