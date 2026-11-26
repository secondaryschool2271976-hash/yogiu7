extends Node2D
## Ilustracion exterior al viewport nativo: el duelo conserva800x600 e input local.
const BACKGROUNDS := {
	"kaiba": "res://assets/backgrounds/kaiba_duel.png",
	"yugi": "res://assets/backgrounds/yugi_duel.jpg",
	"joey": "res://assets/backgrounds/joey_duel.png",
}
var _duel: Node
var _backdrop := ColorRect.new()
var _background := TextureRect.new()
var _shade := ColorRect.new()
var _shade_material := ShaderMaterial.new()
var _container := SubViewportContainer.new()
var _viewport := SubViewport.new()
var _window: Window

func _init(duel: Node) -> void:
	_duel = duel

func _ready() -> void:
	_window = get_tree().root
	_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	_backdrop.color = Color(0.03, 0.03, 0.06)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	var duel_game := str(_duel.get("game")) if _duel != null else ""
	var custom_bg := LauncherSettings.bg_texture_path() if is_instance_valid(LauncherSettings) else ""
	var path: String = custom_bg if custom_bg != "" else str(BACKGROUNDS.get(duel_game, ""))
	if path != "" and ResourceLoader.exists(path) and (custom_bg != "" or LauncherSettings.aspect == "overlay" or LauncherSettings.aspect == "balanced" or Game._is_duel_viewer(_duel)):
		_background.texture = load(path)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.visible = false
	_shade_material.shader = preload("res://scenes/duel/duel_start_shade.gd").SHADER
	add_child(_shade)
	_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_container.stretch = false
	add_child(_container)
	# El duelo sigue en coordenadas 800x600, pero se rasteriza a la densidad de la ventana:
	# ampliar una imagen de 800x600 emborronaba cartas y textos frente al modo estirado.
	_viewport.size_2d_override = Vector2i(800, 600)
	_viewport.size_2d_override_stretch = true
	_viewport.canvas_item_default_texture_filter = _window.canvas_item_default_texture_filter
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_viewport)
	_window.size_changed.connect(_layout)
	_layout()
	_layout.call_deferred()
	_viewport.add_child(_duel)
	_process(0.0)

func _process(_delta: float) -> void:
	# El duelo puede liberarse antes que este envoltorio (cambio de escena o prueba).
	if not is_instance_valid(_duel): return
	# El visor puede crear su presentacion despues de cargar una repeticion.
	var visual: Variant = _duel.get("_visual")
	if visual != null and not visual.background_shade_changed.is_connected(_sync_shade):
		visual.background_shade_changed.connect(_sync_shade)
		visual._render()

func _sync_shade(alpha: float, band_progress: float) -> void:
	_shade.visible = alpha > 0.0
	_shade.color = Color(0, 0, 0, alpha)
	_shade.material = _shade_material if band_progress >= 0 else null
	_shade_material.set_shader_parameter("progress", band_progress)

func _layout() -> void:
	var area := _window.get_visible_rect()
	_backdrop.position = area.position
	_backdrop.size = area.size
	_background.position = area.position
	_background.size = area.size
	_shade.position = area.position
	_shade.size = area.size
	var display_size := Vector2(clampf(area.size.x, 800.0, 1066.4), area.size.y) if LauncherSettings.aspect == "balanced" else Vector2(800, 600)
	_container.position = area.position + (area.size - display_size) * 0.5
	var density := maxf(_window.get_stretch_transform().get_scale().y, 1.0)
	var pixels := Vector2i((display_size * density).round()).clamp(Vector2i(800, 600), Vector2i(4096, 4096))
	_viewport.size = pixels
	_container.size = Vector2(pixels)
	_container.scale = display_size / Vector2(pixels)

## Coordenadas nativas del duelo -> lienzo de la ventana.
func duel_transform() -> Transform2D:
	return _container.get_global_transform_with_canvas() * _viewport.get_final_transform()

func _exit_tree() -> void:
	if is_instance_valid(_window):
		if _window.size_changed.is_connected(_layout): _window.size_changed.disconnect(_layout)
