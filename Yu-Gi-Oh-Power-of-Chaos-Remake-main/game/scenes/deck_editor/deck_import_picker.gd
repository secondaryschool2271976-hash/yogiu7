extends CanvasLayer
## Selector de mazos para Importar: lista grande con casillas, seleccion multiple con circulo.
## Filas altas (64 px) con separacion para que un dedo no toque la fila equivocada.
## Nada se importa al tocar una fila: solo al pulsar el boton Importar.

signal confirmed(names: PackedStringArray)
signal cancelled
signal browse_external

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const ROW_H := 64.0
const ROW_GAP := 10

var _decks_dir := ""
var _files: PackedStringArray = []
var _checked := {}
var _rows: Array[Control] = []
var _circles: Array[Button] = []
var _press_point := Vector2.ZERO
var _moved := false
var _scroll: ScrollContainer = null
var _import_btn: Button = null
var _count_lbl: Label = null
var _done := false
var _btns: Array[Button] = []
var _drag_last := Vector2.ZERO


func setup(decks_dir: String, files: PackedStringArray) -> void:
	_decks_dir = decks_dir
	_files = files


static func _tr(ar: String, es: String, en: String) -> String:
	if is_instance_valid(Assets):
		if Assets.lang == "a":
			return ar
		if Assets.lang == "s":
			return es
	return en


func _ready() -> void:
	layer = 98
	_build_ui()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.04, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 540)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = DialogTheme.BACKGROUND
	pstyle.border_color = DialogTheme.GOLD
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(14)
	pstyle.set_content_margin_all(16)
	pstyle.shadow_color = Color(0, 0, 0, 0.72)
	pstyle.shadow_size = 20
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = _tr("استيراد المجموعات", "Importar mazos", "Import decks")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Assets.ui_font(700))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", DialogTheme.GOLD)
	root.add_child(title)

	var hint := Label.new()
	hint.text = _tr("اضغط على الدائرة لتحديد المجموعات ثم اضغط استيراد.",
			"Toca el círculo para elegir mazos y pulsa Importar.",
			"Tap the circle to select decks, then press Import.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font", Assets.ui_font())
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	root.add_child(hint)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 300)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 26
	root.add_child(_scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ROW_GAP)
	_scroll.add_child(list)

	if _files.is_empty():
		var empty := Label.new()
		empty.text = _tr("لا توجد مجموعات محفوظة. استخدم زر ملف YDC بالأسفل.",
				"No hay mazos guardados. Usa el botón de archivo YDC.",
				"No saved decks. Use the YDC file button below.")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_override("font", Assets.ui_font())
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
		list.add_child(empty)
	for i in _files.size():
		var row := _make_row(i)
		list.add_child(row)
		_rows.append(row)

	_count_lbl = Label.new()
	_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_lbl.add_theme_font_override("font", Assets.ui_font(700))
	_count_lbl.add_theme_font_size_override("font_size", 15)
	_count_lbl.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	root.add_child(_count_lbl)

	var ext := _make_button(_tr("استيراد ملفات YDC/YDK من الجهاز", "Archivos YDC/YDK del dispositivo", "Import .YDC/.YDK files from device"), false)
	ext.pressed.connect(func() -> void:
		if _done:
			return
		_done = true
		browse_external.emit())
	root.add_child(ext)
	_btns.append(ext)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	root.add_child(bar)
	var cancel := _make_button(_tr("إلغاء", "Cancelar", "Cancel"), false)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_cancel)
	bar.add_child(cancel)
	_btns.append(cancel)
	_import_btn = _make_button("", true)
	_import_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_import_btn.pressed.connect(_confirm)
	bar.add_child(_import_btn)
	_btns.append(_import_btn)
	_refresh()


func _make_row(i: int) -> Control:
	# La fila es solo informativa: se marca unicamente tocando el circulo, para poder desplazar
	# la lista con el dedo sin marcar nada por accidente.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_H)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _row_style(Color(0.082, 0.098, 0.205, 0.96), Color(0.30, 0.45, 0.62, 0.9), 1))
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(box)
	var circle := Button.new()
	circle.toggle_mode = true
	circle.focus_mode = Control.FOCUS_NONE
	circle.flat = true
	circle.custom_minimum_size = Vector2(52, 48)
	circle.icon = DialogTheme.radio_icon(false)
	circle.expand_icon = false
	circle.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	circle.toggled.connect(func(on_state: bool) -> void:
		_checked[i] = on_state
		circle.icon = DialogTheme.radio_icon(on_state)
		panel.add_theme_stylebox_override("panel", _row_style(
				Color(0.07, 0.30, 0.34, 0.98) if on_state else Color(0.082, 0.098, 0.205, 0.96),
				DialogTheme.GOLD if on_state else Color(0.30, 0.45, 0.62, 0.9),
				3 if on_state else 1))
		_refresh())
	box.add_child(circle)
	var lbl := Label.new()
	lbl.text = _row_text(i)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.add_theme_font_override("font", Assets.ui_font(700))
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	if is_instance_valid(Assets) and Assets.lang == "a":
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		box.move_child(circle, 0)
	box.add_child(lbl)
	_circles.append(circle)
	return panel


func _row_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _make_button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_override("font", Assets.ui_font(700))
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.62, 0.7))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		if primary:
			s.bg_color = Color(0.10, 0.52, 0.34) if state != "pressed" else Color(0.07, 0.38, 0.25)
		else:
			s.bg_color = DialogTheme.SURFACE_HOVER if state in ["hover", "pressed"] else DialogTheme.SURFACE
		if state == "disabled":
			s.bg_color = Color(0.12, 0.13, 0.20, 0.9)
		s.border_color = DialogTheme.GOLD if state != "disabled" else Color(0.3, 0.32, 0.4)
		s.set_border_width_all(2)
		s.set_corner_radius_all(10)
		s.content_margin_left = 12
		s.content_margin_right = 12
		b.add_theme_stylebox_override(state, s)
	return b


func _row_text(i: int) -> String:
	var n := _files[i]
	var deck := Ydc.load(_decks_dir.path_join(n + ".ydc"))
	if deck.is_empty():
		return n
	var total: int = (deck.get("main", []) as Array).size() + (deck.get("fusion", []) as Array).size() + (deck.get("side", []) as Array).size()
	return "%s    (%d)" % [n, total]


func _selected() -> PackedStringArray:
	var out := PackedStringArray()
	for i in _files.size():
		if bool(_checked.get(i, false)):
			out.append(_files[i])
	return out


func _refresh() -> void:
	var n := _selected().size()
	if _import_btn != null:
		_import_btn.disabled = n == 0
		_import_btn.text = _tr("استيراد (%d)", "Importar (%d)", "Import (%d)") % n
	if _count_lbl != null:
		_count_lbl.text = _tr("المحدد: %d من %d", "Seleccionados: %d de %d", "Selected: %d of %d") % [n, _files.size()]


func _cancel() -> void:
	if _done:
		return
	_done = true
	cancelled.emit()
	queue_free()


func _confirm() -> void:
	if _done:
		return
	var names := _selected()
	if names.is_empty():
		return
	_done = true
	confirmed.emit(names)
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel()


## mobile_pointer consume todo el toque y solo reinyecta raton en coordenadas de escena: los
## Control de este CanvasLayer viven en pixeles del viewport, asi que el dialogo no recibia
## ningun toque (ni filas ni botones). El deck_editor nos pasa el toque por
## handle_mobile_search_touch/handle_mobile_search_drag; aqui lo convertimos y actuamos.
func _viewport_point(scene_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * scene_pos


func _button_at(point: Vector2) -> Button:
	# Los botones van primero: estan dibujados encima de la lista.
	for btn in _btns:
		if is_instance_valid(btn) and btn.visible and not btn.disabled and btn.get_global_rect().grow(4.0).has_point(point):
			return btn
	var area := Rect2()
	if _scroll != null:
		area = _scroll.get_global_rect().grow(4.0)
	for c in _circles:
		if not is_instance_valid(c):
			continue
		if not c.get_global_rect().grow(6.0).has_point(point):
			continue
		if _scroll != null and not area.has_point(point):
			continue
		return c
	return null


func handle_mobile_touch(event: InputEventScreenTouch, scene_pos: Vector2) -> bool:
	if _done:
		return true
	var point: Vector2 = _viewport_point(scene_pos)
	_drag_last = point
	if event.pressed:
		_press_point = point
		_moved = false
		return true
	# Se actua al soltar y solo si el dedo no se desplazo: arrastrar desplaza la lista.
	if _moved:
		return true
	var btn: Button = _button_at(point)
	if btn == null or btn.disabled:
		return true
	if btn in _circles:
		btn.button_pressed = not btn.button_pressed
	else:
		btn.pressed.emit()
	return true


func handle_mobile_drag(event: InputEventScreenDrag, scene_pos: Vector2) -> bool:
	if _done:
		return true
	var point: Vector2 = _viewport_point(scene_pos)
	if point.distance_to(_press_point) > 12.0:
		_moved = true
	if _moved and _scroll != null and _scroll.get_global_rect().grow(8.0).has_point(point):
		_scroll.scroll_vertical -= int(round(point.y - _drag_last.y))
	_drag_last = point
	return true
