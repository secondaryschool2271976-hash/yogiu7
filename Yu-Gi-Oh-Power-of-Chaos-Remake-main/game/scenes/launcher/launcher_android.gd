extends Node2D
## Selector de juego Android: une los tres juegos en uno con el estilo propio del proyecto.

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const RewardModals := preload("res://scenes/launcher/reward_modals.gd")
const CardBackModal := preload("res://scenes/launcher/card_back_modal.gd")
const DESIGN := Vector2(800, 600)
const SLOT := Vector2(225, 150)          # caja en la que se encaja cada logo
const SLOT_GAP := 25.0
const LOGO_Y := 312.0                    # centro vertical de la fila de logos (en DESIGN)
const TITLE_Y := 146.0
const TITLE_SIZE := 50
const SELECTED_SCALE := 1.15
const IDLE_SCALE := 0.9
const DIM := Color(0.45, 0.48, 0.56)
const GOLD := DialogTheme.GOLD
const GOLD_LIGHT := DialogTheme.GOLD_LIGHT
const OUTLINE := DialogTheme.OUTLINE
const CYAN := DialogTheme.CYAN
const CYAN_SOFT := DialogTheme.CYAN_SOFT
const VIOLET := DialogTheme.VIOLET
const BG_TOP := DialogTheme.BG_VOID
const BG_BOTTOM := DialogTheme.BG_ABYSS
const CLASSIC_BG_TOP := Color(0.085, 0.045, 0.095)
const CLASSIC_BG_BOTTOM := Color(0.022, 0.014, 0.030)
const EDITION_ACCENTS := [VIOLET, CYAN, GOLD]

const MUSIC_PATH := "res://assets/music/launcher_theme.mp3"
const MUSIC_DB := 0.0
const SILENT_DB := -60.0
const LOOP_FADE := 2.5
const EXIT_FADE := 0.4

var _selected := 0
var _music := AudioStreamPlayer.new()
var _music_stream: AudioStream = null
var _controls: Node2D = preload("res://scenes/launcher/launcher_controls.gd").new()
var _leaving := false
var _started := false
var _looped := false
var _logos: Array[Sprite2D] = []
var _fit: Array[float] = []
var _emphasis: Array[float] = []
var _halo: Sprite2D
var _classic_glow: Texture2D = null
var _time := 0.0
var _wheel_tick_accum := 0.0
var _font: Font = Assets.ui_font(700)
var _screen := DESIGN
const Tips = preload("res://scenes/launcher/tooltip_texts.gd")
var _language := Button.new()
var _lang_modal: CanvasLayer = null
var _lang_row_buttons: Dictionary = {}
var _lang_row_radios: Dictionary = {}
var _online_button := Button.new()
var _online_mode_button := Button.new()
var _wheel_button := Button.new()
var _special_wheel_button := Button.new()
var _code_button := Button.new()
var _admin_code_button := Button.new()
var _card_back_button := Button.new()
var _ydc_button := Button.new()
var _ydc_export_button := Button.new()
var _card_test_button := Button.new()
var _online_hub: CanvasLayer = null
var _reward_modals: CanvasLayer = null
var _card_back_modal: CanvasLayer = null
var _resume_button := Button.new()
var _resume_summary: Dictionary = {}
var _release_footer: Node = preload("res://scenes/launcher/release_footer.gd").new()
var _origin := Vector2.ZERO
var _bg_tex_cache: Dictionary = {}


func _enter_tree() -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
	if is_instance_valid(Online) and Online.session_changed.is_connected(_refresh_online_controls):
		Online.session_changed.disconnect(_refresh_online_controls)
	if _online_hub != null and is_instance_valid(_online_hub):
		_online_hub.queue_free()
		_online_hub = null
	if _reward_modals != null and is_instance_valid(_reward_modals):
		_reward_modals.queue_free()
		_reward_modals = null
	if _lang_modal != null and is_instance_valid(_lang_modal):
		_lang_modal.queue_free()
		_lang_modal = null
	if _card_back_modal != null and is_instance_valid(_card_back_modal):
		_card_back_modal.queue_free()
		_card_back_modal = null


func _ready() -> void:
	_halo = Sprite2D.new()
	_halo.texture = _halo_texture()
	add_child(_halo)
	for game in Game.GAMES:
		var logo := Sprite2D.new()
		if _available(_logos.size()):
			logo.texture = TitleArt.logo_texture(game)
		var size := logo.texture.get_size() if logo.texture != null else SLOT
		_fit.append(minf(SLOT.x / size.x, SLOT.y / size.y))
		_emphasis.append(0.0)
		add_child(logo)
		_logos.append(logo)
		logo.visible = _available(_logos.size() - 1)
	for i in Game.GAMES.size():
		if _available(i):
			_selected = i
			break
	_emphasis[_selected] = 1.0
	_layout()
	get_viewport().size_changed.connect(_layout)
	_halo.position = _logos[_selected].position
	_apply()
	add_child(_controls)
	_controls.exit_requested.connect(func() -> void:
		Game._save_pending_changes()
		get_tree().quit())
	_controls.update_requested.connect(func() -> void: _release_footer.open_update())
	_controls.card_code_requested.connect(_open_card_code)
	_controls.github_repo_requested.connect(func() -> void: _release_footer.open_repo_editor())
	add_child(_release_footer)
	Updates.changed.connect(func() -> void: _controls.update_available = Updates.state == "available")
	_controls.update_available = Updates.state == "available"
	_language.focus_mode = Control.FOCUS_NONE
	_language.pressed.connect(_open_language_modal)
	_style_control(_language)
	add_child(_language)
	_refresh_language_button()
	_setup_resume_button()
	_setup_online_controls()
	_setup_reward_controls()
	CloudSync.save_replaced.connect(_refresh_resume_button)
	_layout()

	Audio.stop_music()
	_music.bus = Audio.LAUNCHER_MUSIC_BUS
	_controls.changed.connect(_update_music_mute)
	_update_music_mute()
	_music.finished.connect(_start_music)
	add_child(_music)
	if DisplayServer.get_name() != "headless":
		_start_deferred_boot_tasks.call_deferred()
	else:
		_load_and_start_music()


func _start_deferred_boot_tasks() -> void:
	if not is_inside_tree() or _leaving:
		return
	# Let the launcher paint its first frame immediately before loading 4.2 MB music or network sync.
	await get_tree().process_frame
	if not is_inside_tree() or _leaving:
		return
	_load_and_start_music()
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or _leaving:
		return
	if is_instance_valid(Online) and not Online.is_logged_in() and not Online.startup_prompt_dismissed:
		_open_startup_login()
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree() or _leaving:
		return
	CloudSync.sync_now(true)


func _load_and_start_music() -> void:
	if _leaving or _music_stream != null or Audio.AUDIO_DISABLED:
		return
	var loaded: Variant = load(MUSIC_PATH)
	if loaded is AudioStream:
		_music_stream = loaded
		_music.stream = _music_stream
		_start_music()


func _style_control(control: Control) -> void:
	control.add_theme_font_override("font", Assets.ui_font(700))
	if control is OptionButton:
		DialogTheme.style_popup((control as OptionButton).get_popup())
	control.add_theme_color_override("font_color", GOLD_LIGHT)
	control.add_theme_font_size_override("font_size", 15)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = DialogTheme.SURFACE_HOVER if state in ["hover", "pressed"] else DialogTheme.SURFACE
		style.border_color = Color(CYAN, 0.55) if state == "normal" else GOLD
		style.draw_center = state != "focus"
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.anti_aliasing = true
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		control.add_theme_stylebox_override(state, style)


## Recoloca los logos y controles al cambiar el tamano visible.
func _layout() -> void:
	_screen = get_viewport_rect().size
	_origin = ((_screen - DESIGN) / 2.0).floor()
	var x := _screen.x / 2.0 - (SLOT.x + SLOT_GAP)
	for logo in _logos:
		logo.position = Vector2(x, _origin.y + LOGO_Y)
		x += SLOT.x + SLOT_GAP
	if not _logos.is_empty() and _halo != null:
		_halo.position = _logos[_selected].position
	# Top Command Bar (y = 0..64)
	var online_w: float = clampf(_online_button.get_combined_minimum_size().x, 120.0, 240.0)
	_online_button.size = Vector2(online_w, 36)
	_online_button.position = Vector2(142.0, 13)

	_language.size = Vector2(148, 36)
	_language.position = Vector2(_screen.x - 164.0, 13)
	var resume_w := 230.0
	_resume_button.size = Vector2(resume_w, 36)
	_resume_button.position = Vector2(_language.position.x - resume_w - 10.0, 13)

	_layout_feature_dock(_origin.y + LOGO_Y + 108.0)
	queue_redraw()


## Boton Online grande y bien visible, con la palabra escrita (no va dentro del dock de botones pequenos).
func _style_online_hero() -> void:
	_online_mode_button.add_theme_font_override("font", Assets.ui_font(700))
	_online_mode_button.add_theme_font_size_override("font_size", 24)
	_online_mode_button.add_theme_color_override("font_color", Color.WHITE)
	_online_mode_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_online_mode_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var hbox := StyleBoxFlat.new()
		hbox.bg_color = Color(0.06, 0.56, 0.36, 1.0) if state == "normal" else (Color(0.10, 0.68, 0.44, 1.0) if state == "hover" else Color(0.04, 0.40, 0.26, 1.0))
		hbox.border_color = GOLD
		hbox.set_border_width_all(3)
		hbox.set_corner_radius_all(12)
		hbox.shadow_color = Color(0, 0, 0, 0.6)
		hbox.shadow_size = 7
		hbox.content_margin_left = 18
		hbox.content_margin_right = 18
		hbox.content_margin_top = 8
		hbox.content_margin_bottom = 8
		_online_mode_button.add_theme_stylebox_override(state, hbox)


const DOCK_GAP := 14.0       # espacio horizontal entre botones
const DOCK_ROW_GAP := 10.0   # espacio vertical entre filas
const DOCK_ROW_H := 40.0
const HERO_H := 52.0
const HERO_GAP := 12.0


## Boton ONLINE grande: el tamano va en custom_minimum_size para que reset_size() (al cambiar
## el texto o el idioma) no lo encoja otra vez.
func _layout_online_hero(y: float) -> void:
	if not _online_mode_button.visible:
		return
	var w: float = clampf(_screen.x - 60.0, 260.0, 360.0)
	_online_mode_button.clip_text = false
	_online_mode_button.custom_minimum_size = Vector2(w, HERO_H)
	_online_mode_button.size = Vector2(w, HERO_H)
	_online_mode_button.position = Vector2(floorf((_screen.x - w) * 0.5), y)


func _dock_button_width(btn: Button) -> float:
	var font: Font = btn.get_theme_font("font")
	var fs: int = btn.get_theme_font_size("font_size")
	var tw := 0.0
	if font != null:
		tw = ceilf(font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return maxf(tw + 40.0, 124.0)


func _layout_feature_dock(dock_y: float) -> void:
	var dock_buttons: Array[Button] = []
	for btn: Button in [_wheel_button, _special_wheel_button, _code_button, _card_back_button, _ydc_button, _ydc_export_button, _admin_code_button, _card_test_button]:
		if btn.visible:
			dock_buttons.append(btn)
	var max_total := maxf(400.0, _screen.x - 28.0)
	var widths: Array[float] = []
	for btn: Button in dock_buttons:
		widths.append(_dock_button_width(btn))
	# Menos filas posibles, repartidas por igual, sin recortar el texto.
	var n_rows := 1
	var per_row := maxi(dock_buttons.size(), 1)
	while n_rows < 4:
		per_row = ceili(float(dock_buttons.size()) / float(n_rows))
		var fits := true
		for r in n_rows:
			var sum_w := 0.0
			var count := 0
			for i in range(r * per_row, mini((r + 1) * per_row, dock_buttons.size())):
				sum_w += widths[i]
				count += 1
			if count > 0 and sum_w + DOCK_GAP * float(count - 1) > max_total:
				fits = false
		if fits:
			break
		n_rows += 1
	var block_h := (float(n_rows) * DOCK_ROW_H + DOCK_ROW_GAP * float(n_rows - 1) + HERO_GAP + HERO_H) if not dock_buttons.is_empty() else HERO_H
	# Si no cabe debajo de los logos, sube un poco, sin pasar de 28 px; el pie de pagina queda libre.
	var y_start := clampf(_screen.y - 54.0 - block_h, dock_y - 34.0, dock_y)
	var y_cursor := y_start
	for r in n_rows:
		var lo := r * per_row
		var hi := mini((r + 1) * per_row, dock_buttons.size())
		if hi <= lo:
			continue
		var total_w := DOCK_GAP * float(hi - lo - 1)
		for i in range(lo, hi):
			total_w += widths[i]
		var scale_x := minf(1.0, max_total / total_w)
		var bx := (_screen.x - total_w * scale_x) * 0.5
		for i in range(lo, hi):
			var btn: Button = dock_buttons[i]
			var bw := floorf(widths[i] * scale_x)
			btn.clip_text = false
			btn.custom_minimum_size = Vector2(bw, DOCK_ROW_H)
			btn.size = Vector2(bw, DOCK_ROW_H)
			btn.position = Vector2(floorf(bx), y_cursor)
			bx += bw + DOCK_GAP * scale_x
		y_cursor += DOCK_ROW_H + DOCK_ROW_GAP
	_layout_online_hero(y_cursor - DOCK_ROW_GAP + HERO_GAP if not dock_buttons.is_empty() else y_start)


func _setup_resume_button() -> void:
	_resume_button.focus_mode = Control.FOCUS_NONE
	_resume_button.add_theme_font_override("font", Assets.ui_font(700))
	_resume_button.add_theme_font_size_override("font_size", 15)
	_resume_button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.82))
	_resume_button.add_theme_color_override("font_hover_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.08, 0.34, 0.36, 0.96) if state == "normal" else (Color(0.12, 0.46, 0.48, 0.98) if state == "hover" else Color(0.06, 0.25, 0.28, 0.98))
		box.border_color = GOLD
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		_resume_button.add_theme_stylebox_override(state, box)
	_resume_button.pressed.connect(_resume_duel)
	add_child(_resume_button)
	_refresh_resume_button()


func _refresh_resume_button() -> void:
	_resume_summary = DuelResume.summary()
	if _resume_summary.is_empty():
		_resume_button.visible = false
		return
	var g: String = str(_resume_summary.get("game", ""))
	var game_label: String = ""
	if Assets.lang == "a":
		game_label = "يوغي" if g == "yugi" else ("كايبا" if g == "kaiba" else "جوي")
		_resume_button.text = "▶ إكمال المباراة · %s" % game_label
	elif Assets.lang == "s":
		game_label = "Yugi" if g == "yugi" else ("Kaiba" if g == "kaiba" else "Joey")
		_resume_button.text = "▶ Continuar duelo · %s" % game_label
	else:
		game_label = "Yugi" if g == "yugi" else ("Kaiba" if g == "kaiba" else "Joey")
		_resume_button.text = "▶ Resume Duel · %s" % game_label
	_resume_button.visible = true


func _resume_duel() -> void:
	if _leaving or _resume_summary.is_empty():
		return
	_leaving = true
	var cover := CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	get_tree().root.add_child(cover)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music, "volume_db", SILENT_DB, EXIT_FADE)
	tween.tween_property(black, "modulate:a", 1.0, EXIT_FADE)
	tween.chain().tween_callback(Game.resume_saved_duel.bind(cover))


func _setup_online_controls() -> void:
	var show_ui: bool = DisplayServer.get_name() != "headless"
	_online_button.focus_mode = Control.FOCUS_NONE
	_online_button.visible = show_ui
	_style_control(_online_button)
	_online_button.pressed.connect(_open_online_account)
	add_child(_online_button)

	_online_mode_button.focus_mode = Control.FOCUS_NONE
	_online_mode_button.visible = show_ui
	_style_online_hero()
	_online_mode_button.pressed.connect(_open_online_mode)
	add_child(_online_mode_button)

	if is_instance_valid(Online) and not Online.session_changed.is_connected(_refresh_online_controls):
		Online.session_changed.connect(_refresh_online_controls)
	_refresh_online_controls()


func _ensure_online_hub() -> CanvasLayer:
	if _online_hub != null and is_instance_valid(_online_hub):
		return _online_hub
	if DisplayServer.get_name() == "headless":
		return null
	var scr: Script = load("res://scenes/launcher/online_hub.gd")
	if scr == null:
		return null
	_online_hub = scr.new()
	_online_hub.launch_online_duel.connect(_launch_online_duel)
	_online_hub.open_deck_editor_requested.connect(_open_online_deck_editor)
	_online_hub.open_classic_lan_requested.connect(_open_online_classic_lan)
	add_child(_online_hub)
	return _online_hub


func _setup_reward_controls() -> void:
	var show_ui: bool = DisplayServer.get_name() != "headless"
	_wheel_button.focus_mode = Control.FOCUS_NONE
	_wheel_button.visible = show_ui
	_wheel_button.pressed.connect(_open_lucky_wheel)
	_style_feature_button(_wheel_button, Color(0.24, 0.14, 0.46, 0.96), Color(0.32, 0.20, 0.58, 0.98), CYAN)
	add_child(_wheel_button)

	_special_wheel_button.focus_mode = Control.FOCUS_NONE
	_special_wheel_button.visible = show_ui
	_special_wheel_button.pressed.connect(_open_special_wheel)
	_style_feature_button(_special_wheel_button, Color(0.30, 0.12, 0.40, 0.96), Color(0.40, 0.18, 0.52, 0.98), GOLD)
	add_child(_special_wheel_button)

	_code_button.focus_mode = Control.FOCUS_NONE
	_code_button.visible = show_ui
	_code_button.pressed.connect(_open_card_code)
	_style_feature_button(_code_button, Color(0.08, 0.14, 0.30, 0.96), Color(0.12, 0.22, 0.42, 0.98), CYAN_SOFT)
	add_child(_code_button)

	_card_back_button.focus_mode = Control.FOCUS_NONE
	_card_back_button.visible = show_ui
	_card_back_button.pressed.connect(_open_card_back)
	_style_feature_button(_card_back_button, Color(0.10, 0.22, 0.36, 0.96), Color(0.16, 0.32, 0.50, 0.98), GOLD)
	add_child(_card_back_button)

	_admin_code_button.focus_mode = Control.FOCUS_NONE
	_admin_code_button.visible = show_ui
	_admin_code_button.pressed.connect(_open_gift_admin)
	_style_feature_button(_admin_code_button, Color(0.28, 0.18, 0.06, 0.96), Color(0.40, 0.26, 0.10, 0.98), GOLD)
	add_child(_admin_code_button)

	_ydc_button.focus_mode = Control.FOCUS_NONE
	_ydc_button.visible = show_ui
	_ydc_button.pressed.connect(func() -> void:
		if not _leaving and is_instance_valid(_controls):
			_controls.open_ydc_import())
	_style_feature_button(_ydc_button, Color(0.08, 0.24, 0.34, 0.96), Color(0.14, 0.34, 0.48, 0.98), CYAN)
	add_child(_ydc_button)

	_ydc_export_button.focus_mode = Control.FOCUS_NONE
	_ydc_export_button.visible = show_ui
	_ydc_export_button.pressed.connect(func() -> void:
		if not _leaving and is_instance_valid(_controls):
			_controls.open_ydc_export())
	_style_feature_button(_ydc_export_button, Color(0.08, 0.28, 0.24, 0.96), Color(0.14, 0.38, 0.32, 0.98), GOLD)
	add_child(_ydc_export_button)

	_card_test_button.focus_mode = Control.FOCUS_NONE
	_card_test_button.visible = show_ui
	_card_test_button.pressed.connect(func() -> void:
		if not _leaving:
			Game.goto(load("res://scenes/card_effect_test/card_effect_test.tscn").instantiate()))
	_style_feature_button(_card_test_button, Color(0.16, 0.12, 0.30, 0.96), Color(0.24, 0.18, 0.42, 0.98), GOLD)
	add_child(_card_test_button)

	_refresh_reward_buttons()


func _ensure_card_back_modal() -> CanvasLayer:
	if _card_back_modal != null and is_instance_valid(_card_back_modal):
		return _card_back_modal
	if DisplayServer.get_name() == "headless":
		return null
	_card_back_modal = CardBackModal.new()
	_card_back_modal.changed.connect(func() -> void: queue_redraw())
	add_child(_card_back_modal)
	return _card_back_modal


func _ensure_reward_modals() -> CanvasLayer:
	if _reward_modals != null and is_instance_valid(_reward_modals):
		return _reward_modals
	if DisplayServer.get_name() == "headless":
		return null
	_reward_modals = RewardModals.new()
	_reward_modals.card_unlocked.connect(func(_cid: int) -> void: _refresh_wheel_label())
	_reward_modals.closed.connect(_refresh_wheel_label)
	add_child(_reward_modals)
	return _reward_modals


func _style_feature_button(btn: Button, bg: Color, bg_hover: Color, accent: Color) -> void:
	btn.add_theme_font_override("font", Assets.ui_font(700))
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed"]:
		var mbox := StyleBoxFlat.new()
		mbox.bg_color = bg if state == "normal" else bg_hover
		mbox.border_color = GOLD if state != "normal" else Color(accent, 0.90)
		mbox.set_border_width_all(2)
		mbox.set_corner_radius_all(10)
		mbox.shadow_color = Color(0, 0, 0, 0.5)
		mbox.shadow_size = 5
		mbox.content_margin_left = 10
		mbox.content_margin_right = 10
		mbox.content_margin_top = 8
		mbox.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, mbox)


func _open_startup_login() -> void:
	if _leaving:
		return
	if is_instance_valid(Online) and not Online.is_logged_in() and not Online.startup_prompt_dismissed:
		var hub := _ensure_online_hub()
		if hub != null:
			hub.call("open_login", "")


func _open_online_account() -> void:
	if _leaving:
		return
	var hub := _ensure_online_hub()
	if hub == null:
		return
	if is_instance_valid(Online) and Online.is_logged_in():
		hub.call("open_hub", "profile")
	else:
		hub.call("open_login", "")


func _open_online_mode() -> void:
	if _leaving:
		return
	var hub := _ensure_online_hub()
	if hub == null:
		return
	if is_instance_valid(Online) and Online.is_logged_in():
		hub.call("open_game_picker")
	else:
		hub.call("open_login", "pick_game")


func _open_card_code() -> void:
	if _leaving:
		return
	var modals := _ensure_reward_modals()
	if modals != null:
		modals.call("open_card_code")


func _open_lucky_wheel() -> void:
	if _leaving:
		return
	var modals := _ensure_reward_modals()
	if modals != null:
		modals.call("open_lucky_wheel")


func _open_special_wheel() -> void:
	if _leaving:
		return
	var modals := _ensure_reward_modals()
	if modals != null:
		modals.call("open_special_wheel")


func _open_gift_admin() -> void:
	if _leaving:
		return
	var modals := _ensure_reward_modals()
	if modals != null:
		modals.call("open_gift_admin")


func _open_card_back() -> void:
	if _leaving:
		return
	var modal := _ensure_card_back_modal()
	if modal != null:
		modal.call("open_modal")


func _refresh_online_controls() -> void:
	if is_instance_valid(_online_button):
		if is_instance_valid(Online) and Online.is_logged_in():
			var badge: String = " (%d)" % Online.incoming_request_count if Online.incoming_request_count > 0 else ""
			var dot: String = "● " if Online.presence_connected else "○ "
			var pname: String = Online.display_name if Online.display_name != "" else "Duelist"
			_online_button.text = "%s%s · #%s%s" % [dot, pname, Online.player_id, badge]
		else:
			if Assets.lang == "a":
				_online_button.text = "تسجيل الدخول"
			elif Assets.lang == "s":
				_online_button.text = "Iniciar sesión"
			else:
				_online_button.text = "Sign In"
		_online_button.reset_size()
	if is_instance_valid(_online_mode_button):
		if Assets.lang == "a":
			_online_mode_button.text = "أونلاين"
		elif Assets.lang == "s":
			_online_mode_button.text = "ONLINE"
		else:
			_online_mode_button.text = "ONLINE"
		_online_mode_button.reset_size()
		_layout.call_deferred()


func _refresh_reward_buttons() -> void:
	if is_instance_valid(_special_wheel_button):
		if Assets.lang == "a":
			_special_wheel_button.text = "📦 المجموعات الجاهزة"
		elif Assets.lang == "s":
			_special_wheel_button.text = "📦 Mazos Listos"
		else:
			_special_wheel_button.text = "📦 Ready Decks"
		_special_wheel_button.tooltip_text = Tips.text("special_wheel", Assets.lang)
		_special_wheel_button.reset_size()
	if is_instance_valid(_code_button):
		if Assets.lang == "a":
			_code_button.text = "🔑 كود البطاقة"
		elif Assets.lang == "s":
			_code_button.text = "🔑 Código de carta"
		else:
			_code_button.text = "🔑 Card Code"
		_code_button.tooltip_text = Tips.text("card_code", Assets.lang)
		_code_button.reset_size()
	if is_instance_valid(_card_back_button):
		if Assets.lang == "a":
			_card_back_button.text = "🎴 البطاقات والخلفية"
		elif Assets.lang == "s":
			_card_back_button.text = "🎴 Cartas y Fondo"
		else:
			_card_back_button.text = "🎴 Cards & BG"
		_card_back_button.tooltip_text = Tips.text("card_back", Assets.lang)
		_card_back_button.reset_size()
	if is_instance_valid(_admin_code_button):
		if Assets.lang == "a":
			_admin_code_button.text = "🎁 إنشاء كود"
		elif Assets.lang == "s":
			_admin_code_button.text = "🎁 Crear código"
		else:
			_admin_code_button.text = "🎁 Create Code"
		_admin_code_button.tooltip_text = Tips.text("admin_code", Assets.lang)
		_admin_code_button.reset_size()
	if is_instance_valid(_ydc_button):
		_ydc_button.text = "📂 Import .YDC"
		_ydc_button.reset_size()
	if is_instance_valid(_ydc_export_button):
		_ydc_export_button.text = "📤 Export .YDC"
		_ydc_export_button.reset_size()
	if is_instance_valid(_card_test_button):
		if Assets.lang == "a":
			_card_test_button.text = "🧪 اختبار تأثير البطاقة"
		elif Assets.lang == "s":
			_card_test_button.text = "🧪 Prueba de efecto"
		else:
			_card_test_button.text = "🧪 Card Effect Test"
		_card_test_button.reset_size()
	_refresh_wheel_label()


func _refresh_wheel_label() -> void:
	if not is_instance_valid(_wheel_button):
		return
	var rem := RewardModals.remaining_cooldown_sec()
	var new_text := ""
	if rem <= 0:
		if Assets.lang == "a":
			new_text = "🎡 عجلة الحظ · جاهزة!"
		elif Assets.lang == "s":
			new_text = "🎡 Ruleta · ¡Lista!"
		else:
			new_text = "🎡 Lucky Wheel · Ready!"
	else:
		var t_str := RewardModals.format_duration(rem)
		if Assets.lang == "a":
			new_text = "🎡 عجلة الحظ · %s" % t_str
		elif Assets.lang == "s":
			new_text = "🎡 Ruleta · %s" % t_str
		else:
			new_text = "🎡 Wheel · %s" % t_str
	if _wheel_button.text != new_text:
		_wheel_button.text = new_text


func _refresh_language_button() -> void:
	var lang_name: String = str(Assets.LANGUAGES.get(Assets.lang, "English"))
	_language.text = "🌐 %s ▾" % lang_name
	_language.tooltip_text = Tips.text("language", Assets.lang)


func _select_language_code(code: String) -> void:
	if code == "" or not Assets.LANGUAGES.has(code):
		return
	Assets.remember_language(code)
	_refresh_language_button()
	_refresh_resume_button()
	_refresh_online_controls()
	_refresh_reward_buttons()
	_release_footer.refresh()
	_close_language_modal()
	_layout()
	queue_redraw()


func _open_language_modal() -> void:
	if _leaving:
		return
	if _lang_modal == null or not is_instance_valid(_lang_modal):
		_build_language_modal()
	_refresh_language_modal_state()
	_lang_modal.visible = true


func _close_language_modal() -> void:
	if _lang_modal != null and is_instance_valid(_lang_modal):
		_lang_modal.visible = false


func _build_language_modal() -> void:
	_lang_modal = CanvasLayer.new()
	_lang_modal.layer = 96
	_lang_modal.visible = false

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.015, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_language_modal())
	_lang_modal.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lang_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = DialogTheme.BACKGROUND
	pstyle.border_color = GOLD
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(14)
	pstyle.set_content_margin_all(18)
	pstyle.shadow_color = Color(0, 0, 0, 0.7)
	pstyle.shadow_size = 18
	panel.add_theme_stylebox_override("panel", pstyle)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.name = "LangTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", Assets.ui_font(700))
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 38)
	close_btn.focus_mode = Control.FOCUS_NONE
	_style_control(close_btn)
	close_btn.pressed.connect(_close_language_modal)
	header.add_child(close_btn)

	_lang_row_buttons.clear()
	_lang_row_radios.clear()
	for code: String in Assets.LANGUAGES.keys():
		var row_btn := Button.new()
		row_btn.custom_minimum_size = Vector2(320, 50)
		row_btn.focus_mode = Control.FOCUS_NONE
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.add_theme_font_override("font", Assets.ui_font(700))
		row_btn.add_theme_font_size_override("font_size", 18)
		row_btn.add_theme_color_override("font_color", GOLD_LIGHT)
		row_btn.add_theme_color_override("font_hover_color", Color.WHITE)
		row_btn.add_theme_constant_override("h_separation", 14)
		row_btn.text = str(Assets.LANGUAGES[code])
		row_btn.icon = DialogTheme.radio_icon(code == Assets.lang)
		row_btn.pressed.connect(_select_language_code.bind(code))
		vbox.add_child(row_btn)
		_lang_row_buttons[code] = row_btn

	add_child(_lang_modal)


func _refresh_language_modal_state() -> void:
	if _lang_modal == null or not is_instance_valid(_lang_modal):
		return
	var title_node := _lang_modal.find_child("LangTitle", true, false) as Label
	if title_node != null:
		if Assets.lang == "a":
			title_node.text = "🌐 اختر اللغة"
		elif Assets.lang == "s":
			title_node.text = "🌐 Seleccionar idioma"
		else:
			title_node.text = "🌐 Select Language"
	for code: String in _lang_row_buttons.keys():
		var btn: Button = _lang_row_buttons[code]
		if not is_instance_valid(btn):
			continue
		var is_selected: bool = code == Assets.lang
		btn.icon = DialogTheme.radio_icon(is_selected)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.12, 0.24, 0.42, 0.98) if is_selected else (DialogTheme.SURFACE_HOVER if state != "normal" else DialogTheme.SURFACE)
			box.border_color = GOLD if is_selected else (CYAN if state != "normal" else Color(CYAN, 0.38))
			box.set_border_width_all(2 if is_selected else 1)
			box.set_corner_radius_all(10)
			box.content_margin_left = 14
			box.content_margin_right = 14
			box.content_margin_top = 8
			box.content_margin_bottom = 8
			btn.add_theme_stylebox_override(state, box)


func has_online_modal() -> bool:
	var hub_open := _online_hub != null and is_instance_valid(_online_hub) and bool(_online_hub.call("is_open"))
	var mod_open := _reward_modals != null and is_instance_valid(_reward_modals) and bool(_reward_modals.call("is_open"))
	var lang_open := _lang_modal != null and is_instance_valid(_lang_modal) and _lang_modal.visible
	var back_open := _card_back_modal != null and is_instance_valid(_card_back_modal) and bool(_card_back_modal.call("is_open"))
	return hub_open or mod_open or lang_open or back_open


func close_online_modal_if_open() -> bool:
	var closed_any := false
	if _lang_modal != null and is_instance_valid(_lang_modal) and _lang_modal.visible:
		_close_language_modal()
		closed_any = true
	if _card_back_modal != null and is_instance_valid(_card_back_modal) and bool(_card_back_modal.call("is_open")):
		_card_back_modal.call("close_modal")
		closed_any = true
	if _online_hub != null and is_instance_valid(_online_hub) and bool(_online_hub.call("is_open")):
		_online_hub.call("close_all")
		closed_any = true
	if _reward_modals != null and is_instance_valid(_reward_modals) and bool(_reward_modals.call("is_open")):
		_reward_modals.call("close_all")
		closed_any = true
	return closed_any


func _launch_online_duel(game_id: String) -> void:
	if _leaving or not Paths.has_game(game_id):
		return
	_leaving = true
	if _online_hub != null and is_instance_valid(_online_hub):
		_online_hub.queue_free()
		_online_hub = null
	Audio.stop_music()
	Game.open_lan_online(game_id)


func _open_online_deck_editor(game_id: String) -> void:
	if _leaving or not Paths.has_game(game_id):
		return
	_leaving = true
	if _online_hub != null and is_instance_valid(_online_hub):
		_online_hub.queue_free()
		_online_hub = null
	Audio.stop_music()
	Game.open_deck_editor(game_id)


func _open_online_classic_lan(game_id: String) -> void:
	if _leaving or not Paths.has_game(game_id):
		return
	_leaving = true
	if _online_hub != null and is_instance_valid(_online_hub):
		_online_hub.queue_free()
		_online_hub = null
	Audio.stop_music()
	Game.open_lan(game_id)


func _start_music() -> void:
	if _leaving or _music_stream == null:
		return
	_looped = _started
	_started = true
	_music.volume_db = SILENT_DB if _looped else _volume_db(1.0)
	_music.play()


func _volume_db(fade: float) -> float:
	var linear: float = fade * _controls.level()
	return maxf(linear_to_db(maxf(linear, 0.00001)), SILENT_DB) + MUSIC_DB


func _update_music() -> void:
	if _leaving or not _music.playing or _music_stream == null:
		return
	var pos := _music.get_playback_position()
	var length := _music_stream.get_length()
	var fade_in := LOOP_FADE if _looped else 0.0
	var level := clampf((length - pos) / LOOP_FADE, 0.0, 1.0)
	if fade_in > 0.0:
		level = minf(level, pos / fade_in)
	_music.volume_db = _volume_db(level)


func _update_music_mute() -> void:
	Audio.set_launcher_music_muted(_controls.level() == 0.0)


func _available(index: int) -> bool:
	return Paths.has_game(Game.GAMES[index])


func _choose(index: int) -> void:
	if _leaving or not _available(index):
		return
	_leaving = true
	var cover := CanvasLayer.new()
	cover.layer = 100
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.modulate.a = 0.0
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(black)
	get_tree().root.add_child(cover)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_music, "volume_db", SILENT_DB, EXIT_FADE)
	tween.tween_property(black, "modulate:a", 1.0, EXIT_FADE)
	tween.chain().tween_callback(Game.open_title.bind(Game.GAMES[index], "", cover))


func _process(delta: float) -> void:
	_time += delta
	_wheel_tick_accum += delta
	if _wheel_tick_accum >= 0.5:
		_wheel_tick_accum = 0.0
		_refresh_wheel_label()
	_update_music()
	var k := 1.0 - exp(-delta * 12.0)
	for i in _logos.size():
		_emphasis[i] = lerpf(_emphasis[i], 1.0 if i == _selected else 0.0, k)
	_halo.position = _halo.position.lerp(_logos[_selected].position, k)
	_apply()
	queue_redraw()


func _apply() -> void:
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	for i in _logos.size():
		var e := _emphasis[i]
		var s := lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, e)
		_logos[i].scale = Vector2.ONE * _fit[i] * s
		_logos[i].modulate = DIM.lerp(Color.WHITE, e)
	var is_classic := LauncherSettings.bg_style == "classic"
	var halo_rgb := Color(1.0, 0.80, 0.34) if is_classic else Color.WHITE
	_halo.modulate = Color(halo_rgb.r, halo_rgb.g, halo_rgb.b, 0.72 + 0.25 * sin(_time * 3.0))


func _get_bg_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _bg_tex_cache.has(path):
		return _bg_tex_cache[path]
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path)
		_bg_tex_cache[path] = t
		return t
	return null


func _draw() -> void:
	var is_classic := LauncherSettings.bg_style == "classic"
	var bg_top := CLASSIC_BG_TOP if is_classic else BG_TOP
	var bg_bottom := CLASSIC_BG_BOTTOM if is_classic else BG_BOTTOM
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_screen.x, 0), _screen, Vector2(0, _screen.y)]),
			PackedColorArray([bg_top, bg_top, bg_bottom, bg_bottom]))
	var custom_bg_path := LauncherSettings.bg_texture_path() if is_instance_valid(LauncherSettings) else ""
	var custom_bg_tex := _get_bg_texture(custom_bg_path)
	if custom_bg_tex != null:
		draw_texture_rect(custom_bg_tex, Rect2(Vector2.ZERO, _screen), false, Color(1, 1, 1, 0.58))
		draw_rect(Rect2(Vector2.ZERO, _screen), Color(0.015, 0.02, 0.055, 0.45))
	if is_classic:
		if _classic_glow == null:
			_classic_glow = _classic_glow_texture()
		var glow_size := Vector2(maxf(_screen.x * 1.1, 900.0), 540.0)
		draw_texture_rect(_classic_glow, Rect2(Vector2(_screen.x / 2.0, _origin.y + LOGO_Y) - glow_size / 2.0, glow_size), false)
	else:
		_draw_top_bar()
	_draw_title()
	if not is_classic:
		_draw_edition_pedestals()
	var sub := _subtitle_text()
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(_font, Vector2((_screen.x - sw) * 0.5, _origin.y + TITLE_Y + 48.0),
			sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(GOLD_LIGHT, 0.90) if is_classic else CYAN_SOFT)


func _subtitle_text() -> String:
	if Assets.lang == "a":
		return "اختر نسختك أو ادخل إلى الوضع الأونلاين"
	if Assets.lang == "s":
		return "Elige tu juego o entra al modo online"
	return "Choose your edition or enter Online Mode"


func _draw_top_bar() -> void:
	var bar_h := 62.0
	draw_rect(Rect2(0.0, 0.0, _screen.x, bar_h), Color(0.02, 0.024, 0.065, 0.94))
	draw_line(Vector2(0.0, bar_h), Vector2(_screen.x, bar_h), Color(CYAN, 0.45), 1.5, true)
	draw_line(Vector2(0.0, bar_h + 1.5), Vector2(_screen.x, bar_h + 1.5), Color(GOLD, 0.20), 1.0, true)
	var cx := 30.0
	var cy := bar_h * 0.5
	var r := 11.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - r, cy - r * 0.65), Vector2(cx + r, cy - r * 0.65), Vector2(cx, cy + r * 0.95)
	]), Color(GOLD, 0.25))
	draw_polyline(PackedVector2Array([
		Vector2(cx - r, cy - r * 0.65), Vector2(cx + r, cy - r * 0.65), Vector2(cx, cy + r * 0.95), Vector2(cx - r, cy - r * 0.65)
	]), GOLD, 1.8, true)
	draw_circle(Vector2(cx, cy - 1.5), 3.2, CYAN)
	draw_string(_font, Vector2(48.0, cy + 5.5), "Yu-Gi-Oh!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)


func _draw_edition_pedestals() -> void:
	var labels: Array[String] = ["YUGI", "KAIBA", "JOEY"]
	for i in _logos.size():
		if not _available(i):
			continue
		var e := _emphasis[i]
		var accent: Color = EDITION_ACCENTS[i]
		var box_rect := Rect2(_logos[i].position - Vector2(SLOT.x * 0.5 + 7.0, SLOT.y * 0.5 + 8.0), Vector2(SLOT.x + 14.0, SLOT.y + 18.0))
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.045, 0.055, 0.135, 0.72 + 0.18 * e)
		style.border_color = accent.lerp(GOLD, 0.45 * e) if e > 0.3 else Color(accent, 0.35)
		style.set_border_width_all(2 if e > 0.5 else 1)
		style.set_corner_radius_all(12)
		style.shadow_color = Color(accent, 0.26 * e)
		style.shadow_size = int(12.0 * e)
		draw_style_box(style, box_rect)
		var top_bar := Rect2(box_rect.position + Vector2(18.0, 2.0), Vector2(box_rect.size.x - 36.0, 2.5))
		draw_rect(top_bar, Color(accent, 0.35 + 0.60 * e))
		var tag: String = labels[i]
		var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(_font, Vector2(box_rect.get_center().x - tw * 0.5, box_rect.end.y - 6.0),
				tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD_LIGHT if e > 0.5 else Color(CYAN_SOFT, 0.65))


## Titulo dorado con contorno, sombra, brillo que recorre las letras y filete decorativo.
func _draw_title() -> void:
	var title := "Yu-Gi-Oh!"
	var width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var x := (_screen.x - width) / 2.0
	var title_y := _origin.y + TITLE_Y
	var base := Vector2(x, title_y)
	var is_classic := LauncherSettings.bg_style == "classic"
	draw_string_outline(_font, base + Vector2(4, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE,
			10, Color(0, 0, 0, 0.65))
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 10, OUTLINE)
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 4, Color(GOLD if is_classic else CYAN, 0.35))
	var shine := fmod(_time * 0.6, 1.6) - 0.3
	var cx := x
	for ch in title:
		var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
		var t := (cx + w / 2.0 - x) / maxf(width, 1.0)
		var glow := clampf(1.0 - absf(t - shine) * 5.0, 0.0, 1.0)
		var ch_col := GOLD.lerp(GOLD_LIGHT, glow) if is_classic else GOLD.lerp(CYAN_SOFT, glow * 0.65).lerp(GOLD_LIGHT, glow * 0.35)
		draw_string(_font, Vector2(cx, title_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, ch_col)
		cx += w
	var y := title_y + 18.0
	var half := width / 2.0 + 78.0
	var mid := _screen.x / 2.0
	var rule_col := GOLD if is_classic else CYAN
	for dir in [-1.0, 1.0]:
		var pts := PackedVector2Array([Vector2(mid + dir * 12.0, y), Vector2(mid + dir * half, y)])
		draw_polyline_colors(pts, PackedColorArray([rule_col, Color(rule_col, 0.0)]), 2.0, true)
	var d := 5.5
	draw_colored_polygon(PackedVector2Array([Vector2(mid, y - d), Vector2(mid + d, y),
			Vector2(mid, y + d), Vector2(mid - d, y)]), GOLD_LIGHT)


func _unhandled_input(event: InputEvent) -> void:
	if Game.has_active_root_dialog():
		return
	if event.is_action_pressed("ui_left"):
		_move(-1)
	elif event.is_action_pressed("ui_right"):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		_choose(_selected)
	elif event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != -1:
			_selected = hit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit != -1:
			_choose(hit)


func _move(step: int) -> void:
	for unused in _logos.size():
		_selected = wrapi(_selected + step, 0, _logos.size())
		if _available(_selected):
			break


## Cada juego responde en toda su ranura, no solo sobre los pixeles del logo.
func _hit(screen_pos: Vector2) -> int:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in _logos.size():
		if _available(i) and Rect2(_logos[i].position - SLOT / 2.0, SLOT).has_point(local):
			return i
	return -1


func _halo_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.22, 0.82, 1.0, 0.45))
	gradient.set_color(1, Color(0.54, 0.31, 0.98, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 360
	tex.height = 240
	return tex


func _classic_glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.88, 0.62, 0.18, 0.28))
	gradient.set_color(1, Color(0.24, 0.12, 0.28, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 360
	tex.height = 200
	return tex
