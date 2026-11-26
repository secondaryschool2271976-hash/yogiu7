extends "res://scenes/duel/replay_viewer.gd"
## Partida humana: reutiliza el tablero del visor y responde al motor original.
## El mazo activo se lee; esta escena no guarda premios ni modifica la partida.

var _source := ""
var _event_pos := 0
## Peticion ui_request ya avisada (ninguna rutina portada la usa ya; 56a460 usa cursor y cuadros).
var _ui_reported := false
## Clics desde el ultimo fotograma del motor (0x200 izquierdo, 0x100 derecho; ver 0x5407f0).
var _press_bits := 0
## Ventana de la lista de seleccion (duel_list_window.gd) mientras existe.
var _list_window: Node2D = null
## Panel de fases (objeto DAT_005af874, 0x4614b0): phase.txt da las posiciones x*1000+y
## (207,49+82n) de las hojas pha_s_* (2x2 celdas de 40x90) y las tiras de volteo pha_b_*/pha_r_*
## (9 celdas de 40x90) usadas al cambiar de jugador.
const PHASE_ORIGIN := Vector2(207, 49)
const PHASE_STEP := 82
const PHASE_CELL := Vector2(40, 90)
var _ph_clock := 0.0
static var _phase_add_material: CanvasItemMaterial
var _ph_blend := NativeBlend.new()   # fundido y pulso de la ficha de la fase entre ticks
## Ticks nativos pendientes para el motor (un paso de 53dbf0 por tick).
var _engine_clock := 0.0
## El motor compartido completa op14 al emitirlo; Kaiba aun debe consumir
## la vuelta de acuse405450 despues de retirarse el objeto.
var _start_banner_ack := false
var _phase_mask: Image
## `start_options`: opciones de 0x5418a0 (bit 0 = quien empieza) que deja el piedra-papel-tijera
## en DAT_005af770; -1 = sin janken (empieza la CPU, como hasta ahora).
var _start_options := -1
var _replay_decks: Array[Dictionary] = []
var _replay_options := 0
var _replay_seed := 0
## Duelo LAN (Game.duel_mode 3 con sesion activa).
var _lan := false
## Cartel de espera del rival en red (Joey 456360).
var _wait_label: DuelWaitLabel = null
const ONLINE_TURN_LIMIT_SEC := 120.0
const ONLINE_OPPONENT_GRACE_SEC := 10.0
var _online_timer_enabled := false
var _online_turn_left := ONLINE_TURN_LIMIT_SEC
var _online_turn_owner := -1
var _online_auto_ending := false
var _online_auto_tick := 0
var _online_auto_elapsed := 0.0
var _online_resp_wait := 0.0
var _online_resp_auto_decline := false
var _online_net_wait_stuck := 0.0
var _online_timer_paused := false
var _forfeit_handled := false
var _online_timer_panel: Control = null
var _online_timer_border: ColorRect = null
var _online_timer_who_label: Label = null
var _online_timer_label: Label = null
var _online_timer_bar: ColorRect = null
var _resume_snapshot: Dictionary = {}
var _cached_resume_snapshot: Dictionary = {}
var _last_saved_executed := -1


func _init(game_id: String, start_options := -1, resume_snapshot: Dictionary = {}) -> void:
	super(game_id, "demo")
	_phase_layer = Node2D.new()
	_start_options = start_options
	_resume_snapshot = resume_snapshot


func _create_duel() -> Duel:
	return Duel.create(Paths.data_dir, game)


func _prepare_duel_decks(decks: Array[Dictionary]) -> Array[Dictionary]:
	return decks

func _ready() -> void:
	var dialogs: Variant = Assets.dialog_texts()
	_dialogs = dialogs if dialogs is Array else []
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.size = Vector2(800, 600)
	# Sin esto el ColorRect se queda el raton y no llega a las ventanas modales (PocDialog).
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_setup_detail()
	_setup_field()
	#481040: fases0xf0 (Kaiba/Yugi0xff), pilas0x100: las cartas tapan
	#el fondo opaco de las fichas que alcanza los primeros pixeles de las pilas.
	_setup_phase_panel()
	add_child(_board)
	_setup_cursor()
	_info = _label(Vector2(238, 66), Vector2(552, 22), 12)
	_log = _label(Vector2(240, 280), Vector2(300, 60), 12)
	_log.clip_text = true
	# El original no escribe turno, fase ni mensajes sobre el tablero: solo el panel de
	# fases, los cuadros y el panel de detalle. Estas etiquetas solo se usan si faltan datos.
	_info.visible = false
	_log.visible = false
	_duel = _create_duel()
	if _duel == null:
		_log.text = "بيانات محرك المبارزة غير موجودة." if Assets.lang == "a" else ("Faltan los datos del motor de duelo." if Assets.lang == "s" else "Duel engine data is missing.")
		_log.visible = true
		return
	if not _resume_snapshot.is_empty():
		if DuelResume.restore_duel(_duel, _resume_snapshot):
			_lan = false
			var raw_decks: Variant = _resume_snapshot.get("replay_decks", [])
			_replay_decks.clear()
			if raw_decks is Array:
				for deck_entry: Variant in raw_decks:
					if deck_entry is Dictionary:
						_replay_decks.append((deck_entry as Dictionary).duplicate(true))
			_replay_options = int(_resume_snapshot.get("replay_options", 0))
			_replay_seed = int(_resume_snapshot.get("replay_seed", 0))
			_ph_p = int(_resume_snapshot.get("ph_p", _duel.m.u16(0xa133f2) & 1))
			_ph_phase = int(_resume_snapshot.get("ph_phase", (_duel.m.u16(0xa133f2) >> 1) & 7))
			_ph_intro = 0x200
			_ph_fade = 0x100
			_last_saved_executed = _duel.executed
			_cached_resume_snapshot = _resume_snapshot.duplicate(true)
			var resume_mask_tex := Assets.texture("kaiba/duel/phase/ph_b_dr.png" if game == "kaiba" else "%s/duel/phase/pha_s_dr.png" % game)
			_phase_mask = resume_mask_tex.get_image() if resume_mask_tex != null else null
			_duel.input_right_held_query = func() -> bool: return PlatformInput.mouse_pressed(MOUSE_BUTTON_RIGHT)
			_setup_presentation(true)
			_visual._phase_player = _ph_p
			_visual._field_value = preload("res://scenes/duel/duel_field_visual.gd").terrain(_duel)
			if _ph_phase == 3:
				_visual._battle = {"state": 1, "counter": 0, "p": _ph_p, "zone": -1}
				_visual._phase_was_battle = true
			_hand_positions.clear()
			_sync_hand_layout()
			_help = DuelHelp.new()
			_help.setup(game)
			add_child(_help)
			Audio.play_music(preload("res://scenes/duel/duel_music.gd").path(game, Game.duel_mode, _shown_lp()))
			_redraw()
			return
		DuelResume.clear()
		_resume_snapshot = {}
	# Deck.ydc y file/deck_y/k/j.txt convertidos por pocx; Joey no trae demos.ydr.
	var decks: Array[Dictionary] = []
	for name in ["starter_deck", "rival_deck"]:
		var original: Variant = Assets.read_json("%s/file/%s.json" % [game, name])
		if not original is Dictionary:
			push_error("Mazo original no encontrado: %s/file/%s.json" % [game, name])
			_log.text = ("المجموعة الأصلية لـ %s غير موجودة." % game) if Assets.lang == "a" else (("Falta el mazo original de " + game + ".") if Assets.lang == "s" else ("Missing original deck for " + game + "."))
			_log.visible = true
			return
		decks.append({"main": PackedInt32Array(original.get("main", [])), "side": PackedInt32Array(original.get("side", [])), "fusion": PackedInt32Array(original.get("fusion", []))})
	# Mazo de Yugi elegido por 0x437c60 al entrar desde el menu (cpu*.ydc convertido a json).
	var rival: Variant = Assets.read_json(Game.rival_deck) if Game.rival_deck != "" and Paths.cmdline_value("scenario") == "" else null
	if rival is Dictionary:
		decks[1] = {"main": PackedInt32Array(rival.get("main", [])), "side": PackedInt32Array(rival.get("side", [])),
				"fusion": PackedInt32Array(rival.get("fusion", []))}
	var active: Dictionary = SaveData.data.get("decks", {}).get(game, {})
	var is_lan_mode := Game.duel_mode == 3 and Lan.active()
	var preset_player_path := LauncherSettings.get_offline_player_deck(game) if (not is_lan_mode and not Game.joey_demo and Paths.cmdline_value("scenario") == "" and is_instance_valid(LauncherSettings)) else ""
	var preset_player: Variant = Assets.read_json(preset_player_path) if (preset_player_path != "" and Assets.exists(preset_player_path)) else null
	if preset_player is Dictionary and (preset_player as Dictionary).get("main", []).size() >= 40:
		var pd: Dictionary = preset_player
		decks[0] = {"main": PackedInt32Array(pd.get("main", [])), "side": PackedInt32Array(pd.get("side", [])), "fusion": PackedInt32Array(pd.get("fusion", []))}
		_source = (("مجموعة جاهزة: " + preset_player_path.get_file()) if Assets.lang == "a" else (("Mazo listo: " + preset_player_path.get_file()) if Assets.lang == "s" else ("Preset deck: " + preset_player_path.get_file())))
	elif active.get("main", []).size() >= 40 and active.get("main", []).size() <= 80:
		decks[0] = {"main": PackedInt32Array(active.get("main", [])), "side": PackedInt32Array(active.get("side", [])), "fusion": PackedInt32Array(active.get("fusion", []))}
		_source = (("مجموعتك النشطة · الخصم: " + (Game.rival_deck.get_file() if rival is Dictionary else "المجموعة الأصلية")) if Assets.lang == "a" else (("Tu mazo activo · rival: " + (Game.rival_deck.get_file() if rival is Dictionary else "mazo original")) if Assets.lang == "s" else ("Active deck · rival: " + (Game.rival_deck.get_file() if rival is Dictionary else "original deck"))))
	else:
		_source = "المجموعات الأصلية (لا توجد مجموعة نشطة صالحة)" if Assets.lang == "a" else ("Mazos originales (sin mazo activo válido)" if Assets.lang == "s" else "Original decks (no valid active deck)")
	decks = _prepare_duel_decks(decks)
	if decks.size() != 2:
		_log.text = "تعذر تجهيز مجموعتي المبارزة." if Assets.lang == "a" else ("No se pudieron preparar los dos mazos del duelo." if Assets.lang == "s" else "Could not prepare both duel decks.")
		_log.visible = true
		set_process(false)
		return
	# Herramienta de desarrollo: --scenario=<nombre> prepara mano y campo (ver DuelScenario).
	var scenario: DuelScenario = null
	var scenario_name := Paths.cmdline_value("scenario")
	if scenario_name != "":
		scenario = DuelScenario.load_named(scenario_name)
		if scenario == null:
			printerr("Escenario no encontrado: ", scenario_name, " (disponibles: ", ", ".join(DuelScenario.list()), ")")
	var first := 1 if _start_options < 0 else _start_options
	# Con --ui-replay, la semilla del duel_start de la traza (la que el original pasa a 5418a0).
	var rand_seed := Debug.next_duel_seed()
	if rand_seed < 0:
		rand_seed = int(Time.get_unix_time_from_system()) & 0x7fffffff
	if scenario != null:
		decks = scenario.build_decks(decks)
		first = scenario.first
		if scenario.seed >= 0:
			rand_seed = scenario.seed
		_source = ("السيناريو: " if Assets.lang == "a" else ("Escenario: " if Assets.lang == "s" else "Scenario: ")) + scenario_name
	# Duelo LAN de Joey (D17, modo 3): mazo del rival recibido con 0xf004 y semilla de la
	# sesion (0xf005); cada lado se ve como jugador 0 y el rival llega por la red.
	_lan = Game.duel_mode == 3 and Lan.active()
	if _lan:
		var local_lan: Dictionary = Game.lan_local_deck
		if local_lan.get("main", []).size() >= 40:
			decks[0] = {"main": PackedInt32Array(local_lan.get("main", [])), "side": PackedInt32Array(local_lan.get("side", [])),
					"fusion": PackedInt32Array(local_lan.get("fusion", []))}
		var remote: Dictionary = Game.lan_rival_deck
		decks[1] = {"main": PackedInt32Array(remote.get("main", [])), "side": PackedInt32Array(remote.get("side", [])),
				"fusion": PackedInt32Array(remote.get("fusion", []))}
		rand_seed = Game.lan_seed
		if Lan.is_online():
			_source = ("مبارزة أونلاين ضد " if Assets.lang == "a" else ("Duelo Online contra " if Assets.lang == "s" else "Online Duel vs ")) + Lan.remote_name
		else:
			_source = ("مبارزة LAN ضد " if Assets.lang == "a" else ("Duelo LAN contra " if Assets.lang == "s" else "LAN Duel vs ")) + Lan.remote_name
		if scenario != null:
			printerr("Escenario ignorado en el duelo LAN")
			scenario = null
		_duel.start_network(decks, first, rand_seed, Lan)
		_wait_label = DuelWaitLabel.new()
		_wait_label.setup(game)
		_online_timer_enabled = true
		add_child(_wait_label)
	else:
		_duel.start_normal(decks, first, rand_seed)
	_replay_decks = decks
	_replay_options = first
	_replay_seed = rand_seed
	if scenario != null:
		for warning in scenario.apply(_duel):
			printerr("Escenario: ", warning)
	_ph_p = _duel.options & 1
	# Hoja con la que se comprueba el raton: pha_s_dr en Yugi, ph_b_dr (indice 0) en Kaiba.
	var mask_tex := Assets.texture("kaiba/duel/phase/ph_b_dr.png" if game == "kaiba" else "%s/duel/phase/pha_s_dr.png" % game)
	_phase_mask = mask_tex.get_image() if mask_tex != null else null
	_duel.input_right_held_query = func() -> bool: return PlatformInput.mouse_pressed(MOUSE_BUTTON_RIGHT)
	_setup_presentation(true)
	_help = DuelHelp.new()
	_help.setup(game)
	add_child(_help)
	if _online_timer_enabled:
		_setup_online_timer_hud()
	Audio.play_music(preload("res://scenes/duel/duel_music.gd").path(game, Game.duel_mode, _shown_lp()))
	_redraw()

func _process(_delta: float) -> void:
	if _duel == null or _forfeit_handled:
		return
	if _lan:
		Lan._poll()
	if _lan and not _finished and _result == null:
		var net_lost := Lan.terminated or (_duel.m.u8(0xa133f2) & 0x10) != 0
		if net_lost and _duel.winner() == 0:
			_handle_online_disconnect()
			return
	var vis_delta := _delta * (1.65 if _lan else 1.0)
	# Ka437f80 / Jo44dd00: los objetos de mascara1 solo avanzan con
	# sombreado apagado y contador0. El tick que crea op14 ya paso por aqui;
	# el que termina de cerrarlo sigue congelado y se reanuda en el siguiente.
	var mask_one_active: bool = _visual == null or not _visual._start_banner_shade
	if mask_one_active:
		_tick_card_stats(vis_delta)
	if _visual != null:
		_visual.pointer = _pointer_pos
	if mask_one_active:
		_ph_clock += NativeClock.ticks(vis_delta)
		while _ph_clock >= 1.0:
			_ph_clock -= 1.0
			_ph_blend.tick()
			_phase_panel_tick()
			if _duel.dialog_open.is_empty() and _duel.list_open.is_empty():
				_step_pointer()
		_ph_blend.fraction = _ph_clock
		_draw_phase_panel()
	# El original llama a 53dbf0 una vez por vuelta del bucle principal (NativeClock.HZ): el
	# motor da un paso por tick nativo, aunque la pantalla se dibuje mas a menudo.
	_engine_clock = minf(_engine_clock + NativeClock.ticks(vis_delta), 4.0)
	var steps := int(_engine_clock)
	_engine_clock -= steps
	if _help != null: _help.show_between(_engine_clock)
	var start_shade: bool = _visual != null and _visual._start_banner_shade
	var presenting := _advance_visual(vis_delta)
	if game in ["yugi", "kaiba"] and start_shade and not _visual._start_banner_shade:
		_start_banner_ack = true
	if _wait_label != null:
		# 44ba10: sin cartel mientras hay objetos de presentacion activos.
		_wait_label.waiting = not presenting and _duel.net_waiting()
	if _online_timer_enabled and not _finished and _result == null:
		_step_online_timer(_delta, presenting)
		if _forfeit_handled:
			return
	if presenting:
		if _lan and not _finished and not (_duel is JoeyPresentationAdapter):
			if _duel.has_method("f53eda0"):
				_duel.call("f53eda0")
		# El motor no lee el raton mientras la presentacion lo detiene: el clic se pierde.
		if steps > 0: _press_bits = 0
		return
	if _start_banner_ack:
		if steps > 0:
			_start_banner_ack = false
			_press_bits = 0
		return
	if _finished:
		if _forfeit_handled:
			return
		# 53eda0 sin sesion (bit 4 de a133f2): el rival se fue; vuelta al titulo o victoria por abandono en online.
		if _lan and (_duel.m.u8(0xa133f2) & 0x10) != 0 and _duel.winner() == 0:
			_handle_online_disconnect()
			return
		if _online_timer_panel != null and is_instance_valid(_online_timer_panel):
			_online_timer_panel.visible = false
		_start_result()
		return
	if steps == 0:
		if _lan and (not Lan._incoming.is_empty() or _press_bits != 0):
			steps = 1
		else:
			return
	if _online_resp_auto_decline and (_duel.m.u16(0xa133f2) & 1) != 0:
		_press_bits = 0
		_online_step_auto_end(steps, true)
		return
	if _online_auto_ending and (_duel.m.u16(0xa133f2) & 1) == 0:
		_press_bits = 0
		_online_step_auto_end(steps, false)
		return
	var before := _duel.executed
	if not _duel.dialog_open.is_empty():
		_duel.set_frame_input(_press_bits, 0, _hover_input(), -1)
		_press_bits = 0
		# 53dbf0 ejecuta la cola antes de540db0. Los selectores8/9 emiten
		# descartes/materiales mientras la ventana sigue ocupando la ranura.
		if int(_duel.dialog_open.get("type", 0)) in [8, 9]:
			for _i in range(steps):
				_duel.frame()
			_collect_visual_events()
			_redraw()
		_show_dialog()
		return
	if not _duel.list_open.is_empty():
		_show_list()
		return
	var hover := _hover_input()
	var phase_hover := _phase_hover()
	var max_loop_steps := maxi(steps, 6) if _lan else steps
	for step_idx in range(max_loop_steps):
		if _lan:
			Lan._poll()
		if not _duel.ui_pending.is_empty():
			# No hay menus propios: una peticion asi seria un hueco del porte.
			if not _ui_reported:
				printerr("Peticion de interfaz sin ventana del original: ", _duel.ui_pending)
				_ui_reported = true
			break
		# 0x5407f0: los clics valen para un solo fotograma del motor.
		_duel.set_frame_input(_press_bits, 0, hover, phase_hover)
		var confirm_mask := 0x201 if game == "joey" else 0x200
		var clicked := (_press_bits & confirm_mask) != 0
		_press_bits = 0
		if not _duel.frame():
			_finished = true
		# FUN_004437b0: ayuda emergente con el indice que ha pedido el motor en este fotograma.
		if _help != null:
			var help_hover := {}
			var acknowledged := _duel is JoeyPresentationAdapter and (_duel as JoeyPresentationAdapter).cursor_acknowledged()
			if not acknowledged and not hover.is_empty():
				help_hover = hover.duplicate()
				help_hover["pos"] = _help_pos(hover)
			_help.step(_duel, help_hover, clicked)
		_duel.set_frame_input(0, 0, hover, phase_hover)
		if _collect_visual_events(): break
		if not _duel.unported_calls.is_empty():
			printerr("Rutinas pendientes: ", _duel.unported_calls.keys().map(func(a): return "0x%06x" % a))
			_text = "هذا الإجراء غير متاح بعد في هذه النسخة." if Assets.lang == "a" else ("Esta acción todavía no está disponible en esta versión. Puedes volver al título con Esc." if Assets.lang == "s" else "This action is not available yet in this version.")
			_finished = true
			break
		if not _duel.dialog_open.is_empty():
			_show_dialog()
			break
		if not _duel.list_open.is_empty():
			_show_list()
			break
		if _finished or _waiting_for_player() or (_duel.m.u8(0xa13408) & 3) != 0:
			break
		if _lan:
			if _duel.net_waiting() and Lan._incoming.is_empty():
				break
		elif _duel.executed != before:
			break
	_refresh_cursor(true)
	_collect_events()
	if _finished:
		_cached_resume_snapshot.clear()
		DuelResume.clear()
		if _duel.unported_calls.is_empty():
			if Assets.lang == "a":
				_text = "انتهت المبارزة: " + ("فزت!" if _duel.winner() == 1 else "فاز الكمبيوتر" if _duel.winner() == 2 else "تعادل")
			elif Assets.lang == "s":
				_text = "Fin del duelo: " + ("ganaste" if _duel.winner() == 1 else "ganó la CPU" if _duel.winner() == 2 else "empate")
			else:
				_text = "Duel ended: " + ("you won" if _duel.winner() == 1 else "CPU won" if _duel.winner() == 2 else "draw")
		_redraw()
		return
	if before != _duel.executed:
		_redraw()
	save_resume_state(false)


func save_resume_state(force := false) -> void:
	if _duel == null or _finished or _lan or Game.joey_demo:
		return
	if DuelResume.is_clean_state(self):
		if force or _duel.executed != _last_saved_executed:
			var snap: Dictionary = DuelResume.capture(self)
			if not snap.is_empty():
				_cached_resume_snapshot = snap
				_last_saved_executed = _duel.executed
				DuelResume.save_snapshot(snap)
	elif force and not _cached_resume_snapshot.is_empty():
		DuelResume.save_snapshot(_cached_resume_snapshot)


## 540af0/4600f0: un paso del objeto global por tick; el motor consulta el destino.
func _step_pointer() -> void:
	var at := PointerGlide.step(self, _pointer_pos)
	if at != _pointer_pos:
		_pointer_pos = at
		_hover_card = _hit_card(PointerGlide.hover(at))
		_refresh_cursor(true)

var _help: DuelHelp
var _result: DuelResult


## Repeticion de este duelo (lo que graba 0x436f60): mazos, opciones, semilla y los comandos
## emitidos (DuelBase.recorded). La version del duelo es (DAT_005aed1c + 1) * 100.
func make_replay() -> Ydr:
	var r := Ydr.new()
	r.version = 1
	r.deck_mark = int(Time.get_unix_time_from_system()) & 0xffffffff
	r.duel_version = _duel.native_version if game == "joey" else {"yugi": 100, "kaiba": 200}.get(game, 100)
	r.options = _replay_options
	r.seed = _replay_seed
	r.decks = _replay_decks.duplicate(true)
	r.commands = _duel.recorded.duplicate()
	return r


## 0x4379d0 -> escena de resultado (0x435410) cuando el duelo termina y acaba el cartel.
func _start_result() -> void:
	if _result != null or not _duel.unported_calls.is_empty() or _duel.winner() == 0:
		return
	_cached_resume_snapshot.clear()
	DuelResume.clear()
	var winner := _duel.winner()
	# 0x53d9d0 -> 0x437440: resultado del duelo y, en match, el global.
	Game.record_duel_result(winner)
	# 0x435410: el cartel pasa a la escena de resultado (que lo encoge si gana; en match,
	# siempre, junto al tablero).
	if winner == 1 or Game.duel_mode == 1:
		_visual.end_banner = ""
		_visual._render()
	_result = DuelResult.new()
	var surrendered: bool = _duel is JoeyPresentationAdapter and (_duel.engine.m.u16(JoeyMem.MODE) & 0x40) != 0
	_result.setup(game, winner, _duel.m.u32(0xa114b4), surrendered)
	# Estado 7 de 0x435410: match sin decidir -> escena 10 y siguiente duelo; si no, la salida
	# de Yugi con el resultado global. La musica la gestiona Game: en Yugi sigue sonando.
	_result.finished.connect(func() -> void:
		if Game.duel_mode == 1 and Game.match_outcome == 0:
			Game.continue_match(game)
		else:
			Game.finish_normal_duel(game, Game.match_outcome if Game.duel_mode in [0, 1, 3] else winner))
	add_child(_result)


## Posicion actual del objeto de la carta (0x410020): la mano usa su posicion animada.
func _help_pos(h: Dictionary) -> Vector2:
	var p: int = h["p"]
	var loc: int = h["loc"]
	var i: int = h["i"]
	if loc == 11:
		var n := _duel.m.u8(DuelMem.pl(p) + 2)
		return _hand_positions.get(p * 256 + i, DuelGeometry.hand(p, i, n))
	return DuelGeometry.location(p, loc, i)


## El turno del humano espera su entrada: fase principal o de batalla sin comandos en curso.
func _waiting_for_player() -> bool:
	return (_duel.m.u16(0xa133f2) & 1) == 0 and not _duel.is_running() 			and _duel.m.u16(DuelMem.QUEUE_COUNT) == 0 and _duel.m.u8(0xa16180) >= 2 			and _duel.m.u8(0xa16180) < 8


## Objeto bajo el cursor tal como lo ve el original: jugador, ubicacion, posicion y la carta
## (indice) del objeto visual. El mazo tambien es un objeto (ubicacion 0xd).
func _hover_input() -> Dictionary:
	if _hover_card.is_empty():
		var selecting_zone := _duel != null and (
			_duel.ui_target_selection_mask != 0
			or _duel.m.u8(0xa15fe5) != 0
			or (_duel is JoeyPresentationAdapter and (_duel as JoeyPresentationAdapter).engine != null and (_duel as JoeyPresentationAdapter).engine.m.u8(0xa55c8e) != 0)
		)
		if selecting_zone:
			var z := _hit_zone(PointerGlide.hover(_pointer_pos))
			if not z.is_empty() and int(z.get("loc", -1)) == 0:
				return {"p": int(z["p"]), "loc": 0, "i": int(z["i"]), "card": 0}
		return {}
	var p: int = _hover_card["p"]
	var loc: int = _hover_card["loc"]
	var i: int = _hover_card["i"]
	var card := 0
	if loc != 13:
		card = _duel.m.u16(_duel.f5419b0(p, loc, i)) & 0xfff
	return {"p": p, "loc": loc, "i": i, "card": card}


## 0x460f80: ficha bajo el puntero o -1. No responde mientras el panel anima (vtable +4 =
## 0x460b80). x relativa a la columna (0 <= x < 40, mitad del ancho de la hoja); para cada
## ficha en orden, y relativa a su posicion < 90 (mitad del alto) y el pixel (x, y) de la
## hoja 0 (pha_s_dr) no transparente (vtable +0x6c). Las fichas se solapan 8 px: gana la
## primera con pixel opaco.
func _phase_hover() -> int:
	if _phase_busy() or _phase_mask == null or _finished or _result != null:
		return -1
	if _duel == null or not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
		return -1
	if not _hover_card.is_empty():
		return -1
	if is_instance_valid(Game._mobile_pointer) and (Game._mobile_pointer._menu.visible or Game._mobile_pointer._preparing or Game._mobile_pointer._executing_card_action):
		return -1
	var pos := Vector2i(_pointer_pos.floor())
	if game == "kaiba":
		return _phase_hover_kaiba(pos)
	if game == "joey":
		# Jo4812e0: rectangulo 29x54, y relativa en [3,57), sin mascara de pixeles.
		var x := pos.x - _ph_pos[0][0]
		if x < 0 or x >= 29: return -1
		for k in 6:
			var y := pos.y - _ph_pos[k][1]
			if y >= 3 and y < 57: return k
		return -1
	var x := pos.x - int(PHASE_ORIGIN.x)
	if x < 0 or x >= int(PHASE_CELL.x):
		return -1
	for k in 6:
		var y := pos.y - int(PHASE_ORIGIN.y) - PHASE_STEP * k
		if y < int(PHASE_CELL.y) and y >= 0 and _phase_mask.get_pixel(x, y).a > 0.5:
			return k
	return -1


## Kaiba 0x463100: x relativa a la ficha 0 dentro de la primera celda (ancho / 8) y el pixel
## (x, y - y de la ficha k) de ph_b_dr no transparente (vtable +0x6c); gana la primera ficha.
func _phase_hover_kaiba(pos: Vector2i) -> int:
	var cell_w := _phase_mask.get_width() / 8
	var x := pos.x - _ph_pos[0][0]
	if x < 0 or x >= cell_w:
		return -1
	for k in 6:
		var y := pos.y - _ph_pos[k][1]
		if y >= 0 and y < _phase_mask.get_height() and _phase_mask.get_pixel(x, y).a > 0.5:
			return k
	return -1


## 0x460b80: el panel esta animando (volteo de entrada o fundido de la fase actual).
func _phase_busy() -> bool:
	return _ph_intro < 0x200 or _ph_fade < 0x80


func _collect_visual_events() -> bool:
	for n in range(_visual_event_pos, _duel.events.size()):
		var e: Dictionary = _duel.events[n]
		if e.get("kind", "") == "phase":
			_phase_panel_set(int(e.get("p", 0)) & 1, int(e.get("phase", 0)))
	return super._collect_visual_events()


## Ventana de la lista de seleccion del original (FUN_0042e820) mientras el motor la tiene
## abierta (Duel.list_open); se crea al aparecer y se libera sola al cerrarse.
func _show_list() -> void:
	if _list_window != null and is_instance_valid(_list_window):
		return
	_list_window = preload("res://scenes/duel/duel_list_window.gd").new()
	_list_window.setup(self, _duel, game)
	add_child(_list_window)


func _cursor_action() -> int:
	if _duel == null or not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
		return -1
	return _duel.cursor_action if _duel.cursor_action > 0 else -1


func _input(event: InputEvent) -> void:
	if Game.has_active_root_dialog():
		return
	super._input(event)
	if event is InputEventMouseButton and event.pressed and _duel != null:
		if not _duel.dialog_open.is_empty() and int(_duel.dialog_open.get("type", 0)) not in [8, 9]:
			return  # la ventana del cuadro atiende sus propios clics
		if event.button_index == MOUSE_BUTTON_LEFT:
			_press_bits |= 0x200
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_press_bits |= 0x100


## Ventana del cuadro de dialogo del original (duel_dialog_window.gd; 431db0, 431ee0, 432050,
## 432240, 432400, 432570, 4326a0). El texto lo compone _dialog_text.
func _show_dialog() -> void:
	if _dialog_box != null and is_instance_valid(_dialog_box):
		return
	_dialog_box = null
	var window: Node2D = preload("res://scenes/duel/duel_dialog_window.gd").new()
	window.setup(self, _duel, game, _dialog_text(_duel.dialog_open))
	add_child(window)
	_dialog_box = window


## Texto del cuadro con las sustituciones del motor (DuelBase._dialog_subs): el nombre de una
## carta o el texto de otro mensaje en el primer "%s" (0x53fac0), un numero en el primer "%d"
## (0x53fb40) y "<BR>" + otro mensaje al final (0x53f9f0).
func _dialog_text(d: Dictionary) -> String:
	return preload("res://scenes/duel/duel_dialog_text.gd").format(_dialogs, d, true)


func _answer_dialog(value: int) -> void:
	if _dialog_box != null and is_instance_valid(_dialog_box):
		_dialog_box.begin_close()
		_duel.dialog_close(value)
	else:
		_dialog_box = null
		_duel.answer_dialog(value)
	_refresh_cursor(true)


func _dialog_gone(window: Node2D) -> void:
	if _dialog_box != window:
		return
	_dialog_box = null
	_duel.dialog_gone()
	_refresh_cursor(true)


func _collect_events() -> void:
	while _event_pos < _duel.events.size():
		var e: Dictionary = _duel.events[_event_pos]
		_event_pos += 1
		var data: Dictionary = e
		_detail_event(data)
		if data.get("kind", "") == "cursor" and _duel.ui_key_cursor:
			# FUN_0053f7e0 -> FUN_00540bd0/00540af0: el teclado desliza el puntero.
			var at = DuelGeometry.location(int(data["p"]) & 1, int(data["loc"]), int(data["i"]), _duel.m.u8(DuelMem.pl(int(data["p"]) & 1) + 2))
			if game == "joey" and int(data["loc"]) == DuelMem.LOC_BANISH:
				at = DuelGeometry.JOEY_EXCLUDED[int(data["p"]) & 1]
			if int(data["loc"]) == 11: at += DuelGeometry.hand_cursor_offset(int(data["p"]) & 1)
			PointerGlide.request(_pointer_pos, at, game)
			_hover_card = _hit_card(PointerGlide.hover(_pointer_pos))
			if not _hover_card.is_empty():
				_set_preview(_hover_card["id"] if _hover_card["known"] else -1, _is_rival_hand_card(_hover_card))
		var message: int = int(data.get("message", data.get("msg", -1)))
		if message >= 0:
			var pages := _dialog(message)
			if not pages.is_empty():
				_text = "\n".join(pages)

func _redraw() -> void:
	if _duel == null:
		return
	super._redraw()
	for p in 2:
		if _duel.m.u8(0xa11947 + p * DuelMem.PLAYER_SIZE) > 0:
			_register_card(DuelGeometry.DECK[p], CARD_SIZE, p, 13, 0, 0, false)
	_draw_phase_panel()
	var turn := _duel.m.u16(0xa133f2)
	var phase := (turn >> 1) & 7
	var phase_label: String = _localized_phases()[phase] if phase < 6 else "-"
	if Assets.lang == "a":
		_info.text = "الدور: %s · %s" % ["الكمبيوتر" if turn & 1 else "دورك", phase_label]
	elif Assets.lang == "s":
		_info.text = "Turno: %s · %s" % ["CPU" if turn & 1 else "tuyo", phase_label]
	else:
		_info.text = "Turn: %s · %s" % ["CPU" if turn & 1 else "you", phase_label]
	_refresh_cursor()

## 0x461350 (+0x16c): ficha que el motor ilumina al consultar el panel. Solo lo consulta en
## la espera de la fase principal o de batalla del humano cuando no hay ningun objeto bajo el
## cursor (0x571530 devuelve 0); entonces vale BP desde principal 1 si se puede atacar
## (0x571d30), principal 2 desde batalla y EP. 0x461080 la borra tras dibujarla.
func _phase_glow() -> int:
	if _duel == null or _finished or not _duel.dialog_open.is_empty() or not _hover_card.is_empty():
		return -1
	if (_duel.m.u16(0xa133f2) & 1) != 0 or not _waiting_for_player() or (_visual != null and _visual.busy()):
		return -1
	if (_duel.m.u8(0xa13408) & 2) != 0:
		return -1
	var hover := _phase_hover()
	if _ph_phase == 2 and hover == 3 and _duel.f571d30(0) != 0:
		return 3
	if _ph_phase == 3 and hover == 4:
		return 4
	if hover == 5:
		return 5
	return -1


## 0x461080. Tras el volteo (+0x168 >= 0x200) cada ficha es la celda (columna, fila) de su hoja
## pha_s_*: fila 1 si el jugador +0x15c no es 0; columna 1 para la fase actual, que aparece
## con un fundido sobre la columna 0 (alfa +0x164*2) hasta +0x164 = 0x80. La ficha iluminada
## repite la columna 0 sumada con 0x40 (vtable +0xb0). Durante el volteo la ficha k espera
## hasta +0x168 = 24k+64 con la celda de la fila del jugador anterior y despues muestra la
## columna 8 - min(t,64)/8 de su tira (pha_b_* para el jugador 0, pha_r_* para el 1), 3 px
## mas abajo.
func _draw_phase_panel() -> void:
	if game == "kaiba":
		_draw_phase_panel_kaiba(_phase_glow())
		return
	var glow := _phase_glow()
	var fade_alpha: float = _ph_blend.at(["fade", _ph_p, _ph_phase], (_ph_fade << 1) & 0xff) if _ph_fade < 0x80 else 0.0
	# Jo4817e2: pulsa desde256 hasta768, alfa255 hasta reiniciar1024.
	var pulse_alpha: float = 255.0
	if game == "joey" and _ph_fade >= 0x100 and _ph_fade < 0x300:
		pulse_alpha = _ph_blend.at(["pulse", _ph_p, _ph_phase], 127 + absi(DuelVisualMath.cos_fx((_ph_fade - 256) / 2) >> 9))
	var state := [_ph_p, _ph_phase, _ph_fade if game == "joey" or _ph_fade < 0x80 else 0x80, _ph_intro, glow, fade_alpha, pulse_alpha]
	if state == _ph_drawn:
		return
	_ph_drawn = state
	for c in _phase_layer.get_children():
		c.free()
	var row := 1 if _ph_p != 0 else 0
	for k in 6:
		var at := Vector2(_ph_pos[k][0], _ph_pos[k][1]) if game == "joey" else PHASE_ORIGIN + Vector2(0, PHASE_STEP * k)
		var sheet := "%s/duel/phase/pha_s_%s.png" % [game, PHASE_NAMES[k]]
		if _ph_intro < 0x200:
			var t := _ph_intro - k * 24 - 0x40
			if t < 0:
				_phase_cell(sheet, at, Vector2(0, 1 - row), 1.0)
			else:
				var strip := "%s/duel/phase/pha_%s_%s.png" % [game, "b" if _ph_p == 0 else "r", PHASE_NAMES[k]]
				_phase_cell(strip, at + Vector2(0, 3), Vector2(8 - (mini(t, 0x40) >> 3), 0), 1.0)
			continue
		if k == _ph_phase:
			if _ph_fade < 0x80:
				_phase_cell(sheet, at, Vector2(0, row), 1.0)
				_phase_cell(sheet, at, Vector2(1, row), fade_alpha / 255.0)
			elif game == "joey" and _ph_fade >= 0x100:
				_phase_cell(sheet, at, Vector2(0, row), 1.0)
				_phase_cell(sheet, at, Vector2(1, row), pulse_alpha / 255.0)
			else:
				_phase_cell(sheet, at, Vector2(1, row), 1.0)
			continue
		_phase_cell(sheet, at, Vector2(0, row), 1.0)
		if k == glow:
			_phase_cell(sheet, at, Vector2(0, row), 64.0 / 255.0, true)


func _phase_cell(path: String, at: Vector2, cell: Vector2, alpha: float, add := false) -> void:
	var tex := Assets.texture(path)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	var cell_size := Vector2(40, 75) if game == "joey" else PHASE_CELL
	s.region_rect = Rect2(cell * cell_size, cell_size)
	s.position = at
	s.modulate.a = alpha
	if add:
		if _phase_add_material == null:
			_phase_add_material = CanvasItemMaterial.new()
			_phase_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = _phase_add_material
	_phase_layer.add_child(s)


func _unhandled_input(event: InputEvent) -> void:
	if Game.has_active_root_dialog():
		return
	if event.is_action_pressed("ui_cancel") and _duel == null:
		Audio.stop_music()
		Game.open_title(game, "duel")
	elif event is InputEventKey and event.pressed and not event.echo and _duel != null:
		var bit: int = preload("res://core/duel_input.gd").bits(event, game)
		if bit != 0:
			_press_bits |= bit
			if bit & 0xfff00f0:
				_duel.ui_key_cursor = true
	elif event is InputEventMouseMotion and _duel != null:
		if not PointerGlide.drove(event.position):
			PointerGlide.cancel()
			_duel.ui_key_cursor = false


func _setup_online_timer_hud() -> void:
	if _online_timer_panel != null and is_instance_valid(_online_timer_panel):
		_online_timer_panel.visible = _online_timer_enabled and not _finished and _result == null and not _forfeit_handled
		return
	var panel := Control.new()
	panel.position = Vector2(708, 180)
	panel.size = Vector2(88, 56)
	panel.z_as_relative = false
	panel.z_index = 2000
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := ColorRect.new()
	border.position = Vector2.ZERO
	border.size = Vector2(88, 56)
	border.color = Color(0.85, 0.70, 0.28, 0.96)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(border)
	var bg := ColorRect.new()
	bg.position = Vector2(2, 2)
	bg.size = Vector2(84, 52)
	bg.color = Color(0.04, 0.06, 0.12, 0.94)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bg)
	var who_lbl := Label.new()
	who_lbl.position = Vector2(3, 3)
	who_lbl.size = Vector2(82, 18)
	who_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	who_lbl.add_theme_font_override("font", Assets.ui_font(700))
	who_lbl.add_theme_font_size_override("font_size", 11)
	who_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(who_lbl)
	var lbl := Label.new()
	lbl.position = Vector2(3, 20)
	lbl.size = Vector2(82, 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", Assets.ui_font(700))
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(lbl)
	var bar := ColorRect.new()
	bar.position = Vector2(2, 49)
	bar.size = Vector2(84, 5)
	bar.color = Color(0.85, 0.70, 0.28, 0.96)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(bar)
	add_child(panel)
	_online_timer_panel = panel
	_online_timer_border = border
	_online_timer_who_label = who_lbl
	_online_timer_label = lbl
	_online_timer_bar = bar
	if _online_turn_owner < 0 and _duel != null:
		_online_turn_owner = _duel.m.u16(0xa133f2) & 1
	_refresh_online_timer_hud()


func _refresh_online_timer_hud() -> void:
	if _online_timer_panel == null or not is_instance_valid(_online_timer_panel):
		return
	_online_timer_panel.visible = _online_timer_enabled and not _finished and _result == null and not _forfeit_handled
	if not _online_timer_panel.visible:
		return
	var secs := ceili(maxf(0.0, _online_turn_left))
	var mm := secs / 60
	var ss := secs % 60
	var time_str := "%02d:%02d" % [mm, ss]
	var who := ""
	var is_paused_wait := _online_turn_owner == 0 and _online_timer_paused and not _online_auto_ending
	if _online_turn_owner == 1:
		who = "⏱ دور الخصم" if Assets.lang == "a" else ("⏱ Rival" if Assets.lang == "s" else "⏱ Opponent")
	elif is_paused_wait:
		who = "⏸ رد الخصم" if Assets.lang == "a" else ("⏸ Espera" if Assets.lang == "s" else "⏸ Waiting")
	else:
		who = "⏱ دورك" if Assets.lang == "a" else ("⏱ Tu turno" if Assets.lang == "s" else "⏱ Your Turn")
	if _online_timer_who_label != null and is_instance_valid(_online_timer_who_label):
		_online_timer_who_label.text = who
	_online_timer_label.text = time_str
	var ratio := clampf(_online_turn_left / ONLINE_TURN_LIMIT_SEC, 0.0, 1.0)
	_online_timer_bar.size.x = 84.0 * ratio
	var accent := Color(0.28, 0.82, 0.98, 0.96) if _online_turn_owner == 0 else Color(0.90, 0.74, 0.28, 0.94)
	if is_paused_wait:
		accent = Color(0.54, 0.90, 0.62, 0.96)
	elif secs <= 10:
		accent = Color(0.98, 0.24, 0.24, 1.0)
	elif secs <= 25:
		accent = Color(0.98, 0.68, 0.16, 0.96)
	_online_timer_border.color = accent
	_online_timer_bar.color = accent
	if _online_timer_who_label != null and is_instance_valid(_online_timer_who_label):
		_online_timer_who_label.add_theme_color_override("font_color", accent)
	_online_timer_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42) if (secs <= 10 and not is_paused_wait) else Color(1.0, 0.97, 0.88))


func _is_local_prompt_open(turn_owner: int) -> bool:
	if not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
		return true
	if _duel is JoeyPresentationAdapter:
		var adapter := _duel as JoeyPresentationAdapter
		var req: int = adapter.engine.m.u32(0xa57810)
		var local_p: int = adapter.local_native_player
		if (req & 2) != 0 and ((req >> 2) & 1) == local_p:
			return true
	elif (_duel.m.u8(0xa13413) & 2) != 0 and (_duel.m.u8(0xa13413) & 4) == 0:
		return true
	if turn_owner == 1 and _duel.ui_target_selection_mask != 0:
		return true
	return false


func _is_action_menu_open() -> bool:
	if _duel is JoeyPresentationAdapter:
		var adapter := _duel as JoeyPresentationAdapter
		return (adapter.engine.m.u16(0xa57804) & 3) != 0
	return (_duel.m.u8(0xa13408) & 3) != 0


func _safe_slot_card(p: int, loc: int, idx: int) -> int:
	if idx < 0:
		return 0
	if loc == 11:
		var hand_n := _duel.m.u8(DuelMem.pl(p) + 2)
		if idx >= hand_n:
			return 0
	var ptr := _duel.f5419b0(p, loc, idx)
	if ptr <= 0:
		return 0
	return _duel.m.u16(ptr) & 0xfff


func _step_online_timer(delta: float, presenting: bool) -> void:
	if _online_timer_panel == null or not is_instance_valid(_online_timer_panel):
		_setup_online_timer_hud()
	var turn_owner := _duel.m.u16(0xa133f2) & 1
	if turn_owner != _online_turn_owner:
		_online_turn_owner = turn_owner
		_online_turn_left = ONLINE_TURN_LIMIT_SEC
		_online_auto_ending = false
		_online_auto_tick = 0
		_online_auto_elapsed = 0.0
		_online_resp_wait = 0.0
		_online_resp_auto_decline = false
		_online_net_wait_stuck = 0.0
		_online_timer_paused = false
	_online_timer_paused = false
	_online_resp_auto_decline = false
	var start_shaded: bool = _visual != null and _visual._start_banner_shade
	var net_waiting: bool = _duel.net_waiting()
	if not start_shaded and not presenting:
		var local_prompt_open := _is_local_prompt_open(turn_owner)
		var waiting_on_opponent: bool = turn_owner == 0 and not _online_auto_ending and net_waiting and not local_prompt_open
		if turn_owner == 1 and local_prompt_open:
			_online_resp_wait += delta
			if _online_resp_wait >= 25.0:
				_online_resp_auto_decline = true
		elif waiting_on_opponent:
			_online_resp_wait = 0.0
			_online_timer_paused = true
		else:
			_online_resp_wait = 0.0
			_online_turn_left = maxf(0.0, _online_turn_left - delta)
	elif turn_owner == 0 and not _online_auto_ending and net_waiting and not start_shaded:
		_online_timer_paused = true
	if turn_owner == 0 and _online_turn_left <= 0.0:
		if not _online_auto_ending:
			_online_auto_ending = true
			_online_auto_tick = 0
			_online_auto_elapsed = 0.0
		elif not presenting and not start_shaded and not net_waiting:
			_online_auto_elapsed += delta
			if _online_auto_elapsed >= 6.0:
				# Safeguard: never leave the player locked out if an unusual sub-state prevents auto-end.
				_online_auto_ending = false
				_online_auto_tick = 0
				_online_auto_elapsed = 0.0
				_online_turn_left = 15.0
	_refresh_online_timer_hud()
	# Timeout ends only the active player's turn (each side auto-ends its own turn at 00:00);
	# never award a match win or terminate the duel on turn timeout.


func _online_step_auto_end(steps: int, decline_only: bool) -> void:
	_online_auto_tick += 1
	if is_instance_valid(Game._mobile_pointer):
		Game._mobile_pointer.cancel()
	if not _duel.dialog_open.is_empty():
		if bool(_duel.dialog_open.get("closing", false)):
			if _dialog_box == null or not is_instance_valid(_dialog_box):
				_dialog_box = null
				_duel.dialog_gone()
			return
		var dtype := int(_duel.dialog_open.get("type", 0))
		if dtype in [8, 9]:
			var hover := {}
			var press := 0x200 if (_online_auto_tick & 1) == 1 else 0
			if dtype == 8:
				var hand_n := _duel.m.u8(DuelMem.pl(0) + 2)
				if hand_n > 0:
					var slot := (_online_auto_tick >> 1) % hand_n
					hover = {"p": 0, "loc": 11, "i": slot, "card": _safe_slot_card(0, 11, slot)}
				else:
					var z := (_online_auto_tick >> 1) % 10
					var loc := 0 if z < 5 else 5
					var idx := z if z < 5 else z - 5
					hover = {"p": 0, "loc": loc, "i": idx, "card": _safe_slot_card(0, loc, idx)}
			else:
				press = 0x100 if (_online_auto_tick & 1) == 1 else 0
			for _i in range(steps):
				if _lan:
					Lan._poll()
				_duel.set_frame_input(press, 0, hover, -1)
				press = 0
				if not _duel.frame():
					_finished = true
					break
				_duel.set_frame_input(0, 0, hover, -1)
				if _collect_visual_events() or _finished:
					break
				if _duel.dialog_open.is_empty() or bool(_duel.dialog_open.get("closing", false)):
					break
			_collect_events()
			_redraw()
			return
		var msg := int(_duel.dialog_open.get("msg", _duel.dialog_open.get("message", -1)))
		var ans := 0
		if dtype == 1:
			# 0xe6 asks "End your turn?" (1 = Yes / end turn, 0 = No / stay in Main Phase).
			ans = 1 if (not decline_only and msg == 0xe6) else 0
		elif dtype == 2:
			ans = 1
		elif dtype == 3:
			# 0xe5 / 0xdc / 0xdd are the 3-choice phase menus (1 = End Turn, 2 = Cancel).
			if not decline_only and msg in [0xe5, 0xdc, 0xdd]:
				ans = 1
			else:
				var def_val := int(_duel.dialog_open.get("default", -1))
				ans = def_val if def_val >= 0 else 1
		elif dtype in [4, 5, 6, 7]:
			ans = 0
		_answer_dialog(ans)
		return
	if not _duel.list_open.is_empty():
		if bool(_duel.list_open.get("closing", false)):
			if _list_window == null or not is_instance_valid(_list_window):
				_list_window = null
				_duel.list_gone()
			return
		var mode := int(_duel.list_open.get("mode", 0))
		var close_val := 0
		if mode == 1:
			if _duel.f4073e0() > 0:
				_duel.f4073a0(0)
			close_val = 0
		elif mode in [2, 3]:
			var total: int = _duel.f4073e0()
			var limit := int(_duel.list_open.get("selection_limit", 1))
			var need := mini(total, maxi(1, limit))
			var order := 0
			for k in need:
				if _duel.f407570(k) == 0:
					order += 1
					_duel.f407540(k, order)
				else:
					order = maxi(order, _duel.f407570(k))
			close_val = order if bool(_duel.list_open.get("native_selection", false)) else 1
		if _list_window != null and is_instance_valid(_list_window):
			_list_window._close(close_val)
		else:
			_list_window = null
			_duel.list_close(close_val)
			_duel.list_gone()
		return
	if _duel is JoeyPresentationAdapter:
		var adapter := _duel as JoeyPresentationAdapter
		var req_t: int = adapter.engine.m.u32(0xa57810)
		var local_p_t: int = adapter.local_native_player
		if (req_t & 2) != 0 and ((req_t >> 2) & 1) == local_p_t:
			var req_kind := (req_t >> 3) & 0x3f
			var tp := 0
			var tloc := 0
			var tidx := 0
			var tcard := 0
			var force_cancel := false
			if req_kind == 5:
				var opp_hand_n := _duel.m.u8(DuelMem.pl(1) + 2)
				if opp_hand_n > 0:
					tp = 1
					tloc = 11
					tidx = (_online_auto_tick >> 1) % opp_hand_n
					tcard = _safe_slot_card(tp, tloc, tidx)
				else:
					force_cancel = true
			elif req_kind == 6:
				var own_hand_n := _duel.m.u8(DuelMem.pl(0) + 2)
				if own_hand_n > 0:
					tp = 0
					tloc = 11
					tidx = (_online_auto_tick >> 1) % own_hand_n
					tcard = _safe_slot_card(tp, tloc, tidx)
				else:
					force_cancel = true
			else:
				var base_slot := (_online_auto_tick >> 1) % 20
				for off in 20:
					var t_slot := (base_slot + off) % 20
					var cand_p := 0 if t_slot < 10 else 1
					var tz := t_slot % 10
					var cand_loc := 0 if tz < 5 else 5
					var cand_idx := tz if tz < 5 else tz - 5
					var cand_card := _safe_slot_card(cand_p, cand_loc, cand_idx)
					if cand_card != 0 or off == 19:
						tp = cand_p
						tloc = cand_loc
						tidx = cand_idx
						tcard = cand_card
						if cand_card != 0:
							break
			var thover := {} if force_cancel else {"p": tp, "loc": tloc, "i": tidx, "card": tcard}
			var tpress := (0x100 if (force_cancel or (_online_auto_tick % 6) == 1) else 0x200) if (_online_auto_tick & 1) == 1 else 0
			for _i in range(steps):
				if _lan:
					Lan._poll()
				_duel.set_frame_input(tpress, 0, thover, -1)
				tpress = 0
				if not _duel.frame():
					_finished = true
					break
				_duel.set_frame_input(0, 0, thover, -1)
				if _collect_visual_events() or _finished or (_duel.m.u16(0xa133f2) & 1) != 0:
					break
			_collect_events()
			_redraw()
			return
	if _duel.ui_target_selection_mask != 0:
		# Right-click (0x100) cancels attack target selection (0xf00000) and cancelable effect targets cleanly
		# without triggering an attack; only fall back to clicking an occupied slot for mandatory targets.
		var try_cancel := decline_only or (_online_auto_tick % 8) < 6
		var tpress2 := (0x100 if try_cancel else 0x200) if (_online_auto_tick & 1) == 1 else 0
		var thover2 := {}
		if not try_cancel and tpress2 != 0:
			var base_slot2 := (_online_auto_tick >> 1) % 20
			for off2 in 20:
				var t_slot2 := (base_slot2 + off2) % 20
				var cp := 0 if t_slot2 < 10 else 1
				var tz2 := t_slot2 % 10
				var cloc := 0 if tz2 < 5 else 5
				var cidx := tz2 if tz2 < 5 else tz2 - 5
				var ccard := _safe_slot_card(cp, cloc, cidx)
				if ccard != 0:
					thover2 = {"p": cp, "loc": cloc, "i": cidx, "card": ccard}
					break
		for _i in range(steps):
			if _lan:
				Lan._poll()
			_duel.set_frame_input(tpress2, 0, thover2, -1)
			tpress2 = 0
			if not _duel.frame():
				_finished = true
				break
			_duel.set_frame_input(0, 0, thover2, -1)
			if _collect_visual_events() or _finished or (_duel.m.u16(0xa133f2) & 1) != 0:
				break
			if _duel.ui_target_selection_mask == 0 or not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
				break
		_collect_events()
		_redraw()
		return
	if decline_only:
		return
	var before := _duel.executed
	var net_waiting: bool = _duel.net_waiting()
	var action_menu_open := _is_action_menu_open()
	var can_end_phase := (not net_waiting) and (not action_menu_open) and _waiting_for_player()
	var press_bit := 0
	var ph := -1
	if not net_waiting:
		if action_menu_open:
			press_bit = 0x100 if (_online_auto_tick & 1) == 1 else 0
			ph = -1
		elif can_end_phase:
			press_bit = 0x200 if (_online_auto_tick & 1) == 1 else 0
			ph = 5
	for _i in range(steps):
		if _lan:
			Lan._poll()
		_duel.set_frame_input(press_bit, 0, {}, ph)
		press_bit = 0
		if not _duel.frame():
			_finished = true
			break
		_duel.set_frame_input(0, 0, {}, ph)
		if _collect_visual_events():
			break
		if _finished or (_duel.m.u16(0xa133f2) & 1) != 0:
			break
		if not _duel.dialog_open.is_empty() or not _duel.list_open.is_empty():
			break
		if _duel.ui_target_selection_mask != 0:
			break
		if not can_end_phase and not _duel.net_waiting() and not _is_action_menu_open() and _waiting_for_player():
			break
	_refresh_cursor(true)
	_collect_events()
	if _finished or before != _duel.executed:
		_redraw()


func _handle_online_disconnect() -> void:
	if _forfeit_handled:
		return
	if _online_timer_enabled and Lan.peer_left_reason != "" and not Lan.peer_left_reason.begins_with("local_"):
		_finish_online_forfeit_win(Lan.peer_left_reason)
		return
	_forfeit_handled = true
	if _online_timer_panel != null and is_instance_valid(_online_timer_panel):
		_online_timer_panel.visible = false
	set_process(false)
	Game.lan_lost(game)


func _finish_online_forfeit_win(reason: String) -> void:
	if _forfeit_handled or _result != null:
		return
	_forfeit_handled = true
	_finished = true
	_online_auto_ending = false
	if is_instance_valid(Game._mobile_pointer):
		Game._mobile_pointer.cancel()
	if _wait_label != null:
		_wait_label.waiting = false
		_wait_label.visible = false
	if _online_timer_panel != null and is_instance_valid(_online_timer_panel):
		_online_timer_panel.visible = false
	if _dialog_box != null and is_instance_valid(_dialog_box):
		_dialog_box.queue_free()
		_dialog_box = null
	if _list_window != null and is_instance_valid(_list_window):
		_list_window.queue_free()
		_list_window = null
	Lan.close()
	_cached_resume_snapshot.clear()
	DuelResume.clear()
	if Assets.lang == "a":
		_text = "انتهى وقت الخصم — فزت بالمبارزة!" if reason == "timeout" else "انقطع اتصال الخصم — فزت بالمبارزة!"
	elif Assets.lang == "s":
		_text = "Se agotó el tiempo del rival — ¡ganaste!" if reason == "timeout" else "El rival se desconectó — ¡ganaste!"
	else:
		_text = "Opponent timed out — you win!" if reason == "timeout" else "Opponent disconnected — you win!"
	var banner := _label(Vector2(240, 28), Vector2(540, 32), 16)
	banner.z_index = 95
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
	banner.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	banner.add_theme_constant_override("shadow_offset_x", 1)
	banner.add_theme_constant_override("shadow_offset_y", 1)
	banner.text = _text
	Game.record_duel_result(1)
	if _visual != null:
		_visual.end_banner = ""
		_visual._shade_on = true
		_visual._shade_c = 0x100
		_visual._shade_draw_c = 0x100
		_visual._render()
	_result = DuelResult.new()
	_result.setup(game, 1, _duel.m.u32(0xa114b4) & ~0x100, false)
	_result.finished.connect(func() -> void:
		Game.finish_normal_duel(game, Game.match_outcome if Game.duel_mode in [0, 1, 3] else 1))
	add_child(_result)
