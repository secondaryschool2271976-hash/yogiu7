extends SceneTree
## Prueba del reloj del duelo en red (res://core/online_turn_timer.gd) sin datos del juego:
##   godot --headless --path game --script res://tests/online_turn_timer_test.gd
## Comprueba que ninguna espera queda sin tope: turno propio, ventana de respuesta a una carta
## del rival y espera pausada del rival.

const STEP := 1.0 / 30.0

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _check(name: String, ok: bool, detail: String) -> void:
	if not ok:
		failures.append("%s: %s" % [name, detail])
	print("%s %s%s" % ["ok  " if ok else "FALLA", name, "" if ok else " -> " + detail])


## Avanza el reloj `seconds` segundos con el contexto dado.
func _advance(timer: OnlineTurnTimer, seconds: float, owner: int, prompt := false,
		net_waiting := false, presenting := false, start_shaded := false,
		progress_every := 0.0) -> void:
	var elapsed := 0.0
	var since_progress := 0.0
	while elapsed < seconds:
		var progressed := false
		if progress_every > 0.0:
			since_progress += STEP
			if since_progress >= progress_every:
				since_progress = 0.0
				progressed = true
		timer.step(STEP, owner, prompt, net_waiting, presenting, start_shaded, progressed)
		elapsed += STEP


func _run() -> void:
	await process_frame

	# 1. Turno propio: el reloj baja y a los 120 s se cierra el turno solo.
	var t := OnlineTurnTimer.new()
	_advance(t, 60.0, 0)
	_check("turno propio descuenta", t.turn_left < 61.0 and t.turn_left > 59.0, "turn_left=%f" % t.turn_left)
	_advance(t, 61.0, 0)
	_check("turno propio cierra a los 120 s", t.auto_ending, "turn_left=%f auto_ending=%s" % [t.turn_left, t.auto_ending])
	_check("turno propio no da al rival por colgado", not t.opponent_stalled, "opponent_stalled=true")

	# 2. Turno del rival: su reloj corre aqui y a los 120 s + 10 s de gracia no se le espera mas.
	t = OnlineTurnTimer.new()
	_advance(t, 100.0, 1)
	_check("turno del rival descuenta", t.opponent_turn_left < 21.0, "opp_left=%f" % t.opponent_turn_left)
	_check("turno del rival no da colgado antes de tiempo", not t.opponent_stalled, "opponent_stalled=true")
	_advance(t, 25.0, 1)
	_check("rival colgado tras el limite", t.opponent_turn_left <= 0.0, "opp_left=%f" % t.opponent_turn_left)
	_advance(t, 11.0, 1)
	_check("rival colgado tras la gracia", t.opponent_stalled, "opponent_stalled=false")

	# 3. Ventana de respuesta durante el turno del rival: se responde "No" sola a los 25 s.
	t = OnlineTurnTimer.new()
	_advance(t, 20.0, 1, true)
	_check("respuesta no se cierra antes de 25 s", not t.auto_decline, "auto_decline=true")
	_advance(t, 6.0, 1, true)
	_check("respuesta se cierra sola a los 25 s", t.auto_decline, "auto_decline=false")
	_check("respuesta no consume el reloj del rival", t.opponent_turn_left > 119.0, "opp_left=%f" % t.opponent_turn_left)
	_check("respuesta no da al rival por colgado", not t.opponent_stalled, "opponent_stalled=true")

	# 4. Espera pausada en mi turno: mi reloj no corre, pero la espera tiene tope.
	t = OnlineTurnTimer.new()
	_advance(t, 60.0, 0, false, true)
	_check("espera pausada marca pausa", t.paused, "paused=false")
	_check("espera pausada congela mi reloj", t.turn_left > 119.0, "turn_left=%f" % t.turn_left)
	_check("espera pausada no da colgado a los 60 s", not t.opponent_stalled, "opponent_stalled=true")
	_advance(t, 75.0, 0, false, true)
	_check("espera pausada da al rival por colgado", t.opponent_stalled, "opponent_stalled=false")

	# 5. La misma espera con paquetes del rival no da nada por colgado.
	t = OnlineTurnTimer.new()
	_advance(t, 300.0, 0, false, true, false, false, 1.0)
	_check("espera con progreso no da colgado", not t.opponent_stalled, "opponent_stalled=true")

	# 6. Cambio de turno: se reinician relojes y avisos.
	t = OnlineTurnTimer.new()
	_advance(t, 100.0, 1)
	_advance(t, 1.0, 0)
	_check("cambio de turno reinicia el reloj del rival", t.opponent_turn_left > 119.0, "opp_left=%f" % t.opponent_turn_left)
	_check("cambio de turno reinicia mi reloj", t.turn_left > 118.0, "turn_left=%f" % t.turn_left)

	# 7. Presentacion y cartel inicial: no corren los relojes.
	t = OnlineTurnTimer.new()
	_advance(t, 30.0, 1, false, false, true)
	_check("presentacion no consume el turno del rival", t.opponent_turn_left > 119.0, "opp_left=%f" % t.opponent_turn_left)
	_advance(t, 30.0, 0, false, false, false, true)
	_check("cartel inicial no consume mi turno", t.turn_left > 119.0, "turn_left=%f" % t.turn_left)

	if failures.is_empty():
		print("reloj online: todas las comprobaciones pasan")
		quit(0)
	else:
		print("reloj online: %d fallos" % failures.size())
		for failure in failures:
			print("  - " + failure)
		quit(1)
