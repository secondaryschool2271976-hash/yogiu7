extends Node
## Acceso a data/ (fuera de res://, porque los assets de Konami no van en el proyecto).
## - Busqueda sin distinguir mayusculas: los scripts dicen "TITLE1.bmp" y el archivo es
##   "title1.png"; en Android el sistema de archivos si distingue.
## - ".bmp"/".yga" se resuelven al ".png" convertido.
## - "?" es la letra de idioma; si el recurso no existe en ese idioma se usa el ingles.

const LANG_FALLBACK := "e"
const LANGUAGES := {"a": "العربية", "s": "Español", "e": "English", "g": "Deutsch", "f": "Français", "i": "Italiano", "j": "日本語"}
const TEXT_LANGUAGES := {"a": "ara", "s": "spa", "e": "eng", "g": "ger", "f": "fra", "i": "ita", "j": "jpn"}
# Rotulos propios del selector; traducciones del port, no recursos del original.
const PORT_LABELS := {
	"a": ["اختر اللعبة", "الإعدادات", "الموسيقى", "كتم الصوت", "اللغة"],
	"s": ["ELIGE JUEGO", "CONFIGURACIÓN", "Música", "Silenciar", "Idioma"],
	"e": ["CHOOSE GAME", "SETTINGS", "Music", "Mute", "Language"],
	"g": ["SPIEL WÄHLEN", "EINSTELLUNGEN", "Musik", "Stumm", "Sprache"],
	"f": ["CHOISIR UN JEU", "PARAMÈTRES", "Musique", "Muet", "Langue"],
	"i": ["SCEGLI GIOCO", "IMPOSTAZIONI", "Musica", "Silenzia", "Lingua"],
	"j": ["ゲームを選択", "設定", "音楽", "ミュート", "言語"],
}

static var _ui_fonts := {}

static func ui_font(weight := 400) -> Font:
	var key := 700 if weight >= 600 else 400
	if not _ui_fonts.has(key):
		var path := "res://assets/fonts/DejaVuSans-Bold.ttf" if key == 700 else "res://assets/fonts/DejaVuSans.ttf"
		if ResourceLoader.exists(path):
			var loaded: Resource = load(path)
			if loaded is Font:
				_ui_fonts[key] = loaded
				return loaded
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["sans-serif"])
		font.font_weight = key
		_ui_fonts[key] = font
	return _ui_fonts[key]

func port_label(index: int) -> String:
	return str(PORT_LABELS.get(lang, PORT_LABELS[LANG_FALLBACK])[index])


var lang := "a"
var _index := {}        # ruta relativa en minusculas -> ruta absoluta
var _textures := {}     # ruta absoluta -> Texture2D
var _layouts := {}      # ruta absoluta -> Layout
var _missing := {}      # Un aviso por recurso ausente, aunque se solicite cada fotograma.
var _voice_packs := {}

const _CardBackArt := preload("res://core/card_back_art.gd")
const BUNDLED_CARD_PACK := "res://assets/cards/arabic_cards.zip"
const CARD_FULL_SIZE := Vector2i(200, 290)
const CARD_MINI_SIZE := Vector2i(50, 72)
const MIRROR_CHUNK_BYTES := 262144
const MIRROR_FRAME_BUDGET_USEC := 6000
var _card_pack_zip: ZIPReader = null
var _card_pack_file: FileAccess = null
var _card_pack_path := ""
var _card_pack_entries := {}  # stem en minusculas (p. ej. "lob001", "card_ura") -> ruta dentro del ZIP
var _card_pack_direct_entries := {}  # stem -> {lho, size, data_off} para entradas STORED (O(1))
var _card_pack_loaded := false
var _card_pack_mirroring := false
var _mirror_in: FileAccess = null
var _mirror_out: FileAccess = null
var _mirror_tmp := ""
var _mirror_target := ""
var _mirror_expected_size := 0
var _mirror_written := 0
var _mirror_pending_start := false
var _mirror_delay_sec := 0.0
var _card_budget_frame := -1
var _card_budget_loaded := 0
var _card_budget_start_usec := 0


func _ready() -> void:
	reindex()
	if OS.has_feature("android") and DisplayServer.get_name() != "headless":
		# Never touch res:// ZIP or spawn threads during boot; warm up gently after the launcher is visible.
		_mirror_pending_start = true
		_mirror_delay_sec = 1.5
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	if _mirror_pending_start:
		_mirror_delay_sec -= delta
		if _mirror_delay_sec > 0.0:
			return
		_mirror_pending_start = false
		_ensure_card_pack(false)
		if not _card_pack_mirroring:
			set_process(false)
		return
	if _card_pack_mirroring:
		_step_chunked_mirror()
		if not _card_pack_mirroring:
			set_process(false)
		return
	set_process(false)


func _exit_tree() -> void:
	_close_card_pack()


func _index_cache_path() -> String:
	if Paths.storage_error or Paths.storage_dir.is_empty():
		return ""
	return Paths.storage_dir.path_join("content/asset_index.cache")


func _index_cache_key() -> String:
	if Paths.data_dir != "res://data":
		return ""
	var stamp := Paths.content_pack_stamp()
	if stamp == "":
		return ""
	return "%s|%s" % [Paths.data_dir, stamp]


func _try_load_index_cache() -> bool:
	var key := _index_cache_key()
	var cache_file := _index_cache_path()
	if key == "" or cache_file == "" or not FileAccess.file_exists(cache_file):
		return false
	var f := FileAccess.open(cache_file, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = f.get_var(false)
	f.close()
	if not (parsed is Dictionary):
		return false
	if int(parsed.get("v", 0)) != 1 or str(parsed.get("key", "")) != key:
		return false
	var entries: Variant = parsed.get("index", null)
	if not (entries is Dictionary) or (entries as Dictionary).is_empty():
		return false
	_index = entries
	return true


func _save_index_cache() -> void:
	var key := _index_cache_key()
	var cache_file := _index_cache_path()
	if key == "" or cache_file == "" or _index.is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(cache_file.get_base_dir()) != OK:
		return
	var tmp := cache_file + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_var({"v": 1, "key": key, "index": _index}, false)
	var err := f.get_error()
	f.close()
	if err == OK:
		DirAccess.rename_absolute(tmp, cache_file)
	else:
		DirAccess.remove_absolute(tmp)


func reindex() -> void:
	_index.clear()
	_textures.clear()
	_layouts.clear()
	_missing.clear()
	_close_card_pack()
	if not _try_load_index_cache():
		if DirAccess.dir_exists_absolute(Paths.data_dir):
			_scan(Paths.data_dir, "")
			_save_index_cache()
	_voice_packs.clear()
	var voices: Variant = read_json("voice_manifest.json")
	if voices is Dictionary:
		_voice_packs = voices.get("games", {})


func voice_language(game: String) -> String:
	var pack: Dictionary = _voice_packs.get(game, {})
	var available: Array = pack.get("languages", [])
	if available.has(lang):
		return lang
	return str(pack.get("default", ""))


## Preferencia del port; los originales se instalaban con un idioma fijo.
func set_language(value: String) -> bool:
	if not LANGUAGES.has(value):
		return false
	lang = value
	return true


func system_language(locale: String = OS.get_locale_language()) -> String:
	if OS.has_feature("mobile"):
		return "a"
	return {"ar": "a", "es": "s", "en": "e", "de": "g", "fr": "f", "it": "i", "ja": "j"}.get(locale.replace("-", "_").get_slice("_", 0).to_lower(), "e")


func preferred_language() -> String:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	if OS.has_feature("mobile") and not bool(config.get_value("preferences", "arabic_default_v1", false)):
		config.set_value("preferences", "arabic_default_v1", true)
		config.set_value("preferences", "language", "a")
		config.save(Paths.settings_path())
		return "a"
	var value := str(config.get_value("preferences", "language", SaveData.data.get("settings", {}).get("language", system_language())))
	return value if LANGUAGES.has(value) else system_language()


func remember_language(value: String) -> void:
	if not set_language(value):
		return
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	if OS.has_feature("mobile"):
		config.set_value("preferences", "arabic_default_v1", true)
	config.set_value("preferences", "language", value)
	config.save(Paths.settings_path())
	if Paths.has_data():
		SaveData.data.get_or_add("settings", {})["language"] = value
		SaveData.save()


func text_language() -> String:
	return TEXT_LANGUAGES.get(lang, "spa")


func dialog_texts() -> Variant:
	var texts: Variant = read_json("common/db/dlg_%s.json" % text_language())
	if texts != null:
		return texts
	var fallback: Variant = read_json("common/db/dlg_eng.json")
	if lang == "a" and fallback is Array:
		return ArabicDialogs.localize_dialog_array(fallback)
	return fallback


## Ruta absoluta de un recurso, o "" si no existe.
func resolve(rel_path: String) -> String:
	var rel := rel_path.replace("\\", "/").to_lower()
	var parts := rel.split("/")
	if parts.size() == 4 and parts[1] == "voice" and parts[2] in ["stream", "internal"]:
		var pack: Dictionary = _voice_packs.get(parts[0], {})
		var choices: Array = [lang, pack.get("default", ""), "e"]
		choices.append_array(pack.get("languages", []))
		for language in choices:
			var localized := "%s/voice/%s/%s/%s" % [parts[0], language, parts[2], parts[3]]
			var voice := _lookup(localized)
			if voice != "":
				return voice
	for ext in [".bmp", ".yga"]:
		if rel.ends_with(ext):
			rel = rel.trim_suffix(ext) + ".png"
	if rel.contains("?"):
		var found: String = _lookup(rel.replace("?", lang))
		if found == "":
			found = _lookup(rel.replace("?", LANG_FALLBACK))
		return found
	return _lookup(rel)


func _lookup(rel: String) -> String:
	var path: String = _index.get(rel, "")
	# La copia optimizada conserva los nombres WAV en scripts y tablas nativas.
	if path == "" and rel.ends_with(".wav"):
		path = _index.get(rel.trim_suffix(".wav") + ".ogg", "")
	if path == "":
		for src_ext in [".png", ".webp", ".jpg", ".jpeg"]:
			if rel.ends_with(src_ext):
				var stem := rel.trim_suffix(src_ext)
				for dst_ext in [".webp", ".png", ".jpg", ".jpeg"]:
					if dst_ext == src_ext:
						continue
					path = _index.get(stem + dst_ext, "")
					if path != "":
						return path
				break
	return path


func exists(rel_path: String) -> bool:
	if _has_card_pack_entry(rel_path):
		return true
	if resolve(rel_path) != "":
		return true
	return _has_embedded_card_art(rel_path)


func card_pack_count() -> int:
	_ensure_card_pack(true)
	return _card_pack_entries.size()


func _abort_chunked_mirror() -> void:
	if _mirror_in != null:
		_mirror_in.close()
		_mirror_in = null
	if _mirror_out != null:
		_mirror_out.close()
		_mirror_out = null
	if _mirror_tmp != "" and FileAccess.file_exists(_mirror_tmp):
		DirAccess.remove_absolute(_mirror_tmp)
	_mirror_tmp = ""
	_mirror_target = ""
	_mirror_expected_size = 0
	_mirror_written = 0
	_card_pack_mirroring = false


func _close_card_pack() -> void:
	_abort_chunked_mirror()
	if _card_pack_zip != null:
		_card_pack_zip.close()
		_card_pack_zip = null
	if _card_pack_file != null:
		_card_pack_file.close()
		_card_pack_file = null
	_card_pack_path = ""
	_card_pack_entries.clear()
	_card_pack_direct_entries.clear()
	_card_pack_loaded = false


func _card_pack_mirror_targets() -> Array[String]:
	var mirror_targets: Array[String] = []
	if not Paths.storage_error and not Paths.storage_dir.is_empty():
		mirror_targets.append(Paths.storage_dir.path_join("arabic_cards.zip"))
	mirror_targets.append(ProjectSettings.globalize_path("user://arabic_cards.zip"))
	return mirror_targets


func _card_pack_meta_path(target: String) -> String:
	return target + ".cfg"


func _card_pack_build_stamp() -> String:
	var ver := str(ProjectSettings.get_setting("application/config/version", "")) + ":bls1"
	if FileAccess.file_exists("res://build_info.json"):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://build_info.json"))
		if info is Dictionary:
			ver += ":" + str(info.get("android_version_code", 0))
	return ver


func _find_existing_mirrored_pack(source: String, targets: Array[String]) -> String:
	var build_stamp := _card_pack_build_stamp()
	# Fast path: check cached metadata first so Android never reopens the 16 MB APK asset on repeat launches.
	for target: String in targets:
		if not FileAccess.file_exists(target):
			continue
		var meta := ConfigFile.new()
		if meta.load(_card_pack_meta_path(target)) == OK and str(meta.get_value("pack", "build", "")) == build_stamp:
			var cached_size := int(meta.get_value("pack", "size", 0))
			var existing := FileAccess.open(target, FileAccess.READ)
			if existing != null:
				var ok := cached_size > 0 and existing.get_length() == cached_size
				existing.close()
				if ok:
					return target
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return ""
	var expected_size := input.get_length()
	input.close()
	if expected_size <= 0:
		return ""
	for target: String in targets:
		if FileAccess.file_exists(target):
			var existing := FileAccess.open(target, FileAccess.READ)
			if existing != null:
				var same := existing.get_length() == expected_size
				existing.close()
				if same:
					_save_card_pack_meta(target, build_stamp, expected_size)
					return target
	return ""


func _save_card_pack_meta(target: String, build_stamp: String, expected_size: int) -> void:
	var meta := ConfigFile.new()
	meta.set_value("pack", "build", build_stamp)
	meta.set_value("pack", "size", expected_size)
	meta.save(_card_pack_meta_path(target))


func _start_chunked_mirror(source: String, targets: Array[String]) -> bool:
	if _card_pack_mirroring:
		return true
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return false
	var expected_size := input.get_length()
	if expected_size <= 0:
		input.close()
		return false
	for target: String in targets:
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			continue
		var tmp := target + ".tmp"
		var output := FileAccess.open(tmp, FileAccess.WRITE)
		if output != null:
			_mirror_in = input
			_mirror_out = output
			_mirror_tmp = tmp
			_mirror_target = target
			_mirror_expected_size = expected_size
			_mirror_written = 0
			_card_pack_mirroring = true
			set_process(true)
			return true
	input.close()
	return false


func _step_chunked_mirror(finish_now := false) -> void:
	if not _card_pack_mirroring or _mirror_in == null or _mirror_out == null:
		_abort_chunked_mirror()
		return
	var start_usec := Time.get_ticks_usec()
	while _mirror_written < _mirror_expected_size:
		var remaining := _mirror_expected_size - _mirror_written
		var chunk := _mirror_in.get_buffer(mini(MIRROR_CHUNK_BYTES, remaining))
		if chunk.is_empty():
			_abort_chunked_mirror()
			_card_pack_loaded = true
			return
		_mirror_out.store_buffer(chunk)
		if _mirror_out.get_error() != OK:
			_abort_chunked_mirror()
			_card_pack_loaded = true
			return
		_mirror_written += chunk.size()
		if not finish_now and (Time.get_ticks_usec() - start_usec) >= MIRROR_FRAME_BUDGET_USEC:
			return
	var target := _mirror_target
	var tmp := _mirror_tmp
	var expected_size := _mirror_expected_size
	_mirror_in.close()
	_mirror_in = null
	_mirror_out.close()
	_mirror_out = null
	_mirror_tmp = ""
	_mirror_target = ""
	_mirror_expected_size = 0
	_mirror_written = 0
	_card_pack_mirroring = false
	if DirAccess.rename_absolute(tmp, target) != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		_card_pack_loaded = true
		return
	_save_card_pack_meta(target, _card_pack_build_stamp(), expected_size)
	_mount_card_pack_path(target)
	_card_pack_loaded = true


func _ensure_card_pack(allow_blocking := false) -> void:
	if _card_pack_file != null or _card_pack_zip != null:
		return
	if _card_pack_loaded and not allow_blocking:
		return
	_mirror_pending_start = false
	if _card_pack_mirroring:
		if allow_blocking:
			_step_chunked_mirror(true)
		return
	var candidates: Array[String] = []
	if not Paths.storage_dir.is_empty():
		var custom_zip := Paths.storage_dir.path_join("custom_cards.zip")
		if FileAccess.file_exists(custom_zip):
			candidates.append(custom_zip)
	if FileAccess.file_exists(BUNDLED_CARD_PACK):
		candidates.append(BUNDLED_CARD_PACK)
	var is_android_device := OS.has_feature("android") and DisplayServer.get_name() != "headless"
	for source in candidates:
		# On Android, NEVER open a 16 MB ZIP directly from res:// inside the APK (AAsset seeking stalls/deadlocks).
		if not (is_android_device and source == BUNDLED_CARD_PACK):
			if _mount_card_pack_path(source):
				_card_pack_loaded = true
				return
		if source == BUNDLED_CARD_PACK:
			var mirror_targets := _card_pack_mirror_targets()
			var existing := _find_existing_mirrored_pack(source, mirror_targets)
			if existing != "":
				if _mount_card_pack_path(existing):
					_card_pack_loaded = true
					return
				# Corrupted local mirror from an interrupted install: remove and re-mirror cleanly.
				DirAccess.remove_absolute(existing)
				if FileAccess.file_exists(_card_pack_meta_path(existing)):
					DirAccess.remove_absolute(_card_pack_meta_path(existing))
			var must_sync := allow_blocking or DisplayServer.get_name() == "headless" or not OS.has_feature("mobile")
			if not must_sync:
				_start_chunked_mirror(source, mirror_targets)
				return
			for mirror_target in mirror_targets:
				var mirrored := _mirror_bundled_card_pack(source, mirror_target)
				if mirrored != "" and _mount_card_pack_path(mirrored):
					_card_pack_loaded = true
					return
	_card_pack_loaded = true


func _mirror_bundled_card_pack(source: String, target: String) -> String:
	var input := FileAccess.open(source, FileAccess.READ)
	if input == null:
		return ""
	var expected_size := input.get_length()
	if expected_size <= 0:
		input.close()
		return ""
	if FileAccess.file_exists(target):
		var existing := FileAccess.open(target, FileAccess.READ)
		if existing != null:
			var same := existing.get_length() == expected_size
			existing.close()
			if same:
				input.close()
				_save_card_pack_meta(target, _card_pack_build_stamp(), expected_size)
				return target
	if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
		input.close()
		return ""
	var tmp := target + ".tmp"
	var output := FileAccess.open(tmp, FileAccess.WRITE)
	if output == null:
		input.close()
		return ""
	while input.get_position() < expected_size:
		var chunk := input.get_buffer(mini(1024 * 1024, expected_size - input.get_position()))
		if chunk.is_empty():
			output.close()
			input.close()
			DirAccess.remove_absolute(tmp)
			return ""
		output.store_buffer(chunk)
		if output.get_error() != OK:
			output.close()
			input.close()
			DirAccess.remove_absolute(tmp)
			return ""
	output.close()
	input.close()
	if DirAccess.rename_absolute(tmp, target) != OK:
		DirAccess.remove_absolute(tmp)
		return ""
	_save_card_pack_meta(target, _card_pack_build_stamp(), expected_size)
	return target


func _mount_card_pack_path(path: String) -> bool:
	if _try_mount_direct_zip(path):
		return true
	var reader := ZIPReader.new()
	if reader.open(path) == OK:
		_card_pack_path = path
		_mount_card_pack_reader(reader)
		return true
	return false


func _try_mount_direct_zip(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var file_len := f.get_length()
	if file_len < 22:
		f.close()
		return false
	var tail_len := mini(file_len, 65557)
	f.seek(file_len - tail_len)
	var tail := f.get_buffer(tail_len)
	if tail.size() < 22:
		f.close()
		return false
	var eocd_pos := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail[i] == 0x50 and tail[i + 1] == 0x4B and tail[i + 2] == 0x05 and tail[i + 3] == 0x06:
			eocd_pos = i
			break
	if eocd_pos < 0:
		f.close()
		return false
	var cd_size := int(tail.decode_u32(eocd_pos + 12))
	var cd_offset := int(tail.decode_u32(eocd_pos + 16))
	if cd_size <= 0 or cd_offset < 0 or cd_offset + cd_size > file_len:
		f.close()
		return false
	f.seek(cd_offset)
	var cd := f.get_buffer(cd_size)
	if cd.size() != cd_size:
		f.close()
		return false
	var entries := {}
	var direct := {}
	var pos := 0
	var has_compressed := false
	while pos + 46 <= cd_size:
		if cd[pos] != 0x50 or cd[pos + 1] != 0x4B or cd[pos + 2] != 0x01 or cd[pos + 3] != 0x02:
			break
		var method := int(cd.decode_u16(pos + 10))
		var comp_size := int(cd.decode_u32(pos + 20))
		var uncomp_size := int(cd.decode_u32(pos + 24))
		var name_len := int(cd.decode_u16(pos + 28))
		var extra_len := int(cd.decode_u16(pos + 30))
		var comment_len := int(cd.decode_u16(pos + 32))
		var lho := int(cd.decode_u32(pos + 42))
		if pos + 46 + name_len > cd_size:
			break
		var entry := cd.slice(pos + 46, pos + 46 + name_len).get_string_from_utf8()
		pos += 46 + name_len + extra_len + comment_len
		if entry.ends_with("/"):
			continue
		var stem := entry.get_file().get_basename().to_lower()
		if stem != "" and not entries.has(stem):
			entries[stem] = entry
			if method == 0 and comp_size == uncomp_size and comp_size > 0:
				direct[stem] = {"lho": lho, "size": comp_size, "data_off": -1}
			else:
				has_compressed = true
	if entries.is_empty():
		f.close()
		return false
	_card_pack_file = f
	_card_pack_path = path
	_card_pack_entries = entries
	_card_pack_direct_entries = direct
	if not has_compressed and _card_pack_zip != null:
		_card_pack_zip.close()
		_card_pack_zip = null
	return true


func _mount_card_pack_reader(reader: ZIPReader) -> void:
	_card_pack_zip = reader
	_card_pack_entries.clear()
	_card_pack_direct_entries.clear()
	for entry: String in reader.get_files():
		if entry.ends_with("/"):
			continue
		var stem := entry.get_file().get_basename().to_lower()
		if stem != "" and not _card_pack_entries.has(stem):
			_card_pack_entries[stem] = entry


func _read_card_pack_bytes(stem: String, entry: String) -> PackedByteArray:
	if _card_pack_file != null and _card_pack_direct_entries.has(stem):
		var rec: Dictionary = _card_pack_direct_entries[stem]
		var data_off := int(rec["data_off"])
		if data_off < 0:
			var lho := int(rec["lho"])
			_card_pack_file.seek(lho)
			var hdr := _card_pack_file.get_buffer(30)
			if hdr.size() == 30 and hdr[0] == 0x50 and hdr[1] == 0x4B and hdr[2] == 0x03 and hdr[3] == 0x04:
				data_off = lho + 30 + int(hdr.decode_u16(26)) + int(hdr.decode_u16(28))
				rec["data_off"] = data_off
		if data_off >= 0:
			_card_pack_file.seek(data_off)
			return _card_pack_file.get_buffer(int(rec["size"]))
	if _card_pack_zip == null and _card_pack_path != "":
		var reader := ZIPReader.new()
		if reader.open(_card_pack_path) == OK:
			_card_pack_zip = reader
	if _card_pack_zip != null:
		return _card_pack_zip.read_file(entry)
	return PackedByteArray()


func _card_pack_lookup(rel_path: String) -> Dictionary:
	var norm := rel_path.replace("\\", "/").to_lower()
	var is_mini := false
	if norm.begins_with("common/card/"):
		is_mini = false
	elif norm.begins_with("common/mini/"):
		is_mini = true
	else:
		return {}
	var stem := norm.get_file().get_basename().to_lower()
	if stem != "card_ura" and is_instance_valid(LauncherSettings) and LauncherSettings.card_style == "classic":
		if resolve(rel_path) != "":
			return {}
	_ensure_card_pack()
	if (_card_pack_file == null and _card_pack_zip == null) or _card_pack_entries.is_empty():
		return {}
	if not _card_pack_entries.has(stem):
		return {}
	return {"stem": stem, "entry": str(_card_pack_entries[stem]), "mini": is_mini}


func _has_card_pack_entry(rel_path: String) -> bool:
	return not _card_pack_lookup(rel_path).is_empty()


func _load_card_pack_texture(info: Dictionary) -> Texture2D:
	var is_mini := bool(info["mini"])
	var stem := str(info["stem"])
	var cache_key := "card_pack:%s:%s" % ["mini" if is_mini else "card", stem]
	if _textures.has(cache_key):
		return _textures[cache_key]
	var buf = _read_card_pack_bytes(stem, str(info["entry"]))
	if buf.is_empty():
		return null
	var image := Image.new()
	var err := ERR_INVALID_DATA
	if buf.size() >= 2 and buf[0] == 0xFF and buf[1] == 0xD8:
		err = image.load_jpg_from_buffer(buf)
	elif buf.size() >= 4 and buf[0] == 0x89 and buf[1] == 0x50 and buf[2] == 0x4E and buf[3] == 0x47:
		err = image.load_png_from_buffer(buf)
	elif buf.size() >= 2 and buf[0] == 0x42 and buf[1] == 0x4D:
		err = image.load_bmp_from_buffer(buf)
	elif buf.size() >= 4 and buf[0] == 0x52 and buf[1] == 0x49 and buf[2] == 0x46 and buf[3] == 0x46:
		err = image.load_webp_from_buffer(buf)
	if err != OK or image.is_empty():
		return null
	var target := CARD_MINI_SIZE if is_mini else CARD_FULL_SIZE
	if image.get_width() != target.x or image.get_height() != target.y:
		image.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(image)
	_textures[cache_key] = tex
	return tex


## Arte de carta guardada como base64 dentro del proyecto (assets/cards/card_art_b64.json).
## Sirve para cartas cuya imagen todavia no esta en arabic_cards.zip: se decodifica en memoria
## con el mismo tamano que la del pack, asi que el resto del juego no nota la diferencia.
const EMBEDDED_CARD_ART_JSON := "assets/cards/card_art_b64.json"

var _embedded_card_art: Dictionary = {}
var _embedded_card_art_loaded := false


func _embedded_card_art_data() -> Dictionary:
	if _embedded_card_art_loaded:
		return _embedded_card_art
	_embedded_card_art_loaded = true
	var path := resolve(EMBEDDED_CARD_ART_JSON)
	if path == "" or not FileAccess.file_exists(path):
		path = "res://" + EMBEDDED_CARD_ART_JSON
	if not FileAccess.file_exists(path):
		return _embedded_card_art
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return _embedded_card_art
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return _embedded_card_art
	var art: Variant = (parsed as Dictionary).get("art", null)
	if not (art is Dictionary):
		return _embedded_card_art
	var table: Dictionary = art
	for stem: Variant in table.keys():
		var entry: Variant = table.get(stem, null)
		var b64 := ""
		if entry is String:
			b64 = (entry as String).strip_edges()
		elif entry is Array:
			for part: Variant in (entry as Array):
				b64 += str(part).strip_edges()
		if b64 != "":
			_embedded_card_art[str(stem).to_lower()] = b64
	return _embedded_card_art


func _has_embedded_card_art(rel_path: String) -> bool:
	var norm := rel_path.replace("\\", "/").to_lower()
	if not (norm.begins_with("common/card/") or norm.begins_with("common/mini/")):
		return false
	var stem := norm.get_file().get_basename()
	if stem == "" or stem == "card_ura":
		return false
	return _embedded_card_art_data().has(stem)


func _embedded_card_art_texture(rel_path: String) -> Texture2D:
	var norm := rel_path.replace("\\", "/").to_lower()
	var is_mini := norm.begins_with("common/mini/")
	if not is_mini and not norm.begins_with("common/card/"):
		return null
	var stem := norm.get_file().get_basename()
	if stem == "" or stem == "card_ura":
		return null
	var data := _embedded_card_art_data()
	if not data.has(stem):
		return null
	var key := "card_b64:%s:%s" % ["mini" if is_mini else "card", stem]
	if _textures.has(key):
		return _textures[key]
	var raw := Marshalls.base64_to_raw(str(data[stem]))
	if raw.is_empty():
		return null
	var image := Image.new()
	var err := ERR_INVALID_DATA
	if raw.size() >= 4 and raw[0] == 0x52 and raw[1] == 0x49 and raw[2] == 0x46 and raw[3] == 0x46:
		err = image.load_webp_from_buffer(raw)
	elif raw.size() >= 4 and raw[0] == 0x89 and raw[1] == 0x50 and raw[2] == 0x4E and raw[3] == 0x47:
		err = image.load_png_from_buffer(raw)
	if err != OK or image.is_empty():
		return null
	var target := CARD_MINI_SIZE if is_mini else CARD_FULL_SIZE
	if image.get_width() != target.x or image.get_height() != target.y:
		image.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	var tex := ImageTexture.create_from_image(image)
	_textures[key] = tex
	return tex


func invalidate_card_face_cache() -> void:
	_card_budget_frame = -1
	_card_budget_loaded = 0
	var to_erase: Array[String] = []
	for k: Variant in _textures.keys():
		var ks := str(k)
		var kn := ks.replace("\\", "/").to_lower()
		if kn.begins_with("card_pack:") or kn.begins_with("card_b64:") or kn.find("common/card/") != -1 or kn.find("common/mini/") != -1:
			if not kn.ends_with("card_ura") and not kn.ends_with("card_ura.png") and not kn.ends_with("card_ura.bmp") and not kn.ends_with("card_ura.webp"):
				to_erase.append(ks)
	for ks: String in to_erase:
		_textures.erase(ks)


func invalidate_card_back_cache() -> void:
	_CardBackArt.invalidate_cache()
	_textures.erase("card_pack:card:card_ura")
	_textures.erase("card_pack:mini:card_ura")
	for rel: String in ["common/card/card_ura.png", "common/mini/card_ura.png"]:
		var resolved := resolve(rel)
		if resolved != "":
			_textures.erase(resolved)


func _override_card_back_texture(rel_path: String) -> Texture2D:
	if not is_instance_valid(LauncherSettings) or LauncherSettings.card_back == "classic":
		return null
	var norm := rel_path.replace("\\", "/").to_lower()
	if norm.get_file().get_basename() != "card_ura":
		return null
	var is_mini := norm.begins_with("common/mini/")
	if not is_mini and not norm.begins_with("common/card/"):
		return null
	return _CardBackArt.get_texture(LauncherSettings.card_back, is_mini)


func original_card_back_texture(mini := false) -> Texture2D:
	var rel := "common/mini/card_ura.png" if mini else "common/card/card_ura.png"
	var pack_info := _card_pack_lookup(rel)
	if not pack_info.is_empty():
		var pack_tex := _load_card_pack_texture(pack_info)
		if pack_tex != null:
			return pack_tex
	var path := resolve(rel)
	if path == "":
		return null
	if not _textures.has(path):
		var image := Image.load_from_file(path)
		if image == null:
			return null
		_textures[path] = ImageTexture.create_from_image(image)
	return _textures[path]


func texture_card_deferred(rel_path: String, fallback_rel_path: String, max_per_frame := 8, budget_usec := 7000) -> Texture2D:
	var custom_back := _override_card_back_texture(rel_path)
	if custom_back != null:
		return custom_back
	if DisplayServer.get_name() == "headless" or Audio.game_clock:
		return texture(rel_path)
	if OS.has_feature("mobile"):
		max_per_frame = mini(max_per_frame, 4)
		budget_usec = mini(budget_usec, 4500)
	var pack_info := _card_pack_lookup(rel_path)
	if _card_pack_mirroring:
		return texture(fallback_rel_path) if fallback_rel_path != "" else null
	if not pack_info.is_empty():
		var cache_key = "card_pack:%s:%s" % ["mini" if bool(pack_info["mini"]) else "card", str(pack_info["stem"])]
		if _textures.has(cache_key):
			return _textures[cache_key]
	else:
		var resolved := resolve(rel_path)
		if resolved != "" and _textures.has(resolved):
			return _textures[resolved]
	var frame := Engine.get_process_frames()
	if frame != _card_budget_frame:
		_card_budget_frame = frame
		_card_budget_loaded = 0
		_card_budget_start_usec = Time.get_ticks_usec()
	if _card_budget_loaded >= max_per_frame or (_card_budget_loaded > 0 and (Time.get_ticks_usec() - _card_budget_start_usec) >= budget_usec):
		return texture(fallback_rel_path) if fallback_rel_path != "" else null
	_card_budget_loaded += 1
	if not pack_info.is_empty():
		var pack_tex := _load_card_pack_texture(pack_info)
		if pack_tex != null:
			return pack_tex
	return texture(rel_path)


func texture(rel_path: String) -> Texture2D:
	var custom_back := _override_card_back_texture(rel_path)
	if custom_back != null:
		return custom_back
	var pack_info := _card_pack_lookup(rel_path)
	if not pack_info.is_empty():
		var pack_tex := _load_card_pack_texture(pack_info)
		if pack_tex != null:
			return pack_tex
	var path := resolve(rel_path)
	if path == "":
		var embedded := _embedded_card_art_texture(rel_path)
		if embedded != null:
			return embedded
		if not _missing.has(rel_path):
			_missing[rel_path] = true
			push_warning("Recurso no encontrado: %s" % rel_path)
		return null
	if not _textures.has(path):
		var image := Image.load_from_file(path)
		if image == null:
			push_error("No se pudo cargar %s" % path)
			return null
		# Equivale a la opcion de importacion fix_alpha_border: evita que el color clave que
		# queda bajo los pixeles transparentes "sangre" al escalar con filtrado.
		# En movil, evitar fix_alpha_edges en fondos grandes (deck_c/duel) ahorra cientos de ms al abrir.
		var norm := rel_path.replace("\\", "/").to_lower()
		var skip_alpha_fix := norm.begins_with("common/card/") or norm.begins_with("common/mini/") \
			or (OS.has_feature("mobile") and image.get_width() * image.get_height() >= 180000)
		if not skip_alpha_fix and image.detect_alpha() != Image.ALPHA_NONE:
			image.fix_alpha_edges()
		_textures[path] = ImageTexture.create_from_image(image)
	return _textures[path]


func layout(rel_txt_path: String) -> Layout:
	var rel := rel_txt_path.trim_suffix(".txt") + ".layout.json"
	var path := resolve(rel)
	if path == "":
		push_error("Script de maquetacion no encontrado: %s" % rel_txt_path)
		return Layout.new()
	if not _layouts.has(path):
		_layouts[path] = Layout.from_json(FileAccess.get_file_as_string(path), rel_txt_path)
	return _layouts[path]


func read_json(rel_path: String) -> Variant:
	var path := resolve(rel_path)
	if path == "":
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _scan(abs_dir: String, rel_dir: String) -> void:
	var dir := DirAccess.open(abs_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var abs_path := abs_dir.path_join(name)
		var rel := name if rel_dir == "" else rel_dir + "/" + name
		if dir.current_is_dir():
			_scan(abs_path, rel)
		else:
			_index[rel.to_lower()] = abs_path
		name = dir.get_next()
