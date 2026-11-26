class_name PocDialog
extends Node2D
## Ventana modal al estilo del original: un fondo (BMP de la ventana) con los botones ya
## dibujados, y encima la imagen "On" (raton encima / seleccionado) o "Push" (pulsado) de cada
## boton, colocada en la coordenada relativa que da su script (p. ej. dlg_ow_ok "109054").
##
## Raton: encima resalta, pulsar y soltar sobre el mismo boton lo activa.
## Teclado: izquierda/derecha cambian de boton, Aceptar activa, Cancelar (o clic derecho)
## elige el ultimo boton o `cancel_id`.
## Se consume toda la entrada mientras esta abierta. Los Control de la escena de debajo deben
## ignorar el raton (mouse_filter IGNORE): si no, se lo quedan antes que _unhandled_input.

signal closed(button_id: String)
signal closing(button_id: String)

var background: Texture2D
var buttons: Array[Dictionary] = []   # {id, pos (relativa), on: Texture2D, push: Texture2D}
var lines: PackedStringArray = []     # texto opcional (lista de cartas que faltan, etc.)
var text_rect := Rect2()
var text_color := Color.WHITE
## Si no esta vacio, Cancelar / clic derecho cierran con este id en vez de con el ultimo boton.
var cancel_id := ""
var _selected := 0
var _keyboard_selected := false
var _hover := -1
var _pressed := -1
var _font: Font
var native_phase := 2
var native_counter := 128
var native_editor := false
var _native_answer := ""

func enable_native_editor() -> void:
	native_editor = true
	native_phase = 1
	native_counter = 0

func native_tick() -> void:
	if not native_editor: return
	if native_counter < 128:
		native_counter += 12
	elif native_phase == 1:
		native_phase = 2
	elif native_phase in [3, 5]:
		native_phase = 4
		closed.emit(_native_answer)
		queue_free()
	sync_native_visibility()
	queue_redraw()

func sync_native_visibility() -> void:
	for child in get_children():
		if child is CanvasItem: child.visible = native_phase == 2

func _begin_native_close(id: String, cancel := false) -> void:
	_native_answer = id
	native_counter = 0
	native_phase = 5 if cancel else 3
	_pressed = -1
	closing.emit(id)
	queue_redraw()

func native_accepts_input() -> bool:
	return not native_editor or native_phase == 2

func _draw_native_transition() -> bool:
	if not native_editor or native_phase == 2: return false
	if native_phase != 4 and background != null:
		var visual: Dictionary = preload("res://core/editor_window_motion.gd").frame(Vector2i(background.get_size()), native_phase, native_counter)
		draw_texture_rect(background, Rect2(visual.offset, visual.size), false, Color(1, 1, 1, float(visual.alpha) / 255.0))
	return true


func _init(bg: Texture2D, top_left := Vector2(-1, -1)) -> void:
	background = bg
	var bg_size: Vector2 = bg.get_size() if bg != null else Vector2(340, 180)
	position = top_left if top_left.x >= 0 else ((Vector2(800, 600) - bg_size) / 2.0).floor()
	_font = Assets.ui_font()
	z_index = 100


func add_button(id: String, pos: Vector2, on: Texture2D, push: Texture2D) -> void:
	buttons.append({"id": id, "pos": pos, "on": on, "push": push})


func _draw() -> void:
	if _draw_native_transition(): return
	if background != null:
		draw_texture(background, Vector2.ZERO)
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var active_btn: bool = i == _pressed or i == _hover or (_hover == -1 and i == _selected and (not native_editor or _keyboard_selected))
		if i == _pressed and b["push"] != null:
			draw_texture(b["push"], b["pos"])
		elif (i == _hover or (_hover == -1 and i == _selected and (not native_editor or _keyboard_selected))) and b["on"] != null:
			draw_texture(b["on"], b["pos"])
	var y := text_rect.position.y + 13
	for line in lines:
		if y > text_rect.end.y:
			break
		draw_string(_font, Vector2(text_rect.position.x, y), line, HORIZONTAL_ALIGNMENT_LEFT,
				text_rect.size.x, 12, text_color)
		y += 16


func _input(event: InputEvent) -> void:
	if buttons.is_empty() or Game.has_active_root_dialog():
		return
	if native_editor and native_phase in [3, 4, 5]:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if hit != -1 or _pressed != -1:
			if native_editor and native_phase == 1:
				native_phase = 2
				native_counter = 128
				sync_native_visibility()
			if event.pressed:
				_pressed = hit
				_hover = hit
			elif _pressed != -1 and (_hit(event.position, 18.0) == _pressed):
				var act := _pressed
				_pressed = -1
				_close(act)
			elif hit != -1 and _pressed == -1:
				_close(hit)
			else:
				_pressed = -1
			get_viewport().set_input_as_handled()
			queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if native_editor and native_phase == 1 and event is InputEventMouseButton and event.pressed:
		native_phase = 2
		native_counter = 128
		sync_native_visibility()
	if not native_accepts_input(): return
	if buttons.is_empty():
		return
	if event.is_action_pressed("ui_left"):
		_keyboard_selected = true
		_selected = wrapi(_selected - 1, 0, buttons.size())
		_hover = -1
	elif event.is_action_pressed("ui_right"):
		_keyboard_selected = true
		_selected = wrapi(_selected + 1, 0, buttons.size())
		_hover = -1
	elif event.is_action_pressed("ui_accept"):
		_close(_selected)
	elif event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton
			and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_cancel()
	elif event is InputEventMouseMotion:
		_keyboard_selected = false
		_hover = _hit(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(event.position)
		if event.pressed:
			_pressed = hit
		elif _pressed != -1 and (_hit(event.position, 18.0) == _pressed):
			_close(_pressed)
		elif hit != -1 and _pressed == -1:
			_close(hit)
		else:
			_pressed = -1
	queue_redraw()


func _hit(screen_pos: Vector2, extra_pad := 14.0) -> int:
	var local := screen_pos - position
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var size: Vector2 = b["on"].get_size() if b["on"] != null else Vector2(75, 20)
		if Rect2(b["pos"], size).has_point(local):
			return i
	var best_idx := -1
	var best_dist := INF
	for i in buttons.size():
		var b: Dictionary = buttons[i]
		var size: Vector2 = b["on"].get_size() if b["on"] != null else Vector2(75, 20)
		var padded := Rect2(b["pos"], size).grow(extra_pad)
		if padded.has_point(local):
			var dist := local.distance_squared_to(padded.get_center())
			if dist < best_dist:
				best_dist = dist
				best_idx = i
	return best_idx


func _cancel() -> void:
	var fallback_id: String = cancel_id if cancel_id != "" else (str(buttons[-1].id) if not buttons.is_empty() else "cancel")
	if native_editor:
		_begin_native_close(fallback_id, true)
		return
	if cancel_id == "" and not buttons.is_empty():
		_close(buttons.size() - 1)
	else:
		closed.emit(fallback_id)
		queue_free()


func _close(index: int) -> void:
	if index < 0 or index >= buttons.size():
		closed.emit(cancel_id if cancel_id != "" else "cancel")
		queue_free()
		return
	if native_editor:
		_begin_native_close(str(buttons[index].id))
		return
	closed.emit(buttons[index]["id"])
	queue_free()
