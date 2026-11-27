extends Control
## Herramienta de prueba de efectos: busca una carta, empieza un duelo de practica con ella en
## la mano inicial y, si se indica, cartas en el campo/cementerio del rival o tuyo y LP.
## El duelo lo monta Game.open_card_effect_test() con la maquinaria de DuelScenario.
##
## La pantalla entera va dentro de un ScrollContainer (el puntero movil del juego arrastra
## cualquier ScrollContainer que tenga debajo del dedo) y los botones de empezar/volver viven en
## una barra fija abajo, asi que siempre se ven aunque el contenido no quepa.

const MAX_RESULTS := 80
const ROW_HEIGHT := 46

var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _status: Label
var _grid: GridContainer
var _field_o: LineEdit
var _grave_o: LineEdit
var _grave_p: LineEdit
var _lp_o: LineEdit
var _lp_p: LineEdit
var _summary: Label
var _picked_id := 0
var _picked_button: Button = null
var _rtl := false


func _ready() -> void:
	_rtl = Assets.lang == "a"
	_build()
	_refresh("")
	_update_summary()
	get_viewport().size_changed.connect(_relayout)
	_relayout()


## En pantallas estrechas las opciones van en una sola columna.
func _relayout() -> void:
	if _grid == null:
		return
	_grid.columns = 1 if get_viewport_rect().size.x < 640.0 else 2


func _txt(eng: String, ara: String, spa: String) -> String:
	match Assets.lang:
		"a": return ara
		"s": return spa
	return eng


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.09)
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

	var title := Label.new()
	title.text = _txt("Card Effect Test", "اختبار تأثير البطاقة", "Prueba de efecto")
	title.add_theme_font_size_override("font_size", 26)
	if _rtl:
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(title)

	var note := Label.new()
	note.text = _txt("The opponent plays normally, so it may interrupt. If it does, end the duel and start again.",
			"الخصم يلعب بشكل عادي وقد يقاطع الاختبار. إن حدث ذلك، أنهِ المبارزة وابدأ من جديد.",
			"El rival juega normal y puede interrumpir. Si pasa, termina el duelo y vuelve a empezar.")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.modulate = Color(1, 1, 1, 0.75)
	if _rtl:
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(note)

	var steps := Label.new()
	steps.text = _txt("1. Search the card by name or number. 2. Tap it in the list to select it. 3. Optional: add copies to a field or a graveyard. 4. Press Start practice duel.",
			"١. ابحث عن البطاقة بالاسم أو الرقم. ٢. اضغط عليها في القائمة لتحديدها. ٣. اختياري: أضف نسخًا إلى الملعب أو المقبرة. ٤. اضغط «ابدأ مباراة تجريبية».",
			"1. Busca la carta por nombre o número. 2. Púlsala en la lista para elegirla. 3. Opcional: añade copias al campo o cementerio. 4. Pulsa Empezar duelo de prueba.")
	steps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	steps.add_theme_font_size_override("font_size", 15)
	steps.modulate = Color(1, 1, 1, 0.92)
	if _rtl:
		steps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(steps)

	var search := LineEdit.new()
	search.placeholder_text = _txt("Search a card by name", "ابحث عن بطاقة بالاسم", "Busca una carta por nombre")
	search.text_changed.connect(_refresh)
	search.custom_minimum_size = Vector2(0, 48)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_direction = Control.TEXT_DIRECTION_RTL if _rtl else Control.TEXT_DIRECTION_AUTO
	col.add_child(search)

	var add_row := HBoxContainer.new()
	add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_theme_constant_override("separation", 8)
	col.add_child(add_row)
	for spec in [
			[_txt("+ Opp field", "+ ملعب الخصم", "+ campo rival"), "field_o"],
			[_txt("+ Opp GY", "+ مقبرة الخصم", "+ cem. rival"), "grave_o"],
			[_txt("+ My GY", "+ مقبرتي", "+ mi cem."), "grave_p"],
		]:
		var ab := Button.new()
		ab.text = str(spec[0])
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.custom_minimum_size = Vector2(0, 44)
		ab.add_theme_font_size_override("font_size", 14)
		ab.pressed.connect(_on_add_pressed.bind(str(spec[1])))
		add_row.add_child(ab)

	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size = Vector2(0, 190)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(list_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_box.add_theme_constant_override("separation", 4)
	list_scroll.add_child(_list_box)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)

	_field_o = _add_row(_grid, _txt("Opponent field (names/ids, comma separated)", "ملعب الخصم (أسماء أو أرقام مفصولة بفاصلة)", "Campo rival (nombres/ids separados por coma)"))
	_grave_o = _add_row(_grid, _txt("Opponent graveyard", "مقبرة الخصم", "Cementerio rival"))
	_grave_p = _add_row(_grid, _txt("Your graveyard", "مقبرتك", "Tu cementerio"))
	_lp_o = _add_row(_grid, _txt("Opponent LP (blank = 8000)", "نقاط حياة الخصم", "LP rival (vacío = 8000)"))
	_lp_p = _add_row(_grid, _txt("Your LP (blank = 8000)", "نقاط حياتك", "Tus LP (vacío = 8000)"))

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 13)
	_summary.modulate = Color(1, 1, 1, 0.8)
	if _rtl:
		_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_summary)
	for edit in [_field_o, _grave_o, _grave_p]:
		edit.text_changed.connect(func(_t: String) -> void: _update_summary())

	_status = Label.new()
	_status.text = _txt("Pick the card to test, then press Start.", "اختر البطاقة ثم اضغط ابدأ.", "Elige la carta y pulsa Empezar.")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _rtl:
		_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_status)

	var bar_bg := PanelContainer.new()
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.14)
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
	start.custom_minimum_size = Vector2(0, 54)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.add_theme_font_size_override("font_size", 18)
	start.pressed.connect(_on_start)
	row.add_child(start)

	var back := Button.new()
	back.text = _txt("Back", "رجوع", "Volver")
	back.custom_minimum_size = Vector2(130, 54)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func() -> void: Game.open_launcher())
	row.add_child(back)


func _add_row(grid: GridContainer, label_text: String) -> LineEdit:
	var l := Label.new()
	l.text = label_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _rtl:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(l)
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(220, 48)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.text_direction = Control.TEXT_DIRECTION_RTL if _rtl else Control.TEXT_DIRECTION_AUTO
	grid.add_child(e)
	return e


func _list_clear() -> void:
	_picked_id = 0
	_picked_button = null
	if _list_box == null:
		return
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()


func _list_add(text: String, id: int) -> void:
	if _list_box == null:
		return
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if _rtl else HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(_on_row_pressed.bind(b, id))
	b.gui_input.connect(_on_row_input.bind(b, id))
	_list_box.add_child(b)


## En Android el toque puede quedarse en el ScrollContainer y no llegar al boton: se escucha
## tambien el toque de pantalla, y la seleccion se marca en la fila y en la linea de estado.
func _on_row_input(event: InputEvent, button: Button, id: int) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		_on_row_pressed(button, id)


func _on_row_pressed(button: Button, id: int) -> void:
	if _picked_button != null and _picked_button != button and is_instance_valid(_picked_button):
		_picked_button.button_pressed = false
	button.button_pressed = true
	button.modulate = Color(1.0, 1.0, 1.0)
	_picked_button = button
	_picked_id = id
	for child in _list_box.get_children():
		if child != button and child is Button:
			child.modulate = Color(1.0, 1.0, 1.0, 0.75)
	_status.text = _txt("Selected: %s" % button.text, "المحددة: %s" % button.text, "Elegida: %s" % button.text)


func _on_add_pressed(target: String) -> void:
	if _picked_id <= 0:
		_status.text = _txt("Pick a card in the list first.", "اختر بطاقة من القائمة أولًا.", "Elige una carta de la lista primero.")
		return
	var edit: LineEdit = _field_o
	if target == "grave_o":
		edit = _grave_o
	elif target == "grave_p":
		edit = _grave_p
	var cur := edit.text.strip_edges()
	if cur == "":
		edit.text = str(_picked_id)
	elif not cur.contains(str(_picked_id)):
		edit.text = cur + ", " + str(_picked_id)
	_status.text = _txt("Added %s (#%d)" % [_card_name_by_id(_picked_id), _picked_id],
			"أُضيفت %s (#%d)" % [_card_name_by_id(_picked_id), _picked_id],
			"Añadida %s (#%d)" % [_card_name_by_id(_picked_id), _picked_id])
	_update_summary()


func _list_selected() -> Array:
	return [_picked_id] if _picked_id > 0 else []


## Lista de nombres de lo que hay en cada casilla, para que se vea que se anadio.
func _update_summary() -> void:
	if _summary == null:
		return
	var lines: Array = []
	lines.append(_txt("Opp field", "ملعب الخصم", "Campo rival") + ": " + _names(_field_o.text))
	lines.append(_txt("Opp GY", "مقبرة الخصم", "Cem. rival") + ": " + _names(_grave_o.text))
	lines.append(_txt("My GY", "مقبرتك", "Mi cem.") + ": " + _names(_grave_p.text))
	_summary.text = "\n".join(lines)


func _names(text: String) -> String:
	var ids := _ids(text)
	if ids.is_empty():
		return _txt("empty", "فارغ", "vacío")
	var out: Array = []
	for id in ids:
		out.append(_card_name_by_id(int(id)))
	return ", ".join(out)


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
	var picked: Array = _list_selected()
	if picked.is_empty():
		_status.text = _txt("Pick a card first.", "اختر بطاقة أولًا.", "Elige una carta primero.")
		return
	var card_id := int(picked[0])
	var opts := {}
	var fo := _ids(_field_o.text)
	if not fo.is_empty():
		var entries: Array = []
		var mz := 0
		var sz := 5
		for id in fo:
			if mz < 5:
				entries.append({"card": id, "zone": mz, "c": 0})
				mz += 1
			elif sz < 10:
				entries.append({"card": id, "zone": sz, "c": 1})
				sz += 1
		opts["field_o"] = entries
	var go := _ids(_grave_o.text)
	if not go.is_empty():
		opts["grave_o"] = go
	var gp := _ids(_grave_p.text)
	if not gp.is_empty():
		opts["grave_p"] = gp
	if _lp_o.text.strip_edges().is_valid_int():
		opts["lp_o"] = int(_lp_o.text.strip_edges())
	if _lp_p.text.strip_edges().is_valid_int():
		opts["lp_p"] = int(_lp_p.text.strip_edges())
	Game.open_card_effect_test(card_id, opts)


## "Blue-Eyes White Dragon, 0x1f2" -> ids internos.
## Separadores: coma inglesa, coma arabe (،), punto y coma, salto de linea y, si el trozo no
## resuelve entero, espacios ("2500 2501"). Asi los nombres con espacios siguen funcionando.
func _ids(text: String) -> Array:
	var out: Array = []
	var normalizado := text.replace("،", ",").replace(";", ",").replace("\n", ",").replace("\r", ",")
	for raw in normalizado.split(",", false):
		var token := raw.strip_edges()
		if token == "":
			continue
		var id := _resolve(token)
		if id > 0:
			out.append(id)
			continue
		for part in token.split(" ", false):
			var pid := _resolve(part.strip_edges())
			if pid > 0:
				out.append(pid)
	return out


func _resolve(token: String) -> int:
	if token.begins_with("0x") or token.begins_with("0X"):
		return token.hex_to_int()
	if token.is_valid_int():
		return int(token)
	var q := token.to_lower()
	for card: Dictionary in CardDB.cards:
		if _card_name(card).to_lower() == q:
			return int(card.get("internal_id", 0))
	return 0
