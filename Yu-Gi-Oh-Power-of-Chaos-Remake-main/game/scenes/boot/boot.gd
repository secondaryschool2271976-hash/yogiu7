extends Node2D
## Arranque: comprueba que existe data/ y abre el selector de juego.


func _ready() -> void:
	# Herramienta de desarrollo Android: prueba de compartir sin abrir el juego.
	if Paths.cmdline_value("share-smoke") == "true":
		get_tree().root.add_child.call_deferred(load("res://share_smoke.gd").new())
		queue_free()
		return
	_apply_window_override()
	if OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		_show_mobile_loading()
		_boot_after_frame.call_deferred()
		return
	_finish_boot()


func _show_mobile_loading() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.03, 0.085, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	var title := Label.new()
	title.text = "Yu-Gi-Oh! 2"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Assets.ui_font(700))
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.32))
	box.add_child(title)
	var sub := Label.new()
	sub.text = "جاري تحميل اللعبة..." if Assets.lang == "a" else "Loading..."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", Assets.ui_font(700))
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.68, 0.88, 1.0))
	box.add_child(sub)
	add_child(layer)


func _boot_after_frame() -> void:
	await get_tree().process_frame
	if is_inside_tree():
		_finish_boot()


func _finish_boot() -> void:
	# Sin recursos: el importador de la plataforma (PC: copias del usuario; Android: PCK).
	if not Paths.has_data() or Paths.storage_error:
		Game.open_launcher()
		queue_free()
		return
	var start := Debug.start_override()
	var ending := Paths.cmdline_value("scene")
	if ending in ["credits", "video"]:
		Game.open_ending(start if start in Game.GAMES else "yugi", ending)
	elif ending == "joey-native":
		Game.current_game = "joey"
		Game.goto(load("res://scenes/duel/joey_native_normal.gd").new())
	elif ending == "joey-engine-harness":
		Game.current_game = "joey"
		Game.goto(load("res://scenes/duel/joey_native_duel.tscn").instantiate())
	elif ending == "lan":
		# Herramienta de desarrollo: --scene=lan abre la pantalla de conexion de Joey (D17).
		Game.open_lan("joey")
	elif Paths.cmdline_value("scenario") != "":
		# Herramienta de desarrollo: --scenario=<nombre o ruta> abre el duelo preparado.
		Game.open_normal_duel(start if start in Game.GAMES else "yugi")
	elif start in Game.GAMES:
		Game.open_title(start)
	else:
		Game.open_launcher()
	queue_free()


## El modo maximizado se configura al crear la ventana en project.godot.
## --window=ANCHOxALTO tiene prioridad sobre la preferencia del launcher.
func _apply_window_override() -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("mobile"):
		return
	var forced := Paths.cmdline_value("window").split("x")
	if forced.size() == 2 and forced[0].is_valid_int() and forced[1].is_valid_int():
		var size := Vector2i(forced[0].to_int(), forced[1].to_int())
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.window_get_current_screen()
		DisplayServer.window_set_position(DisplayServer.screen_get_position(screen)
				+ (DisplayServer.screen_get_size(screen) - size) / 2)
		return
	if LauncherSettings.fullscreen_mode != Window.MODE_WINDOWED:
		get_window().mode = LauncherSettings.fullscreen_mode
