extends Node
## Estado global y navegacion entre pantallas (todas se construyen por codigo).

const GAMES := ["yugi", "kaiba", "joey"]
## Prefijo de carpeta de cada juego dentro de data/ y nombre visible.
const TITLES := {"yugi": "Yugi the Destiny", "kaiba": "Kaiba the Revenge", "joey": "Joey the Passion"}

# El ultimo nodo recibe los atajos antes que las escenas y sus SubViewports.
class WindowShortcuts:
	extends Node
	func _input(event: InputEvent) -> void:
		if not event is InputEventKey: return
		var key: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if key != KEY_F11 and not (event.alt_pressed and key in [KEY_ENTER, KEY_KP_ENTER]): return
		# Consumir tambien la repeticion: Alt+Enter no confirma una carta o un dialogo.
		get_tree().root.set_input_as_handled()
		if event.pressed and not event.echo:
			LauncherSettings.toggle_fullscreen(get_tree().root)

class MatchHud:
	extends CanvasLayer
	var _btn := Button.new()
	var _pressed := false
	var _normal_style: StyleBoxFlat
	var _hover_style: StyleBoxFlat
	var _pressed_style: StyleBoxFlat

	func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = bg
		box.border_color = border
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		box.shadow_color = Color(0, 0, 0, 0.55)
		box.shadow_size = 4
		return box

	func _ready() -> void:
		layer = 95
		var mobile: bool = OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"
		_btn.focus_mode = Control.FOCUS_NONE
		_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_btn.size = Vector2(146, 40) if mobile else Vector2(138, 32)
		_btn.add_theme_font_override("font", Assets.ui_font(700))
		_btn.add_theme_font_size_override("font_size", 15 if mobile else 13)
		_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
		_normal_style = _make_style(Color(0.42, 0.08, 0.11, 0.90), Color(0.92, 0.75, 0.36, 0.92))
		_hover_style = _make_style(Color(0.58, 0.12, 0.16, 0.96), Color(1.0, 0.86, 0.48, 1.0))
		_pressed_style = _make_style(Color(0.32, 0.06, 0.08, 0.98), Color(1.0, 0.88, 0.52, 1.0))
		_btn.add_theme_stylebox_override("normal", _normal_style)
		_btn.add_theme_stylebox_override("hover", _hover_style)
		_btn.add_theme_stylebox_override("pressed", _pressed_style)
		_btn.hide()
		add_child(_btn)

	func button_visible() -> bool:
		return _btn.visible

	func button_rect() -> Rect2:
		return _btn.get_global_rect()

	func _label_text() -> String:
		var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
		if lang == "a":
			return "انسحاب تام"
		if lang == "s":
			return "Salir del Match"
		return "Surrender Match"

	func _process(_delta: float) -> void:
		if not Game.can_surrender_match():
			_pressed = false
			_btn.hide()
			return
		var wanted: String = _label_text()
		if _btn.text != wanted:
			_btn.text = wanted
		var bounds: Rect2 = get_viewport().get_visible_rect()
		_btn.position = Vector2(bounds.end.x - _btn.size.x - 10.0, bounds.position.y + 8.0)
		_btn.show()

	func _input(event: InputEvent) -> void:
		if not _btn.visible or bool(event.get_meta("platform_touch", false)):
			return
		if event is InputEventMouseMotion:
			var over: bool = _btn.get_global_rect().has_point(event.position)
			_btn.add_theme_stylebox_override("normal", _pressed_style if _pressed else (_hover_style if over else _normal_style))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			var over: bool = _btn.get_global_rect().has_point(event.position)
			if event.pressed:
				if over:
					_pressed = true
					_btn.add_theme_stylebox_override("normal", _pressed_style)
					get_viewport().set_input_as_handled()
			elif _pressed:
				_pressed = false
				_btn.add_theme_stylebox_override("normal", _hover_style if over else _normal_style)
				get_viewport().set_input_as_handled()
				if _btn.get_global_rect().grow(4.0).has_point(event.position):
					Game.confirm_surrender_match()

var _window_shortcuts := WindowShortcuts.new()
var _match_hud: MatchHud = null
var _mobile_pointer: CanvasLayer
var _exit_dialog: ConfirmationDialog = null
var _leave_duel_dialog: ConfirmationDialog = null
var _surrender_match_dialog: ConfirmationDialog = null

const DUEL_VIEWER_PATH := "res://scenes/duel/replay_viewer.gd"

var current_game := ""
## Mazo del rival elegido al entrar al duelo desde el menu (0x437c60), "" = el de demo1.
var rival_deck := ""
## Modo del duelo (DAT_005af778, 0x437f40): 0 duelo normal, 1 torneo (match al mejor de 3).
var duel_mode := 0
## Match: duelo actual 1..3 (DAT_005af76b), resultado de cada duelo (DAT_005af768[]: 1 gana el
## jugador, 2 el rival, 3 empate) y resultado global (DAT_005af764: 0 sigue, 1/2/3).
var match_duel := 1
var match_results := [0, 0, 0]
var match_outcome := 0
var _screen: Node
var _screen_replay_frame := 0
var _screen_host: Node
var _scene_wipe: Node
const SCENE_WIPE := preload("res://core/scene_wipe.gd")
## Contador global por vuelta del bucle principal (NativeClock.HZ): Yugi40c140(5aed18), Kaiba40c370(5b1d38).
## Persiste entre escenas; los titulos/tutoriales lo reinician en sus puntos nativos.
var native_tick := 0
var _native_clock := 0.0
## Mezcla entre ticks de lo que se anima con native_tick (las claves llevan el nodo que dibuja).
var native_blend := NativeBlend.new()
## Contadores de inactividad globales, por tick: raton DAT_005af864+0x30 (0x409680: a 0 si
## cambia la posicion o los botones) y teclado DAT_005af850+0x9f8 (0x45c990: a 0 con
## cualquiera de sus 0x58 teclas). Se guardan como tick de la ultima actividad.
var _ticks := 0
var _mouse_active_at := 0
var _key_active_at := 0



func _process(delta: float) -> void:
	_native_clock += NativeClock.ticks(delta)
	var steps := int(_native_clock)
	_native_clock -= steps
	native_tick = (native_tick + steps) & 0xffffffff
	_ticks += steps
	for _i in steps: native_blend.tick()
	native_blend.fraction = _native_clock


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_active_at = _ticks
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed \
				and is_instance_valid(_scene_wipe) and _scene_wipe.progress < 240 and DisplayServer.get_name() != "headless":
			var point: Vector2 = event.position
			if is_instance_valid(_screen_host): point = _screen_host.duel_transform().affine_inverse() * point
			if Rect2(0, 0, 800, 600).has_point(point): _scene_wipe.click(point)
	elif (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton) \
			and event.pressed:
		# Acciones y mando llegan al juego como teclas de 0x538770.
		_key_active_at = _ticks


## 0x4600f0: el puntero solo se lleva solo a un destino si el teclado se ha usado despues que
## el raton (inactividad del teclado <= la del raton; al arrancar ambas valen lo mismo).
func keyboard_drives_pointer() -> bool:
	return _key_active_at >= _mouse_active_at


func reset_native_tick() -> void:
	native_tick = 0


func _ready() -> void:
	get_tree().quit_on_go_back = false
	var language := Paths.cmdline_value("lang")
	if language == "":
		language = Assets.preferred_language()
	Assets.set_language(language)
	_match_hud = MatchHud.new()
	get_tree().root.add_child.call_deferred(_match_hud)
	if OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true":
		_mobile_pointer = preload("res://core/mobile_pointer.gd").new()
		get_tree().root.add_child.call_deferred(_mobile_pointer)
	get_tree().root.add_child.call_deferred(_window_shortcuts)
	# 0x40c66a: el MT de interfaz se siembra una vez al arrancar con GetTickCount (Debug lo
	# resiembra despues si hay --ui-seed o --ui-replay con semilla).
	UiRandom.seed_shared(UiRandom.clock_seed())
	# Acciones propias ademas de las ui_* de Godot
	_add_key_action("pc_switch", KEY_TAB)   # editor de mazos: bolsa <-> mazo
	_add_key_action("pc_side", KEY_S)       # editor de mazos: anadir al Side Deck
	_add_key_action("pc_filter", KEY_F)     # editor de mazos: siguiente filtro de la bolsa
	_add_key_action("pc_sort", KEY_O)       # editor de mazos: ventana de orden
	_add_key_action("pc_window", KEY_W)     # editor de mazos: plegar/desplegar la bolsa


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_save_pending_changes()
		Audio.pause_for_background()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_pending_changes()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		Audio.resume_from_background()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_go_back()


func _save_pending_changes() -> void:
	if is_instance_valid(_screen) and _screen.get_script() != null:
		var file_name: String = str(_screen.get_script().resource_path).get_file()
		if file_name in ["normal_duel.gd", "joey_native_normal.gd"]:
			if _screen.has_method("save_resume_state"):
				_screen.call("save_resume_state", true)
		elif file_name == "deck_editor.gd":
			var deck_val: Variant = _screen.get("_deck")
			var dirty_val: Variant = _screen.get("_dirty")
			if bool(dirty_val) and deck_val is Dictionary and _screen.has_method("_deck_valid") and bool(_screen.call("_deck_valid", deck_val)):
				SaveData.set_deck(str(_screen.get("game")), (deck_val as Dictionary).duplicate(true))
				_screen.set("_dirty", false)
			if _screen.has_method("_save_settings"):
				_screen.call("_save_settings")
		elif file_name == "title_screen.gd":
			var opts: Variant = _screen.get("_options")
			if opts != null and is_instance_valid(opts) and opts.has_method("save"):
				opts.call("save")
	if Paths.has_data() and not SaveData.data.is_empty():
		SaveData.save()


func _confirm_exit_app() -> void:
	if _exit_dialog == null or not is_instance_valid(_exit_dialog):
		_exit_dialog = ConfirmationDialog.new()
		_exit_dialog.confirmed.connect(func() -> void:
			_save_pending_changes()
			get_tree().quit())
		get_tree().root.add_child(_exit_dialog)
		load("res://scenes/launcher/dialog_theme.gd").apply(_exit_dialog, true)
	if _exit_dialog.visible:
		_exit_dialog.hide()
		return
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		_exit_dialog.title = "الخروج من اللعبة"
		_exit_dialog.dialog_text = "هل تريد حفظ التقدم والخروج من اللعبة؟"
		_exit_dialog.ok_button_text = "YES"
		_exit_dialog.cancel_button_text = "NO"
	elif lang == "s":
		_exit_dialog.title = "Salir del juego"
		_exit_dialog.dialog_text = "¿Guardar el progreso y salir del juego?"
		_exit_dialog.ok_button_text = "YES"
		_exit_dialog.cancel_button_text = "NO"
	else:
		_exit_dialog.title = "Exit Game"
		_exit_dialog.dialog_text = "Save progress and exit the game?"
		_exit_dialog.ok_button_text = "YES"
		_exit_dialog.cancel_button_text = "NO"
	_exit_dialog.popup_centered()


func _confirm_leave_duel() -> void:
	if _leave_duel_dialog == null or not is_instance_valid(_leave_duel_dialog):
		_leave_duel_dialog = ConfirmationDialog.new()
		_leave_duel_dialog.confirmed.connect(func() -> void:
			_save_pending_changes()
			Audio.stop_music()
			open_launcher())
		get_tree().root.add_child(_leave_duel_dialog)
		load("res://scenes/launcher/dialog_theme.gd").apply(_leave_duel_dialog, true)
	if _leave_duel_dialog.visible:
		_leave_duel_dialog.hide()
		return
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		_leave_duel_dialog.title = "العودة للقائمة الرئيسية"
		_leave_duel_dialog.dialog_text = "سيتم حفظ المباراة تلقائياً لتتمكن من إكمالها لاحقاً من زر «إكمال المباراة»."
		_leave_duel_dialog.ok_button_text = "YES"
		_leave_duel_dialog.cancel_button_text = "NO"
	elif lang == "s":
		_leave_duel_dialog.title = "Volver al menú"
		_leave_duel_dialog.dialog_text = "El duelo se guardará automáticamente para que puedas continuarlo después."
		_leave_duel_dialog.ok_button_text = "YES"
		_leave_duel_dialog.cancel_button_text = "NO"
	else:
		_leave_duel_dialog.title = "Return to Launcher"
		_leave_duel_dialog.dialog_text = "Your duel will be saved automatically so you can resume it later."
		_leave_duel_dialog.ok_button_text = "YES"
		_leave_duel_dialog.cancel_button_text = "NO"
	_leave_duel_dialog.popup_centered()


func has_active_root_dialog() -> bool:
	if _exit_dialog != null and is_instance_valid(_exit_dialog) and _exit_dialog.visible:
		return true
	if _leave_duel_dialog != null and is_instance_valid(_leave_duel_dialog) and _leave_duel_dialog.visible:
		return true
	if _surrender_match_dialog != null and is_instance_valid(_surrender_match_dialog) and _surrender_match_dialog.visible:
		return true
	if is_instance_valid(Online) and Online._global_invite_panel != null and is_instance_valid(Online._global_invite_panel) and Online._global_invite_panel.visible:
		return true
	if is_instance_valid(_screen):
		if _screen.has_method("has_online_modal") and bool(_screen.call("has_online_modal")):
			return true
		var controls: Variant = _screen.get("_controls")
		if controls != null and is_instance_valid(controls):
			if bool(controls.get("panel_open")):
				return true
			if controls.has_method("_dialog_visible") and bool(controls.call("_dialog_visible")):
				return true
		var footer: Variant = _screen.get("_release_footer")
		if footer != null and is_instance_valid(footer):
			for dlg_prop: String in ["_dialog", "_repo_dialog"]:
				var fdlg: Variant = footer.get(dlg_prop)
				if fdlg != null and is_instance_valid(fdlg) and fdlg.visible:
					return true
	if get_tree() != null and get_tree().root != null:
		for subwin: Window in get_tree().root.get_embedded_subwindows():
			if is_instance_valid(subwin) and subwin.visible:
				return true
	return false


func is_online_button_visible() -> bool:
	return not has_active_root_dialog() and is_instance_valid(_screen) and _screen.has_method("is_online_button_visible") and bool(_screen.call("is_online_button_visible"))


func online_button_rect() -> Rect2:
	if is_instance_valid(_screen) and _screen.has_method("online_button_rect"):
		return _screen.call("online_button_rect")
	return Rect2()


func open_online_modal() -> void:
	if is_instance_valid(_screen) and _screen.has_method("open_online_modal"):
		_screen.call("open_online_modal")


func can_surrender_match() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	if duel_mode != 1 or joey_demo or match_outcome != 0 or current_game not in GAMES:
		return false
	if has_active_root_dialog() or is_instance_valid(_scene_wipe):
		return false
	if not is_instance_valid(_screen) or _screen.get_script() == null:
		return false
	var file_name: String = str(_screen.get_script().resource_path).get_file()
	if file_name in ["normal_duel.gd", "joey_native_normal.gd"]:
		if _screen.get("_duel") == null or bool(_screen.get("_finished")) or bool(_screen.get("_lan")):
			return false
		if _screen.get("_result") != null:
			return false
		var visual: Variant = _screen.get("_visual")
		if visual != null and is_instance_valid(visual) and bool(visual.get("_start_banner_shade")):
			return false
		var list_win: Variant = _screen.get("_list_window")
		if list_win != null and is_instance_valid(list_win):
			return false
		if is_instance_valid(_mobile_pointer) and (_mobile_pointer._cancel_btn.visible or _mobile_pointer._menu.visible):
			return false
		return true
	if file_name == "deck_editor.gd":
		if not bool(_screen.get("_swap")):
			return false
		var modal: Variant = _screen.get("_modal")
		if modal != null and is_instance_valid(modal):
			return false
		if is_instance_valid(_mobile_pointer) and _mobile_pointer._menu.visible:
			return false
		return true
	return false


func is_match_surrender_button_visible() -> bool:
	return not has_active_root_dialog() and _match_hud != null and is_instance_valid(_match_hud) and _match_hud.button_visible()


func match_surrender_button_rect() -> Rect2:
	if _match_hud != null and is_instance_valid(_match_hud):
		return _match_hud.button_rect()
	return Rect2()


func confirm_surrender_match() -> void:
	if _surrender_match_dialog != null and is_instance_valid(_surrender_match_dialog) and _surrender_match_dialog.visible:
		_surrender_match_dialog.hide()
		return
	if not can_surrender_match():
		return
	if _match_hud != null and is_instance_valid(_match_hud):
		_match_hud._pressed = false
		_match_hud._btn.hide()
	if _surrender_match_dialog == null or not is_instance_valid(_surrender_match_dialog):
		_surrender_match_dialog = ConfirmationDialog.new()
		_surrender_match_dialog.confirmed.connect(surrender_match)
		get_tree().root.add_child(_surrender_match_dialog)
		load("res://scenes/launcher/dialog_theme.gd").apply(_surrender_match_dialog, true)
	var round_num: int = clampi(match_duel, 1, 3)
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		_surrender_match_dialog.title = "انسحاب تام من الماتش"
		_surrender_match_dialog.dialog_text = "أنت الآن في الجولة %d من الماتش.\nهل تريد الانسحاب من الماتش بالكامل والخروج إلى قائمة المبارزة؟" % round_num
		_surrender_match_dialog.ok_button_text = "YES"
		_surrender_match_dialog.cancel_button_text = "NO"
	elif lang == "s":
		_surrender_match_dialog.title = "Rendirse del Match"
		_surrender_match_dialog.dialog_text = "Estás en el duelo %d del Match.\n¿Quieres rendirte de todo el Match y volver al menú de duelos?" % round_num
		_surrender_match_dialog.ok_button_text = "YES"
		_surrender_match_dialog.cancel_button_text = "NO"
	else:
		_surrender_match_dialog.title = "Surrender Match"
		_surrender_match_dialog.dialog_text = "You are in Duel %d of the Match.\nForfeit the entire Match and return to the Duel menu?" % round_num
		_surrender_match_dialog.ok_button_text = "YES"
		_surrender_match_dialog.cancel_button_text = "NO"
	_surrender_match_dialog.popup_centered()


func surrender_match() -> void:
	if duel_mode != 1 or joey_demo or current_game not in GAMES:
		return
	var game_id: String = current_game
	if is_instance_valid(_screen) and _screen.get_script() != null:
		var file_name: String = str(_screen.get_script().resource_path).get_file()
		if file_name in ["normal_duel.gd", "joey_native_normal.gd"]:
			_screen.set("_finished", true)
			_screen.set("_cached_resume_snapshot", {})
			_screen.set_process(false)
	DuelResume.clear()
	PointerGlide.cancel()
	if is_instance_valid(_mobile_pointer):
		_mobile_pointer.cancel()
	var surrendered_stats: Dictionary = SaveData.record_result(game_id, 2)
	if int(surrendered_stats.get("streak_last", 0)) == 1:
		surrendered_stats["streak"] = 0
	surrendered_stats["streak_last"] = 2
	SaveData.data["stats"][game_id] = surrendered_stats
	SaveData.save()
	duel_mode = 0
	match_duel = 1
	match_results = [0, 0, 0]
	match_outcome = 0
	Audio.play_sfx("%s/voice/internal/return.wav" % game_id)
	Audio.stop_music()
	open_title(game_id, "duel")


func _handle_go_back() -> void:
	if _exit_dialog != null and is_instance_valid(_exit_dialog) and _exit_dialog.visible:
		_exit_dialog.hide()
		return
	if _leave_duel_dialog != null and is_instance_valid(_leave_duel_dialog) and _leave_duel_dialog.visible:
		_leave_duel_dialog.hide()
		return
	if _surrender_match_dialog != null and is_instance_valid(_surrender_match_dialog) and _surrender_match_dialog.visible:
		_surrender_match_dialog.hide()
		return
	if get_tree() != null and get_tree().root != null:
		var subwins := get_tree().root.get_embedded_subwindows()
		for i in range(subwins.size() - 1, -1, -1):
			var subwin: Window = subwins[i]
			if is_instance_valid(subwin) and subwin.visible and subwin is Popup:
				subwin.hide()
				return
	if is_instance_valid(_screen) and _screen.has_method("close_online_modal_if_open") and bool(_screen.call("close_online_modal_if_open")):
		return
	if is_instance_valid(_mobile_pointer):
		if _mobile_pointer._menu.visible:
			_mobile_pointer._menu.hide()
			_mobile_pointer._selected_card = ""
			return
		if PlatformInput._normal_duel_active() and _mobile_pointer._cancel_btn.visible:
			_mobile_pointer._trigger_cancel()
			return
	if not is_instance_valid(_screen) or _screen.get_script() == null:
		return
	var file_name: String = str(_screen.get_script().resource_path).get_file()
	match file_name:
		"normal_duel.gd", "joey_native_normal.gd":
			var duel_obj: Variant = _screen.get("_duel")
			if duel_obj == null:
				open_title(str(_screen.get("game")), "duel")
				return
			var list_win: Variant = _screen.get("_list_window")
			if list_win != null and is_instance_valid(list_win) and int(list_win.get("mode")) == 0:
				list_win.call("_close", 0)
				return
			if not bool(_screen.get("_finished")) and not bool(_screen.get("_lan")) and not joey_demo:
				_save_pending_changes()
				_confirm_leave_duel()
			return
		"deck_editor.gd":
			var modal: Variant = _screen.get("_modal")
			if modal != null and is_instance_valid(modal):
				if modal.has_method("_cancel"):
					modal.call("_cancel")
				elif modal.has_method("_close"):
					modal.call("_close", -1)
				return
			if int(_screen.get("_held")) != 0:
				if _screen.has_method("_clear_selection"):
					_screen.call("_clear_selection")
				return
			if _screen.has_method("_leave"):
				_screen.call("_leave")
			return
		"card_list.gd":
			if _screen.has_method("_leave"):
				_screen.call("_leave")
			return
		"title_screen.gd":
			var modal: Variant = _screen.get("_modal")
			if modal != null and is_instance_valid(modal):
				if modal.has_method("_cancel"):
					modal.call("_cancel")
				return
			var phase_name: String = str(_screen.get("_phase"))
			if phase_name == "options":
				var opts: Variant = _screen.get("_options")
				if opts != null and is_instance_valid(opts):
					Audio.play_sfx("%s/voice/internal/return.wav" % str(_screen.get("game")))
					opts.emit_signal("exit_requested")
				return
			if phase_name == "menu" and _screen.has_method("_back"):
				_screen.call("_back")
			return
		"lan_connect.gd":
			if _screen.has_method("_back"):
				if not bool(_screen.call("_back")) and _screen.has_method("_leave"):
					_screen.call("_leave", "title", "return")
			return
		"replay_viewer.gd":
			if _screen.has_method("_leave_replay"):
				_screen.call("_leave_replay")
			else:
				open_title(current_game, "duel")
			return
		"tutorial_lesson.gd", "tutorial_menu.gd", "tutorial_menu_kaiba.gd":
			open_title(current_game, "tutorial")
			return
		"ending_scene.gd":
			open_title(current_game)
			return
		"android_content_setup.gd", "content_setup.gd":
			if Paths.has_data():
				open_launcher()
			else:
				_confirm_exit_app()
			return
		"launcher_android.gd", "launcher.gd":
			var controls: Variant = _screen.get("_controls")
			if controls != null and is_instance_valid(controls):
				if controls.has_method("_dialog_visible") and bool(controls.call("_dialog_visible")):
					for dlg_name: String in ["_reset_dialog", "_reset_result", "_cloud_dialog", "_export_dialog", "_import_dialog"]:
						var dlg: Variant = controls.get(dlg_name)
						if dlg != null and is_instance_valid(dlg) and dlg.visible:
							dlg.hide()
					return
				if bool(controls.get("panel_open")) and controls.has_method("_open_panel"):
					controls.call("_open_panel", false)
					return
			_confirm_exit_app()
			return
		_:
			if current_game != "":
				_save_pending_changes()
				open_title(current_game)
			else:
				_confirm_exit_app()


func _add_key_action(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func goto(screen: Node) -> void:
	if screen == null:
		push_error("Game.goto received null screen")
		return
	SaveData.ensure_game(current_game)
	if is_instance_valid(_scene_wipe):
		_scene_wipe.finish()
		_scene_wipe = null
	var effect := _scene_wipe_mode(_screen, screen)
	var old_frame: Texture2D
	var waves: Array[Node2D] = []
	# El launcher es propio del port; el primer arranque no tiene snapshot previo.
	var headless := DisplayServer.get_name() == "headless"
	var mobile_safe := OS.has_feature("mobile") or Paths.android_platform()
	var prev_script: Script = _screen.get_script() if is_instance_valid(_screen) else null
	var prev_file: String = str(prev_script.resource_path).get_file() if prev_script != null else ""
	var next_script: Script = screen.get_script() if is_instance_valid(screen) else null
	var next_file: String = str(next_script.resource_path).get_file() if next_script != null else ""
	var skip_heavy_ui_wipe := not (headless and Debug.headless_wipe) and (prev_file in ["deck_editor.gd", "card_list.gd"] or next_file in ["deck_editor.gd", "card_list.gd"])
	if not mobile_safe and not skip_heavy_ui_wipe and not LauncherSettings.fast_play and current_game != "" and (not headless or Debug.headless_wipe) \
			and is_instance_valid(_screen) and _screen.is_inside_tree() \
			and prev_file != "" and prev_file not in ["launcher.gd", "launcher_android.gd", "content_setup.gd"]:
		# Sin ventana no hay imagen que barrer; el cotejo por valores (--ui-values) conserva el
		# barrido con una imagen vacia porque retiene la pantalla nueva los mismos ticks.
		if not headless:
			for cursor in get_tree().get_nodes_in_group("duel_cursors"):
				if _screen.is_ancestor_of(cursor) and cursor.is_visible_in_tree():
					var layer: Node2D = cursor.take_transition_waves()
					if layer != null: waves.append(layer)
			# La onda se compone sobre el resultado, fuera de los dos snapshots.
			if not waves.is_empty(): RenderingServer.force_draw(false)
		var old_image := Image.create(1, 1, false, Image.FORMAT_RGBA8) if headless \
				else _screen.get_viewport().get_texture().get_image()
		if old_image != null and not old_image.is_empty():
			old_frame = ImageTexture.create_from_image(old_image)
	if is_instance_valid(_screen_host):
		_screen_host.queue_free()
		_screen_host = null
	elif is_instance_valid(_screen):
		_screen.queue_free()
	_screen = screen
	_screen_replay_frame = Debug._frame
	get_tree().root.content_scale_aspect = LauncherSettings.gameplay_aspect()
	Engine.time_scale = LauncherSettings.simulation_speed if current_game != "" else 1.0
	if (LauncherSettings.aspect == "balanced" and current_game != "") or (LauncherSettings.aspect == "overlay" and _is_duel_viewer(screen) and str(screen.get("game")) in ["yugi", "kaiba", "joey"]):
		_screen_host = load("res://scenes/duel/duel_margins.gd").new(screen)
		get_tree().root.add_child.call_deferred(_screen_host)
	else:
		get_tree().root.add_child.call_deferred(screen)
	if _surrender_match_dialog != null and is_instance_valid(_surrender_match_dialog) and _surrender_match_dialog.visible:
		_surrender_match_dialog.hide()
	if is_instance_valid(_match_hud):
		get_tree().root.move_child.call_deferred(_match_hud, -1)
	if is_instance_valid(_mobile_pointer):
		_mobile_pointer.cancel()
		get_tree().root.move_child.call_deferred(_mobile_pointer, -1)
	get_tree().root.move_child.call_deferred(_window_shortcuts, -1)
	if old_frame != null:
		_start_scene_wipe.call_deferred(old_frame, screen, effect, waves)
	else:
		for wave in waves: wave.free()


## Callers acreditados: título1e/20/13, bust4b, janken/duelo2a.
func _scene_wipe_mode(previous: Node, following: Node) -> int:
	if not is_instance_valid(previous): return 0x13
	var script: Script = previous.get_script()
	if script == null: return 0x13
	var source := script.resource_path.get_file()
	var target: Script = following.get_script()
	var target_name := target.resource_path.get_file() if target != null else ""
	if source == "title_screen.gd":
		match target_name:
			"deck_editor.gd": return 0x1e
			"card_list.gd", "bust_up_scene.gd", "bust_up_rival.gd", "lan_connect.gd", "normal_duel.gd", "joey_native_normal.gd":
				return 0x20
			"replay_viewer.gd": return 0x20 if following.get("kind") == "demo" else 0x13
	if source == "lan_connect.gd": return 0x20
	if source in ["bust_up_scene.gd", "bust_up_rival.gd"]:
		return 0x4b
	if source in ["tutorial_menu.gd", "tutorial_menu_kaiba.gd"] and target_name == "title_screen.gd":
		return 0x4b
	if source in ["normal_duel.gd", "joey_native_normal.gd", "replay_viewer.gd", "tutorial_lesson.gd",
			"janken_scene.gd", "janken_kaiba.gd", "janken_joey.gd"]:
		return 0x2a
	return 0x13


## 531f80 cambia de escena y dibuja una vez el destino antes de la captura40a260.
func _start_scene_wipe(old_frame: Texture2D, screen: Node, effect := 0x13, waves: Array[Node2D] = []) -> void:
	if not is_instance_valid(screen) or screen != _screen or not screen.is_inside_tree():
		for wave in waves: wave.free()
		return
	var previous_mode := screen.process_mode
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	if screen.has_method("_process"):
		screen.call("_process", 1.0 / NativeClock.HZ)
	# Cubrir el primer dibujo mientras Godot vacia las ordenes de CanvasItem.
	# El destino nunca se presenta antes de su barrido.
	var wipe := SCENE_WIPE.new(old_frame, old_frame, screen, previous_mode, effect)
	_scene_wipe = wipe
	screen.get_viewport().add_child(wipe)
	wipe.add_waves(waves)
	wipe.set_process(false)
	if DisplayServer.get_name() == "headless":
		# Sin ventana (Debug.headless_wipe) no hay fotograma que esperar ni imagen de destino:
		# el barrido solo cuenta sus ticks y retiene la pantalla hasta el 240.
		wipe.set_process(true)
		return
	await RenderingServer.frame_post_draw
	if not is_instance_valid(wipe) or not is_instance_valid(screen) or screen != _screen:
		return
	wipe.hide()
	RenderingServer.force_draw(false)
	var image := screen.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		wipe.finish()
		return
	wipe.set_destination(ImageTexture.create_from_image(image))
	wipe.show()
	RenderingServer.force_draw(false)
	wipe.set_process(true)



func open_launcher() -> void:
	current_game = ""
	# Android: biblioteca instalada o importador del PCK privado. PC: biblioteca e importador
	# de las copias del usuario (content_setup amplía el launcher de escritorio).
	if Paths.android_platform():
		var target_path := "res://scenes/launcher/launcher_android.gd" if Paths.has_data() else "res://scenes/launcher/android_content_setup.gd"
		var scr: Script = load(target_path)
		if scr == null and target_path != "res://scenes/launcher/android_content_setup.gd":
			scr = load("res://scenes/launcher/android_content_setup.gd")
		if scr != null:
			goto(scr.new())
	else:
		var scr: Script = load("res://scenes/launcher/content_setup.gd")
		if scr != null:
			goto(scr.new())


## Al volver de otra pantalla (`focus` = opcion de la que se viene) no se repite la portada
## de Yugi y el cursor queda en esa opcion.
func open_title(game: String, focus := "", launcher_cover: CanvasLayer = null) -> void:
	if not Paths.has_game(game):
		if launcher_cover != null and is_instance_valid(launcher_cover):
			launcher_cover.queue_free()
		open_launcher()
		return
	current_game = game
	goto(load("res://scenes/title/title_screen.gd").new(game, focus))
	if launcher_cover != null and is_instance_valid(launcher_cover):
		# Cambiar EXPAND a KEEP bajo negro y descubrir solo el primer dibujo del titulo.
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if is_instance_valid(launcher_cover):
			launcher_cover.queue_free()


## Entradas explícitas de las escenas originales11/1; material visual provisional.
## No se inventa una condición de desbloqueo en el menú comercial.
func open_ending(game: String, mode := "credits") -> void:
	current_game = game
	var scene: Node2D = load("res://scenes/ending/ending_scene.gd").new(game, mode)
	scene.finished.connect(open_title.bind(game), CONNECT_ONE_SHOT)
	goto(scene)


func open_deck_editor(game: String) -> void:
	var target_game := game if game in GAMES and Paths.has_game(game) else ""
	if target_game == "":
		for g: String in ["joey", "kaiba", "yugi"]:
			if Paths.has_game(g):
				target_game = g
				break
	if target_game == "":
		target_game = game if game in GAMES else "yugi"
	current_game = target_game
	var scr: Script = load("res://scenes/deck_editor/deck_editor.gd")
	if scr != null and scr.can_instantiate():
		goto(scr.new(target_game))
	else:
		push_error("Game.open_deck_editor: failed to load/instantiate deck_editor.gd")


## Visor de repeticiones del duelo: `what` = "demo" (Repeticion) o "tutorial".
func open_duel_replay(game: String, what: String) -> void:
	current_game = game
	if game in ["yugi", "kaiba"] and what.begins_with("lesson:"):
		goto(load("res://scenes/duel/tutorial_lesson.gd").new(game, what))
	else:
		goto(load("res://scenes/duel/replay_viewer.gd").new(game, what))


func open_tutorial(game: String) -> void:
	current_game = game
	# Yugi469550, Kaiba46b730, Joey48dd80.
	reset_native_tick()
	if game == "yugi":
		goto(load("res://scenes/duel/tutorial_menu.gd").new())
	elif game == "kaiba":
		goto(load("res://scenes/duel/tutorial_menu_kaiba.gd").new())
	else:
		open_duel_replay(game, "tutorial")


## Joey 48a150: con el menu inactivo (mismos umbrales que Yugi 467000) elige un mazo FUL con
## 44bbe0 para el lado 0 y abre un duelo de tipo 7 (44bee0(7, mazo)): el motor da los dos
## lados a la CPU (MODE |= 6) y la CPU elige su propio mazo. Sin demoN.ydr (D35).
var joey_demo := false
var joey_demo_deck := ""


func open_joey_demo() -> void:
	duel_mode = 0
	joey_demo = true
	joey_demo_deck = choose_rival_deck("joey")
	rival_deck = choose_rival_deck("joey")
	# Empieza el lado de arriba (nativo 0 con el local 1 de la demostracion), como hasta ahora.
	open_normal_duel("joey", 1)


func open_normal_duel(game: String, start_options := -1) -> void:
	current_game = game
	if game == "joey":
		goto(load("res://scenes/duel/joey_native_normal.gd").new(start_options))
	else:
		goto(load("res://scenes/duel/normal_duel.gd").new(game, start_options))


func resume_saved_duel(launcher_cover: CanvasLayer = null) -> void:
	var snap: Dictionary = DuelResume.load_snapshot()
	if snap.is_empty():
		if launcher_cover != null and is_instance_valid(launcher_cover):
			launcher_cover.queue_free()
		open_launcher()
		return
	var game_id: String = str(snap.get("game", ""))
	if not Paths.has_game(game_id):
		DuelResume.clear()
		if launcher_cover != null and is_instance_valid(launcher_cover):
			launcher_cover.queue_free()
		open_launcher()
		return
	joey_demo = false
	duel_mode = int(snap.get("duel_mode", 0))
	match_duel = int(snap.get("match_duel", 1))
	var raw_results: Variant = snap.get("match_results", [0, 0, 0])
	match_results = (raw_results as Array).duplicate() if raw_results is Array else [0, 0, 0]
	match_outcome = int(snap.get("match_outcome", 0))
	rival_deck = str(snap.get("rival_deck", ""))
	current_game = game_id
	if game_id == "joey":
		goto(load("res://scenes/duel/joey_native_normal.gd").new(0, snap))
	else:
		goto(load("res://scenes/duel/normal_duel.gd").new(game_id, -1, snap))
	if launcher_cover != null and is_instance_valid(launcher_cover):
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		if is_instance_valid(launcher_cover):
			launcher_cover.queue_free()


## Duelo desde el menu: en Yugi pasa antes por la entrada de Yugi (escena 6, DAT_005af6f8 = 0).
## Despues de la entrada va el piedra-papel-tijera (escena 7, DAT_005af6f4 = 7), que decide
## quien empieza (DAT_005af770).
## Menus467000(Yugi),4694b0(Kaiba),48a150(Joey): conservan su musica durante
## la entrada; los constructores de janken ponen la pista siguiente.
func start_normal_duel(game: String, mode := 0) -> void:
	DuelResume.clear()
	# 0x437f40 casos 0/1: match a cero.
	duel_mode = mode
	match_duel = 1
	match_results = [0, 0, 0]
	match_outcome = 0
	rival_deck = choose_rival_deck(game)
	current_game = game
	if LauncherSettings.fast_play:
		open_janken(game)
		return
	var script: GDScript = load("res://scenes/duel/bust_up_scene.gd") if game == "yugi" else load("res://scenes/duel/bust_up_rival.gd")
	var scene: Node2D = script.new(game)
	scene.finished.connect(open_janken.bind(game), CONNECT_ONE_SHOT)
	goto(scene)


func open_janken(game: String) -> void:
	current_game = game
	var script: GDScript = load({"yugi": "res://scenes/duel/janken_scene.gd", "kaiba": "res://scenes/duel/janken_kaiba.gd", "joey": "res://scenes/duel/janken_joey.gd"}[game])
	var scene: Node2D = script.new()
	# Joey 44b980: el janken va por red en el modo 3 (duelo LAN).
	scene.lan = duel_mode == 3 and Lan.active()
	scene.lost.connect(func() -> void: lan_lost(game), CONNECT_ONE_SHOT)
	scene.finished.connect(func(options: int) -> void: open_normal_duel(game, options), CONNECT_ONE_SHOT)
	goto(scene)


## Duelo LAN de Joey (D17): mazo propio enviado (0xf004), mazo que mando el rival (0xf004) y semilla de la sesion (0xf005).
var lan_local_deck := {}
var lan_rival_deck := {}
var lan_seed := -1


## Opcion "Duelo LAN" del titulo de Joey: pantalla de conexion (4207d0). Cancelar vuelve al
## titulo en la opcion (escena 2); conectada, janken (escena 7); sin sesion, titulo (escena 4).
func open_lan(game: String) -> void:
	current_game = game
	var scene: Node2D = load("res://scenes/lan/lan_connect.gd").new(game)
	scene.finished.connect(func(next: String) -> void:
		if next == "janken":
			match_duel = 1
			match_results = [0, 0, 0]
			match_outcome = 0
			open_janken(game)
		else:
			Lan.close()
			duel_mode = 0
			open_title(game, "lan"), CONNECT_ONE_SHOT)
	goto(scene)


func open_lan_online(game: String) -> void:
	current_game = game
	var scene: Node2D = load("res://scenes/lan/lan_connect.gd").new(game)
	scene.set("auto_online", true)
	scene.finished.connect(func(next: String) -> void:
		if next == "janken":
			match_duel = 1
			match_results = [0, 0, 0]
			match_outcome = 0
			open_janken(game)
		else:
			Lan.close()
			duel_mode = 0
			open_launcher(), CONNECT_ONE_SHOT)
	goto(scene)


## Se perdio la sesion fuera del duelo (janken 461370 / sala 5bdac0): titulo (escena 4).
func lan_lost(game: String) -> void:
	Lan.close()
	duel_mode = 0
	Audio.stop_music()
	open_title(game)


## 0x437440 (desde 0x53d9d0 al acabar el duelo): guarda el resultado del duelo y, en match,
## decide el global con victorias - derrotas: +-2 decide; en el tercero, +-1 decide y 0 empata.
func record_duel_result(result: int) -> void:
	if duel_mode not in [0, 1, 3]:
		return
	match_results[match_duel - 1] = result
	if duel_mode != 1:
		match_outcome = result
		return
	var count := [0, 0, 0, 0]
	for i in match_duel:
		count[match_results[i] & 3] += 1
	match count[1] - count[2]:
		0:
			if match_duel == 3: match_outcome = 3
		1:
			if match_duel == 3: match_outcome = 1
		2:
			match_outcome = 1
		-2:
			match_outcome = 2
		-1:
			if match_duel == 3: match_outcome = 2


## Estado 7 de 0x435410 con el match sin decidir: escena 10 (editor en modo intercambio con el
## Side, deck_editor.gd con "swap").
func continue_match(game: String) -> void:
	current_game = game
	goto(load("res://scenes/deck_editor/deck_editor.gd").new(game, "swap"))


## Salida valida de la escena 10 (0x459c10): 0x437f40(2) (siguiente duelo del match) y
## escena 7 (piedra-papel-tijera, que en match elige el perdedor).
func after_swap(game: String) -> void:
	match_duel += 1
	open_janken(game)


## 0x437c60: mazo de Yugi (data/Y/file/cpu<sufijo>.ydc) segun el porcentaje de cartas que se
## tienen de las de este juego (0x45dd50, CARD_Pack con el bit del juego) y la racha
## (DAT_00a11215: 1 gana el jugador, 2 la CPU; DAT_00a11216: duelos seguidos). Sin sufijo
## especial, uno de 01..04 al azar. Los azares son el MT de interfaz (0x531140 / 0x401ba0).
func choose_rival_deck(game: String) -> String:
	if not joey_demo and is_instance_valid(LauncherSettings):
		var chosen_deck := LauncherSettings.get_offline_rival_deck(game)
		if chosen_deck != "" and Assets.exists(chosen_deck):
			return chosen_deck
		var diff := LauncherSettings.get_offline_difficulty(game)
		if diff != "auto":
			var picked := RivalDeckChoice.pick_by_difficulty(game, diff, func(): return UiRandom.draw())
			if picked != "":
				return picked
	var pool := CardDB.obtainable_in(game)
	var owned := 0
	for card in pool:
		owned += int(SaveData.card_count(int(card["internal_id"])) > 0)
	var pct := owned * 100 / maxi(1, pool.size())
	var stats: Dictionary = SaveData.data.get("stats", {}).get(game, {})
	var last := int(stats.get("streak_last", 0))
	var run := int(stats.get("streak", 0))
	if game == "kaiba":
		return RivalDeckChoice.kaiba(pct, last, run, has_previous_cards(game), func(): return UiRandom.draw())
	if game == "joey":
		return RivalDeckChoice.joey(int(stats.get("level", 1)) & 255, joey_full_cards(), func(): return UiRandom.draw())
	var suffix := ""
	var strong := func() -> String: return "kk" if (UiRandom.draw() & 1) != 0 else "k"   # 0x437f1d
	if pct < 45:
		if last == 2 and run >= 2 and (UiRandom.draw() & 1) == 0:
			suffix = "jj"
		if last == 1 and run > 2:
			var n := 4 - int(run > 4)
			if UiRandom.draw_mod(n) == 0:
				suffix = "k"
	elif pct < 60:
		if last == 2 and run >= 2 and UiRandom.draw() % 3 == 0:
			suffix = "jj" if (UiRandom.draw() & 1) != 0 else "j"
		if last == 1 and run > 2:
			var n := 3 - int(run > 4)
			if UiRandom.draw_mod(n) == 0:
				suffix = strong.call()
	elif pct < 90:
		if last == 2 and run >= 3 and UiRandom.draw() % 3 == 0:
			suffix = "j"
		if last == 1 and run > 1:
			var n := 3 - int(run > 3)
			if UiRandom.draw_mod(n) == 0:
				suffix = strong.call()
	elif UiRandom.draw() % 3 == 0:
		suffix = strong.call()
	if suffix == "":
		suffix = ["01", "02", "03", "04"][UiRandom.draw() & 3]
	return "%s/file/cpu%s.json" % [game, suffix]


## Kaiba 45fc70 / Joey 5bedd0: se posee una carta usable sin el bit del juego actual.
## No basta con tener cartas de otro paquete: las compartidas con este no activan la rama.
func has_previous_cards(game: String) -> bool:
	var pack: int = CardDB.ORIGINAL_PACK_BITS[game]
	var usable: int = 3 if game == "kaiba" else 7
	for card in CardDB.cards:
		if (int(card["pack"]) & usable) != 0 and (int(card["pack"]) & pack) == 0 \
				and SaveData.card_count(int(card["internal_id"])) > 0:
			return true
	return false


## Jo48a150/44bbe0: FULL selecciona FUL y suma2 al nivel; inventario solo habilita el botón.
func joey_full_cards() -> bool:
	return bool(SaveData.data.get("options", {}).get("joey", {}).get(
			"card_set_full", has_previous_cards("joey")))


## Tras el resultado: en Yugi, su salida (escena 6, DAT_005af6f8 = 1) y despues el titulo.
## Tampoco el resultado (0x435410, estado 7) para la musica antes de la salida.
func finish_normal_duel(game: String, winner: int) -> void:
	DuelResume.clear()
	if duel_mode == 3:
		# Joey 5bd2d0: con el resultado intercambiado (0xf002/0xf003) se cierra la sesion.
		Lan.close()
		duel_mode = 0
	if winner == 0:
		Audio.stop_music()
		open_title(game, "duel")
		return
	if LauncherSettings.fast_play:
		open_title(game, "duel")
		return
	var script: GDScript = load("res://scenes/duel/bust_up_scene.gd") if game == "yugi" else load("res://scenes/duel/bust_up_rival.gd")
	var scene: Node2D = script.new(game, winner)
	scene.finished.connect(open_title.bind(game, "duel"), CONNECT_ONE_SHOT)
	goto(scene)


func open_card_list(game: String) -> void:
	var target_game := game if game in GAMES and Paths.has_game(game) else ""
	if target_game == "":
		for g: String in ["joey", "kaiba", "yugi"]:
			if Paths.has_game(g):
				target_game = g
				break
	if target_game == "":
		target_game = game if game in GAMES else "yugi"
	current_game = target_game
	var scr: Script = load("res://scenes/card_list/card_list.gd")
	if scr != null and scr.can_instantiate():
		goto(scr.new(target_game))
	else:
		push_error("Game.open_card_list: failed to load/instantiate card_list.gd")


## Reconoce también las subclases sin cargar todo el duelo al arrancar.
func _is_duel_viewer(screen: Node) -> bool:
	var script: Script = screen.get_script()
	while script != null:
		if script.resource_path == DUEL_VIEWER_PATH:
			return true
		script = script.get_base_script()
	return false
