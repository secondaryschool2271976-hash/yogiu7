extends Node
## Sesion LAN del port (D17). Sustituye el DirectPlay 8 de igual a igual de Joey
## (443650 crea CLSID_DirectPlay8Peer; 443790 hospeda, 4437f0/443840 enumeran, 443860 se une,
## 443aa0 recibe, 443e60 envia, 4438d0 cierra) por transporte moderno de Godot que funciona igual
## en PC y Android:
##   - ENetMultiplayerPeer (UDP con entrega fiable y ordenada) para los mensajes del juego.
##   - Descubrimiento por UDP: el anfitrion anuncia la partida por difusion y responde por unicast
##     a las consultas de los invitados (lo que en DirectPlay hacia EnumHosts).
## No se busca interoperar con el ejecutable original: se conservan sus mensajes (tipo u16 +
## datos, 0xf0xx en el duelo y 0xfc64-0xfc67 en el janken), cuando los envia cada lado y el
## contador de paquetes en curso de Joey (5bd0f0), no el cable de DirectPlay.
##
## Contrato con el original:
##   send(paquete)        443e40/443e60: el paquete empieza por el tipo u16 (little endian).
##   receive()            444140: saca el siguiente paquete recibido o devuelve vacio.
##   players()            DAT_005f3234+0x44 (444220 compara con 2): jugadores en la sesion.
##   is_host              DAT_005f3234+0x41 (444210): el anfitrion envia la semilla (5bdb40).
##   close()              4438d0/444230: cierra la sesion.
##   terminated           0xffff0016 (DPN_MSGID_TERMINATE_SESSION): 443aa0 guarda el error en
##                        DAT_005f3230; a partir de ahi players() ya no vale 2.

## Puerto del juego. DirectPlay usaba 2302-2400 y 6073 (el original no fija uno propio).
const GAME_PORT := 47624
## El anfitrion escucha consultas aqui y responde por unicast (sirve tambien en Android, donde
## algunas redes filtran la difusion recibida).
const QUERY_PORT := 47625
## Los anuncios periodicos del anfitrion van a este puerto por difusion.
const BEACON_PORT := 47626
## Si el puerto esta ocupado (otra instancia en el mismo equipo) se prueba el siguiente.
const PORT_TRIES := 8
const MAGIC := "POCLAN2"
## Saludo propio del port: nombre y juego de cada lado. En DirectPlay lo daba el mensaje de
## creacion de jugador (0xffff0007, nombre en +0x50/+0x60 del objeto de sesion). Va fuera del
## rango del juego.
const HELLO := 0xfe01
## Control del cable, fuera de los mensajes del motor. El ACK confirma consumo
## por la aplicacion, antes de desconectar ENet y retirar sus colas internas.
const CLOSE_NOTICE := 0xfe02
const CLOSE_ACK := 0xfe03
const CLOSE_TIMEOUT_MS := 5000
const ONLINE_PING_EVERY := 10.0
const ONLINE_CONNECT_TIMEOUT_MS := 60000
## Un anfitrion desaparece de la lista si no se le oye en este tiempo (segundos).
const SESSION_TIMEOUT := 3.0
const ANNOUNCE_EVERY := 0.5
## Tipos que cuentan como paquetes en curso (5bd0f0, bits 21-24 de a58260).
const COUNTED := [0xf002, 0xf003, 0xf041, 0xf042, 0xf051, 0xf052, 0xf053, 0xf054, 0xf055,
		0xf056, 0xf05a, 0xf05b, 0xf071, 0xf073, 0xf081, 0xf082, 0xf091, 0xf092, 0xf0a1, 0xf0a2]

enum State { IDLE, HOSTING, BROWSING, JOINING, CONNECTED, CLOSED, CLOSING }
enum Transport { ENET, RELAY }

signal sessions_changed
signal connected
signal session_lost
signal room_code_ready(code: String)

var state := State.IDLE
var transport := Transport.ENET
var is_host := false
var game := ""
var local_name := ""
var remote_name := ""
var online_url := ""
var room_code := ""
var online_pool := "competitive"
var status_error := ""
var status_detail := ""
var peer_left_reason := ""
## Partidas encontradas al buscar: {name, game, address, port, seen}.
var sessions: Array[Dictionary] = []
## Contador de paquetes en curso de Joey (5bd0f0): +1 al enviar, -1 al recibir los tipos de
## COUNTED. 4 bits con signo, como en a58260.
var in_flight := 0
## Error de la sesion (DAT_005f3230); distinto de 0 tras perderla.
var error := 0
## Sesion terminada por el otro lado, por error de red o por close().
var terminated := false
## Puerto ENet elegido por el anfitrion.
var game_port := GAME_PORT
## Ultima direccion a la que se llamo con join() (para mensajes y pruebas).
var joined_address := ""

var _peer: ENetMultiplayerPeer
var _ws: WebSocketPeer
var _ws_opened := false
var _ws_role_sent := false
var _ws_paired := false
var _ws_claim_code := ""
var _ws_ping_clock := 0.0
var _ws_connect_deadline := 0
var _ws_last_rx_msec := 0
var _lost_pending := false
var _close_requested := false
var _close_notice_sent := false
var _remote_close_requested := false
var _close_ack_sent := false
var _close_ack_received := false
var _disconnect_queued := false
var _close_deadline := 0
var _close_timed_out := false
## --lan-log: traza de la sesion en la consola (pruebas con dos instancias).
var _verbose := false
var _remote_peer := 0
var _hello_sent := false
var _hello_received := false
var _incoming: Array[PackedByteArray] = []
var _query: PacketPeerUDP
var _discovery: PacketPeerUDP
var _announce_clock := 0.0
var _clock := 0.0


static func default_relay_url() -> String:
	return str(ProjectSettings.get_setting("online_duel/relay_url", "")).strip_edges()


static func normalize_relay_url(raw: String) -> String:
	var url: String = raw.strip_edges()
	if url == "":
		return ""
	if url.begins_with("https://"):
		url = "wss://" + url.substr(8)
	elif url.begins_with("http://"):
		url = "ws://" + url.substr(7)
	elif not url.begins_with("wss://") and not url.begins_with("ws://"):
		url = "wss://" + url
	while url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	return url


static func normalize_room_code(raw: String) -> String:
	var out: String = ""
	var cleaned: String = raw.strip_edges().to_upper()
	for i in cleaned.length():
		var code: int = cleaned.unicode_at(i)
		if code >= 0x0660 and code <= 0x0669:
			out += char(48 + (code - 0x0660))
		elif code >= 0x06F0 and code <= 0x06F9:
			out += char(48 + (code - 0x06F0))
		else:
			var ch: String = cleaned.substr(i, 1)
			if (ch >= "0" and ch <= "9") or (ch >= "A" and ch <= "Z"):
				out += ch
	return out.substr(0, 12)


func is_online() -> bool:
	return transport == Transport.RELAY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_verbose = OS.get_cmdline_user_args().has("--lan-log")
	# La red se atiende antes que las escenas: lo recibido en un fotograma ya esta en la cola
	# cuando el motor la consulta.
	process_priority = -100


func _exit_tree() -> void:
	# Solo si hay algo abierto: avisar al rival antes de salir del juego.
	if _peer != null or _ws != null or _discovery != null or _query != null:
		_finish_close(false)


## 443790: crea la sesion como anfitrion con el nombre del jugador.
func host(player_name: String, game_id: String) -> int:
	_finish_close(false)
	_reset(player_name, game_id)
	_peer = ENetMultiplayerPeer.new()
	var err := ERR_CANT_CREATE
	for i in PORT_TRIES:
		err = _peer.create_server(GAME_PORT + i, 1)
		if err == OK:
			game_port = GAME_PORT + i
			break
		_peer = ENetMultiplayerPeer.new()
	if err != OK:
		_peer = null
		return err
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = true
	state = State.HOSTING
	# Consultas de los invitados. Si el puerto esta ocupado por otro anfitrion del mismo equipo
	# se sigue anunciando por difusion.
	_query = PacketPeerUDP.new()
	if _query.bind(QUERY_PORT) != OK:
		_query = null
	_discovery = PacketPeerUDP.new()
	_discovery.set_broadcast_enabled(true)
	_discovery.bind(0)
	_announce_clock = ANNOUNCE_EVERY
	return OK


## 4437f0/443840: empieza a buscar partidas en la red local.
func browse(player_name: String, game_id: String) -> int:
	_finish_close(false)
	_reset(player_name, game_id)
	_discovery = PacketPeerUDP.new()
	_discovery.set_broadcast_enabled(true)
	# Escuchar los anuncios; si otra instancia del equipo ya tiene el puerto, basta con las
	# respuestas a las consultas, que llegan al puerto propio.
	if _discovery.bind(BEACON_PORT) != OK:
		_discovery = PacketPeerUDP.new()
		_discovery.set_broadcast_enabled(true)
		var err := _discovery.bind(0)
		if err != OK:
			_discovery = null
			return err
	state = State.BROWSING
	_announce_clock = ANNOUNCE_EVERY
	return OK


## 443860: se une a la partida elegida. La conexion termina en segundo plano: players() pasa a
## 2 cuando los dos lados se han saludado.
func join(address: String, port: int) -> int:
	_finish_close(false)
	_reset(local_name, game)
	_close_discovery()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(address, port)
	if err != OK:
		_peer = null
		return err
	_peer.peer_connected.connect(_on_peer_connected)
	_peer.peer_disconnected.connect(_on_peer_disconnected)
	is_host = false
	joined_address = address
	state = State.JOINING
	return OK


func _resolve_pool(pool: String) -> String:
	var p: String = pool.strip_edges().to_lower()
	if p in ["competitive", "sandbox"]:
		return p
	if is_instance_valid(Online):
		return Online.effective_pool()
	return "competitive"


## Crea una sala online en el servidor WebSocket (p. ej. Render) y espera codigo + rival.
func host_online(server_url: String, player_name: String, game_id: String, pool := "") -> int:
	var url: String = normalize_relay_url(server_url)
	if url == "":
		status_error = "missing_url"
		return ERR_INVALID_PARAMETER
	_finish_close(false)
	_reset(player_name, game_id)
	transport = Transport.RELAY
	online_url = url
	online_pool = _resolve_pool(pool)
	joined_address = url
	is_host = true
	_ws = WebSocketPeer.new()
	_ws.outbound_buffer_size = 65536
	_ws.inbound_buffer_size = 65536
	var err: int = _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		status_error = "connect_failed"
		terminated = true
		return err
	state = State.HOSTING
	_ws_connect_deadline = Time.get_ticks_msec() + ONLINE_CONNECT_TIMEOUT_MS
	_log("online host [%s] -> %s" % [online_pool, url])
	return OK


## Se une a una sala online usando el codigo de 6 digitos generado por el anfitrion.
func join_online(server_url: String, code: String, player_name: String, game_id: String, pool := "") -> int:
	var url: String = normalize_relay_url(server_url)
	var clean_code: String = normalize_room_code(code)
	if url == "":
		status_error = "missing_url"
		return ERR_INVALID_PARAMETER
	if clean_code == "":
		status_error = "missing_code"
		return ERR_INVALID_PARAMETER
	_finish_close(false)
	_reset(player_name, game_id)
	transport = Transport.RELAY
	online_url = url
	room_code = clean_code
	online_pool = _resolve_pool(pool)
	joined_address = url
	is_host = false
	_ws = WebSocketPeer.new()
	_ws.outbound_buffer_size = 65536
	_ws.inbound_buffer_size = 65536
	var err: int = _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		status_error = "connect_failed"
		terminated = true
		return err
	state = State.JOINING
	_ws_connect_deadline = Time.get_ticks_msec() + ONLINE_CONNECT_TIMEOUT_MS
	_log("online join %s [%s] -> %s" % [clean_code, online_pool, url])
	return OK


## Une a una sala reservada por matchmaking usando claimCode (orden libre anfitrion/invitado).
func claim_online_match(server_url: String, code: String, as_host: bool, player_name: String, game_id: String, pool := "") -> int:
	var clean_code: String = normalize_room_code(code)
	if not as_host:
		return join_online(server_url, clean_code, player_name, game_id, pool)
	var url: String = normalize_relay_url(server_url)
	if url == "" or clean_code == "":
		status_error = "missing_url" if url == "" else "missing_code"
		return ERR_INVALID_PARAMETER
	_finish_close(false)
	_reset(player_name, game_id)
	transport = Transport.RELAY
	online_url = url
	room_code = clean_code
	online_pool = _resolve_pool(pool)
	_ws_claim_code = clean_code
	joined_address = url
	is_host = true
	_ws = WebSocketPeer.new()
	_ws.outbound_buffer_size = 65536
	_ws.inbound_buffer_size = 65536
	var err: int = _ws.connect_to_url(url)
	if err != OK:
		_ws = null
		status_error = "connect_failed"
		terminated = true
		return err
	state = State.HOSTING
	_ws_connect_deadline = Time.get_ticks_msec() + ONLINE_CONNECT_TIMEOUT_MS
	_log("online claim host %s [%s] -> %s" % [clean_code, online_pool, url])
	return OK


## 4438d0: deja de anunciar y solicita cierre fiable. La cola final pertenece
## al motor: se entrega antes de confirmar el cierre, sin demoras artificiales.
func close() -> void:
	_close_discovery()
	if _close_requested:
		return
	var has_link: bool = (_ws != null and _ws_paired) if transport == Transport.RELAY else (_peer != null)
	if has_link and _remote_peer != 0 and state in [State.CONNECTED, State.CLOSING]:
		_close_requested = true
		_begin_closing()
		# Si el rival ya solicito cierre, su ACK basta; no crear otro intercambio.
		if is_host or not _remote_close_requested:
			_send_close_notice()
		return
	_finish_close(false)


func _begin_closing() -> void:
	state = State.CLOSING
	if _close_deadline == 0:
		_close_deadline = Time.get_ticks_msec() + CLOSE_TIMEOUT_MS


func _send_close_notice() -> void:
	if not _close_notice_sent:
		_close_notice_sent = true
		_send_control(CLOSE_NOTICE)


func _send_control(kind: int) -> void:
	var packet := PackedByteArray()
	packet.resize(2)
	packet.encode_u16(0, kind)
	_put_raw_packet(packet)


func _put_raw_packet(packet: PackedByteArray) -> bool:
	if transport == Transport.RELAY:
		if _ws == null or not _ws_paired or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return false
		return _ws.send(packet, WebSocketPeer.WRITE_MODE_BINARY) == OK
	if _peer == null or _remote_peer == 0:
		return false
	_peer.set_transfer_mode(MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	_peer.set_transfer_channel(0)
	_peer.set_target_peer(_remote_peer)
	return _peer.put_packet(packet) == OK


func _send_hello() -> void:
	var payload := PackedByteArray()
	payload.resize(2)
	payload.encode_u16(0, HELLO)
	payload.append_array(("%s\n%s\n%s" % [MAGIC, game, local_name]).to_utf8_buffer())
	if _put_raw_packet(payload):
		_hello_sent = true


func _finish_close(lost: bool) -> void:
	_close_discovery()
	if _peer != null:
		_peer.close()
		_peer = null
	if _ws != null:
		if _ws.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
			_ws.close(1000, "closed")
		_ws = null
	_ws_opened = false
	_ws_role_sent = false
	_ws_paired = false
	_ws_ping_clock = 0.0
	_ws_connect_deadline = 0
	_remote_peer = 0
	_lost_pending = false
	if state != State.IDLE:
		state = State.CLOSED
	terminated = true
	# Preserve _incoming until the application receives the last native packet.
	if lost:
		error = 0x80158160
		session_lost.emit()


## 444220: jugadores en la sesion (el propio cuenta). Vale 2 con el saludo hecho.
func players() -> int:
	if terminated:
		return 0
	if transport == Transport.RELAY:
		if _ws == null:
			return 0
	elif _peer == null:
		return 0
	return 2 if state in [State.CONNECTED, State.CLOSING] else 1


func active() -> bool:
	return players() == 2


## 443e40/443e60: envia un paquete (tipo u16 + datos) al otro jugador, fiable y en orden.
## 5bd0f0(tipo, 1) cuenta los tipos que esperan respuesta.
func send(packet: PackedByteArray) -> bool:
	if packet.size() >= 2:
		_count(packet.decode_u16(0), 1)
		_log("envia %x (%d bytes)" % [packet.decode_u16(0), packet.size()])
	if _remote_peer == 0 or terminated or state == State.CLOSING:
		return false
	return _put_raw_packet(packet)


## Ayuda: arma tipo + datos y lo envia.
func send_message(kind: int, payload := PackedByteArray()) -> bool:
	var packet := PackedByteArray()
	packet.resize(2)
	packet.encode_u16(0, kind & 0xffff)
	packet.append_array(payload)
	return send(packet)


## 444140: saca el siguiente paquete recibido; vacio si no hay. Descuenta los paquetes en curso
## como 5bd2d0 tras leer (5bd0f0(tipo, 0)).
func receive() -> PackedByteArray:
	_poll()
	if _incoming.is_empty():
		return PackedByteArray()
	var packet: PackedByteArray = _incoming.pop_front()
	_count(packet.decode_u16(0), 0)
	_log("recibe %x (%d bytes)" % [packet.decode_u16(0), packet.size()])
	return packet


## Reencola al frente paquetes leidos antes de la transicion de escena (p. ej. janken).
func requeue_packets(packets: Array[PackedByteArray]) -> void:
	for i in range(packets.size() - 1, -1, -1):
		_incoming.push_front(packets[i])


## Reencola paquetes ya extraidos con receive() restaurando el contador in_flight.
func requeue_received_packets(packets: Array[PackedByteArray]) -> void:
	for i in range(packets.size() - 1, -1, -1):
		var packet: PackedByteArray = packets[i]
		if packet.size() >= 2:
			_count(packet.decode_u16(0), 1)
		_incoming.push_front(packet)


## 5bdad0 (parte de red): hay paquetes propios sin respuesta.
func waiting() -> bool:
	return in_flight > 0


func _count(kind: int, sending: int) -> void:
	if not COUNTED.has(kind & 0xffff):
		return
	var value := in_flight + (1 if sending != 0 else -1)
	# Campo de 4 bits con signo (bits 21-24): -8..7.
	in_flight = ((value + 8) & 15) - 8


func _log(text: String) -> void:
	if _verbose:
		print("[lan %s] %s" % ["anfitrion" if is_host else "invitado", text])


func _reset(player_name: String, game_id: String) -> void:
	transport = Transport.ENET
	online_url = ""
	room_code = ""
	online_pool = "competitive"
	status_error = ""
	status_detail = ""
	peer_left_reason = ""
	_ws_opened = false
	_ws_role_sent = false
	_ws_paired = false
	_ws_claim_code = ""
	_ws_ping_clock = 0.0
	_ws_connect_deadline = 0
	_ws_last_rx_msec = 0
	_lost_pending = false
	_close_requested = false
	_close_notice_sent = false
	_remote_close_requested = false
	_close_ack_sent = false
	_close_ack_received = false
	_disconnect_queued = false
	_close_deadline = 0
	_close_timed_out = false
	local_name = player_name
	game = game_id
	remote_name = ""
	sessions.clear()
	in_flight = 0
	error = 0
	terminated = false
	_hello_sent = false
	_hello_received = false
	_incoming.clear()
	_remote_peer = 0
	game_port = GAME_PORT
	joined_address = ""


func _close_discovery() -> void:
	if _query != null:
		_query.close()
		_query = null
	if _discovery != null:
		_discovery.close()
		_discovery = null


func _process(delta: float) -> void:
	_clock += delta
	_poll()
	if transport == Transport.RELAY and _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws_ping_clock += delta
		if _ws_ping_clock >= ONLINE_PING_EVERY:
			_ws_ping_clock = 0.0
			_ws.send_text('{"type":"ping"}')
	if _discovery == null and _query == null:
		return
	_announce_clock += delta
	if _announce_clock >= ANNOUNCE_EVERY:
		_announce_clock = 0.0
		if state == State.HOSTING and _remote_peer == 0:
			_announce()
		elif state == State.BROWSING:
			_ask()
	_read_discovery()
	if state == State.BROWSING:
		var before := sessions.size()
		sessions = sessions.filter(func(s: Dictionary) -> bool: return _clock - float(s["seen"]) < SESSION_TIMEOUT)
		if sessions.size() != before:
			sessions_changed.emit()


func _handle_game_packet(packet: PackedByteArray) -> void:
	var kind: int = packet.decode_u16(0)
	if kind == HELLO:
		_on_hello(packet)
		return
	if kind == CLOSE_NOTICE:
		_remote_close_requested = true
		if not _close_requested and peer_left_reason == "":
			peer_left_reason = "remote_close"
		_begin_closing()
		if is_host:
			_send_close_notice()
		return
	if kind == CLOSE_ACK:
		_close_ack_received = true
		return
	_incoming.append(packet)


func _poll() -> void:
	if transport == Transport.RELAY:
		_poll_relay()
		return
	if _peer == null:
		return
	# ENet signals run inside poll(). Always retain queued application packets
	# before processing disconnection; close controls are reliable and ordered.
	_peer.poll()
	while _peer.get_available_packet_count() > 0:
		var from := _peer.get_packet_peer()
		var packet := _peer.get_packet()
		if from != _remote_peer or packet.size() < 2:
			continue
		_handle_game_packet(packet)
	if _lost_pending:
		if _incoming.is_empty(): _lose()
		return
	if state == State.CLOSING:
		if _remote_close_requested and not _close_ack_sent and _incoming.is_empty():
			_send_control(CLOSE_ACK)
			_close_ack_sent = true
		# peer_disconnect_later waits for ENet's reliable outgoing queue. The
		# explicit ACK also proves the remote application consumed the payload,
		# so ENetMultiplayerPeer's client close cannot discard an unread f003.
		# Only the ENet server initiates the physical disconnect. Simultaneous
		# native close requests must not produce two concurrent disconnects.
		if is_host and _close_notice_sent and _close_ack_received and _incoming.is_empty() and not _disconnect_queued:
			_disconnect_queued = true
			_peer.get_peer(_remote_peer).peer_disconnect_later()
			_peer.host.flush()
		if Time.get_ticks_msec() >= _close_deadline:
			_close_timed_out = true
			_finish_close(true)
		return
	# El invitado no llego a conectar (anfitrion desaparecido o lleno).
	if state == State.JOINING and _remote_peer == 0 \
			and _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_lose()


func _poll_relay() -> void:
	if _ws == null:
		return
	_ws.poll()
	var ws_state: int = _ws.get_ready_state()
	if ws_state == WebSocketPeer.STATE_CONNECTING:
		if _ws_connect_deadline > 0 and Time.get_ticks_msec() >= _ws_connect_deadline:
			status_error = "timeout"
			_finish_close(true)
		return
	if ws_state == WebSocketPeer.STATE_OPEN:
		_ws_opened = true
		if _ws_last_rx_msec == 0:
			_ws_last_rx_msec = Time.get_ticks_msec()
		if not _ws_role_sent:
			_ws_role_sent = true
			var req: Dictionary = {
				"type": "host" if is_host else "join",
				"game": game,
				"name": local_name,
				"pool": online_pool
			}
			if is_instance_valid(Online) and Online.token != "":
				req["token"] = Online.token
			if is_host and _ws_claim_code != "":
				req["claimCode"] = _ws_claim_code
			elif not is_host:
				req["code"] = room_code
			_ws.send_text(JSON.stringify(req))
	while _ws != null and _ws.get_available_packet_count() > 0:
		_ws_last_rx_msec = Time.get_ticks_msec()
		var packet: PackedByteArray = _ws.get_packet()
		if _ws.was_string_packet():
			_on_relay_control(packet.get_string_from_utf8())
		elif _ws_paired and packet.size() >= 2:
			_handle_game_packet(packet)
	if _ws == null:
		return
	if state == State.CONNECTED and _ws_paired and not _close_requested and not _remote_close_requested and not _lost_pending:
		if _ws_last_rx_msec > 0 and Time.get_ticks_msec() - _ws_last_rx_msec > 35000:
			status_error = "timeout"
			if peer_left_reason == "":
				peer_left_reason = "local_timeout"
			_lose()
			return
	if ws_state == WebSocketPeer.STATE_CLOSING or ws_state == WebSocketPeer.STATE_CLOSED:
		if not _ws_opened and status_error == "":
			status_error = "connect_failed"
		if _ws_paired:
			if peer_left_reason == "" and not (_close_requested or _remote_close_requested):
				peer_left_reason = "local_disconnect"
			_lost_pending = true
		else:
			_finish_close(not (_close_requested or _remote_close_requested))
			return
	if _lost_pending:
		if _incoming.is_empty():
			_lose()
		return
	if state == State.CLOSING:
		if _remote_close_requested and not _close_ack_sent and _incoming.is_empty():
			_send_control(CLOSE_ACK)
			_close_ack_sent = true
		if is_host and _close_notice_sent and _close_ack_received and _incoming.is_empty() and not _disconnect_queued:
			_disconnect_queued = true
			_ws.close(1000, "done")
		if Time.get_ticks_msec() >= _close_deadline:
			_close_timed_out = true
			_finish_close(true)


func _on_relay_control(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	var kind: String = str(msg.get("type", ""))
	match kind:
		"hosted":
			room_code = str(msg.get("code", ""))
			var h_pool: String = str(msg.get("pool", ""))
			if h_pool in ["competitive", "sandbox"]:
				online_pool = h_pool
			_log("sala online lista: %s [%s]" % [room_code, online_pool])
			room_code_ready.emit(room_code)
		"ready":
			var code_val: String = str(msg.get("code", ""))
			if code_val != "":
				room_code = code_val
			var r_pool: String = str(msg.get("pool", ""))
			if r_pool in ["competitive", "sandbox"]:
				online_pool = r_pool
			_ws_paired = true
			_remote_peer = 1
			_log("rival online emparejado (%s)" % str(msg.get("opponent", "")))
			_send_hello()
		"peer_left":
			peer_left_reason = str(msg.get("reason", "peer_left"))
			if peer_left_reason == "":
				peer_left_reason = "peer_left"
			_log("rival online desconectado (%s)" % peer_left_reason)
			_lost_pending = true
		"error":
			status_error = str(msg.get("code", "error"))
			var exp_pool: String = str(msg.get("expectedPool", ""))
			status_detail = exp_pool if exp_pool != "" else str(msg.get("expectedGame", ""))
			_log("error online: %s (%s)" % [status_error, status_detail])
			_finish_close(true)
		"pong":
			pass


func _on_peer_connected(id: int) -> void:
	if _remote_peer != 0:
		# Partida de dos: el anfitrion rechaza a un tercero (create_server ya limita a uno).
		_peer.disconnect_peer(id)
		return
	_remote_peer = id
	_log("conectado %d" % id)
	_close_discovery()
	_send_hello()


func _on_hello(packet: PackedByteArray) -> void:
	var parts := packet.slice(2).get_string_from_utf8().split("\n")
	if parts.size() < 3 or parts[0] != MAGIC or parts[1] != game:
		# Otro programa u otro juego: no es un rival valido.
		_log("saludo invalido: %s" % str(parts))
		_lost_pending = true
		return
	remote_name = parts[2]
	_log("saludo de %s" % remote_name)
	_hello_received = true
	state = State.CONNECTED
	connected.emit()


func _on_peer_disconnected(id: int) -> void:
	_log("desconectado %d (rival %d)" % [id, _remote_peer])
	if id == _remote_peer:
		_lost_pending = true


## 0xffff0016 en 443aa0: DAT_005f3230 = 0x80158160 y la sesion deja de valer.
func _lose() -> void:
	_lost_pending = false
	if terminated:
		return
	_log("sesion terminada")
	_finish_close(not (_close_requested or _remote_close_requested))


func _beacon_payload() -> PackedByteArray:
	return ("%s\n%s\n%d\n%s" % [MAGIC, game, game_port, local_name]).to_utf8_buffer()


## Anfitrion: anuncio por difusion (y por la interfaz local, para dos instancias en un equipo).
func _announce() -> void:
	var payload := _beacon_payload()
	for target in _broadcast_targets():
		_discovery.set_dest_address(target, BEACON_PORT)
		_discovery.put_packet(payload)


## Invitado: consulta a los anfitriones; responden por unicast al puerto de origen.
func _ask() -> void:
	var payload := ("%s\n%s\n?" % [MAGIC, game]).to_utf8_buffer()
	for target in _broadcast_targets():
		_discovery.set_dest_address(target, QUERY_PORT)
		_discovery.put_packet(payload)


func _broadcast_targets() -> PackedStringArray:
	var targets := PackedStringArray(["255.255.255.255", "127.0.0.1"])
	# Difusion dirigida de cada red IPv4 privada: algunos sistemas no sacan 255.255.255.255 por
	# todas las interfaces.
	for address in IP.get_local_addresses():
		if address.count(".") != 3 or address.begins_with("127.") or address.begins_with("169.254."):
			continue
		var octets := address.split(".")
		var directed := "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not targets.has(directed):
			targets.append(directed)
	return targets


func _read_discovery() -> void:
	if _query != null:
		while _query.get_available_packet_count() > 0:
			var data := _query.get_packet()
			var parts := data.get_string_from_utf8().split("\n")
			if parts.size() >= 3 and parts[0] == MAGIC and parts[1] == game and parts[2] == "?" \
					and state == State.HOSTING and _remote_peer == 0:
				_query.set_dest_address(_query.get_packet_ip(), _query.get_packet_port())
				_query.put_packet(_beacon_payload())
	if _discovery == null:
		return
	while _discovery.get_available_packet_count() > 0:
		var data := _discovery.get_packet()
		var address := _discovery.get_packet_ip()
		if state != State.BROWSING:
			continue
		var parts := data.get_string_from_utf8().split("\n")
		if parts.size() < 4 or parts[0] != MAGIC or parts[1] != game or not parts[2].is_valid_int():
			continue
		_found(parts[3], address, int(parts[2]))


func _found(host_name: String, address: String, port: int) -> void:
	for s in sessions:
		if int(s["port"]) == port and (s["address"] == address or s["name"] == host_name and _same_machine(s["address"], address)):
			s["seen"] = _clock
			return
	sessions.append({"name": host_name, "game": game, "address": address, "port": port, "seen": _clock})
	sessions_changed.emit()


## La misma partida puede oirse por 127.0.0.1 y por la IP de la red: es la misma.
func _same_machine(a: String, b: String) -> bool:
	var local := IP.get_local_addresses()
	return (a == "127.0.0.1" or local.has(a)) and (b == "127.0.0.1" or local.has(b))
