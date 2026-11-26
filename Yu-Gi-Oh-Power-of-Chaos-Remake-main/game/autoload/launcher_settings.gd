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


func custom_card_back_path(for_write := false) -> String:
	var user_path := ProjectSettings.globalize_path("user://custom_card_back.png")
	if is_instance_valid(Paths) and not Paths.storage_error and not Paths.storage_dir.is_empty():
		var in_storage := Paths.storage_dir.path_join("custom_card_back.png")
		if for_write or FileAccess.file_exists(in_storage):
			return in_storage
		if user_path != "" and FileAccess.file_exists(user_path):
			return user_path
		return in_storage
	return user_path


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
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		return "تعذر قراءة ملف الصورة المحدد." if is_instance_valid(Assets) and Assets.lang == "a" else "Could not load the selected image file."
	if img.get_width() != 200 or img.get_height() != 290:
		img.resize(200, 290, Image.INTERPOLATE_LANCZOS)
	var dest := custom_card_back_path(true)
	if dest.is_empty():
		dest = ProjectSettings.globalize_path("user://custom_card_back.png")
	DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
	var err := img.save_png(dest)
	if err != OK:
		return ("تعذر حفظ الصورة: " + error_string(err)) if is_instance_valid(Assets) and Assets.lang == "a" else ("Failed to save image: " + error_string(err))
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
