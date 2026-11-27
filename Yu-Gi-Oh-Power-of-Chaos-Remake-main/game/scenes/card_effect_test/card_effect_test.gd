extends Control
## Herramienta de prueba de efectos: busca una carta, empieza un duelo de practica con ella en
## la mano inicial y, si se indica, cartas en el campo/cementerio de cada lado y LP.
## El duelo lo monta Game.open_card_effect_test() con la maquinaria de DuelScenario.
##
## Interfaz: arriba se elige el lado (Jugador / Oponente); cada carta de la lista tiene un boton
## "Add" (campo) y "GY" (cementerio) que la anade al lado activo, en el orden en que se eligen.
## Tocar el nombre de la carta la elige como la carta de la mano (la que se prueba).
## Todo va dentro de un ScrollContainer y los botones de empezar/volver viven en una barra fija.

const MAX_RESULTS := 80
const ROW_HEIGHT := 52
const FIELD_MAX := 10

const C_BG := Color(0.92, 0.96, 1.0)
const C_TEXT := Color(0.12, 0.16, 0.28)
const C_PLAYER := Color(0.16, 0.46, 0.92)
const C_OPP := Color(0.93, 0.36, 0.30)
const C_ADD := Color(0.14, 0.70, 0.42)
const C_GY := Color(0.62, 0.42, 0.88)
const C_HAND := Color(1.0, 0.72, 0.18)
const C_CARD := Color(1.0, 1.0, 1.0)
const C_BAR := Color(0.80, 0.88, 1.0)

var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _status: Label
var _lp_o: LineEdit
var _lp_p: LineEdit
var _hand_id := 0
var _side := 0  # 0 = jugador, 1 = oponente
var _field: Array = [[], []]
var _grave: Array = [[], []]
var _tab_buttons: Array = []
var _slots_box: VBoxContainer
var _hand_label: Label
var _rtl := false
var _last_press := {}


func _ready() -> void:
	_rtl = Assets.lang == "a"
	_build()
	_refresh("")
	_update_slots()
	_apply_side()


func _txt(eng: String, ara: String, spa: String) -> String:
	match Assets.lang:
		"a": return ara
		"s": return spa
	return eng


func _flat(color: Color, radius := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _color_button(b: Button, color: Color, font_size := 16) -> void:
	b.add_theme_stylebox_override("normal", _flat(color))
	b.add_theme_stylebox_override("hover", _flat(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _flat(color.darkened(0.2)))
	b.add_theme_stylebox_override("focus", _flat(color))
	b.add_theme_color_override("font_color", Color(1, 1, 1))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_font_size_override("font_size", font_size)
	b.focus_mode = Control.FOCUS_NONE


func _label(text: String, size := 15, color := C_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if _rtl:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _side_color(side: int) -> Color:
	return C_PLAYER if side == 0 else C_OPP


func _side_name(side: int) -> String:
	return _txt("Player", "اللاعب", "Jugador") if side == 0 else _txt("Opponent", "الخصم", "Oponente")


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_theme_constant_override("separation", 0)
	if _rtl:
		page.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(page)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	page.add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_label(_txt("Card Effect Test", "اختبار تأثير البطاقة", "Prueba de efecto"), 28))
	col.add_child(_label(_txt("1. Choose Player or Opponent. 2. Search a card and tap Add (field) or GY (graveyard). 3. Tap a card name to make it the card in your hand. 4. Press Start.",
			"١. اختر اللاعب أو الخصم. ٢. ابحث عن بطاقة واضغط Add (الملعب) أو GY (المقبرة). ٣. اضغط اسم البطاقة لتكون البطاقة في يدك. ٤. اضغط ابدأ.",
			"1. Elige Jugador u Oponente. 2. Busca una carta y pulsa Add (campo) o GY (cementerio). 3. Toca el nombre de una carta para ponerla en tu mano. 4. Pulsa Empezar."), 14))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	col.add_child(tabs)
	_tab_buttons = []
	for s in [0, 1]:
		var t := Button.new()
		t.text = _side_name(s)
		t.custom_minimum_size = Vector2(0, 58)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.pressed.connect(_set_side.bind(s))
		tabs.add_child(t)
		_tab_buttons.append(t)

	var search := LineEdit.new()
	search.placeholder_text = _txt("Search a card by name", "ابحث عن بطاقة بالاسم", "Busca una carta por nombre")
	search.text_changed.connect(_refresh)
	search.custom_minimum_size = Vector2(0, 50)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_direction = Control.TEXT_DIRECTION_RTL if _rtl else Control.TEXT_DIRECTION_AUTO
	search.add_theme_color_override("font_color", C_TEXT)
	search.add_theme_color_override("font_placeholder_color", Color(0.45, 0.5, 0.6))
	search.add_theme_stylebox_override("normal", _flat(C_CARD))
	search.add_theme_stylebox_override("focus", _flat(Color(1, 1, 0.92)))
	col.add_child(search)

	_status = _label("", 15)
	col.add_child(_status)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size = Vector2(0, 300)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(list_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 6)
	list_scroll.add_child(_list_box)

	col.add_child(_label(_txt("Added cards (in the order you picked them)", "البطاقات المضافة (بترتيب اختيارك)", "Cartas añadidas (en el orden elegido)"), 18))

	_hand_label = _label("", 16)
	col.add_child(_hand_label)

	_slots_box = VBoxContainer.new()
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_box.add_theme_constant_override("separation", 8)
	col.add_child(_slots_box)

	var lp_row := HBoxContainer.new()
	lp_row.add_theme_constant_override("separation", 10)
	col.add_child(lp_row)
	_lp_p = _lp_edit(lp_row, _txt("Your LP (blank = 8000)", "نقاط حياتك", "Tus LP (vacío = 8000)"))
	_lp_o = _lp_edit(lp_row, _txt("Opponent LP (blank = 8000)", "نقاط حياة الخصم", "LP rival (vacío = 8000)"))

	var bar_bg := PanelContainer.new()
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = C_BAR
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	bar_bg.add_theme_stylebox_override("panel", style)
	page.add_child(bar_bg)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bar_bg.add_child(row)

	var start := Button.new()
	start.text = _txt("Start practice duel", "ابدأ مباراة تجريبية", "Empezar duelo de prueba")
	start.custom_minimum_size = Vector2(0, 56)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_button(start, C_ADD, 19)
	start.pressed.connect(_on_start)
	row.add_child(start)

	var back := Button.new()
	back.text = _txt("Back", "رجوع", "Volver")
	back.custom_minimum_size = Vector2(130, 56)
	_color_button(back, Color(0.45, 0.52, 0.68), 19)
	back.pressed.connect(func() -> void: Game.open_launcher())
	row.add_child(back)


func _lp_edit(parent: HBoxContainer, placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(0, 48)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_color_override("font_color", C_TEXT)
	e.add_theme_color_override("font_placeholder_color", Color(0.45, 0.5, 0.6))
	e.add_theme_stylebox_override("normal", _flat(C_CARD))
	e.add_theme_stylebox_override("focus", _flat(Color(1, 1, 0.92)))
	parent.add_child(e)
	return e


func _set_side(side: int) -> void:
	_side = side
	_apply_side()
	_status.text = _txt("Adding to: %s" % _side_name(side), "الإضافة إلى: %s" % _side_name(side), "Añadiendo a: %s" % _side_name(side))


func _apply_side() -> void:
	for s in range(_tab_buttons.size()):
		var b: Button = _tab_buttons[s]
		var c := _side_color(s)
		if s == _side:
			_color_button(b, c, 22)
			b.text = "✔ " + _side_name(s)
		else:
			_color_button(b, c.lerp(Color(0.85, 0.88, 0.95), 0.65), 20)
			b.add_theme_color_override("font_color", c.darkened(0.2))
			b.add_theme_color_override("font_hover_color", c.darkened(0.2))
			b.add_theme_color_override("font_pressed_color", c.darkened(0.2))
			b.add_theme_color_override("font_focus_color", c.darkened(0.2))
			b.text = _side_name(s)
	_refresh_rows()


func _list_clear() -> void:
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()


func _list_add(text: String, id: int) -> void:
	if _list_box == null:
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	row.set_meta("id", id)

	var name_btn := Button.new()
	name_btn.text = text
	name_btn.alignment = HORIZONTAL_ALIGNMENT_RIGHT if _rtl else HORIZONTAL_ALIGNMENT_LEFT
	name_btn.clip_text = true
	name_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.focus_mode = Control.FOCUS_NONE
	name_btn.set_meta("role", "name")
	_tap(name_btn, _on_name_pressed.bind(id))
	row.add_child(name_btn)

	var add_btn := Button.new()
	add_btn.text = "Add"
	add_btn.custom_minimum_size = Vector2(76, ROW_HEIGHT)
	add_btn.set_meta("role", "add")
	_tap(add_btn, _on_add_pressed.bind(id, "field"))
	row.add_child(add_btn)

	var gy_btn := Button.new()
	gy_btn.text = "GY"
	gy_btn.custom_minimum_size = Vector2(60, ROW_HEIGHT)
	gy_btn.set_meta("role", "gy")
	_tap(gy_btn, _on_add_pressed.bind(id, "grave"))
	row.add_child(gy_btn)

	_list_box.add_child(row)
	_style_row(row)


## En Android el toque puede quedarse en el ScrollContainer y no llegar al boton: se escucha
## tambien el toque de pantalla. Un filtro de tiempo evita que cuente dos veces.
func _tap(button: Button, callback: Callable) -> void:
	var fire := func() -> void:
		var now := Time.get_ticks_msec()
		var key := button.get_instance_id()
		if now - int(_last_press.get(key, -1000)) < 350:
			return
		_last_press[key] = now
		callback.call()
	button.pressed.connect(fire)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and not event.pressed:
			fire.call())


func _style_row(row: HBoxContainer) -> void:
	var id := int(row.get_meta("id"))
	for child in row.get_children():
		if not (child is Button):
			continue
		match str(child.get_meta("role")):
			"name":
				if id == _hand_id:
					_color_button(child, C_HAND, 16)
					child.add_theme_color_override("font_color", C_TEXT)
					child.add_theme_color_override("font_hover_color", C_TEXT)
					child.add_theme_color_override("font_pressed_color", C_TEXT)
					child.add_theme_color_override("font_focus_color", C_TEXT)
				else:
					_color_button(child, C_CARD, 16)
					for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
						child.add_theme_color_override(k, C_TEXT)
			"add":
				_color_button(child, C_ADD, 18)
			"gy":
				_color_button(child, C_GY, 16)


func _refresh_rows() -> void:
	if _list_box == null:
		return
	for row in _list_box.get_children():
		if row is HBoxContainer:
			_style_row(row)


func _on_name_pressed(id: int) -> void:
	_hand_id = id
	_refresh_rows()
	_update_slots()
	_status.text = _txt("In hand: %s" % _card_name_by_id(id), "في اليد: %s" % _card_name_by_id(id), "En la mano: %s" % _card_name_by_id(id))


func _on_add_pressed(id: int, kind: String) -> void:
	var lst: Array = _field[_side] if kind == "field" else _grave[_side]
	if kind == "field" and lst.size() >= FIELD_MAX:
		_status.text = _txt("The %s field is full (10)." % _side_name(_side), "ملعب %s ممتلئ (10)." % _side_name(_side), "El campo de %s está lleno (10)." % _side_name(_side))
		return
	lst.append(id)
	var where := _txt("field", "الملعب", "campo") if kind == "field" else _txt("graveyard", "المقبرة", "cementerio")
	_status.text = _txt("Added %s to %s %s (#%d)" % [_card_name_by_id(id), _side_name(_side), where, lst.size()],
			"أُضيفت %s إلى %s - %s (رقم %d)" % [_card_name_by_id(id), _side_name(_side), where, lst.size()],
			"Añadida %s a %s %s (n.º %d)" % [_card_name_by_id(id), _side_name(_side), where, lst.size()])
	_update_slots()


func _remove_card(side: int, kind: String, index: int) -> void:
	var lst: Array = _field[side] if kind == "field" else _grave[side]
	if index >= 0 and index < lst.size():
		lst.remove_at(index)
	_update_slots()


## Casillas debajo de la lista: lo anadido a cada lado, numerado en el orden elegido.
## Tocar un chip lo quita.
func _update_slots() -> void:
	if _slots_box == null:
		return
	_hand_label.text = _txt("In hand (card to test): ", "في اليد (البطاقة المختبرة): ", "En la mano (carta a probar): ") \
			+ (_card_name_by_id(_hand_id) if _hand_id > 0 else _txt("none, tap a card name", "لا شيء، اضغط اسم بطاقة", "ninguna, toca un nombre"))
	for child in _slots_box.get_children():
		_slots_box.remove_child(child)
		child.queue_free()
	for s in [0, 1]:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _flat(_side_color(s).lerp(Color(1, 1, 1), 0.8), 14))
		_slots_box.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		panel.add_child(v)
		v.add_child(_label(_side_name(s), 18, _side_color(s).darkened(0.25)))
		for kind in ["field", "grave"]:
			var lst: Array = _field[s] if kind == "field" else _grave[s]
			var title := _txt("Field", "الملعب", "Campo") if kind == "field" else _txt("Graveyard", "المقبرة", "Cementerio")
			v.add_child(_label(title + ":" + ("" if not lst.is_empty() else " " + _txt("empty", "فارغ", "vacío")), 14))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			v.add_child(flow)
			for i in range(lst.size()):
				var chip := Button.new()
				chip.text = "%d. %s  ✕" % [i + 1, _card_name_by_id(int(lst[i]))]
				chip.custom_minimum_size = Vector2(0, 40)
				_color_button(chip, _side_color(s) if kind == "field" else C_GY, 14)
				chip.pressed.connect(_remove_card.bind(s, kind, i))
				flow.add_child(chip)


func _card_name_by_id(id: int) -> String:
	for card: Dictionary in CardDB.cards:
		if int(card.get("internal_id", 0)) == id:
			return _card_name(card)
	return str(id)


func _card_name(card: Dictionary) -> String:
	var names: Dictionary = card.get("names", {})
	var lang: String = str({"a": "ara", "s": "spa"}.get(Assets.lang, "eng"))
	return str(names.get(lang, names.get("eng", "")))


## Normaliza para buscar: quita tashkeel, iguala las variantes de alef/ya/ta marbuta/hamza y
## convierte los digitos arabes a ASCII, asi "المسلح" encuentra "المسلّح" y "٢٥٠٠" encuentra 2500.
func _norm(text: String) -> String:
	var out := ""
	for ch in text:
		var code := ch.unicode_at(0)
		if (code >= 0x064B and code <= 0x065F) or code == 0x0670 or (code >= 0x06D6 and code <= 0x06ED):
			continue
		if code >= 0x0660 and code <= 0x0669:
			out += String.chr(0x30 + (code - 0x0660))
			continue
		if code >= 0x06F0 and code <= 0x06F9:
			out += String.chr(0x30 + (code - 0x06F0))
			continue
		match code:
			0x0622, 0x0623, 0x0625, 0x0627:
				out += "ا"
			0x0649, 0x064A, 0x0626:
				out += "ي"
			0x0629:
				out += "ه"
			0x0624:
				out += "و"
			_:
				out += ch
	return out.to_lower()


func _card_matches(card: Dictionary, q: String) -> bool:
	if q == "":
		return true
	if q.is_valid_int() and int(card.get("internal_id", 0)) == int(q):
		return true
	var names: Dictionary = card.get("names", {})
	for key in ["ara", "eng", "spa"]:
		if _norm(str(names.get(key, ""))).contains(q):
			return true
	return false


func _refresh(query: String) -> void:
	_list_clear()
	var q := _norm(query.strip_edges())
	var shown := 0
	for card: Dictionary in CardDB.cards:
		if not _card_matches(card, q):
			continue
		_list_add("%s  ·  #%d" % [_card_name(card), int(card.get("internal_id", 0))], int(card.get("internal_id", 0)))
		shown += 1
		if shown >= MAX_RESULTS:
			break
	_status.text = _txt("%d cards" % shown, "%d بطاقة" % shown, "%d cartas" % shown)


func _on_start() -> void:
	if _hand_id <= 0:
		_status.text = _txt("Tap a card name first: it is the card in your hand.", "اضغط اسم بطاقة أولًا: هي البطاقة التي في يدك.", "Toca primero el nombre de una carta: será la de tu mano.")
		return
	var opts := {}
	for s in [0, 1]:
		var key := "p" if s == 0 else "o"
		var entries: Array = []
		var mz := 0
		var sz := 5
		for id in _field[s]:
			if mz < 5:
				entries.append({"card": int(id), "zone": mz, "c": 0})
				mz += 1
			elif sz < 10:
				entries.append({"card": int(id), "zone": sz, "c": 1})
				sz += 1
		if not entries.is_empty():
			opts["field_" + key] = entries
		if not _grave[s].is_empty():
			opts["grave_" + key] = _grave[s].duplicate()
	if _lp_o.text.strip_edges().is_valid_int():
		opts["lp_o"] = int(_lp_o.text.strip_edges())
	if _lp_p.text.strip_edges().is_valid_int():
		opts["lp_p"] = int(_lp_p.text.strip_edges())
	Game.open_card_effect_test(_hand_id, opts)
