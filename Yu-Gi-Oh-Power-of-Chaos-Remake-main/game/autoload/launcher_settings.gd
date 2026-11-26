extends Node
## Preferencias del port, independientes de los recursos y de la partida.
const ASPECTS := ["balanced", "stretch", "original", "overlay"]
const BG_STYLES := ["new", "classic", "yugi_bg", "kaiba_bg", "joey_bg"]
const CARD_STYLES := ["arab", "classic"]
const CARD_BACKS := ["classic", "anime_classic", "ember_burst", "ocg_crimson_portal", "shadow_obsidian", "crimson_abyss", "crimson_dragon", "arcane_gold_violet", "yugi_edition", "kaiba_edition", "joey_edition", "gold_millennium", "dark_violet", "blue_eyes", "crimson_egyptian", "obsidian_cyan", "custom"]
const FRAME_RATES := [30, 60, 0] # 0: frecuencia del monitor actual.
const OFFLINE_DIFFICULTIES := ["auto", "easy", "normal", "hard", "expert"]
var aspect := _default_aspect()
var bg_style := "new"
var card_style := "arab"
var card_back := "classic"
var frame_rate := 0
var simulation_speed := 1.0
var fast_play := false
var improved_card_texts := false
var fullscreen_mode := Window.MODE_WINDOWED
var windowed_mode := Window.MODE_MAXIMIZED
var offline_difficulty := {"yugi": "auto", "kaiba": "auto", "joey": "auto"}
var offline_rival_deck := {"yugi": "", "kaiba": "", "joey": ""}
var offline_player_deck := {"yugi": "", "kaiba": "", "joey": ""}
var _refresh_clock := 0.0

static func _default_aspect() -> String:
	return "balanced" if (OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true") else "overlay"

func _ready() -> void:
	reload_preferences()
	apply_timing()

func reload_preferences() -> void:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	var fallback := _default_aspect()
	aspect = str(config.get_value("launcher", "aspect", fallback))
	if aspect not in ASPECTS: aspect = fallback
	bg_style = str(config.get_value("launcher", "bg_style", "new"))
	if bg_style not in BG_STYLES: bg_style = "new"
	card_style = str(config.get_value("launcher", "card_style", "arab"))
	if card_style not in CARD_STYLES: card_style = "arab"
	card_back = str(config.get_value("launcher", "card_back", "classic"))
	if card_back not in CARD_BACKS or (card_back == "custom" and not has_custom_card_back()):
		card_back = "classic"
	frame_rate = int(config.get_value("launcher", "fps", 0))
	if frame_rate not in FRAME_RATES: frame_rate = 0
	simulation_speed = float(config.get_value("launcher", "simulation_speed", 1.0))
	if simulation_speed not in [1.0, 2.0]: simulation_speed = 1.0
	fast_play = bool(config.get_value("launcher", "fast_play", false))
	improved_card_texts = bool(config.get_value("launcher", "improved_card_texts", false))
	fullscreen_mode = int(config.get_value("launcher", "fullscreen_mode", Window.MODE_WINDOWED)) as Window.Mode
	if fullscreen_mode not in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		fullscreen_mode = Window.MODE_WINDOWED
	windowed_mode = Window.MODE_WINDOWED if config.get_value("launcher", "windowed_mode", Window.MODE_MAXIMIZED) == Window.MODE_WINDOWED else Window.MODE_MAXIMIZED
	for g: String in ["yugi", "kaiba", "joey"]:
		var d := str(config.get_value("offline", g + "_difficulty", "auto"))
		offline_difficulty[g] = d if d in OFFLINE_DIFFICULTIES else "auto"
		offline_rival_deck[g] = str(config.get_value("offline", g + "_rival_deck", ""))
		offline_player_deck[g] = str(config.get_value("offline", g + "_player_deck", ""))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	config.set_value("launcher", "aspect", aspect)
	config.set_value("launcher", "bg_style", bg_style)
	config.set_value("launcher", "card_style", card_style)
	config.set_value("launcher", "card_back", card_back)
	config.set_value("launcher", "fps", frame_rate)
	config.set_value("launcher", "simulation_speed", simulation_speed)
	config.set_value("launcher", "fast_play", fast_play)
	config.set_value("launcher", "improved_card_texts", improved_card_texts)
	for g: String in ["yugi", "kaiba", "joey"]:
		config.set_value("offline", g + "_difficulty", str(offline_difficulty.get(g, "auto")))
		config.set_value("offline", g + "_rival_deck", str(offline_rival_deck.get(g, "")))
		config.set_value("offline", g + "_player_deck", str(offline_player_deck.get(g, "")))
	var error := config.save(Paths.settings_path())
	if error != OK: push_error("No se pudieron guardar los ajustes: " + error_string(error))
	apply_timing()


func set_bg_style(style: String) -> void:
	bg_style = style if style in BG_STYLES else "new"
	save_preferences()


func set_card_style(style: String) -> void:
	card_style = style if style in CARD_STYLES else "arab"
	save_preferences()
	if is_instance_valid(Assets) and Assets.has_method("invalidate_card_face_cache"):
		Assets.invalidate_card_face_cache()


func bg_texture_path(style: String = "") -> String:
	var s := bg_style if style == "" else style
	match s:
		"yugi_bg":
			return "res://assets/backgrounds/yugi_duel.jpg"
		"kaiba_bg":
			return "res://assets/backgrounds/kaiba_duel.png"
		"joey_bg":
			return "res://assets/backgrounds/joey_duel.png"
	return ""


func bg_style_label(style: String, lang: String) -> String:
	var ar := lang == "a"
	var es := lang == "s"
	match style:
		"classic":
			return "قديم (كلاسيكي)" if ar else ("Clásico (Antiguo)" if es else "Classic (Old)")
		"yugi_bg":
			return "خلفية يوغي (Yugi)" if ar else ("Fondo Yugi" if es else "Yugi Background")
		"kaiba_bg":
			return "خلفية كايبا (Kaiba)" if ar else ("Fondo Kaiba" if es else "Kaiba Background")
		"joey_bg":
			return "خلفية جوي (Joey)" if ar else ("Fondo Joey" if es else "Joey Background")
		_:
			return "جديد (عصري)" if ar else ("Nuevo (Moderno)" if es else "New (Modern)")


func card_style_label(style: String, lang: String) -> String:
	var ar := lang == "a"
	var es := lang == "s"
	if style == "classic":
		return "العادي الأصلي (القديم)" if ar else ("Clásico Original" if es else "Classic Original")
	return "المتطور (المبارزون العرب)" if ar else ("Moderno (Arab Duelists)" if es else "Modern (Arab Duelists)")


static func _read_file_bytes(src_path: String, max_bytes := 32 * 1024 * 1024) -> PackedByteArray:
	var bytes := PackedByteArray()
	var f := FileAccess.open(src_path, FileAccess.READ)
	if f != null:
		var total: int = f.get_length()
		if total > 0 and total <= max_bytes:
			bytes = f.get_buffer(total)
		else:
			while not f.eof_reached() and bytes.size() < max_bytes:
				var chunk := f.get_buffer(262144)
				if chunk.is_empty():
					break
				bytes.append_array(chunk)
		f.close()
	if bytes.is_empty():
		bytes = FileAccess.get_file_as_bytes(src_path)
	return bytes


static func _is_heif_or_avif(bytes: PackedByteArray) -> bool:
	if bytes.size() < 12:
		return false
	if bytes[4] != 0x66 or bytes[5] != 0x74 or bytes[6] != 0x79 or bytes[7] != 0x70:
		return false
	var brand := bytes.slice(8, 12).get_string_from_ascii().to_lower()
	return brand in ["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1", "avif", "avis"]


static func decode_image_bytes(bytes: PackedByteArray) -> Image:
	if bytes.size() < 4:
		return null
	var order: Array[String] = []
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4e and bytes[3] == 0x47:
		order.append("png")
	elif bytes[0] == 0xff and bytes[1] == 0xd8 and bytes[2] == 0xff:
		order.append("jpg")
	elif bytes.size() >= 12 and bytes[0] == 0x52 and bytes[1] == 0x49 and bytes[2] == 0x46 and bytes[3] == 0x46 and bytes[8] == 0x57 and bytes[9] == 0x45 and bytes[10] == 0x42 and bytes[11] == 0x50:
		order.append("webp")
	elif bytes[0] == 0x42 and bytes[1] == 0x4d:
		order.append("bmp")
	var looks_svg := false
	var head_len := mini(bytes.size(), 64)
	for i in head_len:
		var b := bytes[i]
		if b == 0x20 or b == 0x09 or b == 0x0a or b == 0x0d or (i < 3 and b in [0xef, 0xbb, 0xbf]):
			continue
		looks_svg = (b == 0x3c)
		break
	if looks_svg:
		order.append("svg")
	for fmt: String in ["png", "jpg", "webp", "bmp", "tga"]:
		if fmt not in order:
			order.append(fmt)
	for fmt: String in order:
		var img := Image.new()
		var err: int = ERR_UNAVAILABLE
		match fmt:
			"png":
				err = img.load_png_from_buffer(bytes)
			"jpg":
				err = img.load_jpg_from_buffer(bytes)
			"webp":
				err = img.load_webp_from_buffer(bytes)
			"bmp":
				err = img.load_bmp_from_buffer(bytes)
			"tga":
				err = img.load_tga_from_buffer(bytes)
			"svg":
				err = img.load_svg_from_buffer(bytes)
		if err == OK and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			if img.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
				img.convert(Image.FORMAT_RGBA8)
			return img
	return null


static func load_image_from_any_path(src_path: String) -> Image:
	if src_path.strip_edges().is_empty():
		return null
	var bytes := _read_file_bytes(src_path)
	if not bytes.is_empty():
		var decoded := decode_image_bytes(bytes)
		if decoded != null and not decoded.is_empty():
			return decoded
	var direct := Image.load_from_file(src_path)
	if direct != null and not direct.is_empty():
		if direct.is_compressed():
			direct.decompress()
		if direct.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
			direct.convert(Image.FORMAT_RGBA8)
		return direct
	return null


static func _write_bytes_to_path(dest: String, data: PackedByteArray) -> int:
	if dest.is_empty() or data.is_empty():
		return ERR_INVALID_PARAMETER
	if not dest.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(data)
	var err: int = f.get_error()
	f.close()
	return err


func custom_card_back_path(for_write := false) -> String:
	var user_virtual := "user://custom_card_back.png"
	var user_path := ProjectSettings.globalize_path(user_virtual)
	if is_instance_valid(Paths) and not Paths.storage_error and not Paths.storage_dir.is_empty():
		var in_storage := Paths.storage_dir.path_join("custom_card_back.png")
		if for_write or FileAccess.file_exists(in_storage):
			return in_storage
		if user_path != "" and FileAccess.file_exists(user_path):
			return user_path
		if FileAccess.file_exists(user_virtual):
			return user_virtual
		return in_storage
	if not for_write and not user_path.is_empty() and FileAccess.file_exists(user_path):
		return user_path
	return user_path if not user_path.is_empty() else user_virtual


func has_custom_card_back() -> bool:
	var p := custom_card_back_path(false)
	return p != "" and FileAccess.file_exists(p)


func set_card_back(style: String) -> void:
	if style not in CARD_BACKS:
		style = "classic"
	if style == "custom" and not has_custom_card_back():
		style = "classic"
	card_back = style
	save_preferences()
	if is_instance_valid(Assets):
		Assets.invalidate_card_back_cache()


func save_custom_card_back(src_path: String) -> String:
	var is_ar := is_instance_valid(Assets) and Assets.lang == "a"
	var is_es := is_instance_valid(Assets) and Assets.lang == "s"
	if src_path.strip_edges().is_empty():
		return "لم يتم اختيار أي ملف صورة." if is_ar else ("No se seleccionó ninguna imagen." if is_es else "No image file selected.")
	var raw_bytes := _read_file_bytes(src_path)
	var img: Image = decode_image_bytes(raw_bytes) if not raw_bytes.is_empty() else null
	if img == null or img.is_empty():
		img = load_image_from_any_path(src_path)
	if img == null or img.is_empty():
		if _is_heif_or_avif(raw_bytes):
			return "صيغة هذه الصورة (HEIC/AVIF) غير مدعومة، يرجى اختيار صورة PNG أو JPG أو WebP." if is_ar else ("Formato HEIC/AVIF no compatible; elige una imagen PNG, JPG o WebP." if is_es else "HEIC/AVIF images are not supported; please choose a PNG, JPG, or WebP image.")
		return "تعذر قراءة ملف الصورة المحدد." if is_ar else ("No se pudo leer la imagen seleccionada." if is_es else "Could not load the selected image file.")
	if img.get_width() != 200 or img.get_height() != 290:
		img.resize(200, 290, Image.INTERPOLATE_LANCZOS)
	var png_bytes := img.save_png_to_buffer()
	if png_bytes.is_empty():
		return "تعذر تجهيز الصورة للحفظ." if is_ar else ("No se pudo preparar la imagen." if is_es else "Could not encode the image.")
	var dest := custom_card_back_path(true)
	var err: int = _write_bytes_to_path(dest, png_bytes)
	if err != OK:
		var fallback := ProjectSettings.globalize_path("user://custom_card_back.png")
		if fallback != dest:
			err = _write_bytes_to_path(fallback, png_bytes)
		if err != OK:
			err = _write_bytes_to_path("user://custom_card_back.png", png_bytes)
	if err != OK:
		return ("تعذر حفظ الصورة: " + error_string(err)) if is_ar else (("No se pudo guardar la imagen: " + error_string(err)) if is_es else ("Failed to save image: " + error_string(err)))
	card_back = "custom"
	save_preferences()
	if is_instance_valid(Assets):
		Assets.invalidate_card_back_cache()
	return ""

func get_offline_difficulty(game: String) -> String:
	var d := str(offline_difficulty.get(game, "auto"))
	return d if d in OFFLINE_DIFFICULTIES else "auto"

func get_offline_rival_deck(game: String) -> String:
	return str(offline_rival_deck.get(game, ""))

func get_offline_player_deck(game: String) -> String:
	return str(offline_player_deck.get(game, ""))

func set_offline_setup(game: String, difficulty: String, rival_path: String, player_path: String) -> void:
	if game not in ["yugi", "kaiba", "joey"]:
		return
	offline_difficulty[game] = difficulty if difficulty in OFFLINE_DIFFICULTIES else "auto"
	offline_rival_deck[game] = rival_path.strip_edges()
	offline_player_deck[game] = player_path.strip_edges()
	save_preferences()

func toggle_fullscreen(window: Window) -> void:
	if window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
		set_display_mode(window, windowed_mode)
	else:
		set_display_mode(window, Window.MODE_FULLSCREEN)

func set_display_mode(window: Window, mode: Window.Mode) -> void:
	var fullscreen := mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if fullscreen and window.mode in [Window.MODE_WINDOWED, Window.MODE_MAXIMIZED]:
		windowed_mode = window.mode
	window.mode = mode
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	fullscreen_mode = mode if fullscreen else Window.MODE_WINDOWED
	var config := ConfigFile.new()
	config.load(Paths.settings_path())
	config.set_value("launcher", "fullscreen_mode", fullscreen_mode)
	config.set_value("launcher", "windowed_mode", windowed_mode)
	var error := config.save(Paths.settings_path())
	if error != OK: push_error("No se pudo guardar el modo de pantalla: " + error_string(error))

func gameplay_aspect() -> int:
	if aspect == "stretch": return Window.CONTENT_SCALE_ASPECT_IGNORE
	if aspect == "balanced": return Window.CONTENT_SCALE_ASPECT_EXPAND
	return Window.CONTENT_SCALE_ASPECT_KEEP

func display_fps() -> int:
	if DisplayServer.get_name() == "headless": return 60
	var rate := DisplayServer.screen_get_refresh_rate(get_window().current_screen)
	return roundi(rate) if rate > 0.0 else 60

## Tope del modo Display. En moviles solo manda VSync: las pantallas adaptativas (90/120 Hz)
## informan la frecuencia del momento, a menudo 60 al arrancar, y fijar ese tope impedia que el
## sistema subiera a 120 Hz. El renderer GL de Android no vota frecuencia (Swappy es solo Vulkan).
func monitor_fps_cap() -> int:
	return 0 if OS.has_feature("mobile") else display_fps()

## --max-fps en la linea de comandos (cotejos con el original a 30 Hz) manda sobre la
## preferencia del launcher. Godot consume ese argumento (no sale en get_cmdline_args) y el
## proyecto no fija max_fps: si ya vale algo al arrancar, viene de la linea de comandos.
var _cmdline_max_fps := Engine.max_fps

func _cmdline_timing() -> bool:
	return _cmdline_max_fps > 0

func apply_timing() -> void:
	if _cmdline_timing(): return
	Engine.max_fps = monitor_fps_cap() if frame_rate == 0 else frame_rate
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if frame_rate == 0 else DisplayServer.VSYNC_DISABLED)

func _process(delta: float) -> void:
	# Cambiar de monitor tambien actualiza el limite del modo Display.
	_refresh_clock += delta
	if _refresh_clock >= 1.0:
		_refresh_clock = 0.0
		if frame_rate == 0 and not _cmdline_timing(): Engine.max_fps = monitor_fps_cap()
