extends AcceptDialog
## Ventana de sincronización en la nube (GitHub Gist privado y Google Drive):
## conectar, configurar credenciales, sincronizar partidas/duelos y resolver conflictos.

const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")
const GITHUB_TOKEN_URL := "https://github.com/settings/tokens/new?scopes=gist&description=PowerOfChaosSaveSync"

var _buttons: Array[Button] = []
var _copied_code := ""
var _tab := "github"
var _editing_google := false

var _box := VBoxContainer.new()
var _banner := PanelContainer.new()
var _banner_title := Label.new()
var _banner_sub := Label.new()
var _tabs_row := HBoxContainer.new()
var _tab_github := Button.new()
var _tab_google := Button.new()
var _info_card := PanelContainer.new()
var _info_label := Label.new()
var _github_row := HBoxContainer.new()
var _token_edit := LineEdit.new()
var _paste_btn := Button.new()
var _open_token_btn := Button.new()
var _google_box := VBoxContainer.new()
var _gd_id_edit := LineEdit.new()
var _gd_sec_edit := LineEdit.new()
var _status_label := Label.new()


func _ready() -> void:
	title = "Cloud Sync"
	min_size = Vector2i(540, 0)
	dialog_autowrap = true
	_build_controls()
	CloudSync.changed.connect(_refresh)
	custom_action.connect(_action)
	about_to_popup.connect(_on_about_to_popup)


func _build_controls() -> void:
	_box.add_theme_constant_override("separation", 12)

	var banner_style := StyleBoxFlat.new()
	banner_style.bg_color = Color(0.06, 0.10, 0.24, 0.96)
	banner_style.border_color = DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.5)
	banner_style.set_border_width_all(1)
	banner_style.set_corner_radius_all(10)
	banner_style.set_content_margin_all(12)
	_banner.add_theme_stylebox_override("panel", banner_style)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	_banner.add_child(bv)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_override("font", Assets.ui_font(700))
	_banner_title.add_theme_font_size_override("font_size", 17)
	_banner_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	bv.add_child(_banner_title)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_sub.add_theme_font_size_override("font_size", 12)
	_banner_sub.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	bv.add_child(_banner_sub)
	_box.add_child(_banner)

	_tabs_row.add_theme_constant_override("separation", 10)
	_tab_github.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_google.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_github.custom_minimum_size = Vector2(0, 38)
	_tab_google.custom_minimum_size = Vector2(0, 38)
	_tab_github.pressed.connect(func() -> void:
		_tab = "github"
		_editing_google = false
		_refresh())
	_tab_google.pressed.connect(func() -> void:
		_tab = "google"
		_refresh())
	_tabs_row.add_child(_tab_github)
	_tabs_row.add_child(_tab_google)
	_box.add_child(_tabs_row)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.055, 0.13, 0.94)
	card_style.border_color = Color(DialogTheme.CYAN, 0.35)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(12)
	_info_card.add_theme_stylebox_override("panel", card_style)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_info_card.add_child(_info_label)
	_box.add_child(_info_card)

	_github_row.add_theme_constant_override("separation", 8)
	_token_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_token_edit.secret = true
	_token_edit.placeholder_text = "ghp_... / github_pat_..."
	_token_edit.custom_minimum_size = Vector2(220, 38)
	_style_line_edit(_token_edit)
	_paste_btn.pressed.connect(func() -> void:
		var clip := DisplayServer.clipboard_get().strip_edges()
		if clip != "":
			_token_edit.text = clip)
	_open_token_btn.pressed.connect(func() -> void:
		OS.shell_open(GITHUB_TOKEN_URL))
	_github_row.add_child(_token_edit)
	_github_row.add_child(_paste_btn)
	_github_row.add_child(_open_token_btn)
	_box.add_child(_github_row)

	_google_box.add_theme_constant_override("separation", 8)
	_gd_id_edit.custom_minimum_size = Vector2(0, 36)
	_gd_sec_edit.custom_minimum_size = Vector2(0, 36)
	_gd_sec_edit.secret = true
	_style_line_edit(_gd_id_edit)
	_style_line_edit(_gd_sec_edit)
	_google_box.add_child(_gd_id_edit)
	_google_box.add_child(_gd_sec_edit)
	_box.add_child(_google_box)

	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
	_box.add_child(_status_label)

	add_child(_box)


func _style_line_edit(edit: LineEdit) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.028, 0.036, 0.092, 0.98)
	box.border_color = Color(DialogTheme.CYAN, 0.52)
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	edit.add_theme_stylebox_override("normal", box)
	var focus := box.duplicate() as StyleBoxFlat
	focus.border_color = DialogTheme.GOLD
	focus.set_border_width_all(2)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	edit.add_theme_color_override("font_placeholder_color", Color(0.62, 0.74, 0.90, 0.58))


func _on_about_to_popup() -> void:
	var cfg := CloudSync.google_config_values()
	if _gd_id_edit.text == "" and str(cfg.get("desktop_id", "")) != "":
		_gd_id_edit.text = str(cfg.get("desktop_id", ""))
	if _gd_sec_edit.text == "" and str(cfg.get("desktop_secret", "")) != "":
		_gd_sec_edit.text = str(cfg.get("desktop_secret", ""))
	_refresh()


func _tr(ar: String, es: String, en: String) -> String:
	if Assets.lang == "a":
		return ar
	return es if Assets.lang == "s" else en


func _refresh() -> void:
	for button in _buttons:
		remove_button(button)
		button.queue_free()
	_buttons.clear()
	var spanish := Assets.lang == "s"
	var arabic := Assets.lang == "a"
	title = _tr("التخزين السحابي", "Sincronización en la nube", "Cloud Sync")
	get_ok_button().text = _tr("إغلاق", "Cerrar", "Close")

	if not CloudSync.available():
		_box.visible = false
		dialog_text = _tr(
			"التخزين غير متاح للكتابة على هذا الجهاز.",
			"El almacenamiento no está disponible en este dispositivo.",
			"Storage is not writable on this device.")
		reset_size()
		return

	if CloudSync.state == "off":
		_show_setup_view()
		reset_size()
		return

	_box.visible = false
	var lines := PackedStringArray()
	match CloudSync.state:
		"linking":
			if CloudSync.browser_mode:
				lines.append(_tr(
					"تم فتح المتصفح على صفحة Google: اختر حسابك واسمح بالوصول. ستتحدّث هذه النافذة تلقائياً.",
					"Se abrió tu navegador con la página de Google: elige tu cuenta y permite el acceso. Esta ventana se actualizará sola.",
					"Your browser opened Google's page: choose your account and allow access. This window updates by itself."))
				if CloudSync.verification_url != "":
					_add(_tr("فتح مجدداً", "Abrir de nuevo", "Open again"), "open")
			elif CloudSync.user_code == "" and CloudSync.provider == "google":
				lines.append(_tr("جارٍ الاتصال بـ Google…", "Conectando con Google…", "Contacting Google…"))
			elif CloudSync.user_code == "":
				lines.append(_tr("جارٍ التحقق من حساب GitHub…", "Verificando cuenta de GitHub…", "Verifying GitHub account…"))
			else:
				if _copied_code != CloudSync.user_code:
					_copied_code = CloudSync.user_code
					DisplayServer.clipboard_set(CloudSync.user_code)
				lines.append_array(
					["1. افتح %s" % CloudSync.verification_url, "2. أدخل هذا الرمز (تم نسخه):",
					"        %s" % CloudSync.user_code, "3. اختر حسابك واسمح بالوصول. ستتحدّث هذه النافذة تلقائياً."] if arabic else (
					["1. Abre %s" % CloudSync.verification_url, "2. Escribe este código (ya copiado):",
					"        %s" % CloudSync.user_code, "3. Elige tu cuenta y permite el acceso. Esta ventana se actualizará sola."] if spanish
					else ["1. Open %s" % CloudSync.verification_url, "2. Enter this code (already copied):",
					"        %s" % CloudSync.user_code, "3. Choose your account and allow access. This window updates by itself."]))
				_add(_tr("فتح الصفحة", "Abrir página", "Open page"), "open")
			_add(_tr("إلغاء", "Cancelar", "Cancel"), "cancel")
		"conflict":
			lines.append(_tr(
				"تغيّر الحفظ على هذا الجهاز وفي السحابة بشكل منفصل. أيهما تريد الاحتفاظ به؟ تبقى النسخة الأخرى متاحة كنسخة احتياطية.",
				"Esta partida y la de la nube cambiaron por separado. ¿Cuál conservar? La descartada sigue disponible como respaldo.",
				"This save and the cloud save changed separately. Which one to keep? The other stays available as a backup."))
			lines.append("")
			lines.append(_describe(CloudSync.conflict.local, _tr("هذا الجهاز", "Este dispositivo", "This device"), spanish, arabic))
			lines.append(_describe(CloudSync.conflict.remote, _tr("السحابة", "Nube", "Cloud"), spanish, arabic))
			_add(_tr("استخدام حفظ السحابة", "Usar la de la nube", "Use cloud save"), "remote")
			_add(_tr("استخدام حفظ الجهاز", "Usar la de este dispositivo", "Use this device"), "local")
		_:
			var acct := CloudSync.account_label if CloudSync.account_label != "" else ("GitHub Gist" if CloudSync.provider == "github" else "Google Drive")
			var prov_line := _tr("الحساب: %s", "Cuenta: %s", "Account: %s") % acct
			match CloudSync.state:
				"syncing":
					lines.append(prov_line)
					lines.append(_tr("جارٍ المزامنة…", "Sincronizando…", "Syncing…"))
				"error":
					lines.append(prov_line)
					lines.append(_tr("خطأ: ", "Error: ", "Error: ") + CloudSync.detail)
				_:
					lines.append(prov_line)
					lines.append(_tr("متصل. آخر مزامنة: %s", "Conectado. Última sincronización: %s", "Connected. Last sync: %s")
							% (_date(CloudSync.last_sync) if CloudSync.last_sync > 0 else _tr("أبداً", "nunca", "never")))
					lines.append(_tr(
						"تتم مزامنة البطاقات والمجموعات والمباراة المحفوظة تلقائياً بين الهاتف والكمبيوتر.",
						"Tus cartas, barajas y duelo guardado se sincronizan automáticamente entre móvil y PC.",
						"Cards, decks and saved duels sync automatically between Phone and PC."))
					if CloudSync.detail != "":
						lines.append(CloudSync.detail)
			_add(_tr("مزامنة الآن", "Sincronizar ahora", "Sync now"), "sync")
			_add(_tr("فصل الحساب", "Desconectar", "Disconnect"), "unlink")
	dialog_text = "\n".join(lines)
	reset_size()


func _show_setup_view() -> void:
	dialog_text = ""
	_box.visible = true
	_banner_title.text = _tr("☁️ بوابة المزامنة السحابية للبطاقات والحفظ", "☁️ Sincronización en la Nube", "☁️ Cloud Save & Trunk Sync")
	_banner_sub.text = _tr(
		"احفظ أوراقك ومجموعاتك وتقدمك واربطها بين الهاتف والكمبيوتر بأمان تام",
		"Sincroniza tus cartas, mazos y progreso entre móvil y PC",
		"Keep your cards, decks, and duel progress synced across Phone & PC"
	)
	_tab_github.text = ("◆ " if _tab == "github" else "") + _tr("مزامنة سريعة (Gist خاص)", "Sincronización Rápida (Gist)", "Quick Sync (Private Gist)")
	_tab_google.text = ("◆ " if _tab == "google" else "") + "Google Drive"
	_paste_btn.text = _tr("📋 لصق", "📋 Pegar", "📋 Paste")
	_open_token_btn.text = _tr("🔑 استخراج الرمز", "🔑 Crear token", "🔑 Get Token")
	_gd_id_edit.placeholder_text = _tr("معرّف عميل Desktop (Client ID)", "Desktop Client ID", "Desktop Client ID")
	_gd_sec_edit.placeholder_text = _tr("الرمز السري للعميل (Client Secret)", "Desktop Client Secret", "Desktop Client Secret")

	if _tab == "github":
		_github_row.visible = true
		_google_box.visible = false
		_info_label.text = _tr(
			"مزامنة فورية للبطاقات والمجموعات والمباراة الجارية بين الهاتف والكمبيوتر عبر حسابك في GitHub (Gist خاص وسري):\n1. اضغط «إنشاء رمز» (صلاحية gist محددة تلقائياً) وانسخ الرمز.\n2. الصقه هنا واضغط «اتصال» — واستخدم نفس الرمز على الجهاز الآخر.",
			"Sincroniza cartas, barajas y duelos entre móvil y PC con un Gist privado de GitHub:\n1. Pulsa «Crear token» (permiso gist) y cópialo.\n2. Pégalo aquí y pulsa «Conectar» (usa el mismo token en el otro dispositivo).",
			"Sync cards, decks and in-progress duels between Phone and PC via a private GitHub Gist:\n1. Tap «Create Token» (gist scope) and copy it.\n2. Paste it here and tap «Connect» (use the same token on your other device).")
		_add(_tr("اتصال ومزامنة", "Conectar y sincronizar", "Connect & Sync"), "link_github")
	else:
		_github_row.visible = false
		if CloudSync.google_available() and not _editing_google:
			_google_box.visible = false
			_info_label.text = _tr(
				"قم بمزامنة البطاقات والمجموعات والمباراة الجارية بين الكمبيوتر وأندرويد عبر Google Drive. لا ترى اللعبة سوى الملفات التي تنشئها.",
				"Sincroniza cartas, barajas y resultados entre PC y Android con tu Google Drive. El juego solo puede ver los archivos que crea él mismo.",
				"Sync cards, decks and saved duels between PC and Android through your Google Drive. The game only sees files it creates.")
			_add(_tr("اتصال بـ Google Drive", "Conectar Google Drive", "Connect Google Drive"), "link")
			_add(_tr("تعديل المفاتيح", "Editar claves", "Edit OAuth Keys"), "edit_google")
		else:
			_google_box.visible = true
			_info_label.text = _tr(
				"يحتاج Google Drive إلى بيانات عميل OAuth (من نوع Desktop App في Google Cloud Console)؛ تُحفظ محلياً في cloud.cfg.\nملاحظة: خيار GitHub يعمل فوراً بدون هذه الخطوات.",
				"Google Drive requiere un cliente OAuth (Desktop App de Google Cloud Console); se guarda localmente en cloud.cfg.\nNota: la pestaña GitHub funciona sin configurar OAuth.",
				"Google Drive requires a Desktop OAuth Client ID and Secret (saved locally to cloud.cfg).\nTip: the GitHub tab works immediately without OAuth setup.")
			_add(_tr("حفظ بيانات Google", "Guardar claves Google", "Save Google Keys"), "save_google")
			if CloudSync.google_available():
				_add(_tr("رجوع", "Volver", "Back"), "cancel_edit_google")

	_status_label.visible = CloudSync.detail != ""
	_status_label.text = CloudSync.detail


func _add(text: String, action: String) -> void:
	_buttons.append(add_button(text, false, action))


func _action(action: StringName) -> void:
	match action:
		"link":
			CloudSync.link()
		"link_github":
			CloudSync.link_github(_token_edit.text)
		"edit_google":
			_editing_google = true
			_refresh()
		"cancel_edit_google":
			_editing_google = false
			_refresh()
		"save_google":
			var did := _gd_id_edit.text.strip_edges()
			var dsec := _gd_sec_edit.text.strip_edges()
			if did == "" or dsec == "":
				_status_label.visible = true
				_status_label.text = _tr("أدخل كلاً من Client ID و Client Secret.", "Introduce Client ID y Client Secret.", "Enter both Client ID and Client Secret.")
				reset_size()
				return
			if CloudSync.save_google_config(did, dsec):
				_editing_google = false
				CloudSync.detail = ""
			else:
				CloudSync.detail = _tr("تعذر حفظ الإعدادات.", "No se pudo guardar la configuración.", "Could not save configuration.")
			_refresh()
		"open":
			OS.shell_open(CloudSync.verification_url)
		"cancel":
			CloudSync.cancel_link()
		"sync":
			CloudSync.sync_now(true)
		"unlink":
			CloudSync.unlink()
		"local", "remote":
			CloudSync.resolve_conflict(action)


static func _describe(side: Dictionary, label: String, spanish: bool, arabic := false) -> String:
	var fmt := ("%s (%s, %s): %d بطاقة، %d مميزة، %d فوز، %d خسارة" if arabic else (
		"%s (%s, %s): %d cartas, %d distintas, %d victorias, %d derrotas" if spanish
		else "%s (%s, %s): %d cards, %d distinct, %d wins, %d losses"))
	return fmt % [label, side.device, _date(side.time), side.cards, side.distinct, side.wins, side.losses]


static func _date(unix: int) -> String:
	var local := unix + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_datetime_string_from_unix_time(local, true).left(16)
