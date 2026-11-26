extends Node
## Servicio Online global: cuentas (Google / Cuenta / Invitado), ID unico permanente,
## sincronizacion de coleccion de cartas y estadisticas, directorio de jugadores,
## solicitudes de amistad, presencia en vivo e invitaciones directas a duelo.

signal session_changed
signal friend_request_received(from_id: String, from_name: String)
signal friend_accepted_received(player_id: String, display_name: String)
signal duel_invite_received(from_id: String, from_name: String, room_code: String, game_id: String, pool: String)
signal invite_declined_received(by_id: String, by_name: String, room_code: String)
signal invite_status_received(target_id: String, room_code: String, delivered: bool)
signal invite_error_received(code: String, target_id: String)
signal matchmaking_queued(game_id: String, queue_size: int)
signal matchmaking_found(game_id: String, room_code: String, is_host: bool, opponent_id: String, opponent_name: String)
signal matchmaking_left
signal matchmaking_error_received(code: String)
signal global_chat_received(message: Dictionary)
signal dm_received(message: Dictionary)
signal chat_error_received(code: String)

const DEFAULT_SERVER_URL := "https://poc-online-relay.onrender.com"
const SESSION_FILE := "online_account.cfg"
const HTTP_TIMEOUT_SEC := 40.0
const PRESENCE_PING_EVERY := 20.0
const PRESENCE_RECONNECT_EVERY := 10.0

var server_url := DEFAULT_SERVER_URL
var token := ""
var player_id := ""
var display_name := ""
var username := ""
var auth_provider := ""
var profile: Dictionary = {}
var incoming_request_count := 0
var friend_count := 0
var google_auth_enabled := false
var presence_connected := false
var startup_prompt_dismissed := false
var matchmaking_active := false
var matchmaking_game := ""
var all_cards_unlocked := false
var online_pool := "competitive"
var dm_unread: Dictionary = {}
var active_dm_friend_id := ""

var _ws: WebSocketPeer = null
var _ws_authed := false
var _ping_clock := 0.0
var _reconnect_clock := 0.0
var _sync_timer: Timer = null
var _syncing := false
var _pending_challenge_target := ""
var _pending_challenge_game := "joey"
var _pending_challenge_pool := "competitive"
var _pending_invite_room_code := ""
var _global_invite_layer: CanvasLayer = null
var _global_invite_panel: PanelContainer = null
var _global_invite_title: Label = null
var _global_invite_body: Label = null
var _global_invite_accept_btn: Button = null
var _global_invite_decline_btn: Button = null
var _global_invite_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_server_url()
	_load_session()
	_sync_timer = Timer.new()
	_sync_timer.one_shot = true
	_sync_timer.wait_time = 3.0
	_sync_timer.timeout.connect(_on_sync_timer_timeout)
	add_child(_sync_timer)
	if is_instance_valid(SaveData) and not SaveData.saved.is_connected(_on_save_data_saved):
		SaveData.saved.connect(_on_save_data_saved)
	if not Lan.room_code_ready.is_connected(_on_lan_room_code_ready):
		Lan.room_code_ready.connect(_on_lan_room_code_ready)
	if DisplayServer.get_name() != "headless":
		_build_global_invite_toast()
		_bootstrap_async.call_deferred()


func _exit_tree() -> void:
	_close_presence()


func is_logged_in() -> bool:
	return token != "" and player_id != ""


func effective_pool() -> String:
	if all_cards_unlocked:
		return "sandbox"
	return "sandbox" if online_pool == "sandbox" else "competitive"


func set_online_pool(pool: String) -> void:
	var target: String = "sandbox" if (all_cards_unlocked or pool.strip_edges().to_lower() == "sandbox") else "competitive"
	if online_pool == target:
		return
	online_pool = target
	_save_session()
	session_changed.emit()


func mark_all_cards_unlocked() -> void:
	var changed: bool = (not all_cards_unlocked) or (online_pool != "sandbox")
	all_cards_unlocked = true
	online_pool = "sandbox"
	if is_instance_valid(SaveData) and not SaveData.data.is_empty():
		if not bool(SaveData.data.get("all_cards_unlocked", false)):
			SaveData.data["all_cards_unlocked"] = true
			SaveData.save()
	_save_session()
	if changed:
		session_changed.emit()


func pool_label(pool: String) -> String:
	var p: String = "sandbox" if pool.strip_edges().to_lower() == "sandbox" else "competitive"
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		return "🧪 وضع اختبار المجموعات" if p == "sandbox" else "🏆 وضع المنافسة"
	if lang == "s":
		return "🧪 Prueba de Mazos" if p == "sandbox" else "🏆 Modo Competitivo"
	return "🧪 Deck Testing" if p == "sandbox" else "🏆 Competitive Mode"


func _load_server_url() -> void:
	var configured: String = Lan.default_relay_url()
	if configured == "":
		configured = DEFAULT_SERVER_URL
	var lan_cfg: Variant = SaveData.data.get("lan", {}) if is_instance_valid(SaveData) else {}
	if lan_cfg is Dictionary:
		var custom: String = str((lan_cfg as Dictionary).get("relay_url", "")).strip_edges()
		if custom != "":
			configured = custom
	server_url = _normalize_http_url(configured)


static func _normalize_http_url(raw: String) -> String:
	var url: String = raw.strip_edges()
	if url == "":
		return DEFAULT_SERVER_URL
	if url.begins_with("wss://"):
		url = "https://" + url.substr(6)
	elif url.begins_with("ws://"):
		url = "http://" + url.substr(5)
	elif not url.begins_with("https://") and not url.begins_with("http://"):
		url = "https://" + url
	while url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	return url


func set_server_url(raw: String) -> void:
	server_url = _normalize_http_url(raw)
	if is_instance_valid(SaveData) and not SaveData.data.is_empty():
		var lan_cfg: Dictionary = SaveData.data.get("lan", {}) if SaveData.data.get("lan") is Dictionary else {}
		lan_cfg["relay_url"] = server_url
		SaveData.data["lan"] = lan_cfg
		SaveData.save()


func _session_path() -> String:
	if is_instance_valid(Paths) and Paths.storage_dir != "" and not Paths.storage_error:
		return Paths.storage_dir.path_join(SESSION_FILE)
	return "user://" + SESSION_FILE


func _load_session() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_session_path()) == OK:
		token = str(cfg.get_value("session", "token", "")).strip_edges()
		player_id = str(cfg.get_value("session", "player_id", "")).strip_edges()
		display_name = str(cfg.get_value("session", "display_name", "")).strip_edges()
		username = str(cfg.get_value("session", "username", "")).strip_edges()
		auth_provider = str(cfg.get_value("session", "auth_provider", "")).strip_edges()
		all_cards_unlocked = bool(cfg.get_value("session", "all_cards_unlocked", false))
		var saved_pool: String = str(cfg.get_value("session", "online_pool", "competitive")).strip_edges().to_lower()
		online_pool = "sandbox" if saved_pool == "sandbox" else "competitive"
		var saved_url: String = str(cfg.get_value("session", "server_url", "")).strip_edges()
		if saved_url != "":
			server_url = _normalize_http_url(saved_url)
	if is_instance_valid(SaveData) and not SaveData.data.is_empty() and bool(SaveData.data.get("all_cards_unlocked", false)):
		all_cards_unlocked = true
	if all_cards_unlocked:
		online_pool = "sandbox"


func _save_session() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("session", "token", token)
	cfg.set_value("session", "player_id", player_id)
	cfg.set_value("session", "display_name", display_name)
	cfg.set_value("session", "username", username)
	cfg.set_value("session", "auth_provider", auth_provider)
	cfg.set_value("session", "all_cards_unlocked", all_cards_unlocked)
	cfg.set_value("session", "online_pool", effective_pool())
	cfg.set_value("session", "server_url", server_url)
	cfg.save(_session_path())


func _apply_auth_result(res: Dictionary) -> void:
	var new_token: String = str(res.get("token", "")).strip_edges()
	if new_token != "":
		token = new_token
	var p_val: Variant = res.get("player", {})
	if p_val is Dictionary:
		var p: Dictionary = p_val
		profile = p
		player_id = str(p.get("playerId", player_id))
		display_name = str(p.get("displayName", display_name))
		username = str(p.get("username", username))
		auth_provider = str(p.get("authProvider", auth_provider))
		if p.has("allCardsUnlocked"):
			all_cards_unlocked = bool(p.get("allCardsUnlocked", false))
	if is_instance_valid(SaveData) and not SaveData.data.is_empty() and bool(SaveData.data.get("all_cards_unlocked", false)):
		all_cards_unlocked = true
	if all_cards_unlocked:
		online_pool = "sandbox"
		if is_instance_valid(SaveData) and not SaveData.data.is_empty():
			SaveData.data["all_cards_unlocked"] = true
	if res.has("incomingRequestCount"):
		incoming_request_count = int(res.get("incomingRequestCount", 0))
	if res.has("friendCount"):
		friend_count = int(res.get("friendCount", 0))
	if display_name != "" and is_instance_valid(SaveData) and not SaveData.data.is_empty():
		var lan_cfg: Dictionary = SaveData.data.get("lan", {}) if SaveData.data.get("lan") is Dictionary else {}
		if str(lan_cfg.get("name", "")).strip_edges() == "":
			lan_cfg["name"] = display_name
			SaveData.data["lan"] = lan_cfg
	_save_session()
	_connect_presence()
	session_changed.emit()


func _bootstrap_async() -> void:
	await fetch_config()
	if is_logged_in():
		var res: Dictionary = await refresh_me()
		if bool(res.get("ok", false)):
			await sync_collection_now()
		elif int(res.get("http_status", 0)) == 401:
			logout()


func _on_save_data_saved() -> void:
	if is_logged_in() and _sync_timer != null:
		_sync_timer.start()


func _on_sync_timer_timeout() -> void:
	if is_logged_in():
		sync_collection_now()


func _request(method: int, path: String, body: Variant = null, auth := false) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = HTTP_TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Accept: application/json"])
	var payload_str := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload_str = JSON.stringify(body)
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var url: String = server_url + path
	var err: int = req.request(url, headers, method, payload_str)
	if err != OK:
		req.queue_free()
		return {"ok": false, "http_status": 0, "error": "network_error"}
	var completed: Array = await req.request_completed
	req.queue_free()
	var result_code: int = int(completed[0])
	var http_status: int = int(completed[1])
	var raw_body: PackedByteArray = completed[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "http_status": 0, "error": "network_error"}
	var text: String = raw_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var out: Dictionary = parsed
		out["http_status"] = http_status
		return out
	return {"ok": http_status >= 200 and http_status < 300, "http_status": http_status, "error": "invalid_response"}


func fetch_config() -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, "/api/config")
	if bool(res.get("ok", false)):
		google_auth_enabled = bool(res.get("googleAuthEnabled", false))
		session_changed.emit()
	return res


func login_guest(wanted_name: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/auth/guest", {"displayName": wanted_name.strip_edges()})
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
		sync_collection_now()
	return res


func register_account(user: String, passw: String, wanted_name: String, upgrade_guest := false) -> Dictionary:
	var body: Dictionary = {
		"username": user.strip_edges(),
		"password": passw,
		"displayName": wanted_name.strip_edges()
	}
	if upgrade_guest and auth_provider == "guest" and token != "":
		body["upgradeGuestToken"] = token
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/auth/register", body)
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
		sync_collection_now()
	return res


func login_account(user: String, passw: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/auth/login", {
		"username": user.strip_edges(),
		"password": passw
	})
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
		sync_collection_now()
	return res


func start_google_login(upgrade_guest := false) -> Dictionary:
	var body: Dictionary = {}
	if upgrade_guest and auth_provider == "guest" and token != "":
		body["upgradeGuestToken"] = token
	return await _request(HTTPClient.METHOD_POST, "/api/auth/google/start", body)


func poll_google_login(state: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, "/api/auth/google/poll?state=" + state.uri_encode())
	if bool(res.get("ok", false)) and str(res.get("status", "")) == "done":
		_apply_auth_result(res)
		sync_collection_now()
	return res


func refresh_me() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "not_logged_in"}
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, "/api/me", null, true)
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
	return res


func update_display_name(new_name: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "not_logged_in"}
	var res: Dictionary = await _request(HTTPClient.METHOD_PATCH, "/api/me/profile", {"displayName": new_name.strip_edges()}, true)
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
	return res


func _build_collection_payload() -> Dictionary:
	var col: Dictionary = {}
	var monsters := 0
	var spells := 0
	var traps := 0
	if is_instance_valid(SaveData) and SaveData.data.get("collection") is Dictionary:
		var raw_col: Dictionary = SaveData.data["collection"]
		for key: Variant in raw_col.keys():
			var id: int = int(str(key))
			var copies: int = int(raw_col[key])
			if id <= 0 or copies <= 0:
				continue
			col[str(id)] = mini(copies, 99)
			if is_instance_valid(CardDB):
				var card: Dictionary = CardDB.by_id(id)
				if not card.is_empty():
					var cat: String = str(card.get("category", "monster"))
					if cat == "spell":
						spells += 1
					elif cat == "trap":
						traps += 1
					else:
						monsters += 1
	var wins := 0
	var losses := 0
	var draws := 0
	if is_instance_valid(SaveData) and SaveData.data.get("stats") is Dictionary:
		var stats_map: Dictionary = SaveData.data["stats"]
		for g: String in ["yugi", "kaiba", "joey"]:
			if stats_map.get(g) is Dictionary:
				var gs: Dictionary = stats_map[g]
				wins += int(gs.get("wins", 0))
				losses += int(gs.get("losses", 0))
				draws += int(gs.get("draws", 0))
	return {
		"collection": col,
		"stats": {
			"wins": wins,
			"losses": losses,
			"draws": draws,
			"monsters": monsters,
			"spells": spells,
			"traps": traps,
			"last_game": Game.current_game if is_instance_valid(Game) and Game.current_game in ["yugi", "kaiba", "joey"] else "joey"
		}
	}


func sync_collection_now() -> Dictionary:
	if not is_logged_in() or _syncing:
		return {"ok": false, "error": "busy_or_logged_out"}
	_syncing = true
	var payload: Dictionary = _build_collection_payload()
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/me/sync", payload, true)
	_syncing = false
	if bool(res.get("ok", false)):
		_apply_auth_result(res)
	return res


var _admin_token: String = ""


func is_admin_logged_in() -> bool:
	return _admin_token != ""


func admin_logout() -> void:
	_admin_token = ""


func _admin_request(method: int, path: String, body: Variant = null) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = HTTP_TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Accept: application/json"])
	var payload_str := ""
	if body != null:
		headers.append("Content-Type: application/json")
		payload_str = JSON.stringify(body)
	if _admin_token != "":
		headers.append("Authorization: Bearer " + _admin_token)
	var url: String = server_url + path
	var err: int = req.request(url, headers, method, payload_str)
	if err != OK:
		req.queue_free()
		return {"ok": false, "http_status": 0, "error": "network_error"}
	var completed: Array = await req.request_completed
	req.queue_free()
	var result_code: int = int(completed[0])
	var http_status: int = int(completed[1])
	var raw_body: PackedByteArray = completed[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "http_status": 0, "error": "network_error"}
	var text: String = raw_body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if http_status == 401 and path != "/api/admin/login":
		_admin_token = ""
	if parsed is Dictionary:
		var out: Dictionary = parsed
		out["http_status"] = http_status
		return out
	return {"ok": http_status >= 200 and http_status < 300, "http_status": http_status, "error": "invalid_response"}


func admin_login(passcode: String) -> Dictionary:
	var res: Dictionary = await _admin_request(HTTPClient.METHOD_POST, "/api/admin/login", {"passcode": passcode})
	if bool(res.get("ok", false)) and str(res.get("token", "")) != "":
		_admin_token = str(res["token"])
	return res


func admin_list_gift_codes() -> Dictionary:
	if _admin_token == "":
		return {"ok": false, "http_status": 401, "error": "unauthorized"}
	return await _admin_request(HTTPClient.METHOD_GET, "/api/admin/gift-codes")


func admin_create_gift_code(code: String, card_code: String, card_label: String, max_uses: int, copies: int = 1, reward_type: String = "card", cards: Array = []) -> Dictionary:
	if _admin_token == "":
		return {"ok": false, "http_status": 401, "error": "unauthorized"}
	var payload := {
		"code": code.strip_edges(),
		"rewardType": reward_type,
		"cardCode": card_code.strip_edges(),
		"cardLabel": card_label.strip_edges(),
		"maxUses": max_uses,
		"copies": copies
	}
	if reward_type == "deck" and not cards.is_empty():
		payload["cards"] = cards
	return await _admin_request(HTTPClient.METHOD_POST, "/api/admin/gift-codes", payload)


func admin_toggle_gift_code(code: String, active: bool) -> Dictionary:
	if _admin_token == "":
		return {"ok": false, "http_status": 401, "error": "unauthorized"}
	return await _admin_request(HTTPClient.METHOD_PATCH, "/api/admin/gift-codes/" + code.strip_edges().uri_encode(), {"active": active})


func admin_delete_gift_code(code: String) -> Dictionary:
	if _admin_token == "":
		return {"ok": false, "http_status": 401, "error": "unauthorized"}
	return await _admin_request(HTTPClient.METHOD_DELETE, "/api/admin/gift-codes/" + code.strip_edges().uri_encode())


func redeem_gift_code(raw_code: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "http_status": 0, "error": "not_logged_in"}
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/gift-codes/redeem", {"code": raw_code.strip_edges()}, true)
	if bool(res.get("ok", false)) and (bool(res.get("allCardsUnlocked", false)) or str(res.get("rewardType", "")).to_lower() == "unlock_all"):
		mark_all_cards_unlocked()
	return res


func fetch_players(query := "", online_only := false) -> Dictionary:
	var path: String = "/api/players?q=" + query.strip_edges().uri_encode()
	if online_only:
		path += "&onlineOnly=1"
	return await _request(HTTPClient.METHOD_GET, path, null, true)


func fetch_player_profile(target_id: String) -> Dictionary:
	var clean_id: String = target_id.strip_edges().trim_prefix("#")
	return await _request(HTTPClient.METHOD_GET, "/api/players/" + clean_id.uri_encode(), null, true)


func fetch_friends() -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_GET, "/api/friends", null, true)
	if bool(res.get("ok", false)):
		var inc: Variant = res.get("incoming", [])
		var fr: Variant = res.get("friends", [])
		if inc is Array:
			incoming_request_count = (inc as Array).size()
		if fr is Array:
			friend_count = (fr as Array).size()
		session_changed.emit()
	return res


func send_friend_request(target_id: String) -> Dictionary:
	return await _request(HTTPClient.METHOD_POST, "/api/friends/request", {"targetId": target_id.strip_edges().trim_prefix("#")}, true)


func respond_friend_request(from_id: String, accept: bool) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_POST, "/api/friends/respond", {"fromId": from_id.strip_edges(), "accept": accept}, true)
	if bool(res.get("ok", false)):
		refresh_me()
	return res


func remove_friend(target_id: String) -> Dictionary:
	var res: Dictionary = await _request(HTTPClient.METHOD_DELETE, "/api/friends/" + target_id.strip_edges().uri_encode(), null, true)
	if bool(res.get("ok", false)):
		refresh_me()
	return res


func logout() -> void:
	_close_presence()
	token = ""
	player_id = ""
	display_name = ""
	username = ""
	auth_provider = ""
	profile = {}
	incoming_request_count = 0
	friend_count = 0
	all_cards_unlocked = false
	online_pool = "competitive"
	_pending_challenge_target = ""
	_pending_challenge_pool = "competitive"
	dm_unread.clear()
	active_dm_friend_id = ""
	_save_session()
	session_changed.emit()


# --- Presencia en vivo e invitaciones directas a duelo ---

func _connect_presence() -> void:
	if not is_logged_in() or DisplayServer.get_name() == "headless":
		return
	_close_presence()
	var ws_url: String = Lan.normalize_relay_url(server_url)
	if ws_url == "":
		return
	_ws = WebSocketPeer.new()
	_ws.outbound_buffer_size = 32768
	_ws.inbound_buffer_size = 32768
	if _ws.connect_to_url(ws_url) != OK:
		_ws = null
		return
	_ws_authed = false
	_ping_clock = 0.0
	_reconnect_clock = 0.0


func _close_presence() -> void:
	if _ws != null:
		if _ws.get_ready_state() in [WebSocketPeer.STATE_CONNECTING, WebSocketPeer.STATE_OPEN]:
			_ws.close(1000, "logout")
		_ws = null
	_ws_authed = false
	matchmaking_active = false
	matchmaking_game = ""
	if presence_connected:
		presence_connected = false
		session_changed.emit()


func send_duel_invite(target_id: String, room_code: String, game_id := "joey", pool := "") -> void:
	var eff_pool: String = "sandbox" if (all_cards_unlocked or pool == "sandbox" or (pool == "" and effective_pool() == "sandbox")) else "competitive"
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not _ws_authed or not presence_connected:
		_pending_challenge_target = target_id.strip_edges()
		_pending_challenge_game = game_id
		_pending_challenge_pool = eff_pool
		_pending_invite_room_code = room_code.strip_edges()
		if _ws == null:
			_connect_presence()
		return
	_pending_invite_room_code = ""
	_ws.send_text(JSON.stringify({
		"type": "invite_duel",
		"targetId": target_id.strip_edges(),
		"roomCode": room_code.strip_edges(),
		"game": game_id,
		"pool": eff_pool,
		"fromName": display_name
	}))


func decline_duel_invite(from_id: String, room_code: String) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not _ws_authed:
		return
	_ws.send_text(JSON.stringify({
		"type": "invite_decline",
		"fromId": from_id.strip_edges(),
		"roomCode": room_code.strip_edges()
	}))


func challenge_player(target_id: String, game_id := "joey", pool := "") -> int:
	if not is_logged_in():
		return ERR_UNAUTHORIZED
	if _ws == null:
		_connect_presence()
	var eff_pool: String = "sandbox" if (all_cards_unlocked or pool == "sandbox" or (pool == "" and effective_pool() == "sandbox")) else "competitive"
	_pending_challenge_target = target_id.strip_edges()
	_pending_challenge_game = game_id
	_pending_challenge_pool = eff_pool
	_pending_invite_room_code = ""
	var pname: String = display_name if display_name != "" else "Duelist"
	return Lan.host_online(server_url, pname, game_id, eff_pool)


func cancel_challenge() -> void:
	_pending_challenge_target = ""
	_pending_invite_room_code = ""
	if Lan.is_online() and Lan.players() < 2:
		Lan.close()


func accept_duel_invite(room_code: String, game_id := "joey", pool := "") -> int:
	hide_global_invite_toast()
	var eff_pool: String = "sandbox" if (all_cards_unlocked or pool == "sandbox") else ("competitive" if pool == "competitive" else effective_pool())
	var pname: String = display_name if display_name != "" else "Duelist"
	return Lan.join_online(server_url, room_code, pname, game_id, eff_pool)


func _on_lan_room_code_ready(code: String) -> void:
	if _pending_challenge_target != "" and code != "":
		send_duel_invite(_pending_challenge_target, code, _pending_challenge_game, _pending_challenge_pool)


# --- Matchmaking aleatorio y Chat Global / Privado ---

func start_matchmaking(game_id: String, pool := "") -> bool:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not _ws_authed:
		if is_logged_in() and _ws == null:
			_connect_presence()
		return false
	var eff_pool: String = "sandbox" if (all_cards_unlocked or pool == "sandbox" or (pool == "" and effective_pool() == "sandbox")) else "competitive"
	matchmaking_game = game_id
	_ws.send_text(JSON.stringify({
		"type": "matchmaking_join",
		"game": game_id,
		"pool": eff_pool
	}))
	return true


func cancel_matchmaking() -> void:
	matchmaking_active = false
	matchmaking_game = ""
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN and _ws_authed:
		_ws.send_text('{"type":"matchmaking_leave"}')


func join_matchmaking_room(room_code: String, as_host: bool, game_id: String, pool := "") -> int:
	var eff_pool: String = "sandbox" if (all_cards_unlocked or pool == "sandbox" or (pool == "" and effective_pool() == "sandbox")) else "competitive"
	var pname: String = display_name if display_name != "" else "Duelist"
	return Lan.claim_online_match(server_url, room_code, as_host, pname, game_id, eff_pool)


func fetch_global_chat() -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "not_logged_in"}
	return await _request(HTTPClient.METHOD_GET, "/api/chat/global", null, true)


func send_global_chat(text: String) -> bool:
	var cleaned: String = text.strip_edges()
	if cleaned == "" or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not _ws_authed:
		return false
	_ws.send_text(JSON.stringify({
		"type": "chat_global_send",
		"text": cleaned
	}))
	return true


func fetch_dm_history(friend_id: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "not_logged_in"}
	return await _request(HTTPClient.METHOD_GET, "/api/chat/dm/" + friend_id.strip_edges().uri_encode(), null, true)


func send_dm(to_id: String, text: String) -> bool:
	var cleaned: String = text.strip_edges()
	if cleaned == "" or to_id.strip_edges() == "" or _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN or not _ws_authed:
		return false
	_ws.send_text(JSON.stringify({
		"type": "chat_dm_send",
		"toId": to_id.strip_edges(),
		"text": cleaned
	}))
	return true


func mark_dm_read(friend_id: String) -> void:
	if dm_unread.erase(friend_id):
		session_changed.emit()


func total_dm_unread() -> int:
	var total := 0
	for v: Variant in dm_unread.values():
		total += int(v)
	return total


func _process(delta: float) -> void:
	if is_instance_valid(_global_invite_panel) and _global_invite_panel.visible:
		var vp: Rect2 = get_viewport().get_visible_rect()
		_global_invite_panel.position = Vector2(
			vp.get_center().x - _global_invite_panel.size.x * 0.5,
			maxf(14.0, vp.position.y + 18.0)
		)
	if not is_logged_in() or DisplayServer.get_name() == "headless":
		return
	if _ws == null:
		_reconnect_clock += delta
		if _reconnect_clock >= PRESENCE_RECONNECT_EVERY:
			_reconnect_clock = 0.0
			_connect_presence()
		return
	_ws.poll()
	var st: int = _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _ws_authed:
			_ws_authed = true
			_ws.send_text(JSON.stringify({"type": "presence", "token": token}))
		_ping_clock += delta
		if _ping_clock >= PRESENCE_PING_EVERY:
			_ping_clock = 0.0
			_ws.send_text('{"type":"ping"}')
		while _ws != null and _ws.get_available_packet_count() > 0:
			var raw: PackedByteArray = _ws.get_packet()
			if _ws.was_string_packet():
				_on_ws_message(raw.get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED:
		_close_presence()
		_reconnect_clock = 0.0


func _on_ws_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var msg: Dictionary = parsed
	match str(msg.get("type", "")):
		"presence_ok":
			if msg.has("allCardsUnlocked") and bool(msg.get("allCardsUnlocked", false)):
				mark_all_cards_unlocked()
			if not presence_connected:
				presence_connected = true
				session_changed.emit()
			if _pending_challenge_target != "" and _pending_invite_room_code != "":
				send_duel_invite(_pending_challenge_target, _pending_invite_room_code, _pending_challenge_game, _pending_challenge_pool)
		"friend_request":
			incoming_request_count += 1
			session_changed.emit()
			friend_request_received.emit(str(msg.get("fromId", "")), str(msg.get("fromName", "")))
		"friend_accepted":
			friend_count += 1
			session_changed.emit()
			friend_accepted_received.emit(str(msg.get("playerId", "")), str(msg.get("displayName", "")))
		"duel_invite":
			var f_id: String = str(msg.get("fromId", ""))
			var f_name: String = str(msg.get("fromName", "")).strip_edges()
			if f_name == "":
				f_name = "Duelist"
			var r_code: String = str(msg.get("roomCode", ""))
			var g_id: String = str(msg.get("game", "joey"))
			var inv_pool: String = str(msg.get("pool", "competitive"))
			if inv_pool not in ["competitive", "sandbox"]:
				inv_pool = "competitive"
			_show_global_invite_toast(f_id, f_name, r_code, g_id, inv_pool)
			duel_invite_received.emit(f_id, f_name, r_code, g_id, inv_pool)
		"invite_declined":
			var code: String = str(msg.get("roomCode", ""))
			if _pending_challenge_target != "" and Lan.room_code == code:
				_pending_challenge_target = ""
				_pending_invite_room_code = ""
				Lan.close()
			invite_declined_received.emit(str(msg.get("byId", "")), str(msg.get("byName", "")), code)
		"invite_status":
			invite_status_received.emit(str(msg.get("targetId", "")), str(msg.get("roomCode", "")), bool(msg.get("delivered", false)))
		"invite_error":
			var err_c: String = str(msg.get("code", "error"))
			var tgt_id: String = str(msg.get("targetId", ""))
			if err_c == "unlocked_account_sandbox_only":
				mark_all_cards_unlocked()
			cancel_challenge()
			invite_error_received.emit(err_c, tgt_id)
		"matchmaking_queued":
			matchmaking_active = true
			matchmaking_game = str(msg.get("game", matchmaking_game))
			matchmaking_queued.emit(matchmaking_game, int(msg.get("queueSize", 1)))
		"match_found":
			matchmaking_active = false
			var mg: String = str(msg.get("game", "joey"))
			var mp: String = str(msg.get("pool", ""))
			if mp in ["competitive", "sandbox"] and not all_cards_unlocked:
				online_pool = mp
			matchmaking_found.emit(
				mg,
				str(msg.get("roomCode", "")),
				bool(msg.get("isHost", false)),
				str(msg.get("opponentId", "")),
				str(msg.get("opponentName", "Duelist"))
			)
		"matchmaking_left":
			matchmaking_active = false
			matchmaking_game = ""
			matchmaking_left.emit()
		"matchmaking_error":
			matchmaking_active = false
			matchmaking_game = ""
			var m_err: String = str(msg.get("code", "error"))
			if m_err == "unlocked_account_sandbox_only":
				mark_all_cards_unlocked()
			matchmaking_error_received.emit(m_err)
		"chat_global":
			var gm_val: Variant = msg.get("message", {})
			if gm_val is Dictionary:
				global_chat_received.emit(gm_val as Dictionary)
		"chat_dm":
			var dm_val: Variant = msg.get("message", {})
			if dm_val is Dictionary:
				var dm: Dictionary = dm_val as Dictionary
				var from_id: String = str(dm.get("fromId", ""))
				if from_id != "" and from_id != player_id and from_id != active_dm_friend_id:
					dm_unread[from_id] = int(dm_unread.get(from_id, 0)) + 1
					session_changed.emit()
				dm_received.emit(dm)
		"chat_error":
			chat_error_received.emit(str(msg.get("code", "error")))
		"pong":
			pass


func _build_global_invite_toast() -> void:
	_global_invite_layer = CanvasLayer.new()
	_global_invite_layer.layer = 115
	add_child(_global_invite_layer)

	_global_invite_panel = PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.07, 0.16, 0.98)
	box.border_color = Color(0.96, 0.78, 0.30, 1.0)
	box.set_border_width_all(2)
	box.set_corner_radius_all(12)
	box.set_content_margin_all(14)
	box.shadow_color = Color(0, 0, 0, 0.65)
	box.shadow_size = 14
	_global_invite_panel.add_theme_stylebox_override("panel", box)
	_global_invite_panel.custom_minimum_size = Vector2(460, 168)
	_global_invite_panel.hide()
	_global_invite_layer.add_child(_global_invite_panel)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(430, 0)
	v.add_theme_constant_override("separation", 8)
	_global_invite_panel.add_child(v)

	_global_invite_title = Label.new()
	_global_invite_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_instance_valid(Assets):
		_global_invite_title.add_theme_font_override("font", Assets.ui_font(700))
	_global_invite_title.add_theme_font_size_override("font_size", 18)
	_global_invite_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.36))
	v.add_child(_global_invite_title)

	_global_invite_body = Label.new()
	_global_invite_body.custom_minimum_size = Vector2(420, 48)
	_global_invite_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_global_invite_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_global_invite_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_instance_valid(Assets):
		_global_invite_body.add_theme_font_override("font", Assets.ui_font(600))
	_global_invite_body.add_theme_font_size_override("font_size", 15)
	_global_invite_body.add_theme_color_override("font_color", Color(0.96, 0.95, 0.90))
	v.add_child(_global_invite_body)

	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)

	_global_invite_accept_btn = Button.new()
	_global_invite_accept_btn.custom_minimum_size = Vector2(175, 38)
	var acc_box := StyleBoxFlat.new()
	acc_box.bg_color = Color(0.11, 0.44, 0.26, 0.98)
	acc_box.border_color = Color(0.96, 0.78, 0.30, 1.0)
	acc_box.set_border_width_all(2)
	acc_box.set_corner_radius_all(8)
	acc_box.set_content_margin_all(8)
	_global_invite_accept_btn.add_theme_stylebox_override("normal", acc_box)
	_global_invite_accept_btn.add_theme_stylebox_override("hover", acc_box)
	_global_invite_accept_btn.add_theme_stylebox_override("pressed", acc_box)
	_global_invite_accept_btn.add_theme_color_override("font_color", Color.WHITE)
	if is_instance_valid(Assets):
		_global_invite_accept_btn.add_theme_font_override("font", Assets.ui_font(700))
	_global_invite_accept_btn.pressed.connect(_on_global_invite_accept)
	btns.add_child(_global_invite_accept_btn)

	_global_invite_decline_btn = Button.new()
	_global_invite_decline_btn.custom_minimum_size = Vector2(115, 38)
	var dec_box := StyleBoxFlat.new()
	dec_box.bg_color = Color(0.36, 0.12, 0.14, 0.98)
	dec_box.border_color = Color(0.85, 0.42, 0.42, 0.9)
	dec_box.set_border_width_all(2)
	dec_box.set_corner_radius_all(8)
	dec_box.set_content_margin_all(8)
	_global_invite_decline_btn.add_theme_stylebox_override("normal", dec_box)
	_global_invite_decline_btn.add_theme_stylebox_override("hover", dec_box)
	_global_invite_decline_btn.add_theme_stylebox_override("pressed", dec_box)
	_global_invite_decline_btn.add_theme_color_override("font_color", Color.WHITE)
	if is_instance_valid(Assets):
		_global_invite_decline_btn.add_theme_font_override("font", Assets.ui_font(700))
	_global_invite_decline_btn.pressed.connect(_on_global_invite_decline)
	btns.add_child(_global_invite_decline_btn)


func _edition_label(g: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		match g:
			"yugi": return "يوغي"
			"kaiba": return "كايبا"
			"joey": return "جوي"
	match g:
		"yugi": return "Yugi the Destiny"
		"kaiba": return "Kaiba the Revenge"
		"joey": return "Joey the Passion"
	return g


func _show_global_invite_toast(from_id: String, from_name: String, room_code: String, game_id: String, pool := "competitive") -> void:
	if not is_instance_valid(_global_invite_panel):
		return
	var g: String = game_id if game_id in ["yugi", "kaiba", "joey"] else "joey"
	var p: String = "sandbox" if pool == "sandbox" else "competitive"
	_global_invite_data = {"from_id": from_id, "from_name": from_name, "room_code": room_code, "game_id": g, "pool": p}
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	var plbl: String = pool_label(p)
	if lang == "a":
		_global_invite_title.text = "⚔️ إشعار تحدي مبارزة أونلاين!"
		_global_invite_body.text = "%s أرسل لك تحدي مبارزة أونلاين!\n(الحساب: %s #%s  ·  %s  ·  %s)" % [from_name, from_name, from_id, _edition_label(g), plbl]
		_global_invite_accept_btn.text = "قبول التحدي"
		_global_invite_decline_btn.text = "رفض"
	elif lang == "s":
		_global_invite_title.text = "⚔️ ¡Notificación de desafío online!"
		_global_invite_body.text = "¡%s te envió un desafío de duelo!\n(Cuenta: %s #%s  ·  %s  ·  %s)" % [from_name, from_name, from_id, _edition_label(g), plbl]
		_global_invite_accept_btn.text = "Aceptar desafío"
		_global_invite_decline_btn.text = "Rechazar"
	else:
		_global_invite_title.text = "⚔️ Online Duel Challenge!"
		_global_invite_body.text = "%s sent you a duel challenge!\n(Account: %s #%s  ·  %s  ·  %s)" % [from_name, from_name, from_id, _edition_label(g), plbl]
		_global_invite_accept_btn.text = "Accept Challenge"
		_global_invite_decline_btn.text = "Decline"
	var vp: Rect2 = get_viewport().get_visible_rect()
	var w: float = minf(460.0, vp.size.x - 24.0)
	_global_invite_body.custom_minimum_size = Vector2(maxf(240.0, w - 40.0), 48.0)
	_global_invite_panel.custom_minimum_size = Vector2(w, 168.0)
	_global_invite_panel.show()
	_position_global_invite_toast()
	_position_global_invite_toast.call_deferred()


func _position_global_invite_toast() -> void:
	if not is_instance_valid(_global_invite_panel) or not _global_invite_panel.visible:
		return
	var vp: Rect2 = get_viewport().get_visible_rect()
	_global_invite_panel.reset_size()
	var sz: Vector2 = _global_invite_panel.get_combined_minimum_size()
	sz.x = clampf(sz.x, 300.0, vp.size.x - 24.0)
	sz.y = clampf(sz.y, 150.0, vp.size.y - 28.0)
	_global_invite_panel.size = sz
	_global_invite_panel.position = Vector2(
		maxf(12.0, vp.get_center().x - sz.x * 0.5),
		maxf(14.0, vp.position.y + 18.0)
	).floor()


func hide_global_invite_toast() -> void:
	_global_invite_data = {}
	if is_instance_valid(_global_invite_panel):
		_global_invite_panel.hide()


func _on_global_invite_accept() -> void:
	if _global_invite_data.is_empty():
		hide_global_invite_toast()
		return
	var inv: Dictionary = _global_invite_data
	hide_global_invite_toast()
	var g: String = str(inv.get("game_id", "joey"))
	var code: String = str(inv.get("room_code", ""))
	var inv_pool: String = str(inv.get("pool", "competitive"))
	if not is_instance_valid(Paths) or not Paths.has_game(g):
		return
	if accept_duel_invite(code, g, inv_pool) == OK and is_instance_valid(Game):
		if is_instance_valid(Audio):
			Audio.stop_music()
		Game.open_lan_online(g)


func _on_global_invite_decline() -> void:
	if not _global_invite_data.is_empty():
		decline_duel_invite(str(_global_invite_data.get("from_id", "")), str(_global_invite_data.get("room_code", "")))
	hide_global_invite_toast()

