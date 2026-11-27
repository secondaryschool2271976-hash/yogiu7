extends CanvasLayer
## Manejo exclusivo de movil: menu de opciones al primer toque, sin pulsacion larga ni arrastre en duelos.
var _menu := Panel.new()
var _left := Button.new()
var _right := Button.new()
var _target := Vector2.ZERO
var _finger := -1
var _previous_emulation := true
var _pressed_button := MOUSE_BUTTON_NONE
var _dispatching := false
var _start := Vector2.ZERO
var _generation := 0
var _pile_request := 0
var _action_label := Label.new()
var _actions: Array[int] = []
var _choices: Array[Button] = []
var _right_available := false
var _preparing := false
var _executing_card_action := false
var _card_prepared := false
var _pending_release := false
var _tribute_hint := Label.new()
var _cancel_btn := Button.new()
var _cancel_finger := -1
var _surrender_finger := -1
var _online_finger := -1
var _menu_cancel := Button.new()
var _deck_touch := false
var _drag_starting := false
var _pending_drop := false
var _touch_active := false
var _selected_card := ""
var _touch_card := ""
var _scroll_axis := ""
var _scroll_kind := ""
var _scroll_node: Node
var _scrolling := false
var _scroll_last := Vector2.ZERO
var _scroll_amount := 0.0
var _busy_lock_elapsed := 0.0
var _finger_idle_elapsed := 0.0
const JOEY_VIEW_PILE_ACTION := 1 << 12
const JOEY_PILE_TIMEOUT_MS := 2500

static func _action_name(action: int) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match action:
			1: return "استدعاء"
			2: return "قلب"
			3: return "هجوم"
			4: return "تفعيل"
			5: return "وضع مقلوب"
			6: return "وضع دفاع"
			7: return "وضع هجوم"
			8: return "سحب"
			9: return "استسلام"
			10: return "دمج"
			11: return "استدعاء خاص (هجوم)"
			12: return "استدعاء خاص (دفاع)"
		return "اختيار"
	if lang == "s":
		match action:
			1: return "Invocar"
			2: return "Voltear"
			3: return "Atacar"
			4: return "Activar"
			5: return "Colocar"
			6: return "Posición defensa"
			7: return "Posición ataque"
			8: return "Robar"
			9: return "Rendirse"
			10: return "Fusión"
			11: return "Esp. ataque"
			12: return "Esp. defensa"
		return "Elegir"
	match action:
		1: return "Summon"
		2: return "Flip"
		3: return "Attack"
		4: return "Activate"
		5: return "Set"
		6: return "Defense Pos"
		7: return "Attack Pos"
		8: return "Draw"
		9: return "Surrender"
		10: return "Fusion"
		11: return "Special Attack"
		12: return "Special Defense"
	return "Choose"

## Los cuadros modales hechos con Control (p. ej. el selector de mazos de Importar) no reciben
## el raton sintetico: sus Control viven en pixeles del viewport y nosotros enviamos coordenadas
## de escena. Si el cuadro abierto sabe leer el toque, se le pasa tal cual, en coordenadas de
## escena, y el decide.
func _modal_handles(method: String, event: InputEvent) -> bool:
	if not is_instance_valid(Game._screen):
		return false
	var modal: Variant = Game._screen.get("_modal")
	if modal == null or not is_instance_valid(modal):
		return false
	if not modal.has_method(method):
		return false
	return bool(modal.call(method, event, _scene_point(event.position)))


func _target_viewport() -> Viewport:
	if Game.has_active_root_dialog():
		return get_tree().root
	if is_instance_valid(Game._screen) and Game._screen.is_inside_tree():
		return Game._screen.get_viewport()
	return get_tree().root

func _scene_point(point: Vector2) -> Vector2:
	if Game.has_active_root_dialog():
		return point
	if is_instance_valid(Game._screen_host) and Game._screen_host.has_method("duel_transform"):
		return Game._screen_host.duel_transform().affine_inverse() * point
	return point

func _screen_script_path() -> String:
	if not is_instance_valid(Game._screen):
		return ""
	var scr: Script = Game._screen.get_script()
	return str(scr.resource_path) if scr != null else ""

func _duel_result_active(scene: Node) -> bool:
	return is_instance_valid(scene) and (bool(scene.get("_finished")) or scene.get("_result") != null)

func _can_surrender_deck(scene: Node) -> bool:
	if not is_instance_valid(scene) or _duel_result_active(scene) or scene.get("_duel") == null:
		return false
	var d = scene._duel
	if not d.dialog_open.is_empty() or not d.list_open.is_empty():
		return false
	if (d.m.u16(0xa133f2) & 1) != 0:
		return false
	if scene.get("_visual") != null and scene._visual.busy():
		return false
	if not scene._waiting_for_player() or _target_selection(scene):
		return false
	return true

func _has_right_action(point: Vector2) -> bool:
	if Game.has_active_root_dialog():
		return false
	var scene: Node = Game._screen
	if not is_instance_valid(scene): return false
	var script_path: String = _screen_script_path()
	var local := _scene_point(point)
	if PlatformInput._normal_duel_active():
		if _duel_result_active(scene): return false
		if scene._duel == null or _target_selection(scene) or not (scene._waiting_for_player() or _response_selection(scene)) or scene._visual.busy(): return false
		if not scene._duel.dialog_open.is_empty() or not scene._duel.list_open.is_empty(): return false
		var hit: Dictionary = scene._hit_card(local)
		if hit.is_empty(): return false
		var hit_p: int = int(hit.get("p", -1))
		var hit_loc: int = int(hit.get("loc", -1))
		if hit_p == 0:
			return hit_loc in [0, 5, 10, 11, 13]
		return hit_p == 1 and hit_loc in [0, 5, 10] and bool(hit.get("known", false))
	if script_path.ends_with("deck_editor.gd"):
		return false
	return false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel()

func _process(delta: float) -> void:
	if _dispatching or _preparing or _drag_starting:
		_busy_lock_elapsed += delta
		if _busy_lock_elapsed >= 3.0:
			cancel()
	else:
		_busy_lock_elapsed = 0.0
	if _finger != -1 and not _touch_active and not _scrolling and not _preparing and not _drag_starting:
		_finger_idle_elapsed += delta
		if _finger_idle_elapsed >= 1.5:
			_finger = -1
			_finger_idle_elapsed = 0.0
	else:
		_finger_idle_elapsed = 0.0
	_update_tribute_hint()
	_update_cancel_button()

func _style_box(bg: Color, border: Color, radius := 8, bw := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(bw)
	box.set_corner_radius_all(radius)
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	box.content_margin_left = 8
	box.content_margin_right = 8
	return box

func _style_button(button: Button, font_size := 15) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_override("font", Assets.ui_font(700))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	button.add_theme_stylebox_override("normal", _style_box(Color(0.11, 0.14, 0.24, 0.96), Color(0.84, 0.68, 0.34, 0.95), 8, 2))
	button.add_theme_stylebox_override("hover", _style_box(Color(0.18, 0.23, 0.38, 0.98), Color(1.0, 0.84, 0.44), 8, 2))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.24, 0.29, 0.45), Color(1.0, 0.88, 0.52), 8, 2))

func _style_set_button(button: Button, font_size := 15) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_override("font", Assets.ui_font(700))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.90, 0.88, 0.98))
	button.add_theme_stylebox_override("normal", _style_box(Color(0.18, 0.14, 0.27, 0.96), Color(0.64, 0.58, 0.82, 0.92), 8, 2))
	button.add_theme_stylebox_override("hover", _style_box(Color(0.25, 0.20, 0.37, 0.98), Color(0.80, 0.74, 0.96), 8, 2))
	button.add_theme_stylebox_override("pressed", _style_box(Color(0.30, 0.24, 0.44), Color(0.86, 0.80, 1.0), 8, 2))

static func _order_actions(actions: Array[int]) -> Array[int]:
	var primary: Array[int] = []
	var secondary: Array[int] = []
	for act: int in actions:
		if act == 5:
			secondary.append(act)
		else:
			primary.append(act)
	primary.append_array(secondary)
	return primary

func _ready() -> void:
	layer = 100
	_tribute_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tribute_hint.add_theme_font_override("font", Assets.ui_font(700))
	_tribute_hint.add_theme_color_override("font_color", Color.YELLOW)
	_tribute_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tribute_hint.add_theme_constant_override("shadow_offset_x", 2)
	_tribute_hint.add_theme_constant_override("shadow_offset_y", 2)
	_tribute_hint.add_theme_font_size_override("font_size", 20)
	_tribute_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tribute_hint.hide()
	add_child(_tribute_hint)
	_previous_emulation = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = false
	var panel_style := _style_box(Color(0.06, 0.08, 0.14, 0.96), Color(0.90, 0.72, 0.34, 0.98), 12, 2)
	panel_style.shadow_color = Color(0, 0, 0, 0.65)
	panel_style.shadow_size = 8
	_menu.add_theme_stylebox_override("panel", panel_style)
	_menu.size = Vector2(376, 132)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	add_child(_menu)
	_action_label.position = Vector2(8, 6)
	_action_label.size = Vector2(360, 24)
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_font_override("font", Assets.ui_font(700))
	_action_label.add_theme_font_size_override("font_size", 15)
	_action_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.44))
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_action_label)
	_choices.assign([_left, _right])
	for button in _choices:
		_style_button(button, 15)
		_menu.add_child(button)
	_menu_cancel.focus_mode = Control.FOCUS_NONE
	_menu_cancel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_cancel.add_theme_font_override("font", Assets.ui_font(700))
	_menu_cancel.add_theme_font_size_override("font_size", 15)
	_menu_cancel.add_theme_color_override("font_color", Color.WHITE)
	_menu_cancel.add_theme_stylebox_override("normal", _style_box(Color(0.55, 0.12, 0.15, 0.96), Color(0.95, 0.72, 0.38, 0.9), 8, 2))
	_menu_cancel.add_theme_stylebox_override("hover", _style_box(Color(0.68, 0.16, 0.20), Color(1.0, 0.82, 0.45), 8, 2))
	_menu_cancel.add_theme_stylebox_override("pressed", _style_box(Color(0.45, 0.09, 0.12), Color(1.0, 0.82, 0.45), 8, 2))
	_menu.add_child(_menu_cancel)
	_setup_cancel_button()

func _setup_cancel_button() -> void:
	_cancel_btn.focus_mode = Control.FOCUS_NONE
	_cancel_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cancel_btn.size = Vector2(142, 48)
	_cancel_btn.add_theme_font_override("font", Assets.ui_font(700))
	_cancel_btn.add_theme_font_size_override("font_size", 18)
	_cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	var style := _style_box(Color(0.62, 0.11, 0.14, 0.94), Color(1.0, 0.82, 0.42, 0.95), 10, 2)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 4
	_cancel_btn.add_theme_stylebox_override("normal", style)
	_cancel_btn.add_theme_stylebox_override("hover", style)
	_cancel_btn.add_theme_stylebox_override("pressed", style)
	_cancel_btn.hide()
	add_child(_cancel_btn)

func _exit_tree() -> void:
	Input.emulate_mouse_from_touch = _previous_emulation
	_release()

func cancel() -> void:
	_menu.hide()
	_tribute_hint.hide()
	_cancel_btn.hide()
	_cancel_finger = -1
	_surrender_finger = -1
	_online_finger = -1
	_selected_card = ""
	_touch_card = ""
	_scroll_kind = ""
	_scroll_axis = ""
	_scroll_node = null
	_scroll_amount = 0.0
	_scrolling = false
	_finger = -1
	_touch_active = false
	_preparing = false
	_executing_card_action = false
	_dispatching = false
	_drag_starting = false
	_card_prepared = false
	_pending_release = false
	_pending_drop = false
	_actions.clear()
	_busy_lock_elapsed = 0.0
	_finger_idle_elapsed = 0.0
	_generation += 1
	_release()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		if _modal_handles("handle_mobile_drag", event):
			return
		if is_instance_valid(Game._screen) and Game._screen.has_method("handle_mobile_search_drag"):
			if Game._screen.handle_mobile_search_drag(event, _scene_point(event.position)):
				return
		if event.index == _finger and _touch_active:
			if _touch_card == "pile": return
			if _touch_card.begins_with("duel:") and not _scrolling and event.position.distance_to(_start) < 32.0:
				return
			_target = event.position
			if _scroll_drag(_target): return
			if _drag_starting: return
			if _pressed_button == MOUSE_BUTTON_NONE and not PlatformInput._normal_duel_active() and _deck_touch and _target.distance_to(_start) > 16:
				_begin_drag(_start)
				return
			if not PlatformInput._normal_duel_active() or Game.has_active_root_dialog():
				_move_mouse(_target)
			elif is_instance_valid(Game._screen) and _target_selection(Game._screen):
				_move_mouse(_target)
				_preview_duel_card(_target)
		return
	if event is InputEventScreenTouch:
		if _modal_handles("handle_mobile_touch", event):
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(Game._screen) and Game._screen.has_method("handle_mobile_search_touch"):
			if Game._screen.handle_mobile_search_touch(event, _scene_point(event.position)):
				get_viewport().set_input_as_handled()
				return
		get_viewport().set_input_as_handled()
		if event.canceled:
			cancel()
			return
		if not event.pressed:
			if event.index == _cancel_finger:
				_cancel_finger = -1
				return
			if event.index == _surrender_finger:
				_surrender_finger = -1
				return
			if event.index == _online_finger:
				_online_finger = -1
				return
			if event.index == _finger:
				_finger = -1
				if _scrolling:
					_scrolling = false
					_scroll_kind = ""
					_touch_active = false
					_selected_card = ""
					return
				_scroll_kind = ""
				if _drag_starting:
					_pending_drop = true
					return
				if _preparing:
					_pending_release = true
					return
				if _touch_active:
					_touch_active = false
					if _pressed_button == MOUSE_BUTTON_NONE:
						if _touch_card == "pile": _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, _start, _pile_request)
						elif _touch_card != "": _finish_card_tap(_target)
						elif _deck_touch:
							if is_instance_valid(Game._screen) and Game._screen.has_method("handle_mobile_card_tap"):
								Game._screen.handle_mobile_card_tap(_scene_point(_target))
						else: _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, _target)
					else: _release(_target)
			return
		if _cancel_btn.visible and _cancel_btn.get_global_rect().grow(6.0).has_point(event.position):
			_cancel_finger = event.index
			_trigger_cancel()
			return
		if Game.is_match_surrender_button_visible() and Game.match_surrender_button_rect().grow(6.0).has_point(event.position):
			_surrender_finger = event.index
			Game.confirm_surrender_match()
			return
		if Game.is_online_button_visible() and Game.online_button_rect().grow(6.0).has_point(event.position):
			_online_finger = event.index
			Game.open_online_modal()
			return
		if _finger != -1 and _finger != event.index and not _touch_active and not _scrolling and not _preparing and not _drag_starting:
			_finger = -1
		if _dispatching or _preparing or (_finger != -1 and _finger != event.index): return
		_pile_request += 1
		_finger = event.index
		_finger_idle_elapsed = 0.0
		if _menu.visible:
			if _menu.get_global_rect().grow(6.0).has_point(event.position):
				_choose(event.position)
				return
			_menu.hide()
			_selected_card = ""
			if not _card_identity(event.position).begins_with("duel:"):
				return
		_actions.clear()
		_card_prepared = false
		var root_dialog: bool = Game.has_active_root_dialog()
		_touch_card = "" if root_dialog else _card_identity(event.position)
		if _touch_card in ["", "pile"]: _selected_card = ""
		_deck_touch = not root_dialog and _screen_script_path().ends_with("deck_editor.gd") and is_instance_valid(Game._screen) and Game._screen._modal == null and not Game._screen._hit_at(_scene_point(event.position)).is_empty()
		_right_available = false if (root_dialog or (_screen_script_path().ends_with("deck_editor.gd") and not _deck_touch)) else _has_right_action(event.position)
		_target = event.position
		_start = _target
		_pending_release = false
		_pending_drop = false
		_scroll_candidate(_target)
		_move_mouse(_target)
		if _touch_card.begins_with("duel:"):
			_preview_duel_card(_target)
		if _touch_card == "pile":
			_touch_active = true
			return
		if _scroll_kind != "":
			_touch_active = true
			return
		if _right_available and PlatformInput._normal_duel_active():
			_prepare_card(_target)
			return
		_begin_touch(_target)
	elif event is InputEventMouseButton and _cancel_btn.visible and not bool(event.get_meta("platform_touch", false)) and _cancel_btn.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_trigger_cancel()
	elif event is InputEventMouseButton and Game.is_match_surrender_button_visible() and not bool(event.get_meta("platform_touch", false)) and Game.match_surrender_button_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Game.confirm_surrender_match()
	elif event is InputEventMouseButton and Game.is_online_button_visible() and not bool(event.get_meta("platform_touch", false)) and Game.online_button_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Game.open_online_modal()
	elif event is InputEventMouseButton and _menu.visible:
		get_viewport().set_input_as_handled()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT: _choose(event.position)

func _preview_duel_card(point: Vector2) -> int:
	var scene: Node = Game._screen
	if not is_instance_valid(scene) or not PlatformInput._normal_duel_active() or scene._duel == null:
		return -1
	var local: Vector2 = _scene_point(point)
	var hit: Dictionary = scene._hit_card(local)
	if hit.is_empty() or int(hit.get("loc", -1)) >= 12:
		return -1
	var known: bool = bool(hit.get("known", false))
	var card_id: int = int(hit.get("id", -1)) if known else -1
	if scene.has_method("_set_preview"):
		scene._set_preview(card_id, scene._is_rival_hand_card(hit))
		if "_preview_hover_point" in scene:
			scene._preview_hover_point = local
		if "_preview_hover_ticks" in scene:
			scene._preview_hover_ticks = 4
	return card_id

func _extract_actions(d) -> Array[int]:
	var out: Array[int] = []
	if d == null:
		return out
	var mask: int = d.m.u16(0xa1340a)
	if mask == 0:
		if int(d.cursor_action) > 0:
			out.append(int(d.cursor_action))
		return out
	var ordered: Array[int] = []
	var is_joey: bool = d.get("engine") != null and d.engine.get("m") != null
	var table_len: int = 13 if is_joey else 12
	for i in table_len:
		var action: int = d.engine.m.u8(0x5dd980 + i * 4) if is_joey else d.m.u8(0x59df1c + i * 4)
		if (mask & (1 << action)) != 0 and not ((action + 1) in ordered):
			ordered.append(action + 1)
	for bit in 12:
		if (mask & (1 << bit)) != 0 and not ((bit + 1) in ordered):
			ordered.append(bit + 1)
	var first := ordered.find(int(d.cursor_action))
	for i in ordered.size():
		out.append(ordered[(maxi(0, first) + i) % ordered.size()])
	return out

func _prepare_card(point: Vector2) -> void:
	if not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null or get_tree() == null:
		_preparing = false
		return
	_preparing = true
	var generation := _generation
	var d = Game._screen._duel
	d.m.set_u16(0xa13408, d.m.u16(0xa13408) & 0xfffe)
	d.m.set_u16(0xa1340a, 0)
	d.m.set_u8(0xa1340c, 0)
	if d.get("engine") != null and d.engine.get("m") != null:
		d.engine.m.set_u16(0xa57804, d.engine.m.u16(0xa57804) & 0xfffe)
		d.engine.m.set_u16(0xa57806, 0)
		d.engine.m.set_u8(0xa57808, 0)
	_move_mouse(point)
	var started_ms: int = Time.get_ticks_msec()
	var deadline_ms: int = started_ms + 280
	var idle_ticks: int = 0
	await get_tree().create_timer(1.0 / NativeClock.HZ).timeout
	while Time.get_ticks_msec() < deadline_ms:
		if generation != _generation:
			_preparing = false
			return
		if not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null or _duel_result_active(Game._screen):
			_preparing = false
			return
		var mask_now: int = d.m.u16(0xa1340a)
		if mask_now != 0 and (_is_cursor_action_ready(d) or Time.get_ticks_msec() - started_ms >= 80):
			break
		if mask_now == 0 and int(d.cursor_action) > 0 and _is_cursor_action_ready(d):
			break
		var scene: Node = Game._screen
		if scene._visual != null and not scene._visual.busy() and (scene._waiting_for_player() or _response_selection(scene)):
			idle_ticks += 1
			if idle_ticks >= 3 and Time.get_ticks_msec() - started_ms >= 90:
				break
		_move_mouse(point)
		await get_tree().process_frame
	if generation != _generation:
		_preparing = false
		return
	_preparing = false
	_card_prepared = true
	var extracted: Array[int] = _extract_actions(d)
	if extracted.is_empty() and _touch_card == "duel:0:13:0:0" and _can_surrender_deck(Game._screen):
		extracted = [9]
	_right_available = _has_right_action(point) and not extracted.is_empty()
	_actions.clear()
	if _right_available:
		_actions = extracted
	_begin_touch(point)

func _begin_touch(point: Vector2) -> void:
	var scene: Node = Game._screen
	var duel_board: bool = not Game.has_active_root_dialog() and is_instance_valid(scene) and PlatformInput._normal_duel_active() and not _duel_result_active(scene) and scene._duel != null and scene._duel.dialog_open.is_empty() and scene._duel.list_open.is_empty()
	if _touch_card != "":
		_touch_active = true
		if _pending_release:
			_touch_active = false
			_finish_card_tap(point)
	elif _deck_touch:
		_touch_active = true
		if _pending_release:
			_touch_active = false
			if is_instance_valid(scene) and scene.has_method("handle_mobile_card_tap"):
				scene.handle_mobile_card_tap(_scene_point(point))
	elif duel_board and not _right_available:
		_touch_active = true
		if _pending_release:
			_touch_active = false
			_dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, _target)
	elif not _right_available:
		_touch_active = true
		_press(MOUSE_BUTTON_LEFT, _target)
		if _pending_release:
			_touch_active = false
			_release(_target)
	else:
		_show_at(point)

func _begin_drag(start: Vector2) -> void:
	if get_tree() == null:
		_drag_starting = false
		return
	var generation := _generation
	_drag_starting = true
	_menu.hide()
	_press(MOUSE_BUTTON_LEFT, start)
	await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
	if generation != _generation:
		_drag_starting = false
		return
	_drag_starting = false
	_move_mouse(_target)
	if _pending_drop:
		_touch_active = false
		_release(_target)

func _show_at(point: Vector2) -> void:
	_target = point
	if _actions.size() > 1:
		_actions = _order_actions(_actions)
	var is_deck_editor: bool = _screen_script_path().ends_with("deck_editor.gd")
	var count := _actions.size() if not _actions.is_empty() else (2 if is_deck_editor else 1)
	while _choices.size() < count:
		var extra := Button.new()
		_style_button(extra, 15)
		_menu.add_child(extra)
		_choices.append(extra)
	var has_set_split: bool = not _actions.is_empty() and _actions.size() >= 2 and (5 in _actions)
	var w: float = 264.0
	var y_cursor: float = 36.0
	if has_set_split:
		var primary_count: int = 0
		for act: int in _actions:
			if act != 5:
				primary_count += 1
		var p_cols: int = 1 if primary_count <= 1 else 2
		w = 264.0 if p_cols == 1 else 388.0
		var p_btn_w: float = w - 20.0 if p_cols == 1 else (w - 34.0) * 0.5
		var p_idx: int = 0
		var p_rows: int = int(ceil(primary_count / float(p_cols))) if primary_count > 0 else 0
		var set_y: float = y_cursor + (p_rows * 56.0 + 8.0 if p_rows > 0 else 0.0)
		var set_idx: int = 0
		for i in _choices.size():
			var button := _choices[i]
			button.visible = i < count
			if i >= count:
				continue
			var act: int = _actions[i]
			button.text = _action_name(act)
			if act == 5:
				_style_set_button(button, 15)
				button.position = Vector2(10.0, set_y + set_idx * 56.0)
				button.size = Vector2(w - 20.0, 50.0)
				set_idx += 1
			else:
				_style_button(button, 15)
				var col: int = p_idx % p_cols
				var row: int = int(p_idx / float(p_cols))
				button.position = Vector2(10.0 + col * (p_btn_w + 14.0), y_cursor + row * 56.0)
				button.size = Vector2(p_btn_w, 50.0)
				p_idx += 1
		y_cursor = set_y + set_idx * 56.0 + 8.0
	else:
		var deck_card_menu := is_deck_editor and _actions.is_empty()
		var is_filter_menu: bool = deck_card_menu and str(Game._screen._button_at(_scene_point(point))) == "filter_label"
		var cols := 1 if (count == 1 or deck_card_menu) else 2
		var rows := int(ceil(count / float(cols)))
		if deck_card_menu:
			w = 248.0 if is_filter_menu else 216.0
			y_cursor = 32.0
		else:
			w = 248.0 if cols == 1 else 384.0
		var btn_w := w - 20.0 if cols == 1 else (w - 32.0) * 0.5
		var row_step := 50.0 if deck_card_menu else 56.0
		for i in _choices.size():
			var button := _choices[i]
			button.visible = i < count
			if i >= count:
				continue
			if i < _actions.size() and _actions[i] == 5:
				_style_set_button(button, 15)
			else:
				_style_button(button, 15)
			button.text = _action_name(_actions[i]) if i < _actions.size() else _ui_label("choose_action")
			if deck_card_menu:
				if is_filter_menu:
					button.text = _ui_label("next_filter") if i == 0 else _ui_label("prev_filter")
				elif i == 0:
					button.text = _ui_label("select")
				else:
					button.text = _ui_label("drop") if Game._screen._held != 0 else _ui_label("sort")
			var btn_h := maxf(44.0 if deck_card_menu else 48.0, ceilf(button.get_combined_minimum_size().y) + 4.0)
			row_step = maxf(row_step, btn_h + 6.0)
			var col := i % cols
			var row := int(i / float(cols))
			button.position = Vector2(10.0 + col * (btn_w + 12.0), y_cursor + row_step * row)
			button.size = Vector2(btn_w, btn_h)
		y_cursor += row_step * rows + 4.0
	_action_label.size = Vector2(w - 16.0, 24.0)
	var card_id: int = _preview_duel_card(point) if _touch_card.begins_with("duel:") else -1
	var card_title: String = CardDB.name_of(card_id) if card_id > 0 else ""
	_action_label.text = card_title if card_title != "" and card_title != "?" else _ui_label("choose_action")
	_menu_cancel.text = _ui_label("cancel")
	var cancel_h := maxf(38.0 if is_deck_editor else 42.0, ceilf(_menu_cancel.get_combined_minimum_size().y) + 4.0)
	_menu_cancel.position = Vector2(10.0, y_cursor)
	_menu_cancel.size = Vector2(w - 20.0, cancel_h)
	_menu_cancel.visible = true
	_menu.size = Vector2(w, y_cursor + cancel_h + 10.0)
	var bounds := get_viewport().get_visible_rect()
	var x := point.x - _menu.size.x * 0.5
	var y := point.y - _menu.size.y - 16.0
	if is_deck_editor and _actions.is_empty():
		if point.x > 520.0:
			x = point.x - _menu.size.x - 20.0
			y = point.y - _menu.size.y * 0.5
		else:
			x = point.x + 18.0 if point.x < 300.0 else point.x - _menu.size.x * 0.5
			y = point.y - _menu.size.y * 0.5
	elif y < bounds.position.y + 6.0:
		y = point.y + 18.0
	x = clampf(x, bounds.position.x + 6.0, bounds.end.x - _menu.size.x - 6.0)
	y = clampf(y, bounds.position.y + 6.0, bounds.end.y - _menu.size.y - 6.0)
	_menu.position = Vector2(x, y)
	_menu.show()
	_move_mouse(point)

func _choose(point: Vector2) -> void:
	_finger = -1
	_touch_active = false
	if _menu_cancel.visible and _menu_cancel.get_global_rect().grow(4.0).has_point(point):
		_menu.hide()
		_selected_card = ""
		return
	var chosen := -1
	var best_dist := INF
	for i in _choices.size():
		if _choices[i].visible:
			var r: Rect2 = _choices[i].get_global_rect().grow(5.0)
			if r.has_point(point):
				var dist: float = point.distance_squared_to(r.get_center())
				if dist < best_dist:
					best_dist = dist
					chosen = i
	_menu.hide()
	if chosen < 0:
		_selected_card = ""
		return
	if chosen < _actions.size(): _execute_action.call_deferred(_actions[chosen], _target)
	else: _dispatch_click.call_deferred(MOUSE_BUTTON_LEFT if chosen == 0 else MOUSE_BUTTON_RIGHT, _target)

func _is_cursor_action_ready(d) -> bool:
	if d == null:
		return false
	if d.get("engine") != null and d.engine.get("m") != null:
		return d.engine.m.u8(0xa57808) == 1
	return d.m.u8(0xa1340c) == 1

func _action_consumed(scene: Node, d, expected_action: int) -> bool:
	if not is_instance_valid(scene) or d == null or _duel_result_active(scene):
		return true
	if not d.dialog_open.is_empty() or not d.list_open.is_empty():
		return true
	if scene.get("_visual") != null and scene._visual.busy():
		return true
	if _target_selection(scene):
		return true
	if not (scene._waiting_for_player() or _response_selection(scene)):
		return true
	if expected_action != 9 and d.m.u16(0xa1340a) == 0 and int(d.cursor_action) == 0:
		return true
	return false

func _execute_action(action: int, point: Vector2) -> void:
	_selected_card = ""
	if not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null or _duel_result_active(Game._screen) or get_tree() == null:
		_dispatching = false
		_executing_card_action = false
		return
	var generation := _generation
	_dispatching = true
	_executing_card_action = true
	_move_mouse(point)
	var d = Game._screen._duel
	if action == 9 and (d.m.u16(0xa1340a) & (1 << 8)) == 0 and int(d.cursor_action) != 9:
		await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
		if generation != _generation or not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null:
			_dispatching = false
			_executing_card_action = false
			return
		_press(MOUSE_BUTTON_LEFT, point)
		await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
		_release(point)
		var arm_deadline: int = Time.get_ticks_msec() + 360
		while generation == _generation and is_instance_valid(Game._screen) and Game._screen.get("_duel") != null and Time.get_ticks_msec() < arm_deadline:
			if not d.dialog_open.is_empty():
				_dispatching = false
				_executing_card_action = false
				return
			if int(d.cursor_action) == 9 or (d.m.u16(0xa1340a) & (1 << 8)) != 0:
				break
			_move_mouse(point)
			await get_tree().process_frame
	var ready_deadline: int = Time.get_ticks_msec() + 420
	while generation == _generation and is_instance_valid(Game._screen) and Game._screen.get("_duel") != null and Time.get_ticks_msec() < ready_deadline:
		var scene: Node = Game._screen
		if not d.dialog_open.is_empty():
			_dispatching = false
			_executing_card_action = false
			return
		var vis_busy: bool = scene.get("_visual") != null and scene._visual.busy()
		if not vis_busy and _is_cursor_action_ready(d) and int(d.cursor_action) > 0:
			break
		_move_mouse(point)
		await get_tree().process_frame
	var stalled_retries := 0
	var left_confirm_tries := 0
	for _attempt in 18:
		if generation != _generation or not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null or _duel_result_active(Game._screen): break
		var scene: Node = Game._screen
		if not d.dialog_open.is_empty() or not d.list_open.is_empty():
			break
		var busy_deadline: int = Time.get_ticks_msec() + 260
		while generation == _generation and is_instance_valid(Game._screen) and scene.get("_visual") != null and scene._visual.busy() and Time.get_ticks_msec() < busy_deadline:
			await get_tree().process_frame
		if generation != _generation or not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null: break
		_move_mouse(point)
		if int(d.cursor_action) == action:
			_press(MOUSE_BUTTON_LEFT, point)
			await get_tree().create_timer(1.2 / NativeClock.HZ).timeout
			_release(point)
			left_confirm_tries += 1
			var ack_deadline: int = Time.get_ticks_msec() + 180
			var accepted := false
			while generation == _generation and is_instance_valid(Game._screen) and Game._screen.get("_duel") != null and Time.get_ticks_msec() < ack_deadline:
				if _action_consumed(Game._screen, d, action):
					accepted = true
					break
				await get_tree().process_frame
			if accepted or left_confirm_tries >= 3 or int(d.cursor_action) <= 0:
				break
			_move_mouse(point)
			await get_tree().create_timer(1.0 / NativeClock.HZ).timeout
			continue
		if left_confirm_tries > 0:
			break
		var previous: int = int(d.cursor_action)
		if previous <= 0:
			stalled_retries += 1
			if stalled_retries >= 3:
				break
			_move_mouse(point)
			await get_tree().create_timer(1.0 / NativeClock.HZ).timeout
			continue
		_press(MOUSE_BUTTON_RIGHT, point)
		await get_tree().create_timer(1.0 / NativeClock.HZ).timeout
		_release(point)
		var deadline := Time.get_ticks_msec() + 240
		while generation == _generation and is_instance_valid(Game._screen) and Game._screen.get("_duel") != null and int(d.cursor_action) == previous and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		if int(d.cursor_action) == previous:
			stalled_retries += 1
			if stalled_retries >= 3:
				if action == 9 and d.dialog_open.is_empty():
					_press(MOUSE_BUTTON_LEFT, point)
					await get_tree().create_timer(2.0 / NativeClock.HZ).timeout
					_release(point)
				break
			_move_mouse(point)
			await get_tree().create_timer(1.0 / NativeClock.HZ).timeout
		else:
			stalled_retries = 0
	_dispatching = false
	_executing_card_action = false

func _top_embedded_subwindow() -> Window:
	if get_tree() == null or get_tree().root == null:
		return null
	var wins := get_tree().root.get_embedded_subwindows()
	for i in range(wins.size() - 1, -1, -1):
		var w: Window = wins[i]
		if is_instance_valid(w) and w.visible:
			return w
	return null

func _dispatch_mouse(ev: InputEventMouse) -> void:
	if get_tree() == null:
		return
	ev.device = InputEvent.DEVICE_ID_EMULATION
	ev.set_meta("platform_touch", true)
	if is_instance_valid(Game._screen) and Game._screen.get("_duel") != null:
		PointerGlide.cancel()
		Game._screen._duel.ui_key_cursor = false
	var vp := _target_viewport()
	if vp == null:
		return
	if vp == get_tree().root:
		var subwin := _top_embedded_subwindow()
		if subwin != null and subwin is Popup:
			var rect := Rect2(Vector2(subwin.position), Vector2(subwin.size))
			if rect.has_point(ev.position):
				var local_ev: InputEventMouse = ev.duplicate()
				local_ev.position = ev.position - Vector2(subwin.position)
				local_ev.global_position = local_ev.position
				subwin.push_input(local_ev, true)
			elif ev is InputEventMouseButton and ev.pressed:
				subwin.hide()
			return
	if vp != get_tree().root:
		Game._input(ev)
	vp.push_input(ev, true)

func _move_mouse(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = _scene_point(point)
	motion.global_position = motion.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressed_button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT if _pressed_button == MOUSE_BUTTON_RIGHT else 0
	_dispatch_mouse(motion)

func _dispatch_click(button: MouseButton, point: Vector2, pile_request := -1) -> void:
	if get_tree() == null:
		_dispatching = false
		return
	var generation := _generation
	var joey_pile := pile_request >= 0 and Game.current_game == "joey"
	if joey_pile and pile_request != _pile_request: return
	_dispatching = not joey_pile
	_move_mouse(point)
	if pile_request >= 0:
		await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
		if joey_pile:
			var deadline := Time.get_ticks_msec() + JOEY_PILE_TIMEOUT_MS
			while generation == _generation and pile_request == _pile_request:
				var scene: Node = Game._screen
				if not is_instance_valid(scene) or scene.get("_duel") == null or scene.get("_visual") == null:
					_dispatching = false
					return
				if not scene._visual.busy() and scene._waiting_for_player() \
						and (scene._duel.m.u16(0xa1340a) & JOEY_VIEW_PILE_ACTION) != 0:
					break
				if Time.get_ticks_msec() >= deadline:
					_dispatching = false
					return
				await get_tree().process_frame
			if generation != _generation or pile_request != _pile_request:
				_dispatching = false
				return
	else:
		await get_tree().process_frame
		await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
	if generation != _generation:
		_dispatching = false
		return
	if button == MOUSE_BUTTON_LEFT and pile_request < 0 and PlatformInput._normal_duel_active() and is_instance_valid(Game._screen) and not _duel_result_active(Game._screen) and Game._screen.get("_duel") != null and not _target_selection(Game._screen):
		var hit_id: String = _card_identity(point)
		if hit_id.begins_with("duel:") and _has_right_action(point):
			var live_actions: Array[int] = _extract_actions(Game._screen._duel)
			if live_actions.is_empty() and hit_id == "duel:0:13:0:0" and _can_surrender_deck(Game._screen):
				live_actions = [9]
			if not live_actions.is_empty():
				_dispatching = false
				_touch_card = hit_id
				_selected_card = hit_id
				_actions = live_actions
				_show_at(point)
				return
	_dispatching = true
	_press(button, point)
	await get_tree().process_frame
	await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
	_release(point)
	_dispatching = false

func _dispatch_help_click(point: Vector2) -> void:
	if get_tree() == null:
		_dispatching = false
		return
	var generation := _generation
	_dispatching = true
	_move_mouse(point)
	await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
	if generation != _generation or not is_instance_valid(Game._screen) or Game._screen.get("_duel") == null:
		_dispatching = false
		return
	var scene: Node = Game._screen
	var d = scene._duel
	var live_actions: Array[int] = _extract_actions(d)
	if not live_actions.is_empty() and _has_right_action(point):
		_dispatching = false
		_actions = live_actions
		_selected_card = _card_identity(point)
		_show_at(point)
		return
	if _has_right_action(point) and d.m.u16(0xa1340a) == 0 and int(d.cursor_action) == 0:
		_press(MOUSE_BUTTON_LEFT, point)
		await get_tree().create_timer(1.5 / NativeClock.HZ).timeout
		_release(point)
	_dispatching = false

func _press(button: MouseButton, point: Vector2) -> void:
	_pressed_button = button
	var press := InputEventMouseButton.new()
	press.position = _scene_point(point)
	press.global_position = press.position
	press.button_index = button
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	press.pressed = true
	_dispatch_mouse(press)

func _release(point: Vector2 = _target) -> void:
	if _pressed_button == MOUSE_BUTTON_NONE: return
	var release := InputEventMouseButton.new()
	release.position = _scene_point(point)
	release.global_position = release.position
	release.button_index = _pressed_button
	release.pressed = false
	_dispatch_mouse(release)
	_pressed_button = MOUSE_BUTTON_NONE

func _scroll_candidate(point: Vector2) -> void:
	_scroll_kind = ""
	_scroll_node = null
	_scrolling = false
	_scroll_amount = 0.0
	_scroll_axis = ""
	if Game.has_active_root_dialog():
		_scroll_last = point
		_scroll_node = _scroll_control(get_tree().root, point)
		if _scroll_node != null:
			_scroll_kind = "control"
		return
	_scroll_last = _scene_point(point)
	var scene: Node = Game._screen
	if not is_instance_valid(scene):
		return
	var path: String = _screen_script_path()
	var local := _scroll_last
	if path.ends_with("deck_editor.gd"):
		if is_instance_valid(scene._modal):
			var modal_scr: Script = scene._modal.get_script()
			var modal_path: String = str(modal_scr.resource_path) if modal_scr != null else ""
			if modal_path.ends_with("deck_warning_dialog.gd"):
				var body: Control = scene._modal._body.get_parent()
				if body.get_global_rect().has_point(local):
					_scroll_kind = "bar"
					_scroll_node = scene._modal._scroll
			elif modal_path.ends_with("deck_file_dialog.gd") and scene._modal._list_rect.has_point(local - scene._modal.position):
				_scroll_kind = "files"
				_scroll_node = scene._modal
			return
		if local.x < 224 and local.y >= 370 and is_instance_valid(scene._detail_scroll):
			_scroll_kind = "bar"
			_scroll_node = scene._detail_scroll
		elif not scene._swap and scene._zone_at(local) == scene.BAG and scene._button_at(local) == "":
			_scroll_kind = "bag"
			_scroll_node = scene
	elif path.ends_with("card_list.gd"):
		if scene._text_clip.get_rect().has_point(local):
			if scene.has_method("_scroll_text"):
				_scroll_kind = "text"
				_scroll_node = scene
			else:
				_scroll_kind = "bar"
				_scroll_node = scene._scroll
		elif scene.has_method("_hit_slot"):
			if scene._hit_slot(local) != -1:
				_scroll_kind = "pages"
				_scroll_node = scene
		elif scene._hit(Vector2i(local)) >= 0 and scene._hit(Vector2i(local)) < scene.PER_PAGE:
			_scroll_kind = "pages"
			_scroll_node = scene
	elif PlatformInput._normal_duel_active():
		var list: Node = scene._list_window
		if is_instance_valid(list) and list.has_scroll and Rect2(Vector2(list.center) - Vector2(list.size) / 2, Vector2(list.size)).has_point(local):
			_scroll_kind = "list"
			_scroll_node = list
	if _scroll_kind == "":
		_scroll_node = _scroll_control(scene, local)
		if _scroll_node != null: _scroll_kind = "control"

func _scroll_control(node: Node, point: Vector2) -> Node:
	for child in node.get_children():
		var found := _scroll_control(child, point)
		if found != null: return found
	if node is ScrollContainer and node.is_visible_in_tree() and node.get_global_rect().has_point(point): return node
	return null

func _scroll_drag(point: Vector2) -> bool:
	if _scroll_kind == "" or not is_instance_valid(_scroll_node): return false
	var local := _scene_point(point)
	var distance := local - _scene_point(_start)
	var horizontal := _scroll_kind in ["pages", "list"]
	if not _scrolling:
		if distance.length() < 16: return true
		if _scroll_kind == "bag" and absf(distance.x) > absf(distance.y):
			_scroll_kind = ""
			return false
		_scrolling = true
		_selected_card = ""
		_scroll_axis = "x" if horizontal and absf(distance.x) > absf(distance.y) else "y"
		_menu.hide()
		_release()
	var delta := _scroll_last - local
	_scroll_last = local
	match _scroll_kind:
		"bar", "control":
			_scroll_amount += delta.y
			var pixels := int(_scroll_amount)
			_scroll_amount -= pixels
			if _scroll_kind == "bar": _scroll_node.set_value(_scroll_node.value + pixels)
			else: _scroll_node.scroll_vertical += pixels
		"text": _scroll_node._scroll_text(delta.y)
		_:
			_scroll_amount += delta.x if _scroll_axis == "x" else delta.y
			var pitch := 80.0 if _scroll_kind == "pages" else 32.0
			while absf(_scroll_amount) >= pitch:
				var step := 1 if _scroll_amount > 0 else -1
				_scroll_amount -= step * pitch
				if _scroll_kind == "pages":
					if _scroll_node.has_method("_turn_page"): _scroll_node._turn_page(step)
					else:
						var page := clampi(_scroll_node._page + step, 0, maxi(0, _scroll_node._pages - 1))
						if page != _scroll_node._page: _scroll_node._set_page(page, step > 0)
				elif _scroll_kind == "bag": _scroll_node._trunk_scroll = clampi(_scroll_node._trunk_scroll + step, 0, maxi(0, _scroll_node._view.size() - _scroll_node.TRUNK_ROWS))
				elif _scroll_kind == "files":
					_scroll_node._scroll = clampi(_scroll_node._scroll + step, 0, maxi(0, _scroll_node._files.size() - _scroll_node._visible_rows()))
					_scroll_node.queue_redraw()
				else:
					_scroll_node.row = clampi(_scroll_node.row + step, _scroll_node.row_min, _scroll_node.row_max)
					_scroll_node.queue_redraw()
	return true

func _card_identity(point: Vector2) -> String:
	if Game.has_active_root_dialog():
		return ""
	var scene: Node = Game._screen
	if not is_instance_valid(scene):
		return ""
	var path: String = _screen_script_path()
	var at := _scene_point(point)
	if path.ends_with("deck_editor.gd") and scene._modal == null:
		var hit: Dictionary = scene._hit_at(at)
		if not hit.is_empty(): return "deck:%s" % hit["key"]
	if PlatformInput._normal_duel_active() and not _duel_result_active(scene) and scene._duel != null and scene._duel.dialog_open.is_empty() and scene._duel.list_open.is_empty() and not _target_selection(scene):
		var hit: Dictionary = scene._hit_card(at)
		if not hit.is_empty():
			if int(hit["loc"]) == 13 and int(hit.get("p", -1)) == 0:
				return "duel:0:13:0:0"
			if int(hit["loc"]) >= 12: return "pile"
			return "duel:%s:%s:%s:%s" % [hit["p"], hit["loc"], hit["i"], hit["id"]]
	return ""

func _finish_card_tap(point: Vector2) -> void:
	if _touch_card.begins_with("duel:"):
		_preview_duel_card(point)
		var scene: Node = Game._screen
		if _duel_result_active(scene) or (is_instance_valid(scene) and _target_selection(scene)):
			_dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, point)
			return
		if _actions.is_empty() and is_instance_valid(scene) and scene._duel != null and _has_right_action(point):
			var live_actions: Array[int] = _extract_actions(scene._duel)
			if live_actions.is_empty() and _touch_card == "duel:0:13:0:0" and _can_surrender_deck(scene):
				live_actions = [9]
			if not live_actions.is_empty():
				_actions = live_actions
			elif not _card_prepared:
				_pending_release = true
				_prepare_card(point)
				return
		if not _actions.is_empty():
			_selected_card = _touch_card
			_show_at(point)
			return
		_selected_card = _touch_card
		if is_instance_valid(scene) and not _response_selection(scene) and _touch_card.begins_with("duel:0:"):
			_dispatch_help_click.call_deferred(point)
		return
	if _deck_touch:
		var scene: Node = Game._screen
		if is_instance_valid(scene) and scene.has_method("handle_mobile_card_tap"):
			scene.handle_mobile_card_tap(_scene_point(point))
		return
	_dispatch_click.call_deferred(MOUSE_BUTTON_LEFT, point)

func _material_selection(scene: Node) -> bool:
	if scene._duel == null: return false
	var action: int = scene._duel.m.u32(0xa13408)
	return (action & 2) != 0

func _response_selection(scene: Node) -> bool:
	if scene._duel == null: return false
	var d = scene._duel
	if not d.dialog_open.is_empty() or not d.list_open.is_empty(): return false
	if d.get("engine") != null and d.engine.get("m") != null:
		var jm = d.engine.m
		var flags: int = jm.u32(0xa58260)
		var state: int = jm.u32(0xa55ce8)
		var sp_priority: bool = (jm.u32(0xa55c84) & 0x10000) == 0 and (jm.u8(0xa55c88) & 1) == 0 and jm.u16(0xa55c84) == 0 and (state & 0x2000) != 0
		if (sp_priority or (flags & 0x20000) != 0) and ((state >> 5) & 63) == 10: return true
		var sp_chain: bool = (jm.u32(0xa55c84) & 0x10000) != 0 and ((jm.u16(0xa55c86) & 0xfe) >> 1) in [12, 14]
		if (sp_chain or (flags & 0x8000) != 0) and (state & 31) == 10: return true
		if (flags & 0x200) != 0 and (jm.u8(0xa55cea) & 127) == 2: return true
		return false
	var m = d.m
	if (m.u8(0xa16092) & 0x40) != 0 and m.u8(0xa16091) == 10: return true
	if (m.u8(0xa15fce) & 1) != 0 and (m.u8(0xa15fce) >> 1) in [12, 14] and m.u8(0xa16090) == 10: return true
	if (m.u16(0xa16092) >> 9) == 2 and (m.u32(0xa15a44) & 0x8000) != 0: return true
	return false

func _target_selection(scene: Node) -> bool:
	if scene._duel == null: return false
	var d = scene._duel
	if not d.dialog_open.is_empty() or not d.list_open.is_empty():
		return false
	if int(d.get("ui_target_selection_mask")) != 0 and not _response_selection(scene):
		return true
	var m = d.m
	if _material_selection(scene):
		return true
	if (m.u8(0xa15fce) & 1) != 0 and m.u8(0xa15fe0) in [0x78, 0x7d, 0x7e, 0x7f, 0x80]:
		return true
	if (m.u16(0xa13412) & 0x200) != 0:
		var act: int = m.u16(0xa13414) & 0x3f
		var step: int = m.u8(0xa13426)
		if (act == 17 and step == 2) or (act in [6, 7, 13, 16, 20] and step == 1) or act == 19:
			return true
	if d.get("engine") != null and d.engine.get("m") != null:
		if m.u8(0xa15fe5) != 0:
			return true
		var jm = d.engine.m
		var local_turn: bool = (m.u8(0xa133f2) & 1) == 0
		var turn_phase: int = (jm.u8(0xa577fa) >> 1) & 7
		if local_turn and turn_phase == 3 and jm.u8(0xa577fb) == 2 and jm.u8(0xa577fc) in [3, 20, 30, 100]:
			return true
		if local_turn and jm.u8(0xa577fd) == 1 and jm.u8(0xa577ff) == 122:
			return true
		var req: int = jm.u32(0xa57810)
		var local_p: int = int(d.local_native_player) if d.get("local_native_player") != null else 0
		if (req & 2) != 0 and ((req >> 2) & 1) == local_p:
			var req_kind: int = (req >> 3) & 0x3f
			var req_step: int = (req >> 9) & 0x1f
			if (req_kind == 8 and req_step == 2) or (req_kind in [5, 6, 17] and req_step in [1, 2]):
				return true
		return false
	var effect_running: bool = ((m.u8(0xa15fce) & 1) != 0 and (m.u8(0xa15fce) >> 1) in [3, 5]) or ((m.u32(0xa15a44) & 0x8000) != 0 and (m.u16(0xa16092) >> 9) in [4, 5])
	if effect_running and m.u8(0xa15fe5) != 0:
		return true
	var human_turn: bool = (m.u8(0xa133f2) & 1) == 0
	var phase: int = (m.u8(0xa133f2) >> 1) & 7
	var substep: int = (m.u16(0xa133f2) >> 7) & 0xff
	if human_turn and phase == 3 and substep == 2 and m.u8(0xa133f4) in [3, 20, 30, 100]:
		return true
	if human_turn and phase == 1 and m.u8(0xa133fc) == 122:
		return true
	return false

func _ui_label(kind: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match kind:
			"close": return "✕ إغلاق"
			"done": return "✓ تم"
			"undo": return "↩ تراجع"
			"choose_action": return "اختر الإجراء"
			"next_filter": return "الفلتر التالي"
			"prev_filter": return "الفلتر السابق"
			"select": return "اختيار"
			"drop": return "إفلات البطاقة"
			"sort": return "ترتيب"
			_: return "✕ إلغاء"
	if lang == "s":
		match kind:
			"close": return "✕ Cerrar"
			"done": return "✓ Listo"
			"undo": return "↩ Deshacer"
			"choose_action": return "Elige acción"
			"next_filter": return "Siguiente filtro"
			"prev_filter": return "Filtro anterior"
			"select": return "Seleccionar"
			"drop": return "Soltar selección"
			"sort": return "Ordenar"
			_: return "✕ Cancelar"
	match kind:
		"close": return "✕ Close"
		"done": return "✓ Done"
		"undo": return "↩ Undo"
		"choose_action": return "Choose action"
		"next_filter": return "Next filter"
		"prev_filter": return "Previous filter"
		"select": return "Select"
		"drop": return "Drop card"
		"sort": return "Sort"
		_: return "✕ Cancel"

func _cancel_context() -> String:
	var scene: Node = Game._screen
	if not is_instance_valid(scene) or not PlatformInput._normal_duel_active() or scene._duel == null:
		return ""
	if _menu.visible:
		return "menu"
	var d = scene._duel
	if not d.list_open.is_empty():
		var lw: Node = scene._list_window
		if is_instance_valid(lw) and not lw.closing:
			if lw.mode == 0:
				return "close"
			if lw.native_selection:
				return "done" if lw.allow_early_close and lw.marks > 0 else ""
			if lw.mode in [2, 3] and lw.marks > 0:
				return "undo"
		return ""
	if not d.dialog_open.is_empty():
		if d.dialog_open.get("closing", false):
			return ""
		var dtype := int(d.dialog_open.get("type", 0))
		if dtype in [8, 9]:
			return "cancel"
		if dtype == 3 and int(d.dialog_open.get("default", -1)) >= 0:
			return "cancel"
		return ""
	if scene._visual != null and scene._visual.busy():
		return ""
	if _target_selection(scene) or _response_selection(scene):
		return "cancel"
	return ""

func _update_cancel_button() -> void:
	var ctx := _cancel_context()
	if ctx == "":
		_cancel_btn.hide()
		return
	_cancel_btn.text = _ui_label(ctx if ctx in ["close", "done", "undo"] else "cancel")
	var bounds := get_viewport().get_visible_rect()
	var avoid_top_hand := false
	var scene: Node = Game._screen
	if ctx == "cancel" and is_instance_valid(scene) and scene.get("_duel") != null:
		var d = scene._duel
		var mask := int(d.get("ui_target_selection_mask"))
		if (mask & 0x10000) != 0 or (d.has_method("hand_face_up") and d.hand_face_up(1)):
			avoid_top_hand = true
	if avoid_top_hand:
		_cancel_btn.position = Vector2(bounds.position.x + 12.0, bounds.end.y - _cancel_btn.size.y - 12.0)
	else:
		_cancel_btn.position = Vector2(bounds.end.x - _cancel_btn.size.x - 14.0, bounds.position.y + 12.0)
	_cancel_btn.show()

func _trigger_cancel() -> void:
	var ctx := _cancel_context()
	_menu.hide()
	_selected_card = ""
	_touch_card = ""
	_touch_active = false
	_preparing = false
	_pending_release = false
	_release()
	if ctx in ["", "menu"]:
		return
	var bounds := get_viewport().get_visible_rect()
	_dispatch_click.call_deferred(MOUSE_BUTTON_RIGHT, bounds.position + Vector2(4, 4))

func _update_tribute_hint() -> void:
	_tribute_hint.hide()
	var scene: Node = Game._screen
	if not is_instance_valid(scene) or not PlatformInput._normal_duel_active() or scene._duel == null: return
	var d = scene._duel
	var action: int = d.m.u32(0xa13408)
	if not _material_selection(scene) or ((action >> 2) & 15) not in [0, 4] or not d.dialog_open.is_empty(): return
	var state: int = d.m.u8(0xa1340d)
	if state not in [2, 3, 4, 5, 10, 11]: return
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		_tribute_hint.text = "اضغط على وحش للتضحية به" if state in [10, 11] else "اختر التضحية الأولى" if state in [2, 3] else "اختر التضحية الثانية"
	elif lang == "s":
		_tribute_hint.text = "Toca un monstruo para sacrificarlo" if state in [10, 11] else "Selecciona el primer sacrificio" if state in [2, 3] else "Selecciona el segundo sacrificio"
	else:
		_tribute_hint.text = "Tap a monster to Tribute" if state in [10, 11] else "Select first Tribute" if state in [2, 3] else "Select second Tribute"
	var bounds := get_viewport().get_visible_rect()
	_tribute_hint.position = bounds.position + Vector2(4, 8)
	_tribute_hint.size = Vector2(bounds.size.x - 8, 36)
	_tribute_hint.show()
