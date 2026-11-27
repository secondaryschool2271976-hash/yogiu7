extends Control
## Herramienta de prueba de efectos: busca una carta, empieza un duelo de practica con ella en
## la mano inicial y, si se indica, cartas en el campo/cementerio del rival o tuyo y LP.
## El duelo lo monta Game.open_card_effect_test() con la maquinaria de DuelScenario.

const MAX_RESULTS := 200

var _list: ItemList
var _grid: GridContainer
var _status: Label
var _field_o: LineEdit
var _grave_o: LineEdit
var _grave_p: LineEdit
var _lp_o: LineEdit
var _lp_p: LineEdit


func _ready() -> void:
	_build()
	_refresh("")
	get_viewport().size_changed.connect(_relayout)
	_relayout()


## En pantallas estrechas (telefono en vertical) las opciones van en una sola columna.
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
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = _txt("Card Effect Test", "اختبار تأثير البطاقة", "Prueba de efecto")
	title.add_theme_font_size_override("font_size", 28)
	col.add_child(title)

	var search := LineEdit.new()
	search.placeholder_text = _txt("Search a card by name", "ابحث عن بطاقة بالاسم", "Busca una carta por nombre")
	search.text_changed.connect(_refresh)
	search.custom_minimum_size = Vector2(0, 44)
	col.add_child(search)

	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0, 220)
	col.add_child(_list)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 6)
	col.add_child(_grid)
	var extra: GridContainer = _grid

	_field_o = _add_row(extra, _txt("Opponent field (names/ids, comma separated)", "ملعب الخصم (أسماء أو أرقام مفصولة بفاصلة)", "Campo rival (nombres/ids separados por coma)"))
	_grave_o = _add_row(extra, _txt("Opponent graveyard", "مقبرة الخصم", "Cementerio rival"))
	_grave_p = _add_row(extra, _txt("Your graveyard", "مقبرتك", "Tu cementerio"))
	_lp_o = _add_row(extra, _txt("Opponent LP (blank = 8000)", "نقاط حياة الخصم", "LP rival (vacío = 8000)"))
	_lp_p = _add_row(extra, _txt("Your LP (blank = 8000)", "نقاط حياتك", "Tus LP (vacío = 8000)"))

	_status = Label.new()
	_status.text = _txt("Pick the card to test, then press Start.", "اختر البطاقة ثم اضغط ابدأ.", "Elige la carta y pulsa Empezar.")
	col.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var start := Button.new()
	start.text = _txt("Start practice duel", "ابدأ مباراة تجريبية", "Empezar duelo de prueba")
	start.custom_minimum_size = Vector2(0, 52)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(_on_start)
	row.add_child(start)
	var back := Button.new()
	back.text = _txt("Back", "رجوع", "Volver")
	back.custom_minimum_size = Vector2(120, 52)
	back.pressed.connect(func() -> void: Game.open_launcher())
	row.add_child(back)


func _add_row(grid: GridContainer, label_text: String) -> LineEdit:
	var l := Label.new()
	l.text = label_text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)
	var e := LineEdit.new()
	e.custom_minimum_size = Vector2(0, 48)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(e)
	return e


func _list_clear() -> void:
	if _list != null:
		_list.clear()


func _list_add(text: String, id: int) -> void:
	if _list == null:
		return
	var i := _list.add_item(text)
	_list.set_item_metadata(i, id)


func _list_selected() -> Array:
	if _list == null:
		return []
	var sel := _list.get_selected_items()
	if sel.is_empty():
		return []
	var meta: Variant = _list.get_item_metadata(sel[0])
	return [int(meta)] if meta != null else []


func _card_name(card: Dictionary) -> String:
	var names: Dictionary = card.get("names", {})
	var lang: String = str({"a": "ara", "s": "spa"}.get(Assets.lang, "eng"))
	return str(names.get(lang, names.get("eng", "")))


func _refresh(query: String) -> void:
	_list_clear()
	var q := query.strip_edges().to_lower()
	var shown := 0
	for card: Dictionary in CardDB.cards:
		var nm := _card_name(card)
		if q != "" and not nm.to_lower().contains(q):
			continue
		_list_add("%s  ·  #%d" % [nm, int(card.get("internal_id", 0))], int(card.get("internal_id", 0)))
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
func _ids(text: String) -> Array:
	var out: Array = []
	for raw in text.split(",", false):
		var token := raw.strip_edges()
		if token == "":
			continue
		var id := _resolve(token)
		if id > 0:
			out.append(id)
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
