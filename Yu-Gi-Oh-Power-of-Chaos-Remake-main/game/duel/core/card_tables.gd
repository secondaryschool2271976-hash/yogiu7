class_name CardTables
extends RefCounted
## Tablas de cartas tal como las consulta el motor del duelo (data/common/bin).
##
## El motor guarda en memoria el INDICE de la carta (12 bits) y lo traduce cuando hace falta:
##   id_of(indice)     = CARD_ID.bin[indice]   (FUN_00401a70; 0xffff si se sale de la tabla)
##   index_of(id)      = CARD_IntID.bin[id % 2000] + (id >= 2000)   (FUN_00401ad0)
##   prop(indice)      = CARD_Prop.bin[indice]  (FUN_00401a20)
## Los .ydc, los .ydr y los argumentos de los comandos usan el id ("internal_id" en cards.json).
##
## Campos de prop: bits 0-8 DEF/10, 9-17 ATK/10, 18-19 clase de monstruo, 20-24 tipo
## (21 = trampa, 22 = magia, < 21 monstruo), 25-28 nivel, 29-31 atributo.

const MAX_INDEX := 0x7fe
const EXTRA_CARDS_PATH := "res://assets/cards/extra_cards.json"

var ids := PackedInt32Array()
var int_ids := PackedInt32Array()
var props := PackedInt64Array()
var packs := PackedInt32Array()
var extra_id_to_index := {}
var effect_aliases := {}


func load_from(data_dir: String) -> bool:
	var bin_dir := data_dir.path_join("common/bin")
	var id_bytes := FileAccess.get_file_as_bytes(bin_dir.path_join("card_id.bin"))
	var int_bytes := FileAccess.get_file_as_bytes(bin_dir.path_join("card_intid.bin"))
	var prop_bytes := FileAccess.get_file_as_bytes(bin_dir.path_join("card_prop.bin"))
	var pack_bytes := FileAccess.get_file_as_bytes(bin_dir.path_join("card_pack.bin"))
	if id_bytes.is_empty() or int_bytes.is_empty() or prop_bytes.is_empty() or pack_bytes.is_empty():
		return false
	ids.resize(id_bytes.size() / 2)
	for i in ids.size():
		ids[i] = id_bytes.decode_u16(i * 2)
	int_ids.resize(int_bytes.size() / 2)
	for i in int_ids.size():
		int_ids[i] = int_bytes.decode_u16(i * 2)
	props.resize(prop_bytes.size() / 4)
	for i in props.size():
		props[i] = prop_bytes.decode_u32(i * 4)
	packs.resize(pack_bytes.size() / 2)
	for i in packs.size():
		packs[i] = pack_bytes.decode_u16(i * 2)
	_merge_extra_cards()
	return true


func _merge_extra_cards() -> void:
	extra_id_to_index.clear()
	effect_aliases.clear()
	if not FileAccess.file_exists(EXTRA_CARDS_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(EXTRA_CARDS_PATH))
	if not parsed is Dictionary:
		return
	var list: Variant = parsed.get("cards", [])
	if not list is Array:
		return
	var max_idx := ids.size()
	for raw: Variant in list:
		if raw is Dictionary:
			var idx := int(raw.get("index", 0))
			if idx > 0 and idx <= MAX_INDEX and idx + 1 > max_idx:
				max_idx = idx + 1
	if max_idx > ids.size():
		var old_n := ids.size()
		ids.resize(max_idx)
		props.resize(max_idx)
		packs.resize(max_idx)
		for i in range(old_n, max_idx):
			ids[i] = 0
			props[i] = 0
			packs[i] = 0
	for raw: Variant in list:
		if not raw is Dictionary:
			continue
		var idx := int(raw.get("index", 0))
		var iid := int(raw.get("internal_id", 0))
		if idx <= 0 or idx > MAX_INDEX or iid <= 0:
			continue
		ids[idx] = iid
		props[idx] = int(raw.get("prop", 0))
		packs[idx] = int(raw.get("pack", 7))
		extra_id_to_index[iid] = idx
		var alias_id := int(raw.get("effect_alias", 0))
		if alias_id > 0:
			effect_aliases[iid] = alias_id


## FUN_00401a70
func id_of(index: int) -> int:
	index &= 0xffff
	if index > MAX_INDEX or index >= ids.size():
		return 0xffff
	return ids[index]


## FUN_00401ad0
func index_of(card_id: int) -> int:
	card_id &= 0xffff
	if extra_id_to_index.has(card_id):
		return int(extra_id_to_index[card_id])
	if card_id > 3999:
		return 0
	return int_ids[card_id % 2000] + (1 if card_id > 1999 else 0)


func effect_id_of(card_id: int) -> int:
	return int(effect_aliases.get(card_id, card_id))


## FUN_00401a20
func prop(index: int) -> int:
	index &= 0x7ff
	return props[index] if index < props.size() else 0


## Tipo (bits 20-24): < 21 monstruo, 21 trampa, 22 magia.
func type_of(index: int) -> int:
	return (prop(index) >> 20) & 0x1f
