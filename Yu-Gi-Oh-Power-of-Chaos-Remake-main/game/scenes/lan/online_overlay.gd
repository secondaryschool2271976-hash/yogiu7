extends CanvasLayer
## Overlay de duelo Online (servidor WebSocket en Render) e IP directa Wi-Fi para lan_connect.gd.

signal match_ready

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")

var _game_id := "joey"
var _name_input: LineEdit
var _url_input: LineEdit
var _code_input: LineEdit
var _ip_input: LineEdit
var _host_btn: Button
var _join_btn: Button
var _ip_btn: Button
var _copy_btn: Button
var _cancel_btn: Button
var _close_btn: Button
var _code_box: PanelContainer
var _code_label: Label
var _status_label: Label

var _trigger_btn := Button.new()
var _trigger_pressed := false
var _trigger_normal: StyleBoxFlat
var _trigger_hover: StyleBoxFlat
var _trigger_press: StyleBoxFlat

var _backdrop := ColorRect.new()
var _panel := PanelContainer.new()
var _modal_open := false
var _waiting := false
var _waiting_kind := ""
var _sync_name_cb: Callable


func setup(game_id: String, initial_name: String, sync_name_cb: Callable) -> void:
	_game_id = game_id
	_sync_name_cb = sync_name_cb
	if _name_input != null:
		_name_input.text = initial_name


func _t(key: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match key:
			"trigger": return "أونلاين / IP"
			"title": return "مبارزة أونلاين (سيرفر Render) و IP مباشر"
			"name_lbl": return "اسم اللاعب"
			"url_lbl": return "رابط السيرفر (Render)"
			"url_hint": return "https://your-relay.onrender.com"
			"host_btn": return "إنشاء غرفة أونلاين"
			"code_hint": return "كود الغرفة (6 أرقام)"
			"join_btn": return "دخول بالكود"
			"ip_lbl": return "اتصال Wi-Fi مباشر بالـ IP (اختياري)"
			"ip_hint": return "192.168.1.5"
			"ip_btn": return "اتصال IP"
			"copy_btn": return "نسخ الكود"
			"copied": return "تم نسخ كود الغرفة: %s"
			"close_btn": return "إغلاق"
			"cancel_btn": return "إلغاء الانتظار"
			"err_name": return "اكتب اسم اللاعب أولاً."
			"err_url": return "اكتب رابط سيرفر Render أولاً."
			"err_code": return "اكتب كود الغرفة المكون من 6 أرقام."
			"err_ip": return "اكتب عنوان IP المضيف (مثال: 192.168.1.5)."
			"connecting": return "جاري الاتصال بالسيرفر... (لو السيرفر في وضع السكون على Render قد يستغرق 30 ثانية أول مرة)"
			"waiting_guest": return "الغرفة جاهزة! ابعت الكود لصديقك وفي انتظار دخوله..."
			"joining_room": return "جاري الدخول للغرفة %s..."
			"joining_ip": return "جاري الاتصال المباشر بـ %s..."
			"matched": return "تم الاتصال بالمنافس! جاري بدء المبارزة..."
			"err_not_found": return "كود الغرفة غير موجود أو تم إغلاقه."
			"err_room_full": return "الغرفة ممتلئة بالفعل."
			"err_game_mismatch": return "اللاعب الآخر يستخدم إصدار لعبة مختلف."
			"err_timeout": return "انتهت مهلة الاتصال بالسيرفر. حاول مرة أخرى."
			"err_expired": return "انتهت مدة انتظار الغرفة."
			"err_connect": return "تعذر الاتصال بالسيرفر. تأكد من الرابط ومن الإنترنت."
			"err_ip_fail": return "تعذر الاتصال بعنوان الـ IP. تأكد أن المضيف فتح غرفة Wi-Fi على نفس الشبكة."
		return ""
	if lang == "s":
		match key:
			"trigger": return "Online / IP"
			"title": return "Duelo Online (Render) e IP directa"
			"name_lbl": return "Nombre del jugador"
			"url_lbl": return "URL del servidor (Render)"
			"url_hint": return "https://your-relay.onrender.com"
			"host_btn": return "Crear sala Online"
			"code_hint": return "Código de sala (6 dígitos)"
			"join_btn": return "Unirse"
			"ip_lbl": return "Conexión Wi-Fi directa por IP (opcional)"
			"ip_hint": return "192.168.1.5"
			"ip_btn": return "Conectar IP"
			"copy_btn": return "Copiar"
			"copied": return "Código copiado: %s"
			"close_btn": return "Cerrar"
			"cancel_btn": return "Cancelar espera"
			"err_name": return "Escribe tu nombre primero."
			"err_url": return "Escribe la URL del servidor Render."
			"err_code": return "Escribe el código de sala de 6 dígitos."
			"err_ip": return "Escribe la IP del anfitrión (ej. 192.168.1.5)."
			"connecting": return "Conectando al servidor... (si Render estaba dormido puede tardar ~30s)"
			"waiting_guest": return "¡Sala lista! Comparte el código y espera a tu rival..."
			"joining_room": return "Uniéndose a la sala %s..."
			"joining_ip": return "Conectando por IP a %s..."
			"matched": return "¡Rival conectado! Iniciando duelo..."
			"err_not_found": return "No se encontró esa sala."
			"err_room_full": return "La sala ya está llena."
			"err_game_mismatch": return "El rival está usando otro juego."
			"err_timeout": return "Tiempo de espera agotado al conectar."
			"err_expired": return "La sala expiró por inactividad."
			"err_connect": return "No se pudo conectar al servidor. Revisa la URL e Internet."
			"err_ip_fail": return "No se pudo conectar a esa IP. Comprueba la red Wi-Fi."
		return ""
	match key:
		"trigger": return "Online / IP"
		"title": return "Online Duel (Render) & Direct IP"
		"name_lbl": return "Player Name"
		"url_lbl": return "Relay Server URL (Render)"
		"url_hint": return "https://your-relay.onrender.com"
		"host_btn": return "Create Online Room"
		"code_hint": return "Room Code (6 digits)"
		"join_btn": return "Join Code"
		"ip_lbl": return "Direct Wi-Fi IP (Optional Fallback)"
		"ip_hint": return "192.168.1.5"
		"ip_btn": return "Join IP"
		"copy_btn": return "Copy Code"
		"copied": return "Copied room code: %s"
		"close_btn": return "Close"
		"cancel_btn": return "Cancel Wait"
		"err_name": return "Enter a player name first."
		"err_url": return "Enter your Render server URL first."
		"err_code": return "Enter the 6-digit room code."
		"err_ip": return "Enter the host IP address (e.g. 192.168.1.5)."
		"connecting": return "Connecting to server... (Render free tier may take ~30s to wake up)"
		"waiting_guest": return "Room ready! Share this code with your friend..."
		"joining_room": return "Joining room %s..."
		"joining_ip": return "Connecting directly to %s..."
		"matched": return "Opponent connected! Starting duel..."
		"err_not_found": return "Room code not found or already closed."
		"err_room_full": return "That room is already full."
		"err_game_mismatch": return "Host is running a different game."
		"err_timeout": return "Connection timed out. Please try again."
		"err_expired": return "Room expired while waiting."
		"err_connect": return "Could not reach server. Check the URL and Internet."
		"err_ip_fail": return "Could not connect to that IP. Ensure host is on the same Wi-Fi."
	return ""


func _make_style(bg: Color, border: Color, radius := 8, border_w := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_w)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _make_input_style(focused: bool) -> StyleBoxFlat:
	var box := _make_style(Color(0.04, 0.03, 0.05, 0.98), DialogTheme.GOLD if focused else Color(DialogTheme.GOLD, 0.42), 6, 2 if focused else 1)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func _style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_stylebox_override("normal", _make_input_style(false))
	edit.add_theme_stylebox_override("focus", _make_input_style(true))
	edit.add_theme_stylebox_override("read_only", _make_input_style(false))
	edit.add_theme_color_override("font_color", Color(1.0, 0.96, 0.85))
	edit.add_theme_color_override("font_placeholder_color", Color(0.75, 0.68, 0.55, 0.55))
	edit.add_theme_color_override("caret_color", DialogTheme.GOLD)
	edit.add_theme_font_override("font", Assets.ui_font())
	edit.add_theme_font_size_override("font_size", 15)


func _ready() -> void:
	layer = 96
	var mobile: bool = OS.has_feature("mobile") or Paths.cmdline_value("mobile-controls") == "true"

	_trigger_btn.focus_mode = Control.FOCUS_NONE
	_trigger_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trigger_btn.size = Vector2(150, 42) if mobile else Vector2(138, 34)
	_trigger_btn.text = _t("trigger")
	_trigger_btn.add_theme_font_override("font", Assets.ui_font(700))
	_trigger_btn.add_theme_font_size_override("font_size", 15 if mobile else 14)
	_trigger_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_trigger_normal = _make_style(Color(0.11, 0.07, 0.16, 0.94), Color(0.95, 0.78, 0.34, 0.95))
	_trigger_hover = _make_style(Color(0.18, 0.12, 0.25, 0.98), Color(1.0, 0.88, 0.48, 1.0))
	_trigger_press = _make_style(Color(0.08, 0.05, 0.12, 0.98), Color(1.0, 0.90, 0.54, 1.0))
	_trigger_btn.add_theme_stylebox_override("normal", _trigger_normal)
	_trigger_btn.add_theme_stylebox_override("hover", _trigger_hover)
	_trigger_btn.add_theme_stylebox_override("pressed", _trigger_press)
	add_child(_trigger_btn)

	_backdrop.color = Color(0.02, 0.01, 0.03, 0.80)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.hide()
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(center)

	_panel.theme = DialogTheme.theme()
	var panel_style := _make_style(DialogTheme.BACKGROUND, DialogTheme.GOLD.darkened(0.12), 12, 2)
	panel_style.set_content_margin_all(16)
	panel_style.shadow_color = Color(0, 0, 0, 0.7)
	panel_style.shadow_size = 18
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(_panel)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	_panel.add_child(root_box)

	var header := HBoxContainer.new()
	root_box.add_child(header)
	var title := Label.new()
	title.text = _t("title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", Assets.ui_font(700))
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", DialogTheme.GOLD)
	header.add_child(title)
	_close_btn = Button.new()
	_close_btn.text = "✕"
	_close_btn.custom_minimum_size = Vector2(36, 32)
	_close_btn.pressed.connect(close_modal)
	header.add_child(_close_btn)

	var lan_cfg: Dictionary = SaveData.data.get("lan", {}) if SaveData.data.get("lan") is Dictionary else {}
	var saved_url: String = str(lan_cfg.get("relay_url", "")).strip_edges()
	if saved_url == "":
		saved_url = Online.server_url if is_instance_valid(Online) and Online.server_url != "" else Lan.default_relay_url()
	var saved_name: String = str(lan_cfg.get("name", "")).strip_edges()
	if saved_name == "" and is_instance_valid(Online) and Online.display_name != "":
		saved_name = Online.display_name

	var top_grid := GridContainer.new()
	top_grid.columns = 2
	top_grid.add_theme_constant_override("h_separation", 10)
	top_grid.add_theme_constant_override("v_separation", 6)
	root_box.add_child(top_grid)

	var name_lbl := Label.new()
	name_lbl.text = _t("name_lbl")
	name_lbl.add_theme_font_size_override("font_size", 14)
	top_grid.add_child(name_lbl)

	var url_lbl := Label.new()
	url_lbl.text = _t("url_lbl")
	url_lbl.add_theme_font_size_override("font_size", 14)
	top_grid.add_child(url_lbl)

	_name_input = LineEdit.new()
	_name_input.max_length = 20
	_name_input.custom_minimum_size = Vector2(180, 36)
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.text = saved_name
	_style_line_edit(_name_input)
	top_grid.add_child(_name_input)

	_url_input = LineEdit.new()
	_url_input.custom_minimum_size = Vector2(320, 36)
	_url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_url_input.placeholder_text = _t("url_hint")
	_url_input.text = saved_url
	_url_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_style_line_edit(_url_input)
	top_grid.add_child(_url_input)

	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	root_box.add_child(actions_row)

	_host_btn = Button.new()
	_host_btn.text = _t("host_btn")
	_host_btn.custom_minimum_size = Vector2(180, 40)
	_host_btn.pressed.connect(_on_host_online)
	actions_row.add_child(_host_btn)

	_code_input = LineEdit.new()
	_code_input.max_length = 12
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.custom_minimum_size = Vector2(140, 40)
	_code_input.placeholder_text = _t("code_hint")
	_code_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_code_input.text_submitted.connect(func(_s: String) -> void: _on_join_online())
	_style_line_edit(_code_input)
	actions_row.add_child(_code_input)

	_join_btn = Button.new()
	_join_btn.text = _t("join_btn")
	_join_btn.custom_minimum_size = Vector2(120, 40)
	_join_btn.pressed.connect(_on_join_online)
	actions_row.add_child(_join_btn)

	_code_box = PanelContainer.new()
	var code_style := _make_style(Color(0.14, 0.10, 0.04, 0.95), DialogTheme.GOLD, 8, 2)
	code_style.set_content_margin_all(10)
	_code_box.add_theme_stylebox_override("panel", code_style)
	_code_box.hide()
	root_box.add_child(_code_box)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 10)
	_code_box.add_child(code_row)

	_code_label = Label.new()
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_override("font", Assets.ui_font(700))
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.45))
	code_row.add_child(_code_label)

	_copy_btn = Button.new()
	_copy_btn.text = _t("copy_btn")
	_copy_btn.custom_minimum_size = Vector2(110, 38)
	_copy_btn.pressed.connect(_on_copy_code)
	code_row.add_child(_copy_btn)

	var sep := HSeparator.new()
	root_box.add_child(sep)

	var ip_lbl := Label.new()
	ip_lbl.text = _t("ip_lbl")
	ip_lbl.add_theme_font_size_override("font_size", 13)
	ip_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.65))
	root_box.add_child(ip_lbl)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	root_box.add_child(ip_row)

	_ip_input = LineEdit.new()
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ip_input.custom_minimum_size = Vector2(260, 36)
	_ip_input.placeholder_text = _t("ip_hint")
	_ip_input.text = str(lan_cfg.get("last_ip", ""))
	_ip_input.text_submitted.connect(func(_s: String) -> void: _on_join_ip())
	_style_line_edit(_ip_input)
	ip_row.add_child(_ip_input)

	_ip_btn = Button.new()
	_ip_btn.text = _t("ip_btn")
	_ip_btn.custom_minimum_size = Vector2(126, 36)
	_ip_btn.pressed.connect(_on_join_ip)
	ip_row.add_child(_ip_btn)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0, 36)
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	root_box.add_child(_status_label)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root_box.add_child(footer)

	_cancel_btn = Button.new()
	_cancel_btn.text = _t("close_btn")
	_cancel_btn.custom_minimum_size = Vector2(130, 38)
	_cancel_btn.pressed.connect(_on_cancel_or_close)
	footer.add_child(_cancel_btn)

	if not Lan.room_code_ready.is_connected(_on_room_code_ready):
		Lan.room_code_ready.connect(_on_room_code_ready)


func _exit_tree() -> void:
	if Lan.room_code_ready.is_connected(_on_room_code_ready):
		Lan.room_code_ready.disconnect(_on_room_code_ready)


func is_modal_open() -> bool:
	return _modal_open


func button_visible() -> bool:
	return not _modal_open and _trigger_btn.visible


func button_rect() -> Rect2:
	return _trigger_btn.get_global_rect()


func open_modal(current_name := "") -> void:
	if _modal_open:
		return
	if current_name.strip_edges() != "":
		_name_input.text = current_name.strip_edges()
	_modal_open = true
	_trigger_pressed = false
	_trigger_btn.hide()
	_backdrop.show()
	_set_busy(false)
	_code_box.hide()
	_set_status("", DialogTheme.GOLD_LIGHT)


func close_modal() -> void:
	if not _modal_open:
		return
	if _waiting:
		_waiting = false
		_waiting_kind = ""
		Lan.close()
	_modal_open = false
	_backdrop.hide()
	_set_busy(false)
	_code_box.hide()


func _on_cancel_or_close() -> void:
	if _waiting:
		_waiting = false
		_waiting_kind = ""
		Lan.close()
		_set_busy(false)
		_code_box.hide()
		_set_status("", DialogTheme.GOLD_LIGHT)
		return
	close_modal()


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _set_busy(busy: bool) -> void:
	_name_input.editable = not busy
	_url_input.editable = not busy
	_code_input.editable = not busy
	_ip_input.editable = not busy
	_host_btn.disabled = busy
	_join_btn.disabled = busy
	_ip_btn.disabled = busy
	_cancel_btn.text = _t("cancel_btn") if busy else _t("close_btn")


func _save_prefs(player_name: String, relay_url: String, last_ip := "") -> void:
	var lan_cfg: Dictionary = SaveData.data.get("lan", {}) if SaveData.data.get("lan") is Dictionary else {}
	if player_name != "":
		lan_cfg["name"] = player_name
	if relay_url != "":
		lan_cfg["relay_url"] = relay_url
	if last_ip != "":
		lan_cfg["last_ip"] = last_ip
	SaveData.data["lan"] = lan_cfg
	SaveData.save()
	if _sync_name_cb.is_valid() and player_name != "":
		_sync_name_cb.call(player_name)


func _on_host_online() -> void:
	var player_name: String = _name_input.text.strip_edges()
	var relay_url: String = _url_input.text.strip_edges()
	if player_name == "":
		_set_status(_t("err_name"), Color(1.0, 0.55, 0.45))
		return
	if relay_url == "":
		_set_status(_t("err_url"), Color(1.0, 0.55, 0.45))
		return
	_save_prefs(player_name, relay_url)
	_code_box.hide()
	var err: int = Lan.host_online(relay_url, player_name, _game_id)
	if err != OK:
		_set_status(_t("err_connect"), Color(1.0, 0.55, 0.45))
		return
	_waiting = true
	_waiting_kind = "online_host"
	_set_busy(true)
	_set_status(_t("connecting"), DialogTheme.GOLD_LIGHT)


func _on_join_online() -> void:
	var player_name: String = _name_input.text.strip_edges()
	var relay_url: String = _url_input.text.strip_edges()
	var code: String = Lan.normalize_room_code(_code_input.text)
	if player_name == "":
		_set_status(_t("err_name"), Color(1.0, 0.55, 0.45))
		return
	if relay_url == "":
		_set_status(_t("err_url"), Color(1.0, 0.55, 0.45))
		return
	if code == "":
		_set_status(_t("err_code"), Color(1.0, 0.55, 0.45))
		return
	_code_input.text = code
	_save_prefs(player_name, relay_url)
	_code_box.hide()
	var err: int = Lan.join_online(relay_url, code, player_name, _game_id)
	if err != OK:
		_set_status(_t("err_connect"), Color(1.0, 0.55, 0.45))
		return
	_waiting = true
	_waiting_kind = "online_join"
	_set_busy(true)
	_set_status(_t("joining_room") % code, DialogTheme.GOLD_LIGHT)


func _on_join_ip() -> void:
	var player_name: String = _name_input.text.strip_edges()
	var raw_ip: String = _ip_input.text.strip_edges()
	if player_name == "":
		_set_status(_t("err_name"), Color(1.0, 0.55, 0.45))
		return
	if raw_ip == "":
		_set_status(_t("err_ip"), Color(1.0, 0.55, 0.45))
		return
	var host_addr: String = raw_ip
	var port: int = Lan.GAME_PORT
	if raw_ip.contains(":"):
		var parts: PackedStringArray = raw_ip.split(":")
		if parts.size() == 2 and parts[1].is_valid_int():
			host_addr = parts[0].strip_edges()
			port = int(parts[1])
	_save_prefs(player_name, _url_input.text.strip_edges(), raw_ip)
	Lan.local_name = player_name
	Lan.game = _game_id
	_code_box.hide()
	var err: int = Lan.join(host_addr, port)
	if err != OK:
		_set_status(_t("err_ip_fail"), Color(1.0, 0.55, 0.45))
		return
	_waiting = true
	_waiting_kind = "direct_ip"
	_set_busy(true)
	_set_status(_t("joining_ip") % host_addr, DialogTheme.GOLD_LIGHT)


func _on_room_code_ready(code: String) -> void:
	if not _waiting or _waiting_kind != "online_host":
		return
	_code_label.text = code
	_code_box.show()
	_set_status(_t("waiting_guest"), Color(0.65, 0.95, 0.65))


func _on_copy_code() -> void:
	var code: String = _code_label.text.strip_edges()
	if code == "":
		return
	DisplayServer.clipboard_set(code)
	_set_status(_t("copied") % code, Color(0.65, 0.95, 0.65))


func _error_message(code: String) -> String:
	if _waiting_kind == "direct_ip":
		return _t("err_ip_fail")
	match code:
		"not_found": return _t("err_not_found")
		"room_full": return _t("err_room_full")
		"game_mismatch": return _t("err_game_mismatch")
		"timeout": return _t("err_timeout")
		"expired": return _t("err_expired")
		_: return _t("err_connect")


func _process(_delta: float) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect()
	_trigger_btn.position = Vector2(bounds.end.x - _trigger_btn.size.x - 10.0, bounds.position.y + 8.0)
	var show_trigger: bool = not _modal_open and not Game.has_active_root_dialog()
	_trigger_btn.visible = show_trigger
	if not _waiting:
		return
	if Lan.players() == 2:
		_waiting = false
		_waiting_kind = ""
		_set_status(_t("matched"), Color(0.65, 0.95, 0.65))
		_modal_open = false
		_backdrop.hide()
		_trigger_btn.hide()
		match_ready.emit()
		return
	if Lan.terminated:
		var msg: String = _error_message(Lan.status_error)
		_waiting = false
		_waiting_kind = ""
		_set_busy(false)
		_code_box.hide()
		_set_status(msg, Color(1.0, 0.55, 0.45))


func _input(event: InputEvent) -> void:
	if _modal_open:
		if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_cancel_or_close()
		return
	if not _trigger_btn.visible or bool(event.get_meta("platform_touch", false)):
		return
	if event is InputEventMouseMotion:
		var over: bool = _trigger_btn.get_global_rect().has_point(event.position)
		_trigger_btn.add_theme_stylebox_override("normal", _trigger_press if _trigger_pressed else (_trigger_hover if over else _trigger_normal))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var over: bool = _trigger_btn.get_global_rect().has_point(event.position)
		if event.pressed:
			if over:
				_trigger_pressed = true
				_trigger_btn.add_theme_stylebox_override("normal", _trigger_press)
				get_viewport().set_input_as_handled()
		elif _trigger_pressed:
			_trigger_pressed = false
			_trigger_btn.add_theme_stylebox_override("normal", _trigger_hover if over else _trigger_normal)
			get_viewport().set_input_as_handled()
			if _trigger_btn.get_global_rect().grow(4.0).has_point(event.position):
				open_modal()
