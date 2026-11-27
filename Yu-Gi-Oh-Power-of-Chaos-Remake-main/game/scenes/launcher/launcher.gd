extends Node2D
## Selector de juego: lo unico que no existe en el original. Une los tres juegos en uno
## mostrando el logo de cada uno; el resto del juego es el original.

## Composicion pensada en 800x600; se centra en la pantalla visible, que en el selector se
## estira al formato del monitor (aspecto EXPAND). El resto del juego sigue en 4:3 (KEEP).
const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const RewardModals := preload("res://scenes/launcher/reward_modals.gd")
const CardBackModal := preload("res://scenes/launcher/card_back_modal.gd")
const DESIGN := Vector2(800, 600)
const SLOT := Vector2(204, 132)          # caja en la que se encaja cada logo
const SLOT_GAP := 26.0
const LOGO_Y := 262.0                    # centro vertical de la fila de logos (en DESIGN)
const TITLE_Y := 118.0
const TITLE_SIZE := 44
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

## Musica propia del selector (no es del original): arranca de golpe al abrir y despues sale y
## vuelve a entrar con fundido en cada vuelta.
var MUSIC: AudioStream
const MUSIC_DB := 0.0
const SILENT_DB := -60.0
const LOOP_FADE := 2.5                    # segundos de fundido al empezar y al acabar la vuelta
const EXIT_FADE := 0.4                    # fundido de salida al elegir juego

var _selected_index := 0
var _music := AudioStreamPlayer.new()
var _controls: Node2D = preload("res://scenes/launcher/launcher_controls.gd").new()
var _leaving := false
var _started := false                     # ya sono la primera vuelta
var _looped := false                      # vuelta actual es una repeticion (entra con fundido)
var _logos: Array[Sprite2D] = []
var _fit: Array[float] = []              # escala que encaja cada logo en SLOT
var _emphasis: Array[float] = []         # 0..1, animado hacia 1 en el seleccionado
var _halo: Sprite2D
var _glow := _radial(Color(0.16, 0.40, 0.72), 0.24, Vector2i(512, 256))
var _classic_glow := _radial(Color(0.88, 0.62, 0.18), 0.26, Vector2i(512, 256))
var _time := 0.0
var _wheel_tick_accum := 0.0
var _font: Font = Assets.ui_font(700)
var _screen := DESIGN                    # pantalla visible
var _origin := Vector2.ZERO              # esquina de la composicion DESIGN centrada en ella
var import_mode := false
var logo_y := LOGO_Y
var heading_y := TITLE_Y
var _language := OptionButton.new()
const Tips = preload("res://scenes/launcher/tooltip_texts.gd")
var _setup_button := Button.new()
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
var _bg_tex_cache: Dictionary = {}


func _enter_tree() -> void:
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _exit_tree() -> void:
	_music.stop()
	_music.stream = null
	if is_instance_valid(Online) and Online.session_changed.is_connected(_refresh_online_button):
		Online.session_changed.disconnect(_refresh_online_button)
	if _online_hub != null and is_instance_valid(_online_hub):
		_online_hub.queue_free()
		_online_hub = null
	if _reward_modals != null and is_instance_valid(_reward_modals):
		_reward_modals.queue_free()
		_reward_modals = null
	if _card_back_modal != null and is_instance_valid(_card_back_modal):
		_card_back_modal.queue_free()
		_card_back_modal = null


func _ready() -> void:
	# Recurso propio del remake, incluido expresamente en la copia publica.
	var music_path := "res://assets/music/launcher_theme.mp3"
	if Audio.MENU_SOUND and not Audio.AUDIO_DISABLED and ResourceLoader.exists(music_path):
		MUSIC = load(music_path)
	_halo = Sprite2D.new()
	# Halo a doble resolucion, dibujado a la mitad: caida suave sin escalones.
	_halo.texture = _radial(Color(0.22, 0.82, 1.0), 0.52, Vector2i(720, 480))
	_halo.scale = Vector2.ONE * 0.5
	add_child(_halo)
	for game in Game.GAMES:
		var logo := Sprite2D.new()
		logo.texture = _smooth(TitleArt.logo_texture(game)) if Paths.has_game(game) else null
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if logo.texture != null:
			var outline := ShaderMaterial.new()
			outline.shader = preload("res://scenes/launcher/logo_outline.gdshader")
			logo.material = outline
		var size := logo.texture.get_size() if logo.texture != null else SLOT
		_fit.append(minf(SLOT.x / size.x, SLOT.y / size.y))
		_emphasis.append(0.0)
		add_child(logo)
		_logos.append(logo)
	_emphasis[_selected_index] = 1.0
	_layout()
	get_viewport().size_changed.connect(_layout)
	_halo.position = _logos[_selected_index].position
	_apply()
	add_child(_controls)
	_controls.exit_requested.connect(_request_exit)
	_controls.update_requested.connect(_request_update)
	_controls.card_code_requested.connect(_open_card_code)
	_controls.github_repo_requested.connect(_open_repo_editor)
	add_child(_release_footer)
	Updates.changed.connect(_update_badge)
	_update_badge()
	# En el selector ninguna escena usa la partida: momento seguro para traer cambios de la nube.
	CloudSync.save_replaced.connect(_refresh_resume_button)
	CloudSync.sync_now(true)
	Audio.stop_music()
	_music.stream = MUSIC
	_music.bus = Audio.LAUNCHER_MUSIC_BUS
	_controls.changed.connect(_update_music_mute)
	_update_music_mute()
	_music.finished.connect(_start_music)
	add_child(_music)
	_start_music()
	_setup_button.text = "ISO / " + _folder_label()
	_setup_button.position = Vector2(24, 14)
	_setup_button.visible = not import_mode
	_setup_button.pressed.connect(func() -> void: Game.goto(load("res://scenes/launcher/content_setup.gd").new()))
	_style_control(_setup_button)
	add_child(_setup_button)
	_setup_online_controls()
	_setup_reward_controls()
	for key: String in Assets.LANGUAGES:
		_language.add_item(Assets.LANGUAGES[key])
	_language.item_selected.connect(_select_language)
	_style_control(_language)
	add_child(_language)
	_setup_resume_button()
	_controls.changed.connect(_language_updated)
	_language_updated()
	_layout()


## Copia con mipmaps: los logos se dibujan reducidos y sin ellos se ven dentados.
func _smooth(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func _folder_label() -> String:
	return {"a": "مجلد", "s": "Carpeta", "e": "Folder", "g": "Ordner", "f": "Dossier", "i": "Cartella", "j": "フォルダー"}.get(Assets.lang, "Folder")


func _request_exit() -> void:
	Game._save_pending_changes()
	get_tree().quit()


func _request_update() -> void:
	if not _leaving:
		_release_footer.open_update()


func _open_repo_editor() -> void:
	if not _leaving:
		_release_footer.open_repo_editor()


func _update_badge() -> void:
	_controls.update_available = Updates.state == "available"


func _style_control(control: Control) -> void:
	control.add_theme_font_override("font", Assets.ui_font(700))
	if control is OptionButton:
		DialogTheme.style_popup((control as OptionButton).get_popup())
	control.add_theme_color_override("font_color", GOLD_LIGHT)
	control.add_theme_font_size_override("font_size", 14)
	control.add_theme_color_override("font_hover_color", Color.WHITE)
	control.add_theme_color_override("font_disabled_color", Color(GOLD_LIGHT, 0.35))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = DialogTheme.SURFACE_HOVER if state in ["hover", "pressed"] else DialogTheme.SURFACE
		style.border_color = Color(CYAN, 0.25) if state == "disabled" else (Color(CYAN, 0.55) if state == "normal" else GOLD)
		style.draw_center = state != "focus"
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		style.anti_aliasing = true
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		control.add_theme_stylebox_override(state, style)


func _select_language(index: int) -> void:
	Assets.remember_language(Assets.LANGUAGES.keys()[index])
	_language_updated()


func _language_updated() -> void:
	_language.select(Assets.LANGUAGES.keys().find(Assets.lang))
	_language.tooltip_text = Tips.text("language", Assets.lang)
	_setup_button.tooltip_text = Tips.text("import", Assets.lang)
	_setup_button.text = "ISO / " + _folder_label()
	_refresh_online_button()
	_refresh_reward_buttons()
	_refresh_resume_button()
	if _release_footer.is_node_ready():
		_release_footer.refresh()
	queue_redraw()


func _setup_online_controls() -> void:
	var show_ui: bool = DisplayServer.get_name() != "headless"
	_online_button.focus_mode = Control.FOCUS_NONE
	_online_button.visible = show_ui
	_online_button.pressed.connect(_open_online_account)
	_style_control(_online_button)
	add_child(_online_button)

	_online_mode_button.focus_mode = Control.FOCUS_NONE
	_online_mode_button.visible = show_ui
	_online_mode_button.pressed.connect(_open_online_mode)
	_style_online_hero()
	add_child(_online_mode_button)

	if is_instance_valid(Online) and not Online.session_changed.is_connected(_refresh_online_button):
		Online.session_changed.connect(_refresh_online_button)
	_refresh_online_button()
	if show_ui:
		_online_hub = preload("res://scenes/launcher/online_hub.gd").new()
		_online_hub.launch_online_duel.connect(_launch_online_duel)
		_online_hub.open_deck_editor_requested.connect(_open_online_deck_editor)
		_online_hub.open_classic_lan_requested.connect(_open_online_classic_lan)
		add_child(_online_hub)
		if is_instance_valid(Online) and not Online.is_logged_in() and not Online.startup_prompt_dismissed:
			_open_startup_login.call_deferred()


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

	if show_ui:
		_reward_modals = RewardModals.new()
		_reward_modals.card_unlocked.connect(func(_cid: int) -> void: _refresh_wheel_label())
		_reward_modals.closed.connect(_refresh_wheel_label)
		add_child(_reward_modals)
		_card_back_modal = CardBackModal.new()
		_card_back_modal.changed.connect(func() -> void: queue_redraw())
		add_child(_card_back_modal)
	_refresh_reward_buttons()


func _style_feature_button(btn: Button, bg: Color, bg_hover: Color, accent: Color) -> void:
	btn.add_theme_font_override("font", Assets.ui_font(700))
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = bg if state == "normal" else (bg_hover if state in ["hover", "pressed"] else bg.darkened(0.25))
		box.border_color = GOLD if state in ["hover", "pressed"] else Color(accent, 0.85)
		box.draw_center = state != "focus"
		box.set_border_width_all(2)
		box.set_corner_radius_all(8)
		box.anti_aliasing = true
		box.shadow_color = Color(0, 0, 0, 0.36)
		box.shadow_size = 3
		box.content_margin_left = 8
		box.content_margin_right = 8
		box.content_margin_top = 5
		box.content_margin_bottom = 5
		btn.add_theme_stylebox_override(state, box)


func _open_startup_login() -> void:
	if _leaving or _online_hub == null or not is_instance_valid(_online_hub):
		return
	if is_instance_valid(Online) and not Online.is_logged_in() and not Online.startup_prompt_dismissed:
		_online_hub.call("open_login", "")


func _open_online_account() -> void:
	if _leaving or _online_hub == null or not is_instance_valid(_online_hub):
		return
	if is_instance_valid(Online) and Online.is_logged_in():
		_online_hub.call("open_hub", "profile")
	else:
		_online_hub.call("open_login", "")


func _open_online_mode() -> void:
	if _leaving or _online_hub == null or not is_instance_valid(_online_hub):
		return
	if is_instance_valid(Online) and Online.is_logged_in():
		_online_hub.call("open_game_picker")
	else:
		_online_hub.call("open_login", "pick_game")


func _open_card_code() -> void:
	if _leaving or _reward_modals == null or not is_instance_valid(_reward_modals):
		return
	_reward_modals.call("open_card_code")


func _open_lucky_wheel() -> void:
	if _leaving or _reward_modals == null or not is_instance_valid(_reward_modals):
		return
	_reward_modals.call("open_lucky_wheel")


func _open_special_wheel() -> void:
	if _leaving or _reward_modals == null or not is_instance_valid(_reward_modals):
		return
	_reward_modals.call("open_special_wheel")


func _open_gift_admin() -> void:
	if _leaving or _reward_modals == null or not is_instance_valid(_reward_modals):
		return
	_reward_modals.call("open_gift_admin")


func _open_card_back() -> void:
	if _leaving or _card_back_modal == null or not is_instance_valid(_card_back_modal):
		return
	_card_back_modal.call("open_modal")


func _refresh_online_button() -> void:
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


func has_online_modal() -> bool:
	var hub_open := _online_hub != null and is_instance_valid(_online_hub) and bool(_online_hub.call("is_open"))
	var mod_open := _reward_modals != null and is_instance_valid(_reward_modals) and bool(_reward_modals.call("is_open"))
	var back_open := _card_back_modal != null and is_instance_valid(_card_back_modal) and bool(_card_back_modal.call("is_open"))
	return hub_open or mod_open or back_open


func close_online_modal_if_open() -> bool:
	var closed_any := false
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


func _setup_resume_button() -> void:
	_resume_button.focus_mode = Control.FOCUS_NONE
	_resume_button.add_theme_font_override("font", Assets.ui_font(700))
	_resume_button.add_theme_font_size_override("font_size", 14)
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
	if _resume_summary.is_empty() or import_mode:
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
	if _music.playing:
		tween.tween_property(_music, "volume_db", SILENT_DB, EXIT_FADE)
	tween.tween_property(black, "modulate:a", 1.0, EXIT_FADE)
	tween.chain().tween_callback(Game.resume_saved_duel.bind(cover))


func _heading() -> String:
	return "Yu-Gi-Oh!"


## Recoloca los logos y los controles al cambiar el tamano visible.
func _layout() -> void:
	_screen = get_viewport_rect().size
	_origin = ((_screen - DESIGN) / 2.0).floor()
	var x := _screen.x / 2.0 - (SLOT.x + SLOT_GAP)
	for logo in _logos:
		logo.position = Vector2(x, _origin.y + logo_y)
		x += SLOT.x + SLOT_GAP
	if not _logos.is_empty() and _halo != null:
		_halo.position = _logos[_selected_index].position
	# Top Command Bar (y = 0..56) with guaranteed non-overlapping spacing
	_language.size = Vector2(128, 32)
	_language.position = Vector2(_screen.x - 142.0, 12)
	var right_limit := _language.position.x - 10.0
	if _resume_button.visible:
		var resume_w := clampf(_resume_button.get_combined_minimum_size().x + 8.0, 150.0, 204.0)
		_resume_button.size = Vector2(resume_w, 32)
		_resume_button.position = Vector2(right_limit - resume_w, 12)
		right_limit = _resume_button.position.x - 10.0
	var left_x := 142.0
	if _setup_button.visible:
		var setup_w: float = clampf(_setup_button.get_combined_minimum_size().x, 96.0, 134.0)
		_setup_button.size = Vector2(setup_w, 32)
		_setup_button.position = Vector2(left_x, 12)
		left_x += setup_w + 10.0
	var max_online_w: float = maxf(120.0, right_limit - left_x)
	var online_w: float = clampf(_online_button.get_combined_minimum_size().x + 6.0, 120.0, minf(224.0, max_online_w))
	_online_button.clip_text = true
	_online_button.size = Vector2(online_w, 32)
	_online_button.position = Vector2(left_x, 12)

	if not import_mode:
		_layout_feature_dock(_origin.y + logo_y + 106.0)
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


func _layout_online_hero(below_y: float) -> void:
	if not _online_mode_button.visible:
		return
	var w: float = clampf(_screen.x - 60.0, 240.0, 340.0)
	var h := 50.0
	_online_mode_button.clip_text = false
	_online_mode_button.size = Vector2(w, h)
	_online_mode_button.position = Vector2((_screen.x - w) * 0.5, minf(below_y, _screen.y - 104.0))


func _layout_feature_dock(dock_y: float) -> void:
	var dock_buttons: Array[Button] = []
	for btn: Button in [_wheel_button, _special_wheel_button, _code_button, _card_back_button, _ydc_button, _ydc_export_button, _admin_code_button, _card_test_button]:
		if btn.visible:
			dock_buttons.append(btn)
	if dock_buttons.is_empty():
		_layout_online_hero(dock_y)
		return
	var gap := 12.0
	var max_total := clampf(_screen.x - 44.0, 560.0, 820.0)
	var use_two_rows: bool = dock_buttons.size() > 4
	var rows: Array[Array] = []
	if use_two_rows:
		var split := ceili(float(dock_buttons.size()) * 0.5)
		rows.append(dock_buttons.slice(0, split))
		rows.append(dock_buttons.slice(split, dock_buttons.size()))
	else:
		rows.append(dock_buttons)
	var y_cursor := dock_y
	for row_btns: Array in rows:
		var widths: Array[float] = []
		var sum_w := 0.0
		for btn: Button in row_btns:
			var bw := clampf(btn.get_combined_minimum_size().x + 8.0, 122.0, 184.0)
			widths.append(bw)
			sum_w += bw
		var avail_buttons := max_total - gap * float(row_btns.size() - 1)
		if sum_w > avail_buttons and sum_w > 0.0:
			var ratio := avail_buttons / sum_w
			sum_w = 0.0
			for i in widths.size():
				widths[i] = floorf(widths[i] * ratio)
				sum_w += widths[i]
		var total_w := sum_w + gap * float(row_btns.size() - 1)
		var bx := (_screen.x - total_w) * 0.5
		var row_h := 34.0 if use_two_rows else 38.0
		for i in row_btns.size():
			var btn: Button = row_btns[i]
			btn.clip_text = true
			btn.size = Vector2(widths[i], row_h)
			btn.position = Vector2(bx, y_cursor)
			bx += widths[i] + gap
		y_cursor += row_h + 10.0
	_layout_online_hero(y_cursor)


func _start_music() -> void:
	if _leaving or MUSIC == null:
		return
	_looped = _started
	_started = true
	_music.volume_db = SILENT_DB if _looped else _volume_db(1.0)
	_music.play()


## Nivel del fundido (0..1) por el volumen y el silencio elegidos en los botones.
func _volume_db(fade: float) -> float:
	var linear: float = fade * _controls.level()
	return maxf(linear_to_db(maxf(linear, 0.00001)), SILENT_DB) + MUSIC_DB


## Volumen segun la posicion en la vuelta: sube al empezar y baja antes del final. Se
## interpola en lineal (no en dB) para que el fundido se oiga uniforme.
func _update_music() -> void:
	if _leaving or not _music.playing:
		return
	var pos := _music.get_playback_position()
	var length := MUSIC.get_length()
	# La primera vuelta entra de golpe al abrir el launcher; las siguientes, con fundido.
	var fade_in := LOOP_FADE if _looped else 0.0
	var level := clampf((length - pos) / LOOP_FADE, 0.0, 1.0)
	if fade_in > 0.0:
		level = minf(level, pos / fade_in)
	_music.volume_db = _volume_db(level)


func _update_music_mute() -> void:
	Audio.set_launcher_music_muted(_controls.level() == 0.0)


func _choose(index: int) -> void:
	if not Paths.has_game(Game.GAMES[index]):
		Game.open_launcher()
		return
	if _leaving:
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
	# Sobrevive al launcher: el cambio de formato ocurre completamente bajo negro.
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
		_emphasis[i] = lerpf(_emphasis[i], 1.0 if i == _selected_index else 0.0, k)
	_halo.position = _halo.position.lerp(_logos[_selected_index].position, k)
	_apply()
	queue_redraw()


func _apply() -> void:
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	for i in _logos.size():
		var e := _emphasis[i]
		var s := lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, e)
		_logos[i].scale = Vector2.ONE * _fit[i] * s
		_logos[i].modulate = DIM.lerp(Color.WHITE, e)
		if _logos[i].material != null:
			_logos[i].material.set_shader_parameter("emphasis", e)
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
	# Luz tenue detras de la fila de logos para que no floten sobre un fondo plano.
	var glow_size := Vector2(maxf(_screen.x * 1.1, 900.0), 540.0)
	draw_texture_rect(_classic_glow if is_classic else _glow, Rect2(Vector2(_screen.x / 2.0, _origin.y + logo_y) - glow_size / 2.0, glow_size), false)
	if not is_classic:
		_draw_top_bar()
	_draw_title()
	if not is_classic:
		_draw_edition_pedestals()
	for i in _logos.size():
		if _logos[i].texture == null:
			_draw_game_card(i)
	if not import_mode:
		var sub := _standalone_subtitle()
		var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(_font, Vector2((_screen.x - sw) * 0.5, _origin.y + heading_y + 40.0),
				sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(GOLD_LIGHT, 0.90) if is_classic else CYAN_SOFT)
	var voice_language := Assets.voice_language(Game.GAMES[_selected_index])
	if voice_language != "" and not import_mode:
		var voices_prefix := "الأصوات: " if Assets.lang == "a" else ("Voices: " if Assets.lang == "e" else "Voces: ")
		var vtext = voices_prefix + str(Assets.LANGUAGES.get(voice_language, voice_language))
		var vw := _font.get_string_size(vtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(_font, Vector2((_screen.x - vw) * 0.5, _origin.y + 478),
				vtext, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(GOLD_LIGHT, 0.88))


func _standalone_subtitle() -> String:
	if Assets.lang == "a":
		return "اختر نسختك أو ادخل إلى الوضع الأونلاين"
	if Assets.lang == "s":
		return "Elige tu juego o entra al modo online"
	return "Choose your edition or enter Online Mode"


func _draw_top_bar() -> void:
	var bar_h := 56.0
	draw_rect(Rect2(0.0, 0.0, _screen.x, bar_h), Color(0.02, 0.024, 0.065, 0.94))
	draw_line(Vector2(0.0, bar_h), Vector2(_screen.x, bar_h), Color(CYAN, 0.45), 1.5, true)
	draw_line(Vector2(0.0, bar_h + 1.5), Vector2(_screen.x, bar_h + 1.5), Color(GOLD, 0.20), 1.0, true)
	# Mini Millennium crest + Yu-Gi-Oh! brand badge on left
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
		# Top luminous accent bar
		var top_bar := Rect2(box_rect.position + Vector2(18.0, 2.0), Vector2(box_rect.size.x - 36.0, 2.5))
		draw_rect(top_bar, Color(accent, 0.35 + 0.60 * e))
		if _logos[i].texture != null:
			var tag: String = labels[i]
			var tw := _font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_string(_font, Vector2(box_rect.get_center().x - tw * 0.5, box_rect.end.y - 6.0),
					tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD_LIGHT if e > 0.5 else Color(CYAN_SOFT, 0.65))


func _draw_game_card(index: int) -> void:
	var rect := Rect2(_logos[index].position - SLOT / 2.0, SLOT)
	var color: Color = EDITION_ACCENTS[index]
	for outline: PackedVector2Array in _logo_contours(index):
		draw_colored_polygon(outline, color.darkened(0.84))
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, GOLD if index == _selected_index else Color(CYAN_SOFT, 0.55), 1.6, true)
	var title: String = ["YUGI", "KAIBA", "JOEY"][index]
	var subtitle: String = ["THE DESTINY", "THE REVENGE", "THE PASSION"][index]
	var reveal := _card_revealed(index)
	var lines := [[title, 27, -27]] if reveal else [[title, 34, -5], [subtitle, 14, 22]]
	for pair in lines:
		var width := _font.get_string_size(pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[1]).x
		draw_string(_font, Vector2(rect.get_center().x - width / 2, rect.get_center().y + pair[2]), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, pair[1], GOLD_LIGHT)


func _logo_contours(index: int) -> Array[PackedVector2Array]:
	var shape: Dictionary = LogoContours.DATA[Game.GAMES[index]]
	var dimensions: Vector2 = shape["size"]
	var fit := minf(SLOT.x / dimensions.x, SLOT.y / dimensions.y)
	var pulse := 1.0 + 0.03 * sin(_time * 3.0)
	fit *= lerpf(IDLE_SCALE, SELECTED_SCALE * pulse, _emphasis[index])
	var contours: Array[PackedVector2Array] = []
	for points: Array in shape["loops"]:
		var outline := PackedVector2Array()
		for point: Vector2 in points:
			outline.append(_logos[index].position + (point - dimensions / 2.0) * fit)
		contours.append(outline)
	return contours


func _import_center(index: int) -> Vector2:
	var largest := 0.0
	var center := _logos[index].position
	for contour: PackedVector2Array in _logo_contours(index):
		var cross_sum := 0.0
		var weighted := Vector2.ZERO
		for i in contour.size():
			var a := contour[i] - _logos[index].position
			var b := contour[(i + 1) % contour.size()] - _logos[index].position
			var cross := a.cross(b)
			cross_sum += cross
			weighted += (a + b) * cross
		if absf(cross_sum) > largest:
			largest = absf(cross_sum)
			center = _logos[index].position + weighted / (3.0 * cross_sum)
	return center


func _card_revealed(_index: int) -> bool:
	return false


## Titulo dorado con contorno, sombra, brillo que recorre las letras y filete decorativo.
func _draw_title() -> void:
	var title := _heading()
	var natural_width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var title_size := mini(TITLE_SIZE, int(700.0 * TITLE_SIZE / maxf(natural_width, 1.0)))
	var width := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var x := (_screen.x - width) / 2.0
	var title_y := _origin.y + heading_y
	var base := Vector2(x, title_y)
	var is_classic := LauncherSettings.bg_style == "classic"
	draw_string_outline(_font, base + Vector2(4, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
			10, Color(0, 0, 0, 0.65))
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 10, OUTLINE)
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, 4, Color(GOLD if is_classic else CYAN, 0.35))
	var shine := fmod(_time * 0.6, 1.6) - 0.3
	var has_rtl := false
	for ch in title:
		if ch.unicode_at(0) >= 0x0590:
			has_rtl = true
			break
	if has_rtl:
		var glow := clampf(1.0 - absf(0.5 - shine) * 3.0, 0.0, 1.0)
		draw_string(_font, Vector2(x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size,
				GOLD.lerp(GOLD_LIGHT, glow))
	else:
		var cx := x
		for ch in title:
			var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
			var t := (cx + w / 2.0 - x) / maxf(width, 1.0)
			var glow := clampf(1.0 - absf(t - shine) * 5.0, 0.0, 1.0)
			var ch_col := GOLD.lerp(GOLD_LIGHT, glow) if is_classic else GOLD.lerp(CYAN_SOFT, glow * 0.65).lerp(GOLD_LIGHT, glow * 0.35)
			draw_string(_font, Vector2(cx, title_y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, ch_col)
			cx += w
	# Filete: dos lineas que se desvanecen hacia fuera y un rombo en el centro.
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
		_choose(_selected_index)
	elif event is InputEventMouseMotion:
		var hit := _hit(event.position)
		if hit != -1:
			_selected_index = hit
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit != -1:
			_choose(hit)


func _move(step: int) -> void:
	_selected_index = wrapi(_selected_index + step, 0, _logos.size())


## Cada juego responde en toda su ranura, no solo sobre los pixeles del logo.
func _hit(screen_pos: Vector2) -> int:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_pos
	for i in _logos.size():
		for contour: PackedVector2Array in _logo_contours(i):
			if Geometry2D.is_point_in_polygon(local, contour):
				return i
	return -1


## Degradado radial con caida suave hasta cero (varias paradas) para evitar bandas visibles al escalar.
static func _radial(color: Color, alpha: float, size: Vector2i) -> GradientTexture2D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in 9:
		var t := i / 8.0
		offsets.append(t)
		colors.append(Color(color, alpha * pow(1.0 - t, 1.6)))
	gradient.offsets = offsets
	gradient.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size.x
	tex.height = size.y
	return tex
