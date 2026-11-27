class_name Ydc
extends RefCounted
## Formato de mazo .ydc del original (Deck.ydc, file/cpu*.ydc):
##   8 bytes de cabecera: byte0/version y u32 +4/fecha de la coleccion.
##   El editor exporta la cabecera de system.dat; herramientas sin cabecera usan 1/0.
##   y tres listas en este orden: principal, fusion, side; cada una u16 n + n x u16 id interno.


static func save(path: String, deck: Dictionary, head := PackedByteArray()) -> bool:
	if not head.is_empty() and head.size() != 8: return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	if head.is_empty():
		f.store_32(1)
		f.store_32(0)
	else:
		f.store_buffer(head)
	for zone in ["main", "fusion", "side"]:
		var ids: Array = deck.get(zone, [])
		f.store_16(ids.size())
		for id in ids:
			f.store_16(int(id))
	f.close()
	return true


## Los 8 bytes de cabecera (vacio si no caben). El original (0x436bf0 -> 0x442750) solo
## compara el byte 0 y el u32 de +4 con los de la cabecera del system.dat.
static func header(path: String) -> PackedByteArray:
	var raw := FileAccess.get_file_as_bytes(path)
	return raw.slice(0, 8) if raw.size() >= 8 else PackedByteArray()

static func header_matches(actual: PackedByteArray, expected: PackedByteArray) -> bool:
	return actual.size() == 8 and expected.size() == 8 and actual[0] == expected[0] and actual.decode_u32(4) == expected.decode_u32(4)


## Devuelve {main, fusion, side} o {} si el archivo no es valido.
## Acepta el .ydc binario del original y tambien el .ydk de texto (empieza por '#').
static func load(path: String) -> Dictionary:
	var raw := FileAccess.get_file_as_bytes(path)
	if raw.size() < 2:
		return {}
	if raw[0] == 0x23:
		return load_ydk(raw.get_string_from_utf8())
	return _load_binary(raw)


static func _load_binary(raw: PackedByteArray) -> Dictionary:
	if raw.size() < 14:
		return {}
	var sp := StreamPeerBuffer.new()
	sp.data_array = raw
	sp.seek(8)
	var deck := {}
	for zone in ["main", "fusion", "side"]:
		if sp.get_position() + 2 > raw.size():
			return {}
		var n := sp.get_u16()
		if n > 200 or sp.get_position() + n * 2 > raw.size():
			return {}
		var ids: Array = []
		for i in n:
			ids.append(sp.get_u16())
		deck[zone] = ids
	return deck


## .ydk de texto: secciones #main / #extra / !side y el codigo de 8 digitos de cada carta.
## Aqui se traduce a id interno; las cartas que el juego no conoce se descartan.
static func load_ydk(text: String) -> Dictionary:
	var deck := {"main": [], "fusion": [], "side": []}
	var zone := "main"
	var saw_section := false
	for line in text.split("\n"):
		var l := line.strip_edges()
		if l == "":
			continue
		var low := l.to_lower()
		if low.begins_with("#main"):
			zone = "main"
			saw_section = true
			continue
		if low.begins_with("#extra"):
			zone = "fusion"
			saw_section = true
			continue
		if low.begins_with("!side") or low.begins_with("#side"):
			zone = "side"
			saw_section = true
			continue
		if low.begins_with("#") or low.begins_with("!"):
			continue
		if not l.is_valid_int():
			continue
		var cid := _id_for_code(l.to_int())
		if cid >= 0:
			deck[zone].append(cid)
	if not saw_section:
		return {}
	return deck


static var _code_map := {}


## El autoload CardDB se busca por nombre para que este script no dependa de el al compilar.
static func _card_db() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("CardDB")
	return null


## Codigo de carta del .ydk (password de 8 digitos) -> id interno del juego, o -1 si no existe.
static func _id_for_code(code: int) -> int:
	if code <= 0:
		return -1
	if code < 2500:
		return code
	if _code_map.is_empty():
		var db := _card_db()
		if db == null:
			return -1
		var cards: Variant = db.get("cards")
		if not (cards is Array):
			return -1
		for item: Variant in (cards as Array):
			if not (item is Dictionary):
				continue
			var card: Dictionary = item
			var pwd := str(card.get("password", card.get("code", ""))).strip_edges()
			if pwd != "" and not _code_map.has(pwd):
				_code_map[pwd] = int(card.get("internal_id", 0))
	var found: Variant = _code_map.get(str(code), null)
	if found != null:
		return int(found)
	# Tambien se acepta el id interno escrito tal cual (util para mazos hechos a mano).
	var db := _card_db()
	if db != null:
		var direct: Variant = db.call("by_id", code)
		if direct is Dictionary and not (direct as Dictionary).is_empty():
			return code
	return -1
