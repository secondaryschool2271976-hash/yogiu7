extends Node
## Actualizador de la plataforma, con la misma API en PC y Android. Windows descarga y aplica
## el ejecutable publicado (core/updates_desktop.gd); Android valida el APK publicado y delega
## su instalación en el sistema (core/updates_android.gd).
signal changed

const _FORWARDED := [&"current", &"available", &"release_notes", &"state", &"detail", &"_http"]

var REPOSITORY: String:
	get:
		return repository_url()

# Por el script y no por el autoload: las pruebas pueden compilar este archivo antes.
var impl: Node = load("res://core/updates_android.gd" if preload("res://autoload/paths.gd").android_platform()
		else "res://core/updates_desktop.gd").new()


func _ready() -> void:
	impl.name = "Implementation"
	impl.changed.connect(changed.emit)
	add_child(impl)


func _get(property: StringName) -> Variant:
	return impl.get(property) if property in _FORWARDED else null


static func normalize_repository(raw: String) -> String:
	var s := raw.strip_edges()
	if s.is_empty():
		return ""
	if s.begins_with("http://github.com/"):
		s = "https://" + s.substr(7)
	elif not s.begins_with("https://"):
		if s.contains("://"):
			return ""
		s = "https://github.com/" + s.trim_prefix("/")
	if not s.begins_with("https://github.com/"):
		return ""
	var rest := s.substr(19).trim_suffix("/")
	if rest.ends_with(".git"):
		rest = rest.substr(0, rest.length() - 4)
	var parts := rest.split("/", false)
	if parts.size() < 2:
		return ""
	var owner := parts[0]
	var repo := parts[1]
	var re := RegEx.create_from_string("^[A-Za-z0-9_.-]+$")
	if re.search(owner) == null or re.search(repo) == null:
		return ""
	return "https://github.com/%s/%s" % [owner, repo]


static func repository_url() -> String:
	var paths_node := preload("res://autoload/paths.gd")
	var cfg := ConfigFile.new()
	var settings_file := ""
	if Engine.get_main_loop() is SceneTree:
		var root := (Engine.get_main_loop() as SceneTree).root
		if root != null and root.has_node("Paths"):
			settings_file = str(root.get_node("Paths").call("settings_path"))
	if settings_file != "" and cfg.load(settings_file) == OK:
		var saved := normalize_repository(str(cfg.get_value("launcher", "github_repository", "")))
		if saved != "":
			return saved
	return normalize_repository(str(ProjectSettings.get_setting("application/config/github_repository", "")))


static func api_url(repo := "") -> String:
	var target := normalize_repository(repo) if repo != "" else repository_url()
	if target == "":
		return ""
	return "https://api.github.com/repos/%s/releases?per_page=100" % target.substr(19)


static func set_repository_url(raw: String) -> bool:
	var normalized := normalize_repository(raw)
	if raw.strip_edges() != "" and normalized == "":
		return false
	if Engine.get_main_loop() is SceneTree:
		var root := (Engine.get_main_loop() as SceneTree).root
		if root != null and root.has_node("Paths"):
			var settings_file := str(root.get_node("Paths").call("settings_path"))
			var cfg := ConfigFile.new()
			cfg.load(settings_file)
			cfg.set_value("launcher", "github_repository", normalized)
			cfg.save(settings_file)
		if root != null and root.has_node("Updates"):
			var upd := root.get_node("Updates")
			upd.changed.emit()
	return true


func supported() -> bool:
	return impl.supported()


func check_once() -> void:
	impl.check_once()


func check() -> void:
	impl.check()


func download() -> void:
	impl.download()


func cancel() -> void:
	impl.cancel()


## Fracción descargada (0..1) o -1 si la plataforma o el servidor no la informan.
func progress() -> float:
	return impl.progress() if impl.has_method("progress") else -1.0
