extends CanvasLayer
## Interactive modal to choose built-in card back styles or pick a custom image from device storage.

signal changed
signal closed

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const _CardBackArt := preload("res://core/card_back_art.gd")

const GOLD := DialogTheme.GOLD
const GOLD_LIGHT := DialogTheme.GOLD_LIGHT
const CYAN := DialogTheme.CYAN
const CYAN_SOFT := DialogTheme.CYAN_SOFT

var _panel: PanelContainer = null
var _title: Label = null
var _subtitle: Label = null
var _preview_tex: TextureRect = null
var _preview_name: Label = null
var _status_label: Label = null
var _custom_btn: Button = null
var _close_btn: Button = null
var _style_buttons: Dictionary = {}
var _card_face_title: Label = null
var _card_face_buttons: Dictionary = {}
var _bg_title: Label = null
var _bg_buttons: Dictionary = {}
var _back_list_title: Label = null
var _file_dialog: FileDialog = null


func _ready() -> void:
	layer = 97
	visible = false
	_build_ui()


func is_open() -> bool:
	return visible


func open_modal() -> void:
	_refresh_state()
	visible = true


func close_modal() -> void:
	visible = false
	closed.emit()


func _tr(ar: String, es: String, en: String) -> String:
	if is_instance_valid(Assets):
		if Assets.lang == "a":
			return ar
		if Assets.lang == "s":
			return es
	return en


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.04, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_modal())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = DialogTheme.BACKGROUND
	pstyle.border_color = GOLD
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(14)
	pstyle.set_content_margin_all(16)
	pstyle.shadow_color = Color(0, 0, 0, 0.72)
	pstyle.shadow_size = 20
	_panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(_panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	_panel.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_box.add_child(header)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_font_override("font", Assets.ui_font(700))
	_title.add_theme_font_size_override("font_size", 19)
	_title.add_theme_color_override("font_color", GOLD)
	header.add_child(_title)

	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(38, 34)
	_close_btn.focus_mode = Control.FOCUS_NONE
	_style_button(_close_btn, false)
	_close_btn.pressed.connect(close_modal)
	header.add_child(_close_btn)

	_subtitle = Label.new()
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_override("font", Assets.ui_font())
	_subtitle.add_theme_font_size_override("font_size", 12)
	_subtitle.add_theme_color_override("font_color", CYAN_SOFT)
	root_box.add_child(_subtitle)

	# Row 1: Card Face Style (Arab Duelists Modern vs Classic Original)
	var face_box := VBoxContainer.new()
	face_box.add_theme_constant_override("separation", 5)
	root_box.add_child(face_box)

	_card_face_title = Label.new()
	_card_face_title.add_theme_font_override("font", Assets.ui_font(700))
	_card_face_title.add_theme_font_size_override("font_size", 14)
	_card_face_title.add_theme_color_override("font_color", GOLD_LIGHT)
	face_box.add_child(_card_face_title)

	var face_row := HBoxContainer.new()
	face_row.add_theme_constant_override("separation", 8)
	face_box.add_child(face_row)

	_card_face_buttons.clear()
	for f_id: String in LauncherSettings.CARD_STYLES:
		var fbtn := Button.new()
		fbtn.custom_minimum_size = Vector2(210, 34)
		fbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fbtn.focus_mode = Control.FOCUS_NONE
		fbtn.add_theme_font_override("font", Assets.ui_font(700))
		fbtn.add_theme_font_size_override("font_size", 13)
		fbtn.add_theme_color_override("font_color", GOLD_LIGHT)
		fbtn.add_theme_color_override("font_hover_color", Color.WHITE)
		fbtn.add_theme_constant_override("h_separation", 8)
		fbtn.pressed.connect(_on_select_card_face.bind(f_id))
		face_row.add_child(fbtn)
		_card_face_buttons[f_id] = fbtn

	# Row 2: Background Selector (New, Classic, Yugi, Kaiba, Joey)
	var bg_box := VBoxContainer.new()
	bg_box.add_theme_constant_override("separation", 5)
	root_box.add_child(bg_box)

	_bg_title = Label.new()
	_bg_title.add_theme_font_override("font", Assets.ui_font(700))
	_bg_title.add_theme_font_size_override("font_size", 14)
	_bg_title.add_theme_color_override("font_color", GOLD_LIGHT)
	bg_box.add_child(_bg_title)

	var bg_row := HFlowContainer.new()
	bg_row.add_theme_constant_override("h_separation", 6)
	bg_row.add_theme_constant_override("v_separation", 6)
	bg_box.add_child(bg_row)

	_bg_buttons.clear()
	for b_id: String in LauncherSettings.BG_STYLES:
		var bbtn := Button.new()
		bbtn.custom_minimum_size = Vector2(122, 32)
		bbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bbtn.focus_mode = Control.FOCUS_NONE
		bbtn.add_theme_font_override("font", Assets.ui_font(700))
		bbtn.add_theme_font_size_override("font_size", 12)
		bbtn.add_theme_color_override("font_color", GOLD_LIGHT)
		bbtn.add_theme_color_override("font_hover_color", Color.WHITE)
		bbtn.add_theme_constant_override("h_separation", 6)
		bbtn.pressed.connect(_on_select_bg_style.bind(b_id))
		bg_row.add_child(bbtn)
		_bg_buttons[b_id] = bbtn

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	root_box.add_child(body)

	# Left preview card frame
	var preview_col := VBoxContainer.new()
	preview_col.custom_minimum_size = Vector2(170, 0)
	preview_col.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_col.add_theme_constant_override("separation", 6)
	body.add_child(preview_col)

	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(150, 210)
	var fstyle := StyleBoxFlat.new()
	fstyle.bg_color = Color(0.03, 0.04, 0.10, 0.95)
	fstyle.border_color = Color(CYAN, 0.65)
	fstyle.set_border_width_all(2)
	fstyle.set_corner_radius_all(10)
	fstyle.set_content_margin_all(8)
	preview_frame.add_theme_stylebox_override("panel", fstyle)
	preview_col.add_child(preview_frame)

	_preview_tex = TextureRect.new()
	_preview_tex.custom_minimum_size = Vector2(134, 192)
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_frame.add_child(_preview_tex)

	_preview_name = Label.new()
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name.add_theme_font_override("font", Assets.ui_font(700))
	_preview_name.add_theme_font_size_override("font_size", 13)
	_preview_name.add_theme_color_override("font_color", GOLD_LIGHT)
	preview_col.add_child(_preview_name)

	# Right selectable card back list
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	body.add_child(right_col)

	_back_list_title = Label.new()
	_back_list_title.add_theme_font_override("font", Assets.ui_font(700))
	_back_list_title.add_theme_font_size_override("font_size", 14)
	_back_list_title.add_theme_color_override("font_color", GOLD_LIGHT)
	right_col.add_child(_back_list_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 198)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_col.add_child(scroll)

	var list_col := VBoxContainer.new()
	list_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_col.add_theme_constant_override("separation", 6)
	scroll.add_child(list_col)

	_style_buttons.clear()
	for style_id: String in LauncherSettings.CARD_BACKS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 34)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_override("font", Assets.ui_font(700))
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", GOLD_LIGHT)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_constant_override("h_separation", 10)
		btn.pressed.connect(_on_select_style.bind(style_id))
		list_col.add_child(btn)
		_style_buttons[style_id] = btn

	_custom_btn = Button.new()
	_custom_btn.custom_minimum_size = Vector2(280, 36)
	_custom_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_custom_btn.focus_mode = Control.FOCUS_NONE
	_custom_btn.add_theme_font_override("font", Assets.ui_font(700))
	_custom_btn.add_theme_font_size_override("font_size", 13)
	_custom_btn.add_theme_color_override("font_color", Color.WHITE)
	_style_button(_custom_btn, true)
	_custom_btn.pressed.connect(_pick_custom_image)
	right_col.add_child(_custom_btn)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_override("font", Assets.ui_font())
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.56, 0.92, 0.70))
	_status_label.visible = false
	root_box.add_child(_status_label)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp;Images;image/png,image/jpeg,image/webp"])
	_file_dialog.file_selected.connect(_on_custom_image_selected)
	add_child(_file_dialog)


func _style_button(btn: Button, accent_gold: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.14, 0.24, 0.42, 0.98) if accent_gold and state == "normal" else (DialogTheme.SURFACE_HOVER if state != "normal" else DialogTheme.SURFACE)
		box.border_color = GOLD if (accent_gold or state != "normal") else Color(CYAN, 0.45)
		box.set_border_width_all(2 if accent_gold else 1)
		box.set_corner_radius_all(9)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 5
		box.content_margin_bottom = 5
		btn.add_theme_stylebox_override(state, box)


func _style_choice_button(btn: Button, is_sel: bool) -> void:
	btn.icon = DialogTheme.radio_icon(is_sel)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.12, 0.24, 0.42, 0.98) if is_sel else (DialogTheme.SURFACE_HOVER if state != "normal" else DialogTheme.SURFACE)
		box.border_color = GOLD if is_sel else (CYAN if state != "normal" else Color(CYAN, 0.38))
		box.set_border_width_all(2 if is_sel else 1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 10
		box.content_margin_right = 10
		box.content_margin_top = 5
		box.content_margin_bottom = 5
		btn.add_theme_stylebox_override(state, box)


func _on_select_card_face(face_id: String) -> void:
	LauncherSettings.set_card_style(face_id)
	_status_label.visible = false
	_refresh_state()
	changed.emit()


func _on_select_bg_style(bg_id: String) -> void:
	LauncherSettings.set_bg_style(bg_id)
	_status_label.visible = false
	_refresh_state()
	changed.emit()


func _on_select_style(style_id: String) -> void:
	if style_id == "custom" and not LauncherSettings.has_custom_card_back():
		_pick_custom_image()
		return
	LauncherSettings.set_card_back(style_id)
	_status_label.visible = false
	_refresh_state()
	changed.emit()


func _pick_custom_image() -> void:
	if _file_dialog != null:
		_file_dialog.popup_file_dialog()


func _on_custom_image_selected(path: String) -> void:
	var err: String = LauncherSettings.save_custom_card_back(path)
	if err != "":
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
		_status_label.text = err
		_status_label.visible = true
		return
	_status_label.add_theme_color_override("font_color", Color(0.56, 0.92, 0.70))
	_status_label.text = _tr("تم حفظ وتفعيل خلفية البطاقة المخصصة.", "Reverso personalizado guardado y aplicado.", "Custom card back saved and applied.")
	_status_label.visible = true
	_refresh_state()
	changed.emit()


func _refresh_state() -> void:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	var cur: String = LauncherSettings.card_back if is_instance_valid(LauncherSettings) else "classic"
	var cur_face: String = LauncherSettings.card_style if is_instance_valid(LauncherSettings) else "arab"
	var cur_bg: String = LauncherSettings.bg_style if is_instance_valid(LauncherSettings) else "new"
	var has_custom: bool = is_instance_valid(LauncherSettings) and LauncherSettings.has_custom_card_back()

	_title.text = _tr("🎴 أشكال البطاقات والخلفية", "🎴 Cartas y Fondo", "🎴 Cards & Background")
	_subtitle.text = _tr(
		"تحكم في شكل البطاقات (الشكل المتطور للمبارزون العرب أو الشكل العادي الأصلي)، وخلفية اللعبة، وتصميم ظهر البطاقات.",
		"Personaliza el diseño frontal de las cartas, el fondo del juego y el reverso de las cartas.",
		"Customize card front style (Arab Duelists Modern vs Classic Original), game background, and card back."
	)
	_card_face_title.text = _tr("🃏 شكل البطاقات (الوحوش والأوراق):", "🃏 Diseño frontal de cartas:", "🃏 Card Front Style:")
	_bg_title.text = _tr("🖼 خلفية اللعبة:", "🖼 Fondo del juego:", "🖼 Game Background:")
	_back_list_title.text = _tr("🎴 تصميم ظهر البطاقة:", "🎴 Reverso de la carta:", "🎴 Card Back Design:")
	_custom_btn.text = _tr("📁 اختيار صورة من الجهاز...", "📁 Elegir imagen del dispositivo...", "📁 Choose Image from Device...")

	for f_id: String in _card_face_buttons.keys():
		var fbtn: Button = _card_face_buttons[f_id]
		if not is_instance_valid(fbtn):
			continue
		fbtn.text = LauncherSettings.card_style_label(f_id, lang)
		_style_choice_button(fbtn, cur_face == f_id)

	for b_id: String in _bg_buttons.keys():
		var bbtn: Button = _bg_buttons[b_id]
		if not is_instance_valid(bbtn):
			continue
		bbtn.text = LauncherSettings.bg_style_label(b_id, lang)
		_style_choice_button(bbtn, cur_bg == b_id)

	for style_id: String in _style_buttons.keys():
		var btn: Button = _style_buttons[style_id]
		if not is_instance_valid(btn):
			continue
		if style_id == "custom" and not has_custom:
			btn.visible = false
			continue
		btn.visible = true
		btn.text = _CardBackArt.label_for(style_id, lang)
		_style_choice_button(btn, cur == style_id)

	var preview: Texture2D = null
	if cur == "classic":
		preview = Assets.original_card_back_texture(false) if is_instance_valid(Assets) else null
		if preview == null:
			preview = _CardBackArt.get_texture("gold_millennium", false)
	else:
		preview = _CardBackArt.get_texture(cur, false)
		if preview == null and is_instance_valid(Assets):
			preview = Assets.original_card_back_texture(false)
	_preview_tex.texture = preview
	_preview_name.text = _CardBackArt.label_for(cur, lang)
