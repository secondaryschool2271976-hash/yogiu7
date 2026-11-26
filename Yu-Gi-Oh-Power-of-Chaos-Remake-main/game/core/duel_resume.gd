class_name DuelResume
extends RefCounted
## Auto-save and restore of an in-progress single-player duel (Yugi, Kaiba, Joey).

const VERSION := 1
const FILE_NAME := "duel_resume.dat"

const CLASSIC_LOW_START := 0x5a0000
const CLASSIC_LOW_END := 0x5b5000
const CLASSIC_HIGH_START := 0xa0f000
const CLASSIC_HIGH_END := 0xa18000

const JOEY_LOW_START := 0x5eb000
const JOEY_LOW_END := 0x5f5000
const JOEY_HIGH_START := 0xa52000
const JOEY_HIGH_END := 0xa5e000


static func _autoload(node_name: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var root: Window = (loop as SceneTree).root
		if root != null and root.has_node(node_name):
			return root.get_node(node_name)
	return null


static func file_path() -> String:
	var paths: Node = _autoload("Paths")
	if paths == null:
		return ""
	var save_dir: String = str(paths.get("save_dir"))
	return "" if save_dir == "" else save_dir.path_join(FILE_NAME)


static func has_saved() -> bool:
	return not summary().is_empty()


static func clear(notify_cloud := true) -> void:
	var path: String = file_path()
	if path == "":
		return
	var existed: bool = FileAccess.file_exists(path)
	if existed:
		DirAccess.remove_absolute(path)
	var tmp: String = path + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	if notify_cloud and existed:
		var cs: Node = _autoload("CloudSync")
		if cs != null and cs.has_method("on_resume_changed"):
			cs.call("on_resume_changed", true)


static func save_snapshot(snapshot: Dictionary) -> bool:
	if snapshot.is_empty():
		return false
	var path: String = file_path()
	if path == "":
		return false
	var dir_path: String = path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var raw: PackedByteArray = var_to_bytes(snapshot)
	if raw.is_empty():
		return false
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	if compressed.is_empty():
		return false
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return false
		f.store_buffer(compressed)
		f.flush()
		f.close()
		return true
	f.store_buffer(compressed)
	f.flush()
	f.close()
	var err: Error = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		var direct: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if direct == null:
			return false
		direct.store_buffer(compressed)
		direct.flush()
		direct.close()
		DirAccess.remove_absolute(tmp)
	var cs: Node = _autoload("CloudSync")
	if cs != null and cs.has_method("on_resume_changed"):
		cs.call("on_resume_changed", false)
	return true


static func load_snapshot() -> Dictionary:
	var path: String = file_path()
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var compressed: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if compressed.is_empty():
		return {}
	var raw: PackedByteArray = compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return {}
	var decoded: Variant = bytes_to_var(raw)
	if not decoded is Dictionary:
		return {}
	var snap: Dictionary = decoded as Dictionary
	if int(snap.get("version", 0)) != VERSION:
		return {}
	var game_id: String = str(snap.get("game", ""))
	if game_id not in ["yugi", "kaiba", "joey"]:
		return {}
	var paths: Node = _autoload("Paths")
	if paths == null or not bool(paths.call("has_data")) or not bool(paths.call("has_game", game_id)):
		return {}
	var kind: String = str(snap.get("kind", ""))
	if kind == "joey":
		var low: Variant = snap.get("engine_mem_low", PackedByteArray())
		var high: Variant = snap.get("engine_mem_high", PackedByteArray())
		if not (low is PackedByteArray and high is PackedByteArray):
			return {}
		if (low as PackedByteArray).size() != JOEY_LOW_END - JOEY_LOW_START:
			return {}
		if (high as PackedByteArray).size() != JOEY_HIGH_END - JOEY_HIGH_START:
			return {}
	elif kind == "classic":
		var low: Variant = snap.get("mem_low", PackedByteArray())
		var high: Variant = snap.get("mem_high", PackedByteArray())
		if not (low is PackedByteArray and high is PackedByteArray):
			return {}
		if (low as PackedByteArray).size() != CLASSIC_LOW_END - CLASSIC_LOW_START:
			return {}
		if (high as PackedByteArray).size() != CLASSIC_HIGH_END - CLASSIC_HIGH_START:
			return {}
	else:
		return {}
	return snap


static func summary() -> Dictionary:
	var snap: Dictionary = load_snapshot()
	if snap.is_empty():
		return {}
	return {
		"game": str(snap.get("game", "")),
		"lp": snap.get("lp", [8000, 8000]),
		"duel_mode": int(snap.get("duel_mode", 0)),
		"match_duel": int(snap.get("match_duel", 1)),
		"timestamp": int(snap.get("timestamp", 0)),
	}


static func is_clean_state(scene: Node) -> bool:
	if not is_instance_valid(scene):
		return false
	if bool(scene.get("_finished")) or bool(scene.get("_lan")):
		return false
	var game_node: Node = _autoload("Game")
	if game_node != null and bool(game_node.get("joey_demo")):
		return false
	var paths: Node = _autoload("Paths")
	if paths != null and str(paths.call("cmdline_value", "scenario")) != "":
		return false
	var duel_var: Variant = scene.get("_duel")
	if duel_var == null or not duel_var is Duel:
		return false
	var duel: Duel = duel_var as Duel
	if duel.executed <= 0:
		return false
	if not duel.dialog_open.is_empty() or not duel.list_open.is_empty():
		return false
	var visual_var: Variant = scene.get("_visual")
	if visual_var == null or not is_instance_valid(visual_var):
		return false
	if bool(visual_var.call("busy")) or bool(visual_var.get("_start_banner_shade")):
		return false
	if not scene.has_method("_waiting_for_player") or not bool(scene.call("_waiting_for_player")):
		return false
	if duel is JoeyPresentationAdapter:
		var adapter: JoeyPresentationAdapter = duel as JoeyPresentationAdapter
		if adapter.engine == null:
			return false
		var jm: JoeyMem = adapter.engine.m
		if (jm.u32(0xa57804) & 3) != 0:
			return false
		if jm.u8(0xa55c8d) != 0 or jm.u8(0xa55c8e) != 0:
			return false
	else:
		if (duel.m.u32(0xa13408) & 3) != 0 or duel.m.u8(0xa15fe5) != 0:
			return false
	return true


static func _pack_commands(list: Array[PackedInt32Array]) -> Array:
	var out: Array = []
	for item: PackedInt32Array in list:
		out.append(item.duplicate())
	return out


static func capture(scene: Node) -> Dictionary:
	if not is_clean_state(scene):
		return {}
	var duel: Duel = scene.get("_duel") as Duel
	var game_node: Node = _autoload("Game")
	var snap: Dictionary = {
		"version": VERSION,
		"game": str(scene.get("game")),
		"timestamp": int(Time.get_unix_time_from_system()),
		"duel_mode": int(game_node.get("duel_mode")) if game_node != null else 0,
		"match_duel": int(game_node.get("match_duel")) if game_node != null else 1,
		"match_results": (game_node.get("match_results") as Array).duplicate() if game_node != null else [0, 0, 0],
		"match_outcome": int(game_node.get("match_outcome")) if game_node != null else 0,
		"rival_deck": str(game_node.get("rival_deck")) if game_node != null else "",
		"replay_decks": (scene.get("_replay_decks") as Array).duplicate(true),
		"replay_options": int(scene.get("_replay_options")),
		"replay_seed": int(scene.get("_replay_seed")),
		"ph_p": int(scene.get("_ph_p")),
		"ph_phase": int(scene.get("_ph_phase")),
		"lp": [int(duel.m.u16(DuelMem.pl(0))), int(duel.m.u16(DuelMem.pl(1)))],
	}
	if duel is JoeyPresentationAdapter:
		var adapter: JoeyPresentationAdapter = duel as JoeyPresentationAdapter
		var eng: JoeyEngine = adapter.engine
		snap["kind"] = "joey"
		snap["engine_mem_low"] = eng.m.bytes.slice(JOEY_LOW_START - JoeyMem.BASE, JOEY_LOW_END - JoeyMem.BASE)
		snap["engine_mem_high"] = eng.m.bytes.slice(JOEY_HIGH_START - JoeyMem.BASE, JOEY_HIGH_END - JoeyMem.BASE)
		snap["rng_holdrand"] = int(eng.rng.holdrand)
		snap["phase_choice"] = int(eng.phase_choice)
		snap["tutorial_wait"] = int(eng.tutorial_wait)
		snap["native_normal_kind"] = int(adapter.native_normal_kind)
		snap["local_native_player"] = int(adapter.local_native_player)
		snap["native_version"] = int(adapter.native_version)
		snap["native_ticks"] = int(adapter.native_ticks)
		snap["options"] = int(adapter.options)
		snap["seed"] = int(adapter.seed)
		snap["field_target"] = int(adapter._field_target)
		snap["focused_excluded_player"] = int(adapter.focused_excluded_player)
		snap["recorded"] = _pack_commands(eng.recorded)
		snap["file_recorded"] = _pack_commands(adapter.file_recorded)
	else:
		snap["kind"] = "classic"
		snap["mem_low"] = duel.m.bytes.slice(CLASSIC_LOW_START - DuelMem.BASE, CLASSIC_LOW_END - DuelMem.BASE)
		snap["mem_high"] = duel.m.bytes.slice(CLASSIC_HIGH_START - DuelMem.BASE, CLASSIC_HIGH_END - DuelMem.BASE)
		snap["rng_holdrand"] = int(duel.rng.holdrand)
		snap["rules_game"] = str(duel.rules_game)
		snap["native_version"] = int(duel.native_version)
		snap["options"] = int(duel.options)
		snap["seed"] = int(duel.seed)
		snap["executed"] = int(duel.executed)
		snap["game_mode"] = int(duel.game_mode)
		snap["recorded"] = _pack_commands(duel.recorded)
		snap["response_text"] = duel._response_text.duplicate(true)
	return snap


static func _write_slice(dst: PackedByteArray, offset: int, src: PackedByteArray) -> void:
	for i in src.size():
		dst[offset + i] = src[i]


static func restore_duel(duel: Duel, snap: Dictionary) -> bool:
	if duel == null or snap.is_empty():
		return false
	var kind: String = str(snap.get("kind", ""))
	if kind == "joey" and duel is JoeyPresentationAdapter:
		var adapter: JoeyPresentationAdapter = duel as JoeyPresentationAdapter
		var eng: JoeyEngine = adapter.engine
		if eng == null:
			return false
		var low: PackedByteArray = snap.get("engine_mem_low", PackedByteArray())
		var high: PackedByteArray = snap.get("engine_mem_high", PackedByteArray())
		if low.size() != JOEY_LOW_END - JOEY_LOW_START or high.size() != JOEY_HIGH_END - JOEY_HIGH_START:
			return false
		eng.init_application()
		_write_slice(eng.m.bytes, JOEY_LOW_START - JoeyMem.BASE, low)
		_write_slice(eng.m.bytes, JOEY_HIGH_START - JoeyMem.BASE, high)
		eng.m._stack_top = 0
		eng.rng.holdrand = int(snap.get("rng_holdrand", 0))
		eng.phase_choice = int(snap.get("phase_choice", 0))
		eng.tutorial_wait = int(snap.get("tutorial_wait", 0))
		eng.ui_enabled = true
		eng.ui_cursor_ready = false
		eng.ui_busy = false
		eng.lp_projection_enabled = true
		eng.set_lp_projection_state([])
		eng.network_transport = null
		eng.events.clear()
		eng.unported_calls.clear()
		eng.recorded.clear()
		var rec_list: Array = snap.get("recorded", [])
		for cmd_var: Variant in rec_list:
			if cmd_var is PackedInt32Array:
				eng.recorded.append((cmd_var as PackedInt32Array).duplicate())
		if eng is JoeyReplayEngine:
			(eng as JoeyReplayEngine).replay_active = false
		adapter.net = null
		adapter.file_recording_enabled = true
		adapter.file_recorded.clear()
		var file_rec: Array = snap.get("file_recorded", [])
		for cmd_var: Variant in file_rec:
			if cmd_var is PackedInt32Array:
				adapter.file_recorded.append((cmd_var as PackedInt32Array).duplicate())
		adapter.native_normal_kind = int(snap.get("native_normal_kind", 0))
		adapter.local_native_player = int(snap.get("local_native_player", 1))
		adapter.native_version = int(snap.get("native_version", 1300))
		adapter.native_ticks = int(snap.get("native_ticks", 0))
		adapter.options = int(snap.get("options", 0))
		adapter.seed = int(snap.get("seed", 0))
		adapter.game_mode = DuelBase.GAME_NORMAL
		adapter.focused_excluded_player = int(snap.get("focused_excluded_player", -1))
		adapter._battle_player = 0
		adapter._battle_attacker = -1
		adapter._done = false
		adapter.frame_pressed = 0
		adapter.events.clear()
		adapter.recorded.clear()
		adapter.unported_calls.clear()
		adapter.mismatches.clear()
		adapter.dialog_open.clear()
		adapter.list_open.clear()
		adapter._text_templates.clear()
		adapter._dialog_template.clear()
		adapter._last_text_symbol.clear()
		adapter._lp_held.clear()
		adapter._lp_started.clear()
		adapter._native_event_pos = 0
		adapter._native_record_pos = 0
		adapter._mail_stamp = ""
		adapter._field_target = int(snap.get("field_target", 0))
		adapter.m.set_u32(0xa114b4, 0)
		adapter.m.set_u16(0xa133ec, (adapter.m.u16(0xa133ec) & 0xfff0) | (adapter._field_target & 15))
		for p in 2:
			adapter._lp_targets[p] = eng.m.u16(JoeyMem.pl(p) + JoeyMem.P_LP)
		adapter.synchronize_view()
		return true
	if kind == "classic" and not (duel is JoeyPresentationAdapter):
		var low: PackedByteArray = snap.get("mem_low", PackedByteArray())
		var high: PackedByteArray = snap.get("mem_high", PackedByteArray())
		if low.size() != CLASSIC_LOW_END - CLASSIC_LOW_START or high.size() != CLASSIC_HIGH_END - CLASSIC_HIGH_START:
			return false
		_write_slice(duel.m.bytes, CLASSIC_LOW_START - DuelMem.BASE, low)
		_write_slice(duel.m.bytes, CLASSIC_HIGH_START - DuelMem.BASE, high)
		duel.m._stack_top = 0
		duel.rng.holdrand = int(snap.get("rng_holdrand", 0))
		duel.rules_game = str(snap.get("rules_game", duel.rules_game))
		duel.native_version = int(snap.get("native_version", 100))
		duel.options = int(snap.get("options", 0))
		duel.seed = int(snap.get("seed", 0))
		duel.game_mode = int(snap.get("game_mode", DuelBase.GAME_NORMAL))
		duel.executed = int(snap.get("executed", 0))
		duel.recorded.clear()
		var rec_list: Array = snap.get("recorded", [])
		for cmd_var: Variant in rec_list:
			if cmd_var is PackedInt32Array:
				duel.recorded.append((cmd_var as PackedInt32Array).duplicate())
		duel._incoming.clear()
		duel._incoming_pos = 0
		duel.events.clear()
		duel.headless_detached.clear()
		duel.mismatches.clear()
		duel.unported_calls.clear()
		duel.ui_pending.clear()
		duel._ui_answer = -1
		duel.dialog_open = {}
		duel.list_open = {}
		var resp: Variant = snap.get("response_text", {})
		duel._response_text = (resp as Dictionary).duplicate(true) if resp is Dictionary else {}
		return true
	return false
