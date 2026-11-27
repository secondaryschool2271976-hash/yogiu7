extends Node
## Headless card-effect harness (dev tool, excluded from APK builds via tests/* in export_presets).
##
## godot --headless --path game res://tests/duel_harness/duel_harness.tscn -- \
##     --data=/path/to/data --scenarios=res://tests/duel_harness/redeyes.json [--only=3131]
##
## --data is a folder holding common/bin/*.bin and common/duel/yugi_image.bin (the original game
## data, never committed). Each scenario sets hands/field/grave/deck/banish, then calls
## CustomCardEffects.can_activate() and resolve_chain_link() directly and prints the state.
## It does NOT run the engine's own activation flow (chain building, UI prompts, timing windows).

const LOC := {"hand": 11, "deck": 13, "grave": 14, "banish": 15, "field": 0, "st": 5}
var failures := 0
var ran := 0
var _cards_by_name := {}


func _arg(name: String, fallback := "") -> String:
	var prefix := "--%s=" % name
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	var data := _arg("data")
	var path := _arg("scenarios", "res://tests/duel_harness/redeyes.json")
	var only := _arg("only")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("cannot read scenarios: ", path)
		get_tree().quit(2)
		return
	_index_names()
	for sc: Dictionary in parsed.get("scenarios", []):
		if only != "" and str(sc.get("name", "")).find(only) < 0 and str(sc.get("card", "")).find(only) < 0:
			continue
		_scenario(data, sc)
	print("== %d scenarios, %d failed" % [ran, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _index_names() -> void:
	var f: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/cards/extra_cards.json"))
	for c: Dictionary in f.get("cards", []):
		_cards_by_name[str(c["names"]["eng"]).to_lower()] = int(c["internal_id"])


func _id(v: Variant) -> int:
	if v is float or v is int:
		return int(v)
	var s := str(v)
	if s.is_valid_int():
		return s.to_int()
	var k := s.to_lower()
	if _cards_by_name.has(k):
		return _cards_by_name[k]
	push_error("unknown card name: " + s)
	return -1


func _ids(list: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in list:
		out.append(_id(v))
	return out


func _filler() -> PackedInt32Array:
	# 40 filler Traps (Bottomless Trap Hole, Compulsory Evacuation Device): never a monster, so deck-search conditions are not satisfied by accident.
	var out := PackedInt32Array()
	for i in 40:
		out.append(2521 + (i % 2))
	return out


func _scenario(data: String, sc: Dictionary) -> void:
	ran += 1
	var name := str(sc.get("name", sc.get("card", "?")))
	var duel: Duel = Duel.create(data, _arg("game", "yugi"))
	if duel == null:
		printerr("Duel.create failed (check --data)")
		failures += 1
		return
	var hands := [_ids(sc.get("hand", [[], []])[0]), _ids(sc.get("hand", [[], []])[1])]
	# "summon_post" / "gy_post": cards put on the field / in the GY after the deal through the
	# effect ops. Works on the Joey engine too, whose scenario loader ignores field and grave.
	var post_summon := [_ids(sc.get("summon_post", [[], []])[0]), _ids(sc.get("summon_post", [[], []])[1])]
	var post_gy := [_ids(sc.get("gy_post", [[], []])[0]), _ids(sc.get("gy_post", [[], []])[1])]
	for pp in 2:
		for id in post_summon[pp] + post_gy[pp]:
			hands[pp].append(id)
	var decks: Array[Dictionary] = []
	for p in 2:
		var main := _filler()
		for id in hands[p] + _ids(sc.get("grave", [[], []])[p]) + _ids(sc.get("deck_top", [[], []])[p]):
			main.append(id)
		for e in sc.get("field", [[], []])[p]:
			main.append(_id(e["card"]))
		for id in _ids(sc.get("banish", [[], []])[p]):
			main.append(id)
		while main.size() > 80:
			main.remove_at(0)
		decks.append({"main": main, "side": PackedInt32Array(), "fusion": _ids(sc.get("fusion", [[], []])[p])})
	var field := [[], []]
	for p in 2:
		for e in sc.get("field", [[], []])[p]:
			field[p].append({"card": _id(e["card"]), "zone": int(e.get("zone", 0)), "c": int(e.get("c", 0))})
	var graves := [_ids(sc.get("grave", [[], []])[0]), _ids(sc.get("grave", [[], []])[1])]
	duel.start_normal(decks, int(sc.get("first", 0)), int(sc.get("seed", 1234)))
	var warns := duel.apply_scenario({"hands": hands, "field": field, "grave": graves, "lp": sc.get("lp", [])})
	for w in warns:
		print("  warn: ", w)
	duel.run_until_idle(4000)
	# Banished cards: move from deck to banish after the deal.
	for p in 2:
		for id in _ids(sc.get("banish", [[], []])[p]):
			var i: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, id)
			if i >= 0:
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_DECK, i, p, CustomDuelOps.LOC_BANISH)
	for pp in 2:
		for id in post_summon[pp]:
			var hi: int = CustomDuelOps.find_pile_index_by_id(duel, pp, CustomDuelOps.LOC_HAND, id)
			if hi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, pp, CustomDuelOps.LOC_HAND, hi, pp, true, false)
		for id in post_gy[pp]:
			var gi: int = CustomDuelOps.find_pile_index_by_id(duel, pp, CustomDuelOps.LOC_HAND, id)
			if gi >= 0:
				CustomDuelOps.move_pile_card(duel, pp, CustomDuelOps.LOC_HAND, gi, pp, CustomDuelOps.LOC_GRAVE)
	duel.run_until_idle(4000)
	_set_phase(duel, int(sc.get("phase", 2)))
	print("=== %s" % name)
	var names := []
	for p2 in 2:
		for id in hands[p2] + graves[p2]:
			names.append("%d=%s" % [id, _name_of(id)])
	print("cards: ", names)
	print("before: ", _state(duel))
	var flow: Dictionary = sc.get("flow", {})
	if not flow.is_empty():
		_flow(duel, flow)
		return
	var act: Dictionary = sc.get("act", {})
	if act.is_empty():
		return
	var p: int = int(act.get("p", 0))
	var cid: int = _id(act["card"])
	var loc: int = int(LOC.get(str(act.get("loc", "hand")), 11))
	var z: int = int(act.get("z", -1))
	var ctx: Dictionary = (act.get("ctx", {}) as Dictionary).duplicate()
	if loc != 0 and loc != 5 and loc != 10:
		var pi: int = CustomDuelOps.find_pile_index_by_id(duel, p, loc, cid)
		ctx["pile_i"] = pi
		if pi < 0:
			print("  !! card %d is not in that pile" % cid)
			failures += 1
			return
	else:
		if z < 0:
			for zz in 11:
				if CustomDuelOps.zone_id(duel, p, zz) == cid:
					z = zz
					break
	if str(act.get("kind", "activate")) == "special_summon":
		var slot: int = int(ctx.get("pile_i", z))
		var ok: bool = CustomCardEffects.can_special_summon(duel, p, cid, loc, slot)
		print("can_special_summon: ", ok)
		var want_ss: Variant = sc.get("expect_can", null)
		if want_ss != null and bool(want_ss) != ok:
			print("  !! expected can_special_summon == ", want_ss)
			failures += 1
		if ok:
			var zone: int = CustomCardEffects.special_summon(duel, p, cid, loc, slot)
			duel.run_until_idle(4000)
			print("special_summon -> zone ", zone)
			print("after:  ", _state(duel))
			_check_expect(duel, sc)
		return
	var can: bool = CustomCardEffects.can_activate(duel, p, cid, loc, z, ctx)
	print("can_activate: ", can)
	var expect_can: Variant = sc.get("expect_can", null)
	if expect_can != null and bool(expect_can) != can:
		print("  !! expected can_activate == ", expect_can)
		failures += 1
	if can and not bool(sc.get("skip_resolve", false)):
		var handled: bool = CustomCardEffects.resolve_chain_link(duel, p, cid, loc, z, ctx)
		var guard := 0
		while duel.ui_pending.size() > 0 and guard < 20:
			guard += 1
			print("  ui prompt pending: ", duel.ui_pending)
			break
		duel.run_until_idle(4000)
		print("resolved: ", handled)
		print("after:  ", _state(duel))
		_check_expect(duel, sc)
	if not duel.unported_calls.is_empty():
		print("  unported engine calls: ", duel.unported_calls)


func _name_of(id: int) -> String:
	for k in _cards_by_name:
		if _cards_by_name[k] == id:
			return k
	return "(original card)"


func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return int(a) == int(b)
	return str(a) == str(b)


func _set_phase(duel: Duel, ph: int) -> void:
	var v := duel.m.u16(0xa133f2)
	duel.m.set_u16(0xa133f2, (v & ~0xe) | ((ph & 7) << 1))


## Query like "p0.hand.count", "p0.grave.has:3131", "p1.lp", "p0.field.3" (zone id)
func _query(duel: Duel, q: String) -> Variant:
	var parts := q.split(".")
	var p := int(parts[0].substr(1))
	match parts[1]:
		"lp": return CustomDuelOps.get_lp(duel, p)
		"field": return CustomDuelOps.zone_id(duel, p, int(parts[2]))
		_:
			var loc: int = LOC[parts[1]]
			if parts[2] == "count":
				return CustomDuelOps.pile_count(duel, p, loc)
			if parts[2].begins_with("has:"):
				return CustomDuelOps.find_pile_index_by_id(duel, p, loc, int(parts[2].substr(4))) >= 0
	return null


func _pile(duel: Duel, p: int, loc: int) -> Array:
	var out := []
	for i in CustomDuelOps.pile_count(duel, p, loc):
		out.append(CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, loc, i)))
	return out


func _state(duel: Duel) -> String:
	var s := []
	for p in 2:
		var field := {}
		for z in 11:
			var id := CustomDuelOps.zone_id(duel, p, z)
			if id != 0 and CustomDuelOps.zone_idx(duel, p, z) != 0:
				field[z] = "%d%s" % [id, "" if CustomDuelOps.is_face_up(duel, p, z) else "(fd)"]
		var hand := _pile(duel, p, 11)
		var gy := _pile(duel, p, 14)
		var bn := _pile(duel, p, 15)
		s.append("P%d lp=%d hand=%s field=%s gy=%s banish=%s deck=%d" % [p, CustomDuelOps.get_lp(duel, p), hand, field, gy, bn, CustomDuelOps.pile_count(duel, p, 13)])
	return " | ".join(s) + " | phase=%d turn=%d" % [CustomDuelOps.phase(duel), CustomDuelOps.turn_number(duel)]


func _check_expect(duel: Duel, sc: Dictionary) -> void:
	for key in sc.get("expect", {}):
		var got: Variant = _query(duel, str(key))
		var want: Variant = sc["expect"][key]
		if not _same(got, want):
			print("  !! expected %s == %s, got %s" % [key, want, got])
			failures += 1


## Engine-flow mode: let the real turn state machine run (CPU attacks, trap windows) and log what happens.
## flow: {turn, phase, frames, answer}. Logs phase/LP changes and every ui_pending prompt.
func _flow(duel: Duel, flow: Dictionary) -> void:
	if flow.has("turn"):
		duel.m.set_u16(0xa133f0, int(flow["turn"]))
	if flow.has("auto_answer"):
		duel.auto_answer = int(flow["auto_answer"])
	var last := ""
	var prompts := 0
	var clicks := 0
	for i in int(flow.get("frames", 20000)):
		duel.ui_phase_hover = -1
		duel.ui_mouse_click = false
		if flow.has("click_phase") and i % 50 == 25 and clicks < int(flow.get("max_clicks", 6)):
			duel.ui_phase_hover = int(flow["click_phase"])
			duel.ui_mouse_click = true
			clicks += 1
		var busy := duel.frame()
		if not duel.ui_pending.is_empty():
			prompts += 1
			print("  frame %d ui_pending: %s" % [i, duel.ui_pending])
			if flow.has("answer"):
				duel.ui_answer(int(flow["answer"]))
			if prompts > 30:
				break
		var st := _state(duel) + " sb=%x atk=%x dlg=%s run=%s" % [duel.m.u8(0xa133f4), duel.m.u32(0xa114c0), str(duel.dialog_open), str(duel.is_running())]
		if st != last:
			print("  f%d %s" % [i, st])
			last = st
		if not busy and duel.ui_pending.is_empty() and not flow.has("click_phase"):
			print("  idle at frame ", i)
			break
	print("flow end: ", _state(duel))
