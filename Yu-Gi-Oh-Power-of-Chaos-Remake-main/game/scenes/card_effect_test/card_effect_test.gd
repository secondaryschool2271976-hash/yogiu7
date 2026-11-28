extends Control
## Herramienta de prueba de efectos: busca una carta, empieza un duelo de practica con ella en
## la mano inicial y, si se indica, cartas en el campo/cementerio de cada lado y LP.
## El duelo lo monta Game.open_card_effect_test() con la maquinaria de DuelScenario.
##
## Interfaz: arriba se elige el lado (Jugador / Oponente) y su mazo (por defecto, el activo, uno
## guardado o uno del juego). Cada carta de la lista tiene "Hand" (mano), "Add" (campo: monstruo a
## la zona de monstruos, magia/trampa a la zona de magia/trampa segun su tipo) y "GY" (cementerio).
## Cada lado muestra cuatro secciones con TODAS las cartas anadidas: mano, campo, magia/trampa y
## cementerio. Tocar una carta anadida la quita.
## Todo va dentro de un ScrollContainer y los botones de empezar/volver viven en una barra fija.

const MAX_RESULTS := 30  # filas por pagina; el boton "mas" agrega otras 30
## Solo se listan las cartas personalizadas (ids >= 2500); los monstruos normales originales no aportan nada al probar efectos.
const CUSTOM_MIN_ID := 2500
const ROW_HEIGHT := 52
const MON_MAX := 5
const ST_MAX := 5
const HAND_MAX := 5
const KINDS := ["hand", "field", "st", "grave"]

const C_BG := Color(0.88, 0.93, 0.99)
const C_TEXT := Color(0.07, 0.10, 0.22)
const C_PLAYER := Color(0.10, 0.34, 0.76)
const C_OPP := Color(0.78, 0.20, 0.18)
const C_ADD := Color(0.05, 0.50, 0.30)
const C_GY := Color(0.45, 0.27, 0.74)
const C_HAND := Color(1.0, 0.72, 0.18)
const C_CARD := Color(1.0, 1.0, 1.0)
const C_BAR := Color(0.70, 0.80, 0.95)

var _scroll: ScrollContainer
var _list_box: VBoxContainer
var _status: Label
var _lp_o: LineEdit
var _lp_p: LineEdit
var _side := 0  # 0 = jugador, 1 = oponente
var _hand: Array = [[], []]
var _field: Array = [[], []]  # monstruos
var _st: Array = [[], []]     # magia / trampa
var _grave: Array = [[], []]
var _deck_src: Array = [{"kind": "default"}, {"kind": "default"}]
var _deck_btns: Array = []
var _deck_overlay: Control = null
var _tab_buttons: Array = []
var _slots_box: VBoxContainer
var _rtl := false
var _last_press := {}
var _index: Array = []  # [id, texto normalizado], se construye una sola vez
var _style_cache := {}
var _search_timer: Timer
var _pending_query := ""
var _shown_limit := MAX_RESULTS
var _more_btn: Button
## Colocacion elegida para lo que se anade al campo: 0 ataque, 1 defensa, 11 boca abajo (monstruos);
## en magia/trampa, false = boca abajo y true = boca arriba. Se guarda en paralelo a _field / _st.
var _mon_pos := 0
var _st_up := false
var _field_c: Array = [[], []]
var _st_c: Array = [[], []]
var _pos_btn: Button


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
	# Los estilos se comparten entre botones: crear 4 por boton por pulsacion de tecla colgaba el movil.
	var ckey := "%s|%d" % [str(color), radius]
	if _style_cache.has(ckey):
		return _style_cache[ckey]
	var s := StyleBoxFlat.new()
	_style_cache[ckey] = s
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = color.darkened(0.28)
	s.set_border_width_all(2)
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

	col.add_child(_label(_txt("Card Effect Test", "اختبار تأثير البطاقات", "Prueba de efecto"), 28))
	col.add_child(_label(_txt("1. Choose Player or Opponent, and optionally a deck for that side. 2. Search a card and tap Hand, Add (field or spell/trap by card type) or GY (graveyard). 3. Tap an added card to remove it. 4. Press Start.",
			"١. اختر الجانب (اللاعب أو الخصم)، ويمكنك اختيار ديك له. ٢. ابحث عن البطاقة بالاسم أو الرقم، ثم اضغط «اليد» أو «الملعب» (وحش، أو سحر/فخ حسب نوع البطاقة) أو «المقبرة». ٣. لحذف بطاقة مضافة اضغط عليها. ٤. اضغط «ابدأ المباراة التجريبية». القائمة تعرض بطاقاتنا المخصصة فقط.",
			"1. Elige Jugador u Oponente y, si quieres, un mazo para ese lado. 2. Busca una carta y pulsa Hand (mano), Add (campo o magia/trampa según el tipo) o GY (cementerio). 3. Toca una carta añadida para quitarla. 4. Pulsa Empezar."), 14))

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

	var decks_row := HBoxContainer.new()
	decks_row.add_theme_constant_override("separation", 10)
	col.add_child(decks_row)
	_deck_btns = []
	for s2 in [0, 1]:
		var db := Button.new()
		db.custom_minimum_size = Vector2(0, 50)
		db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		db.clip_text = true
		_tap(db, _open_deck_picker.bind(s2))
		decks_row.add_child(db)
		_deck_btns.append(db)
	_update_deck_buttons()

	_pos_btn = Button.new()
	_pos_btn.custom_minimum_size = Vector2(0, 50)
	_pos_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tap(_pos_btn, _cycle_pos)
	col.add_child(_pos_btn)
	_update_pos_btn()

	var search := LineEdit.new()
	search.placeholder_text = _txt("Search a card by name", "ابحث بالاسم أو برقم البطاقة", "Busca una carta por nombre")
	search.text_changed.connect(_on_search_changed)
	_search_timer = Timer.new()
	_search_timer.one_shot = true
	_search_timer.wait_time = 0.35
	_search_timer.timeout.connect(func() -> void: _refresh(_pending_query))
	add_child(_search_timer)
	search.custom_minimum_size = Vector2(0, 50)
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_direction = Control.TEXT_DIRECTION_RTL if _rtl else Control.TEXT_DIRECTION_AUTO
	search.add_theme_color_override("font_color", C_TEXT)
	search.add_theme_color_override("font_placeholder_color", Color(0.35, 0.40, 0.52))
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

	col.add_child(_label(_txt("Added cards (in the order you picked them)", "البطاقات المضافة (بترتيب إضافتها)", "Cartas añadidas (en el orden elegido)"), 18))

	_slots_box = VBoxContainer.new()
	_slots_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_box.add_theme_constant_override("separation", 8)
	col.add_child(_slots_box)

	var lp_row := HBoxContainer.new()
	lp_row.add_theme_constant_override("separation", 10)
	col.add_child(lp_row)
	_lp_p = _lp_edit(lp_row, _txt("Your LP (blank = 8000)", "نقاط حياتك (فارغ = 8000)", "Tus LP (vacío = 8000)"))
	_lp_o = _lp_edit(lp_row, _txt("Opponent LP (blank = 8000)", "نقاط حياة الخصم (فارغ = 8000)", "LP rival (vacío = 8000)"))

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
	start.text = _txt("Start practice duel", "ابدأ المباراة التجريبية", "Empezar duelo de prueba")
	start.custom_minimum_size = Vector2(0, 56)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_button(start, C_ADD, 19)
	start.pressed.connect(_on_start)
	row.add_child(start)

	var back := Button.new()
	back.text = _txt("Back", "رجوع", "Volver")
	back.custom_minimum_size = Vector2(130, 56)
	_color_button(back, Color(0.33, 0.40, 0.56), 19)
	back.pressed.connect(func() -> void: Game.open_launcher())
	row.add_child(back)


func _pos_name() -> String:
	var mon: String = _txt("Attack", "هجوم", "Ataque")
	if _mon_pos == 1:
		mon = _txt("Defense", "دفاع", "Defensa")
	elif _mon_pos == 11:
		mon = _txt("Face-down", "مقلوب", "Boca abajo")
	var st: String = _txt("face-up", "مكشوف", "boca arriba") if _st_up else _txt("face-down", "مخفي", "boca abajo")
	return "%s: %s  |  %s: %s" % [_txt("Monsters", "الوحوش", "Monstruos"), mon, _txt("Spell/Trap", "السحر/الفخ", "Magia/Trampa"), st]


func _update_pos_btn() -> void:
	if _pos_btn == null:
		return
	_pos_btn.text = _pos_name() + "  (" + _txt("tap to change", "اضغط للتغيير", "toca para cambiar") + ")"
	_color_button(_pos_btn, Color(0.35, 0.40, 0.62), 15)


## Cada toque pasa a la siguiente combinacion: ataque, defensa, boca abajo; y al dar la vuelta
## completa se alterna magia/trampa boca abajo / boca arriba.
func _cycle_pos() -> void:
	if _mon_pos == 0:
		_mon_pos = 1
	elif _mon_pos == 1:
		_mon_pos = 11
	else:
		_mon_pos = 0
		_st_up = not _st_up
	_update_pos_btn()


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

	var hand_btn := Button.new()
	hand_btn.text = _txt("Hand", "اليد", "Mano")
	hand_btn.custom_minimum_size = Vector2(84, ROW_HEIGHT)
	hand_btn.clip_text = true
	hand_btn.set_meta("role", "hand")
	_tap(hand_btn, _on_add_pressed.bind(id, "hand"))
	row.add_child(hand_btn)

	var add_btn := Button.new()
	add_btn.text = _txt("Add", "الملعب", "Añadir")
	add_btn.custom_minimum_size = Vector2(76, ROW_HEIGHT)
	add_btn.clip_text = true
	add_btn.set_meta("role", "add")
	_tap(add_btn, _on_add_pressed.bind(id, "board"))
	row.add_child(add_btn)

	var gy_btn := Button.new()
	gy_btn.text = _txt("GY", "المقبرة", "Cem.")
	gy_btn.custom_minimum_size = Vector2(72, ROW_HEIGHT)
	gy_btn.clip_text = true
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
	for child in row.get_children():
		if not (child is Button):
			continue
		match str(child.get_meta("role")):
			"name":
				_color_button(child, C_CARD, 16)
				for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
					child.add_theme_color_override(k, C_TEXT)
			"hand":
				_color_button(child, C_HAND, 16)
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
	var card := CardDB.by_id(id)
	_status.text = "%s  (%s)" % [_card_name_by_id(id), _kind_label(card)]


func _kind_label(card: Dictionary) -> String:
	match str(card.get("category", "monster")):
		"spell": return _txt("Spell", "سحر", "Magia")
		"trap": return _txt("Trap", "فخ", "Trampa")
	return _txt("Monster", "وحش", "Monstruo")


func _is_field_spell(id: int) -> bool:
	var card := CardDB.by_id(id)
	return str(card.get("category", "")) == "spell" and CardDB.card_subcategory(card) == "field"


func _is_st(id: int) -> bool:
	var cat := str(CardDB.by_id(id).get("category", "monster"))
	return cat == "spell" or cat == "trap"


func _list_for(side: int, kind: String) -> Array:
	match kind:
		"hand": return _hand[side]
		"field": return _field[side]
		"st": return _st[side]
	return _grave[side]


func _kind_title(kind: String) -> String:
	match kind:
		"hand": return _txt("Hand", "اليد", "Mano")
		"field": return _txt("Field (monsters)", "ساحة الوحوش", "Campo (monstruos)")
		"st": return _txt("Spell/Trap", "السحر والفخ", "Magia/Trampa")
	return _txt("Graveyard", "المقبرة", "Cementerio")


## kind: "hand", "board" (monstruo -> campo, magia/trampa -> zona M/T segun el tipo) o "grave".
func _on_add_pressed(id: int, kind: String) -> void:
	if kind == "board":
		kind = "st" if _is_st(id) else "field"
	var lst: Array = _list_for(_side, kind)
	var cap := 99
	match kind:
		"hand": cap = HAND_MAX
		"field": cap = MON_MAX
		"st": cap = ST_MAX
	if lst.size() >= cap:
		_status.text = _txt("%s: %s is full (%d)." % [_side_name(_side), _kind_title(kind), cap],
				"%s: %s ممتلئة (%d)." % [_side_name(_side), _kind_title(kind), cap],
				"%s: %s está lleno (%d)." % [_side_name(_side), _kind_title(kind), cap])
		return
	if kind == "st" and _is_field_spell(id):
		for existing in lst:
			if _is_field_spell(int(existing)):
				_status.text = _txt("%s already has a Field Spell." % _side_name(_side),
						"%s لديه بطاقة ساحة (Field) بالفعل." % _side_name(_side),
						"%s ya tiene una Magia de Campo." % _side_name(_side))
				return
	lst.append(id)
	if kind == "field":
		_field_c[_side].append(_mon_pos)
	elif kind == "st":
		_st_c[_side].append(0 if _st_up else 1)
	_status.text = _txt("Added %s to %s - %s (#%d)" % [_card_name_by_id(id), _side_name(_side), _kind_title(kind), lst.size()],
			"تمت إضافة %s إلى %s ← %s (رقم %d)" % [_card_name_by_id(id), _side_name(_side), _kind_title(kind), lst.size()],
			"Añadida %s a %s - %s (n.º %d)" % [_card_name_by_id(id), _side_name(_side), _kind_title(kind), lst.size()])
	_update_slots()


func _remove_card(side: int, kind: String, index: int) -> void:
	var lst: Array = _list_for(side, kind)
	if index >= 0 and index < lst.size():
		lst.remove_at(index)
		if kind == "field" and index < _field_c[side].size():
			_field_c[side].remove_at(index)
		elif kind == "st" and index < _st_c[side].size():
			_st_c[side].remove_at(index)
	_update_slots()


## Casillas debajo de la lista: por lado, cuatro secciones (mano, campo, magia/trampa y
## cementerio) con todo lo anadido, numerado en el orden elegido. Tocar un chip lo quita.
func _update_slots() -> void:
	if _slots_box == null:
		return
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
		v.add_child(_label(_side_name(s) + "  ·  " + _deck_label(s), 18, _side_color(s).darkened(0.25)))
		for kind in KINDS:
			var lst: Array = _list_for(s, kind)
			v.add_child(_label("%s (%d):%s" % [_kind_title(kind), lst.size(), "" if not lst.is_empty() else " " + _txt("empty", "فارغ", "vacío")], 14))
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			v.add_child(flow)
			for i in range(lst.size()):
				var chip := Button.new()
				chip.text = "%d. %s  ✕" % [i + 1, _card_name_by_id(int(lst[i]))]
				chip.custom_minimum_size = Vector2(0, 40)
				var chip_color := _side_color(s)
				if kind == "grave":
					chip_color = C_GY
				elif kind == "hand":
					chip_color = Color(0.68, 0.42, 0.02)
				_color_button(chip, chip_color, 14)
				_tap(chip, _remove_card.bind(s, kind, i))
				flow.add_child(chip)


# ---------------------------------------------------------------- mazos

func _deck_label(side: int) -> String:
	var src: Dictionary = _deck_src[side]
	match str(src.get("kind", "default")):
		"active": return _txt("Active deck", "المجموعة النشطة", "Mazo activo")
		"default": return _txt("Default deck", "المجموعة الافتراضية", "Mazo por defecto")
	return str(src.get("label", "?"))


func _update_deck_buttons() -> void:
	for s in range(_deck_btns.size()):
		var b: Button = _deck_btns[s]
		b.text = "%s: %s" % [_txt("Deck", "المجموعة", "Mazo"), _deck_label(s)]
		_color_button(b, _side_color(s).darkened(0.1), 15)


## Origenes de mazo: por defecto, activo, guardados en el dispositivo (.ydc) y los del juego.
func _deck_sources() -> Array:
	var out: Array = []
	out.append({"kind": "default"})
	out.append({"kind": "active"})
	var dir := Paths.save_dir.path_join("decks")
	if DirAccess.dir_exists_absolute(dir):
		var files := Array(DirAccess.get_files_at(dir))
		files.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
		for f: String in files:
			if f.get_extension().to_lower() == "ydc":
				out.append({"kind": "ydc", "path": dir.path_join(f), "label": f.get_basename()})
	var presets: Dictionary = load("res://scenes/duel/rival_deck_choice.gd").PRESET_DECKS
	for g in ["yugi", "kaiba", "joey"]:
		for raw: Variant in presets.get(g, []):
			var e: Dictionary = raw
			var p := str(e.get("path", ""))
			if p == "" or not Assets.exists(p):
				continue
			out.append({"kind": "json", "path": p, "label": "[%s] %s" % [g, _txt(str(e.get("en", "")), str(e.get("ar", "")), str(e.get("es", "")))]})
	return out


func _open_deck_picker(side: int) -> void:
	_close_deck_picker()
	var layer := ColorRect.new()
	layer.color = Color(0.05, 0.08, 0.16, 0.97)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	_deck_overlay = layer
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	layer.add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	if _rtl:
		page.layout_direction = Control.LAYOUT_DIRECTION_RTL
	margin.add_child(page)
	page.add_child(_label(_txt("Deck for %s" % _side_name(side), "مجموعة %s" % _side_name(side), "Mazo de %s" % _side_name(side)), 24, Color(1, 1, 1)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	sc.add_child(box)
	for src: Dictionary in _deck_sources():
		var b := Button.new()
		var kind := str(src.get("kind", ""))
		var text := str(src.get("label", ""))
		if kind == "default":
			text = _txt("Default deck (original)", "المجموعة الافتراضية (الأصلية)", "Mazo por defecto (original)")
		elif kind == "active":
			text = _txt("Active deck (from the deck editor)", "المجموعة النشطة (من محرر المجموعات)", "Mazo activo (del editor)")
		elif kind == "ydc":
			text = "📁 " + text
		else:
			text = "🃏 " + text
		b.text = text
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 54)
		_color_button(b, Color(0.20, 0.30, 0.55), 16)
		_tap(b, _pick_deck.bind(side, src))
		box.add_child(b)
	var close := Button.new()
	close.text = _txt("Back", "رجوع", "Volver")
	close.custom_minimum_size = Vector2(0, 56)
	_color_button(close, Color(0.33, 0.40, 0.56), 19)
	_tap(close, _close_deck_picker)
	page.add_child(close)


func _close_deck_picker() -> void:
	if is_instance_valid(_deck_overlay):
		_deck_overlay.queue_free()
	_deck_overlay = null


func _pick_deck(side: int, src: Dictionary) -> void:
	_deck_src[side] = src
	_close_deck_picker()
	_update_deck_buttons()
	_update_slots()
	_status.text = _txt("%s deck: %s" % [_side_name(side), _deck_label(side)], "مجموعة %s: %s" % [_side_name(side), _deck_label(side)], "Mazo de %s: %s" % [_side_name(side), _deck_label(side)])


## El mazo elegido como {main, side, fusion}, o {} para usar el de defecto del duelo.
func _load_deck(side: int) -> Dictionary:
	var src: Dictionary = _deck_src[side]
	var raw: Variant = null
	match str(src.get("kind", "default")):
		"active":
			var decks: Dictionary = SaveData.data.get("decks", {})
			raw = decks.get("yugi", {})
		"ydc":
			raw = Ydc.load(str(src.get("path", "")))
		"json":
			raw = Assets.read_json(str(src.get("path", "")))
	if not (raw is Dictionary) or (raw as Dictionary).get("main", []).is_empty():
		return {}
	var d: Dictionary = raw
	return {"main": Array(d.get("main", [])), "side": Array(d.get("side", [])), "fusion": Array(d.get("fusion", []))}


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


func _on_search_changed(query: String) -> void:
	_pending_query = query
	_search_timer.start()


func _build_index() -> void:
	if not _index.is_empty():
		return
	for card: Dictionary in CardDB.cards:
		var cid := int(card.get("internal_id", 0))
		if cid < CUSTOM_MIN_ID:
			continue
		var names: Dictionary = card.get("names", {})
		var parts: Array = []
		for key in ["ara", "eng", "spa"]:
			parts.append(_norm(str(names.get(key, ""))))
		_index.append([cid, "\n".join(parts), _card_name(card)])
	_index.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))


func _refresh(query: String, limit := MAX_RESULTS) -> void:
	_build_index()
	_list_clear()
	_more_btn = null
	_shown_limit = limit
	var q := _norm(query.strip_edges())
	var shown := 0
	var total := 0
	var is_id := q.is_valid_int()
	for entry: Array in _index:
		var cid := int(entry[0])
		if q != "" and not ((is_id and cid == int(q)) or str(entry[1]).contains(q)):
			continue
		total += 1
		if shown < limit:
			_list_add("%s  ·  #%d" % [str(entry[2]), cid], cid)
			shown += 1
	if total > shown:
		_more_btn = Button.new()
		_more_btn.text = _txt("Show more (%d left)" % (total - shown), "عرض المزيد (باقي %d)" % (total - shown), "Mostrar más (faltan %d)" % (total - shown))
		_more_btn.custom_minimum_size = Vector2(0, ROW_HEIGHT)
		_color_button(_more_btn, Color(0.33, 0.40, 0.56), 18)
		var qq := query
		var lim := limit + MAX_RESULTS
		_tap(_more_btn, func() -> void: _refresh(qq, lim))
		_list_box.add_child(_more_btn)
	_status.text = _txt("%d cards" % total, "%d بطاقة" % total, "%d cartas" % total)


func _on_start() -> void:
	var opts := {}
	for s2 in [0, 1]:
		var key := "p" if s2 == 0 else "o"
		var entries: Array = []
		var mz := 0
		var sz := 5
		for fi in range(_field[s2].size()):
			if mz < MON_MAX:
				var fc := int(_field_c[s2][fi]) if fi < _field_c[s2].size() else 0
				entries.append({"card": int(_field[s2][fi]), "zone": mz, "c": fc})
				mz += 1
		for si in range(_st[s2].size()):
			if sz >= 10:
				break
			var id := int(_st[s2][si])
			var sc := int(_st_c[s2][si]) if si < _st_c[s2].size() else 1
			if _is_field_spell(id):
				entries.append({"card": id, "zone": 10, "c": 0})
			else:
				entries.append({"card": id, "zone": sz, "c": sc})
				sz += 1
		if not entries.is_empty():
			opts["field_" + key] = entries
		if not _grave[s2].is_empty():
			opts["grave_" + key] = _grave[s2].duplicate()
		if not _hand[s2].is_empty():
			opts["hand_" + key] = _hand[s2].duplicate()
		var deck := _load_deck(s2)
		if not deck.is_empty():
			opts["deck_" + key] = deck
	if _lp_o.text.strip_edges().is_valid_int():
		opts["lp_o"] = int(_lp_o.text.strip_edges())
	if _lp_p.text.strip_edges().is_valid_int():
		opts["lp_p"] = int(_lp_p.text.strip_edges())
	Game.open_card_effect_test(opts)
