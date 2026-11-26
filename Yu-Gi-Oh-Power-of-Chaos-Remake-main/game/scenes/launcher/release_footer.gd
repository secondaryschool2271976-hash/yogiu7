extends Control
## Small shared footer for the library and the import screen.
var _version := Label.new()
var _status := Label.new()
var _github := LinkButton.new()
var _licenses := LinkButton.new()
var _row := HBoxContainer.new()
var _dialog := ConfirmationDialog.new()
var _repo_dialog := ConfirmationDialog.new()
var _repo_input := LineEdit.new()
var _repo_error := Label.new()
var _review := VBoxContainer.new()
var _scroll := ScrollContainer.new()
var _notes := RichTextLabel.new()
var _update_message := Label.new()
var _change_history := LinkButton.new()
var _reviewed_release := ""
const HISTORY_LABELS := {
	"a": "سجل التغييرات",
	"s": "Historial de cambios", "e": "Changelog", "g": "Änderungsverlauf",
	"f": "Historique des modifications", "i": "Cronologia delle modifiche", "j": "変更履歴",
}
const Tips = preload("res://scenes/launcher/tooltip_texts.gd")
const DialogTheme = preload("res://scenes/launcher/dialog_theme.gd")


const TELEGRAM_URL := "https://t.me/games2creator"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 18)
	_version.hide()
	_row.add_child(_version)
	_row.add_child(_github)
	_row.add_child(_licenses)
	add_child(_row)
	add_child(_status)
	add_child(_dialog)
	DialogTheme.apply(_dialog)
	_setup_repo_dialog()
	for control in [_version, _status, _github, _licenses]:
		control.add_theme_font_override("font", Assets.ui_font(700))
		control.add_theme_font_size_override("font_size", 13)
		control.add_theme_color_override("font_color", Color(0.76, 0.86, 0.96))
	_github.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_github.pressed.connect(_on_github_pressed)
	_licenses.pressed.connect(_open_licenses)
	_setup_review()
	_dialog.confirmed.connect(_confirm)
	_dialog.canceled.connect(func() -> void:
		_reviewed_release = ""
		Updates.cancel())
	Updates.changed.connect(refresh)
	get_viewport().size_changed.connect(_layout)
	refresh()
	Updates.check_once()


func _setup_repo_dialog() -> void:
	add_child(_repo_dialog)
	DialogTheme.apply(_repo_dialog)
	_repo_dialog.dialog_hide_on_ok = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var hint_lbl := Label.new()
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(400, 0)
	hint_lbl.text = _tr(
		"أدخل رابط مستودعك على GitHub (مثال: https://github.com/username/repo):",
		"Introduce la URL de tu repositorio de GitHub (ej: https://github.com/usuario/repo):",
		"Enter your GitHub repository URL (e.g. https://github.com/username/repo):"
	)
	box.add_child(hint_lbl)
	_repo_input.placeholder_text = "https://github.com/username/repo"
	_repo_input.custom_minimum_size = Vector2(400, 38)
	_repo_input.add_theme_font_override("font", Assets.ui_font())
	box.add_child(_repo_input)
	_repo_error.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	_repo_error.hide()
	box.add_child(_repo_error)
	_repo_dialog.add_child(box)
	_repo_dialog.confirmed.connect(_save_repo_dialog)


func open_repo_editor() -> void:
	_repo_dialog.title = _tr("رابط مستودع GitHub", "Repositorio de GitHub", "GitHub Repository")
	_repo_dialog.get_ok_button().text = _tr("حفظ", "Guardar", "Save")
	_repo_dialog.get_cancel_button().text = _tr("إلغاء", "Cancelar", "Cancel")
	_repo_input.text = Updates.repository_url()
	_repo_error.hide()
	_repo_dialog.popup_centered(Vector2i(460, 210))
	_repo_input.grab_focus()


func _save_repo_dialog() -> void:
	var raw := _repo_input.text.strip_edges()
	if not Updates.set_repository_url(raw):
		_repo_error.text = _tr(
			"الرابط غير صالح. استخدم https://github.com/user/repo",
			"URL no válida. Usa https://github.com/usuario/repo",
			"Invalid URL. Use https://github.com/user/repo"
		)
		_repo_error.show()
		return
	_repo_dialog.hide()
	refresh()
	if Updates.repository_url() != "":
		Updates.check()


func _on_github_pressed() -> void:
	OS.shell_open(TELEGRAM_URL)


func _tr(ar: String, es: String, en: String) -> String:
	if Assets.lang == "a":
		return ar
	return es if Assets.lang == "s" else en


func _releases_url() -> String:
	var repo := Updates.repository_url()
	return (repo + "/releases") if repo != "" else TELEGRAM_URL


func hint() -> String:
	if Updates.repository_url() == "":
		return ""
	match Updates.state:
		"validating", "checking": return _tr("جارٍ البحث عن تحديثات…", "Buscando actualizaciones…", "Checking for updates…")
		"available": return _tr("متاح %s · اضغط للتحديث", "Disponible %s · Pulsa actualizar", "%s available · Press update") % Updates.available
		"current": return ""
		"downloading": return _tr("جارٍ التنزيل والتحقق…", "Descargando y verificando…", "Downloading and verifying…")
		"installing": return _tr("جارٍ التحديث…", "Actualizando…", "Installing update…")
		"ready": return _tr("تم تنزيل التحديث · اضغط للتثبيت", "Actualización descargada · Pulsa actualizar para instalar", "Update downloaded · Press update to install")
		"opened": return _tr("أكّد التثبيت في أندرويد", "Confirma la instalación en Android", "Confirm installation in Android")
		"manual": return _tr("تحديث بتوقيع مختلف: راجع التفاصيل", "Actualización con otra firma: consulta el aviso", "Different signing key: see details")
		"error": return _tr("تعذر التحقق أو إكمال التحديث", "No se pudo comprobar o completar la actualización", "Could not check or complete the update")
	return ""


func refresh() -> void:
	_version.text = ""
	_version.hide()
	_github.text = _tr("📢 قناة التليجرام · t.me/games2creator ↗", "📢 Canal de Telegram · t.me/games2creator ↗", "📢 Telegram Channel · t.me/games2creator ↗")
	_licenses.text = _tr("التراخيص", "Licencias", "Licenses")
	_github.tooltip_text = TELEGRAM_URL
	_licenses.tooltip_text = Tips.text("licenses", Assets.lang)
	_status.text = hint()
	_status.visible = _status.text != ""
	_status.tooltip_text = Updates.detail
	if _reviewed_release != "" and (Updates.state != "available" or Updates.available != _reviewed_release):
		_reviewed_release = ""
		_dialog.hide()
	_layout.call_deferred()


func _layout() -> void:
	if not is_inside_tree():
		return
	var screen := get_viewport_rect().size
	_row.size = _row.get_combined_minimum_size()
	_row.position = Vector2((screen.x - _row.size.x) / 2.0, screen.y - 50)
	_status.size = _status.get_minimum_size()
	_status.position = Vector2((screen.x - _status.size.x) / 2.0, screen.y - 28)


func open_update() -> void:
	var rel_url := _releases_url()
	if rel_url == "":
		open_repo_editor()
		return
	if not Updates.supported():
		OS.shell_open(rel_url)
		return
	if Paths.android_platform() and Updates.state in ["ready", "opened"]:
		Updates.download()
		return
	if Updates.state != "available":
		Updates.check()
		return
	_show_release()


func _setup_review() -> void:
	_dialog.wrap_controls = false
	_dialog.dialog_autowrap = true
	_dialog.dialog_hide_on_ok = false
	_dialog.add_child(_review)
	_review.add_theme_constant_override("separation", 14)
	_review.hide()
	_review.add_child(_scroll)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_child(_notes)
	_notes.fit_content = true
	_notes.scroll_active = false
	_notes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes.add_theme_color_override("default_color", DialogTheme.GOLD_LIGHT)
	_notes.add_theme_constant_override("line_separation", 5)
	_change_history.uri = _releases_url()
	_change_history.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_change_history.custom_minimum_size.y = 32
	_change_history.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_review.add_child(_change_history)
	_review.add_child(_update_message)


func _show_release() -> void:
	_reviewed_release = Updates.available
	_change_history.uri = _releases_url()
	_change_history.text = HISTORY_LABELS.get(Assets.lang, HISTORY_LABELS["e"])
	_dialog.title = _tr("التحديث إلى %s", "Actualizar a %s", "Update to %s") % _reviewed_release
	_dialog.dialog_text = ""
	_dialog.get_ok_button().text = _tr("تحديث", "Actualizar", "Update")
	_dialog.get_ok_button().show()
	_dialog.get_cancel_button().text = _tr("إلغاء", "Cancelar", "Cancel")
	_update_message.text = _tr("سيطلب منك أندرويد تأكيد التثبيت.", "Android te pedirá confirmar la instalación.", "Android will ask you to confirm installation.") if Paths.android_platform() else (
		_tr("سيتم إعادة تشغيل اللعبة لتثبيت التحديث.", "El juego se reiniciará al instalar la actualización.", "The game will restart to install the update."))
	var notes: String = Updates.release_notes
	_fill_notes(notes if not notes.is_empty() else _tr("لم ينشر GitHub ملاحظات لهذا الإصدار.", "GitHub no publicó notas para esta versión.", "GitHub did not publish notes for this release."))
	_review.show()
	_dialog.popup_centered_clamped(Vector2i(680, 460), 0.80)
	_scroll.scroll_vertical = 0


func _fill_notes(notes: String) -> void:
	_notes.clear()
	var bold := RegEx.create_from_string("\\*\\*([^*]+)\\*\\*")
	for line: String in notes.replace("\r\n", "\n").split("\n"):
		var heading := line.begins_with("#") and line.lstrip("#").begins_with(" ")
		if heading:
			line = line.lstrip("#").strip_edges()
			_notes.push_color(DialogTheme.GOLD)
			_notes.push_bold()
		elif line.begins_with("- ") or line.begins_with("* "):
			line = "• " + line.substr(2)
		var end := 0
		for span in bold.search_all(line):
			_notes.add_text(line.substr(end, span.get_start() - end))
			_notes.push_bold()
			_notes.add_text(span.get_string(1))
			_notes.pop()
			end = span.get_end()
		_notes.add_text(line.substr(end) + "\n")
		if heading:
			_notes.pop()
			_notes.pop()


func _confirm() -> void:
	if _reviewed_release.is_empty() or Updates.state != "available" or Updates.available != _reviewed_release:
		return
	_reviewed_release = ""
	Updates.download()
	if Updates.state != "downloading":
		_dialog.hide()
		return
	_review.hide()
	_dialog.get_ok_button().hide()
	_dialog.dialog_text = hint()
	var previous_size := _dialog.size
	_dialog.size = Vector2i(490, 132)
	_dialog.position += (previous_size - _dialog.size) / 2
	_dialog.get_cancel_button().grab_focus()


func _process(_delta: float) -> void:
	if Updates.state == "downloading":
		var mb: float = Updates._http.get_downloaded_bytes() / 1048576.0
		var fraction: float = Updates.progress()
		_dialog.dialog_text = hint() + (" (%d %%, %.1f MB)" % [roundi(fraction * 100.0), mb] if fraction >= 0.0 else " (%.1f MB)" % mb)
	elif _dialog.visible and not _dialog.get_ok_button().visible:
		_dialog.hide()


func _open_licenses() -> void:
	var directory := "" if Paths.android_platform() else BundledTools.prepare(true)
	var repo := Updates.repository_url()
	if directory != "":
		OS.shell_open(directory)
	elif repo != "":
		OS.shell_open(repo + "/blob/main/THIRD_PARTY_NOTICES.md")
	else:
		OS.shell_open(TELEGRAM_URL)
