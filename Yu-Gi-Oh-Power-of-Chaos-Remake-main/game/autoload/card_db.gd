extends Node
## Base de datos de cartas (data/common/db/cards.json, generada por pocx).
##
## Reparto por juego, como en el original (card_pack.bin es un campo de bits):
## - se GANAN solo las cartas del juego al que se esta jugando;
## - se pueden USAR las del juego en curso y las de los anteriores:
##   Yugi=1, Kaiba=3, Joey=7 (mascaras acumulativas del validador nativo).

## type_id de card_prop.bin (deducido de cartas conocidas, ver docs/INVENTARIO.md 4)
const TYPE_NAMES := {
	1: "Dragón", 2: "Zombi", 3: "Demonio", 4: "Piro", 5: "Serpiente Marina", 6: "Roca",
	7: "Máquina", 8: "Pez", 9: "Dinosaurio", 10: "Insecto", 11: "Bestia",
	12: "Guerrero-Bestia", 13: "Planta", 14: "Aqua", 15: "Guerrero", 16: "Bestia Alada",
	17: "Hada", 18: "Lanzador de Conjuros", 19: "Trueno", 20: "Reptil",
}
const KIND_SUFFIX := {"effect": "/Efecto", "fusion": "/Fusión", "ritual": "/Ritual"}
const TYPE_NAMES_AR := {
	1: "تنين", 2: "زومبي", 3: "شيطان", 4: "ناري", 5: "ثعبان بحر", 6: "صخري",
	7: "آلة", 8: "سمك", 9: "ديناصور", 10: "حشرة", 11: "وحش",
	12: "وحش محارب", 13: "نبات", 14: "مائي", 15: "محارب", 16: "وحش مجنح",
	17: "جنية", 18: "ساحر", 19: "رعد", 20: "زاحف",
	21: "بطاقة فخ", 22: "بطاقة سحر", 23: "طقوس", 24: "إله",
}
const KIND_SUFFIX_AR := {"effect": "/تأثير", "fusion": "/اندماج", "ritual": "/طقوس"}

## Grupos del editor de mazos, en el orden de las gemas del original:
## oro = normal, rojo = efecto, verde = magia, rosa = trampa, azul = ritual.
enum Group { NORMAL, EFFECT, SPELL, TRAP, RITUAL, FUSION }

const ALL_PACK_BITS := 1 | 2 | 4
const ORIGINAL_PACK_BITS := {"yugi": 1, "kaiba": 2, "joey": 4}
const PACK_BITS := {"yugi": ALL_PACK_BITS, "kaiba": ALL_PACK_BITS, "joey": ALL_PACK_BITS}
const USABLE_BITS := {"yugi": ALL_PACK_BITS, "kaiba": ALL_PACK_BITS, "joey": ALL_PACK_BITS}
const EXTRA_CARDS_PATH := "res://assets/cards/extra_cards.json"

var cards: Array[Dictionary] = []
var extra_cards: Array[Dictionary] = []
var _by_internal_id := {}
var _type_labels := {}
var _orig_art_map := {}
var _extra_props := {}
var _effect_aliases := {}
var _search_cache := {}
var _name_sort_ranks := {}


func _ready() -> void:
	load_db()


func _load_extra_pack() -> void:
	extra_cards.clear()
	_orig_art_map.clear()
	_extra_props.clear()
	_effect_aliases.clear()
	if not FileAccess.file_exists(EXTRA_CARDS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXTRA_CARDS_PATH))
	if not parsed is Dictionary:
		return
	var art_map: Variant = parsed.get("original_art", {})
	if art_map is Dictionary:
		_orig_art_map = art_map
	var extra_list: Variant = parsed.get("cards", [])
	if extra_list is Array:
		for raw: Variant in extra_list:
			if not raw is Dictionary:
				continue
			var card: Dictionary = raw
			extra_cards.append(card)
			var idx := int(card.get("index", 0))
			var iid := int(card.get("internal_id", 0))
			if idx > 0 and card.has("prop"):
				_extra_props[idx] = int(card["prop"])
			var alias_id := int(card.get("effect_alias", 0))
			if alias_id > 0:
				_effect_aliases[iid] = alias_id


func _db_cache_path() -> String:
	if Paths.storage_error or Paths.storage_dir.is_empty():
		return ""
	return Paths.storage_dir.path_join("content/card_db.cache")


func _db_cache_key() -> String:
	var extra_size := 0
	if FileAccess.file_exists(EXTRA_CARDS_PATH):
		var ef := FileAccess.open(EXTRA_CARDS_PATH, FileAccess.READ)
		if ef != null:
			extra_size = ef.get_length()
			ef.close()
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	var stamp := Paths.content_pack_stamp()
	var cards_path := Assets.resolve("common/db/cards.json")
	if stamp == "" and cards_path != "" and not cards_path.begins_with("res://"):
		stamp = "%d" % FileAccess.get_modified_time(cards_path)
	return "%s|%s|%d|%s|%s" % [Paths.data_dir, stamp, extra_size, ver, cards_path]


func _try_load_db_cache() -> bool:
	var cache_file := _db_cache_path()
	if cache_file == "" or not FileAccess.file_exists(cache_file):
		return false
	var f := FileAccess.open(cache_file, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = f.get_var(false)
	f.close()
	if not (parsed is Dictionary) or int(parsed.get("v", 0)) != 5:
		return false
	if str(parsed.get("key", "")) != _db_cache_key():
		return false
	var cached_cards: Variant = parsed.get("cards", null)
	var cached_extra: Variant = parsed.get("extra_cards", null)
	if not (cached_cards is Array) or not (cached_extra is Array):
		return false
	cards.assign(cached_cards)
	extra_cards.assign(cached_extra)
	_orig_art_map = parsed.get("orig_art_map", {})
	_extra_props = parsed.get("extra_props", {})
	_effect_aliases = parsed.get("effect_aliases", {})
	for card: Dictionary in cards:
		_by_internal_id[int(card["internal_id"])] = card
	return true


func _save_db_cache() -> void:
	var cache_file := _db_cache_path()
	if cache_file == "" or cards.is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(cache_file.get_base_dir()) != OK:
		return
	var tmp := cache_file + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({
		"v": 5,
		"key": _db_cache_key(),
		"cards": cards,
		"extra_cards": extra_cards,
		"orig_art_map": _orig_art_map,
		"extra_props": _extra_props,
		"effect_aliases": _effect_aliases,
	}, false)
	var err := f.get_error()
	f.close()
	if err == OK:
		DirAccess.rename_absolute(tmp, cache_file)
	else:
		DirAccess.remove_absolute(tmp)


func load_db() -> void:
	cards.clear()
	extra_cards.clear()
	_by_internal_id.clear()
	_type_labels.clear()
	_orig_art_map.clear()
	_extra_props.clear()
	_effect_aliases.clear()
	_search_cache.clear()
	_name_sort_ranks.clear()
	if _try_load_db_cache():
		return
	_load_extra_pack()
	var data: Variant = Assets.read_json("common/db/cards.json")
	if data != null:
		for card: Dictionary in data:
			var iid := int(card["internal_id"])
			if is_card_back_image(card.get("image", null), card):
				card["image"] = null
			var art_key := str(iid)
			if _orig_art_map.has(art_key):
				var arab_img := str(_orig_art_map[art_key])
				if not is_card_back_image(arab_img, card):
					card["arab_image"] = arab_img
			elif card.has("arab_image") and is_card_back_image(card.get("arab_image", null), card):
				card.erase("arab_image")
			cards.append(card)
			_by_internal_id[iid] = card
	for extra: Dictionary in extra_cards:
		var iid := int(extra["internal_id"])
		if is_card_back_image(extra.get("image", null), extra):
			extra["image"] = null
		if not _by_internal_id.has(iid):
			cards.append(extra)
			_by_internal_id[iid] = extra
	_save_db_cache()


func prop_bytes_with_extras(base_bytes: PackedByteArray) -> PackedByteArray:
	if _extra_props.is_empty():
		return base_bytes
	var max_index := base_bytes.size() / 4
	for idx: int in _extra_props:
		if idx + 1 > max_index:
			max_index = idx + 1
	var out := base_bytes.duplicate()
	if out.size() < max_index * 4:
		out.resize(max_index * 4)
	for idx: int in _extra_props:
		out.encode_u32(idx * 4, int(_extra_props[idx]))
	return out


func effect_alias_for(internal_id: int) -> int:
	return int(_effect_aliases.get(internal_id, internal_id))


func by_id(internal_id: int) -> Dictionary:
	return _by_internal_id.get(internal_id, {})


func name_of(internal_id: int, lang := "") -> String:
	var card := by_id(internal_id)
	return text(card, "names", lang) if card else "?"


func text(card: Dictionary, field: String, language := "") -> String:
	if language == "":
		language = Assets.text_language()
	var improved := CardTranslations.text(card, field, language)
	if improved != "":
		return improved
	var values: Dictionary = card.get(field, {})
	return str(values.get(language, values.get("eng", values.get("spa", ""))))


func obtainable_in(game: String) -> Array[Dictionary]:
	return _filter(PACK_BITS[game])


func usable_in(game: String) -> Array[Dictionary]:
	return _filter(USABLE_BITS[game])


func is_usable(internal_id: int, game: String) -> bool:
	var card := by_id(internal_id)
	return not card.is_empty() and (int(card["pack"]) & USABLE_BITS[game]) != 0


var _fallback_face_cache: Dictionary = {}


func _fallback_face_texture(card: Dictionary, mini: bool) -> Texture2D:
	var grp := group_of(card)
	var key := "%d_%d" % [int(grp), 1 if mini else 0]
	if _fallback_face_cache.has(key):
		return _fallback_face_cache[key] as Texture2D
	var w := 50 if mini else 200
	var h := 72 if mini else 290
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var frame := Color(0.84, 0.72, 0.42, 1.0)
	match grp:
		Group.EFFECT:
			frame = Color(0.82, 0.49, 0.25, 1.0)
		Group.RITUAL:
			frame = Color(0.35, 0.56, 0.84, 1.0)
		Group.FUSION:
			frame = Color(0.56, 0.36, 0.72, 1.0)
		Group.SPELL:
			frame = Color(0.14, 0.62, 0.54, 1.0)
		Group.TRAP:
			frame = Color(0.72, 0.28, 0.54, 1.0)
	var border := Color(0.16, 0.14, 0.12, 1.0)
	var inner_border := frame.darkened(0.32)
	var art_bg := Color(0.10, 0.11, 0.16, 1.0)
	var text_bg := frame.lightened(0.45)
	img.fill(border)
	var pad := 2 if mini else 6
	img.fill_rect(Rect2i(pad, pad, w - pad * 2, h - pad * 2), frame)
	var ax := 6 if mini else 20
	var ay := 12 if mini else 48
	var aw := w - ax * 2
	var ah := 36 if mini else 156
	img.fill_rect(Rect2i(ax - 1, ay - 1, aw + 2, ah + 2), inner_border)
	img.fill_rect(Rect2i(ax, ay, aw, ah), art_bg)
	var tx := 5 if mini else 16
	var ty := ay + ah + (4 if mini else 14)
	var tw := w - tx * 2
	var th := maxi(6, h - ty - (5 if mini else 16))
	img.fill_rect(Rect2i(tx - 1, ty - 1, tw + 2, th + 2), inner_border)
	img.fill_rect(Rect2i(tx, ty, tw, th), text_bg)
	var tex := ImageTexture.create_from_image(img)
	_fallback_face_cache[key] = tex
	return tex


static func is_card_back_image(raw_name: Variant, card: Dictionary = {}) -> bool:
	if raw_name == null:
		return true
	var base := str(raw_name).strip_edges().replace("\\", "/").get_file().get_basename().to_lower()
	if base == "" or base == "null":
		return true
	if base == "card_ura":
		return true
	if base == "token_sl":
		var names: Variant = card.get("names", {})
		var en := str(names.get("eng", "")) if names is Dictionary else ""
		return not en.ends_with(" Token")
	return false


static func has_card_art(card: Dictionary) -> bool:
	if card.is_empty():
		return false
	return (not is_card_back_image(card.get("image", null), card)) or (not is_card_back_image(card.get("arab_image", null), card))


func card_texture(internal_id: int, mini := false, allow_defer := false) -> Texture2D:
	var fallback := "common/mini/card_ura.png" if mini else "common/card/card_ura.png"
	var card := by_id(internal_id)
	if card.is_empty():
		return Assets.texture(fallback) if internal_id < 0 else _fallback_face_texture({}, mini)
	var use_classic := is_instance_valid(LauncherSettings) and LauncherSettings.card_style == "classic"
	var raw_orig: Variant = card.get("image", null)
	var raw_arab: Variant = card.get("arab_image", null)
	var orig_str := str(raw_orig) if not is_card_back_image(raw_orig, card) else ""
	var arab_str := str(raw_arab) if not is_card_back_image(raw_arab, card) else ""
	var primary_prefix := "common/mini/" if mini else "common/card/"
	var alt_prefix := "common/card/" if mini else "common/mini/"
	var candidates: Array[String] = []
	var ordered: Array[String] = []
	if use_classic:
		if orig_str != "":
			ordered.append(orig_str)
		if arab_str != "":
			ordered.append(arab_str)
	else:
		if arab_str != "":
			ordered.append(arab_str)
		if orig_str != "":
			ordered.append(orig_str)
	for img_name in ordered:
		candidates.append(primary_prefix + img_name)
	for img_name in ordered:
		candidates.append(alt_prefix + img_name)
	var rel := ""
	for cand in candidates:
		if Assets.exists(cand):
			rel = cand
			break
	if rel == "":
		return _fallback_face_texture(card, mini)
	if allow_defer:
		var deferred := Assets.texture_card_deferred(rel, "")
		return deferred if deferred != null else _fallback_face_texture(card, mini)
	var tex := Assets.texture(rel)
	return tex if tex != null else _fallback_face_texture(card, mini)


func group_of(card: Dictionary) -> Group:
	match str(card.get("category", "")):
		"spell":
			return Group.SPELL
		"trap":
			return Group.TRAP
	match str(card.get("monster_kind", "normal")):
		"effect":
			return Group.EFFECT
		"fusion":
			return Group.FUSION
		"ritual":
			return Group.RITUAL
	return Group.NORMAL


## Rotulos nativos dlg_text: tipos501..524 y sufijos550..554, en los seis idiomas.
func type_name(type_id: int) -> String:
	if type_id < 1 or type_id > 24:
		return "?"
	if Assets.lang == "a":
		return TYPE_NAMES_AR.get(type_id, "?")
	return _dialog_label(500 + type_id, TYPE_NAMES.get(type_id, "?"))


func _dialog_label(index: int, fallback: String) -> String:
	if not _type_labels.has(Assets.lang):
		_type_labels[Assets.lang] = Assets.dialog_texts()
	var labels: Variant = _type_labels[Assets.lang]
	if labels is Array and index < labels.size():
		return str(labels[index])
	return fallback


func type_text(card: Dictionary) -> String:
	match str(card.get("category", "")):
		"spell":
			return "[%s]" % type_name(22)
		"trap":
			return "[%s]" % type_name(21)
	var kind := str(card.get("monster_kind", ""))
	if bool(card.get("divine", false)):
		if Assets.lang == "a":
			return "[إله وحش%s]" % KIND_SUFFIX_AR.get(kind, "")
		return "[Divine-Beast%s]" % KIND_SUFFIX.get(kind, "")
	if Assets.lang == "a":
		return "[%s%s]" % [type_name(int(card.get("type_id", 0))), KIND_SUFFIX_AR.get(kind, "")]
	var suffix_index: int = {"effect": 550, "fusion": 551, "ritual": 552}.get(kind, -1)
	var suffix := _dialog_label(suffix_index, KIND_SUFFIX.get(kind, "")) if suffix_index >= 0 else ""
	return "[%s%s]" % [type_name(int(card.get("type_id", 0))), suffix]


func _filter(bits: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in cards:
		if int(card["pack"]) & bits:
			out.append(card)
	return out


static func normalize_search_text(raw: String) -> String:
	var s := raw.strip_edges().to_lower()
	if s.is_empty():
		return ""
	var out := ""
	for i in s.length():
		var code := s.unicode_at(i)
		# Strip Arabic diacritics (tashkeel) and tatweel
		if (code >= 0x064b and code <= 0x065f) or code == 0x0670 or code == 0x0640:
			continue
		# Normalize Arabic Alef variants, Ta Marbuta, Alef Maksura, Hamza-on-Waw/Ya
		match code:
			0x0622, 0x0623, 0x0625, 0x0671:
				out += "ا"
			0x0629:
				out += "ه"
			0x0649, 0x0626:
				out += "ي"
			0x0624:
				out += "و"
			_:
				out += s[i]
	return out


func _card_search_haystack(card: Dictionary) -> String:
	var iid := int(card.get("internal_id", -1))
	if iid >= 0 and _search_cache.has(iid):
		return str(_search_cache[iid])
	var parts: PackedStringArray = []
	var ar_name := text(card, "names", "ara")
	if ar_name != "":
		parts.append(ar_name)
	var cur_name := text(card, "names")
	if cur_name != "" and cur_name != ar_name:
		parts.append(cur_name)
	var en_name := text(card, "names", "eng")
	if en_name != "":
		parts.append(en_name)
	var es_name := text(card, "names", "spa")
	if es_name != "":
		parts.append(es_name)
	if iid >= 0:
		parts.append(str(iid))
	var pwd := str(card.get("password", card.get("code", "")))
	if pwd != "":
		parts.append(pwd)
	var haystack := normalize_search_text(" ".join(parts))
	if iid >= 0:
		_search_cache[iid] = haystack
	return haystack


func matches_search(card: Dictionary, normalized_query: String) -> bool:
	if normalized_query.is_empty():
		return true
	var haystack := _card_search_haystack(card)
	for token in normalized_query.split(" ", false):
		if not haystack.contains(token):
			return false
	return true


static func card_attribute_key(card: Dictionary) -> String:
	if str(card.get("category", "")) != "monster":
		return ""
	if bool(card.get("divine", false)) or int(card.get("type_id", 0)) == 24:
		return "divine"
	var attr := str(card.get("attribute", "")).strip_edges().to_lower()
	if attr in ["light", "dark", "fire", "water", "earth", "wind", "divine"]:
		return attr
	var prop := int(card.get("prop", 0))
	match prop >> 29:
		1: return "light"
		2: return "dark"
		3: return "water"
		4: return "fire"
		5: return "earth"
		6: return "wind"
		7: return "divine"
	return ""


func matches_filters(card: Dictionary, normalized_query: String, attr_filter := "all", type_filter := "all") -> bool:
	if not matches_search(card, normalized_query):
		return false
	if attr_filter != "" and attr_filter != "all":
		if card_attribute_key(card) != attr_filter:
			return false
	if type_filter != "" and type_filter != "all":
		match type_filter:
			"monster":
				if str(card.get("category", "")) != "monster":
					return false
			"normal":
				if group_of(card) != Group.NORMAL:
					return false
			"effect":
				if group_of(card) != Group.EFFECT:
					return false
			"fusion":
				if group_of(card) != Group.FUSION:
					return false
			"ritual":
				if group_of(card) != Group.RITUAL:
					return false
			"spell":
				if group_of(card) != Group.SPELL:
					return false
			"trap":
				if group_of(card) != Group.TRAP:
					return false
	return true


static func attribute_filter_options(lang: String) -> Array[Dictionary]:
	if lang == "a":
		return [
			{"id": "all", "label": "كل السمات"},
			{"id": "light", "label": "النور (LIGHT)"},
			{"id": "dark", "label": "الظلام (DARK)"},
			{"id": "fire", "label": "النار (FIRE)"},
			{"id": "water", "label": "الماء (WATER)"},
			{"id": "earth", "label": "الأرض (EARTH)"},
			{"id": "wind", "label": "الرياح (WIND)"},
			{"id": "divine", "label": "إلهي (DIVINE)"},
		]
	if lang == "s":
		return [
			{"id": "all", "label": "Todos los atributos"},
			{"id": "light", "label": "LUZ"},
			{"id": "dark", "label": "OSCURIDAD"},
			{"id": "fire", "label": "FUEGO"},
			{"id": "water", "label": "AGUA"},
			{"id": "earth", "label": "TIERRA"},
			{"id": "wind", "label": "VIENTO"},
			{"id": "divine", "label": "DIVINIDAD"},
		]
	return [
		{"id": "all", "label": "All Attributes"},
		{"id": "light", "label": "LIGHT"},
		{"id": "dark", "label": "DARK"},
		{"id": "fire", "label": "FIRE"},
		{"id": "water", "label": "WATER"},
		{"id": "earth", "label": "EARTH"},
		{"id": "wind", "label": "WIND"},
		{"id": "divine", "label": "DIVINE"},
	]


static func type_filter_options(lang: String) -> Array[Dictionary]:
	if lang == "a":
		return [
			{"id": "all", "label": "كل الأنواع"},
			{"id": "monster", "label": "كل الوحوش"},
			{"id": "normal", "label": "وحش عادي"},
			{"id": "effect", "label": "وحش تأثير"},
			{"id": "fusion", "label": "وحش اندماج"},
			{"id": "ritual", "label": "وحش طقوس"},
			{"id": "spell", "label": "بطاقات السحر"},
			{"id": "trap", "label": "بطاقات الفخ"},
		]
	if lang == "s":
		return [
			{"id": "all", "label": "Todos los tipos"},
			{"id": "monster", "label": "Todos los monstruos"},
			{"id": "normal", "label": "Monstruo Normal"},
			{"id": "effect", "label": "Monstruo de Efecto"},
			{"id": "fusion", "label": "Monstruo de Fusión"},
			{"id": "ritual", "label": "Monstruo de Ritual"},
			{"id": "spell", "label": "Cartas Mágicas"},
			{"id": "trap", "label": "Cartas de Trampa"},
		]
	return [
		{"id": "all", "label": "All Card Types"},
		{"id": "monster", "label": "All Monsters"},
		{"id": "normal", "label": "Normal Monster"},
		{"id": "effect", "label": "Effect Monster"},
		{"id": "fusion", "label": "Fusion Monster"},
		{"id": "ritual", "label": "Ritual Monster"},
		{"id": "spell", "label": "Spell Cards"},
		{"id": "trap", "label": "Trap Cards"},
	]


func _build_name_sort_ranks(language: String) -> Dictionary:
	var entries: Array[Dictionary] = []
	entries.resize(cards.size())
	for i in cards.size():
		var card: Dictionary = cards[i]
		var iid := int(card.get("internal_id", 0))
		var raw_name := text(card, "names", language)
		var norm := normalize_search_text(raw_name)
		entries[i] = {"id": iid, "key": norm}
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka := str(a["key"])
		var kb := str(b["key"])
		if ka != kb:
			return ka < kb
		return int(a["id"]) < int(b["id"])
	)
	var ranks := {}
	for i in entries.size():
		ranks[int(entries[i]["id"])] = i
	return ranks


func name_sort_rank(card: Dictionary, language := "") -> int:
	var target_lang := language if language != "" else Assets.text_language()
	if not _name_sort_ranks.has(target_lang):
		_name_sort_ranks[target_lang] = _build_name_sort_ranks(target_lang)
	var ranks: Dictionary = _name_sort_ranks[target_lang]
	var iid := int(card.get("internal_id", 0))
	return int(ranks.get(iid, 100000 + int(card.get("index", 0))))


static func make_magnifying_glass_icon(size_px: int = 16, col: Color = Color(1.0, 0.92, 0.62, 1.0)) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := float(size_px) * 0.40
	var cy := float(size_px) * 0.40
	var radius := float(size_px) * 0.28
	var thickness := maxf(1.6, float(size_px) * 0.11)
	for y in size_px:
		for x in size_px:
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			var ring_err := absf(dist - radius)
			var alpha := 0.0
			if ring_err <= thickness:
				alpha = clampf(1.0 - maxf(0.0, ring_err - (thickness - 0.85)) / 0.85, 0.0, 1.0)
			# Handle extending down-right from the lens rim
			var hx0 := cx + radius * 0.68
			var hy0 := cy + radius * 0.68
			var hx1 := float(size_px) * 0.88
			var hy1 := float(size_px) * 0.88
			var vx := hx1 - hx0
			var vy := hy1 - hy0
			var vlen2 := vx * vx + vy * vy
			if vlen2 > 0.001:
				var t := clampf(((float(x) + 0.5 - hx0) * vx + (float(y) + 0.5 - hy0) * vy) / vlen2, 0.0, 1.0)
				var px := hx0 + t * vx
				var py := hy0 + t * vy
				var hdist := sqrt((float(x) + 0.5 - px) * (float(x) + 0.5 - px) + (float(y) + 0.5 - py) * (float(y) + 0.5 - py))
				if hdist <= thickness * 0.95:
					var ha := clampf(1.0 - maxf(0.0, hdist - (thickness * 0.95 - 0.75)) / 0.75, 0.0, 1.0)
					alpha = maxf(alpha, ha)
			if alpha > 0.01:
				img.set_pixel(x, y, Color(col.r, col.g, col.b, col.a * alpha))
	return ImageTexture.create_from_image(img)


