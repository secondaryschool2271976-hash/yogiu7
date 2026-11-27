class_name OnlineTurnTimer
## Reloj del duelo en red (0xa133f2 bit 0 = jugador activo; cada lado se ve como jugador 0 y el
## rival llega por la red). Vive fuera de la escena para poder probarlo sin los datos del juego.
##
## Reglas:
##   - Quien tiene el turno dispone de TURN_LIMIT_SEC; al llegar a 0 su lado cierra el turno solo.
##   - Mientras el rival tiene el turno y yo tengo una ventana abierta (respuesta a una carta,
##     cadena), se responde "No" sola a los RESPONSE_LIMIT_SEC: nadie retiene al otro.
##   - El reloj del rival se cuenta tambien en mi lado. Si su turno pasa de
##     TURN_LIMIT_SEC + OPPONENT_GRACE_SEC, o si mi reloj lleva STALL_SEC pausado esperandole
##     sin que llegue nada, el rival esta colgado: `opponent_stalled`.
##
## El estado se lee desde la escena despues de `step()` (paused, auto_decline, auto_ending,
## turn_left, opponent_turn_left, opponent_stalled).

const TURN_LIMIT_SEC := 120.0
const OPPONENT_GRACE_SEC := 10.0
const RESPONSE_LIMIT_SEC := 25.0
## Tope de espera sin progreso antes de dar el turno del rival por colgado.
const STALL_SEC := TURN_LIMIT_SEC + OPPONENT_GRACE_SEC
## Reintento del cierre automatico cuando el motor no acepta la respuesta.
const AUTO_RETRY_SEC := 6.0
const AUTO_RETRY_TURN_SEC := 15.0

var turn_owner := -1
## Tiempo que le queda a quien tiene el turno (el mio si turn_owner == 0).
var turn_left := TURN_LIMIT_SEC
## Tiempo que le queda al rival, contado desde mi lado.
var opponent_turn_left := TURN_LIMIT_SEC
var auto_ending := false
var auto_elapsed := 0.0
var response_wait := 0.0
var auto_decline := false
var paused := false
var wait_stuck := 0.0
var stall_elapsed := 0.0
var opponent_stalled := false


func reset_turn(owner: int) -> void:
	turn_owner = owner
	turn_left = TURN_LIMIT_SEC
	opponent_turn_left = TURN_LIMIT_SEC
	auto_ending = false
	auto_elapsed = 0.0
	response_wait = 0.0
	auto_decline = false
	paused = false
	wait_stuck = 0.0
	stall_elapsed = 0.0
	opponent_stalled = false


## `progressed`: llego un paquete del rival o el motor avanzo desde el paso anterior. Reinicia
## las esperas para no dar por colgado a un rival que si esta jugando.
func step(delta: float, owner: int, local_prompt_open: bool, net_waiting: bool,
		presenting: bool, start_shaded: bool, progressed: bool) -> void:
	if owner != turn_owner:
		reset_turn(owner)
	auto_decline = false
	paused = false
	if progressed:
		wait_stuck = 0.0
		stall_elapsed = 0.0
	# Presentacion y cartel inicial congelan los relojes, como antes del cambio.
	if start_shaded or presenting:
		return
	if turn_owner == 1:
		if local_prompt_open:
			response_wait += delta
			if response_wait >= RESPONSE_LIMIT_SEC:
				auto_decline = true
		else:
			response_wait = 0.0
			opponent_turn_left = maxf(0.0, opponent_turn_left - delta)
			if opponent_turn_left <= 0.0:
				stall_elapsed += delta
	else:
		response_wait = 0.0
		if net_waiting and not local_prompt_open and not auto_ending:
			# Espero su respuesta (cadena o carta): mi reloj no corre, pero la espera se cuenta.
			paused = true
			wait_stuck += delta
		else:
			wait_stuck = 0.0
			turn_left = maxf(0.0, turn_left - delta)
		if turn_left <= 0.0:
			if not auto_ending:
				auto_ending = true
				auto_elapsed = 0.0
			elif not net_waiting:
				auto_elapsed += delta
				if auto_elapsed >= AUTO_RETRY_SEC:
					# Nunca dejar al jugador sin salida si un subestado raro impide cerrar el turno.
					auto_ending = false
					auto_elapsed = 0.0
					turn_left = AUTO_RETRY_TURN_SEC
	if stall_elapsed >= OPPONENT_GRACE_SEC or wait_stuck >= STALL_SEC:
		opponent_stalled = true
