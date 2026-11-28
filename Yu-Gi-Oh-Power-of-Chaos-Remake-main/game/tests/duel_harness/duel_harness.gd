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
		if sc.has("deck_only"):
			main = PackedInt32Array()
			for id in _ids(sc["deck_only"][p]):
				main.append(id)
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
	if sc.has("deck_only"):
		for pp in 2:
			var top := []
			for i in mini(8, CustomDuelOps.pile_count(duel, pp, 13)):
				top.append(CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, pp, 13, i)))
			print("deck top (P%d): %s" % [pp, top])
	for pe in sc.get("print_effect", []):
		print("effect id of card %d = 0x%x" % [int(pe), duel.cards.effect_id_of(int(pe))])
	var flow: Dictionary = sc.get("flow", {})
	if not flow.is_empty():
		_flow(duel, flow)
		return
	var eng = duel.engine if duel is JoeyPresentationAdapter else duel
	var act: Dictionary = sc.get("act", {})
	if act.is_empty():
		return
	if eng != duel:
		# Joey cannot load field/grave from the scenario: summon them from hand, then force
		# them face-up in attack position (see the f568610 argument-order bug).
		for jf in sc.get("jfield", []):
			var jp: int = 1 - int(jf.get("p", 0))
			var ji: int = CustomDuelOps.find_pile_index_by_id(eng, jp, 11, _id(jf["card"]))
			var jz: int = CustomDuelOps.special_summon_from_pile(eng, jp, 11, ji, jp, true, false)
			var ja: int = CustomDuelOps.zone_addr(eng, jp, jz)
			eng.m.set_u8(ja + 6, (eng.m.u8(ja + 6) & ~3) | 2)
		for jg in sc.get("jgy", []):
			var gp: int = 1 - int(jg.get("p", 0))
			var gi2: int = CustomDuelOps.find_pile_index_by_id(eng, gp, 11, _id(jg["card"]))
			var gz2: int = CustomDuelOps.special_summon_from_pile(eng, gp, 11, gi2, gp, true, false)
			duel.run_until_idle(2000)
			var sent: bool = CustomDuelOps.send_zone_to_gy(eng, gp, gz2)
			duel.run_until_idle(2000)
			print("  jgy send ->", sent)
		for jt in sc.get("jst", []):
			var tp: int = 1 - int(jt.get("p", 0))
			var ti: int = CustomDuelOps.find_pile_index_by_id(eng, tp, 11, _id(jt["card"]))
			var tz2: int = CustomDuelOps.set_st_from_pile(eng, tp, 11, ti, tp, false)
			duel.run_until_idle(2000)
			print("  jst set %s -> zone %d" % [str(jt["card"]), tz2])
		print("  joey field set: ", _state(eng))
	if sc.get("dbg_eng", false):
		print("  eng class=", eng.get_script().resource_path, " is_joey=", CustomDuelOps.is_joey(eng), " hand_n=", CustomDuelOps.pile_count(eng, 0, 11), " deck_n=", CustomDuelOps.pile_count(eng, 0, 13))
		print("  eng state: ", _state(eng))
	var p: int = int(act.get("p", 0))
	if eng != duel:
		p = 1 - p  # the Joey rules engine indexes players the other way round from the adapter
	var cid: int = _id(act["card"])
	var loc: int = int(LOC.get(str(act.get("loc", "hand")), 11))
	var z: int = int(act.get("z", -1))
	var ctx: Dictionary = (act.get("ctx", {}) as Dictionary).duplicate()
	if loc != 0 and loc != 5 and loc != 10:
		var pi: int = CustomDuelOps.find_pile_index_by_id(eng, p, loc, cid)
		ctx["pile_i"] = pi
		if pi < 0:
			print("  !! card %d is not in that pile" % cid)
			failures += 1
			return
	else:
		if z < 0:
			for zz in 11:
				if CustomDuelOps.zone_id(eng, p, zz) == cid:
					z = zz
					break
	if str(act.get("kind", "activate")) == "ds_seq":
		# Joey only: sequence of resolve / summon / menu steps for Double Summon tests (ep = engine summoner).
		var epd: int = 1 - p
		eng.m.set_u8(JoeyMem.TURN, (eng.m.u8(JoeyMem.TURN) & ~0xe) | (2 << 1))
		var mode0: int = eng.m.u32(JoeyMem.MODE)
		for stp in act["steps"]:
			var cdo: String = str(stp["do"]); var cc: int = int(stp["card"])
			var hidx := -1; var hpi := -1
			for pj in CustomDuelOps.pile_count(eng, epd, 11):
				var ei: int = CustomDuelOps.pile_idx(eng, epd, 11, pj)
				if ei != 0 and CustomDuelOps.raw_id(eng, ei) == cc:
					hidx = ei; hpi = pj; break
			if cdo == "resolve":
				print("  DS resolve %d -> %s" % [cc, str(CustomCardEffects.resolve_chain_link(eng, epd, cc, 11, 0, {}))])
			elif cdo == "menu":
				if hidx == 0: print("  DS menu %d: not in hand" % cc); continue
				var am: int = eng.f5a02a0(hidx, epd, hpi)
				print("  DS menu %d f5a02a0=0x%x normal/set=0x%x used_flag=%s" % [cc, am, eng.f5aab90(epd, hidx), str(CustomDuelOps.normal_summon_used(eng, epd))])
			elif cdo == "summon":
				if hidx == 0: print("  DS summon %d: not in hand" % cc); continue
				eng.m.set_u16(0xa57802, hidx)
				eng.m.set_u8(0xa5780c, hpi)
				eng.m.set_u8(0xa5780b, (11 << 1) | (epd & 1))
				eng.m.set_u16(0xa57804, (eng.m.u16(0xa57804) & 0xff87) | (8 << 3))
				eng.m.set_u8(0xa57809, 0)
				var sset: int = int(stp.get("set", 0))
				var rr5 := 0
				eng.m.set_u32(JoeyMem.MODE, mode0 | 0x6)
				for it in 8:
					rr5 = eng.f59df40(1, sset, 0)
					if rr5 != 0: break
				eng.m.set_u32(JoeyMem.MODE, mode0)
				duel.run_until_idle(60)
				for _kk in 10: duel.frame()
				print("  DS summon %d set=%d ret=%d | %s" % [cc, sset, rr5, _state(eng)])
		return
	if str(act.get("kind", "activate")) == "fgate":
		# Core: Fusion Gate (0x60b) activation trace: material list f563e50 per fusion monster, then f5703c0 steps.
		for fi2 in CustomDuelOps.pile_count(eng, p, 12):
			var fidx: int = CustomDuelOps.pile_idx(eng, p, 12, fi2)
			var outa: int = eng.m.local(40)
			var okk: int = eng.f563e50(p, fidx, outa)
			print("  FG fusion pile[%d] idx=%d raw=%d f563e50=%d out=0x%x/0x%x" % [fi2, fidx, CustomDuelOps.raw_id(eng, fidx), okk, eng.m.u32(outa), eng.m.u32(outa + 4)])
		print("  FG hand: ", _pile(eng, p, 11), " fusion: ", _pile(eng, p, 12), " eff_card_0x60b=", eng.f401ad0(0x60b))
		eng.m.set_u8(0xa1340d, 0)
		for st3 in 6:
			var r3: int = eng.f5703c0()
			print("  FG f5703c0 step %d ret=%d a1340d=%d a15fe0=0x%x ui_pending=%s" % [st3, r3, eng.m.u8(0xa1340d), eng.m.u8(0xa15fe0), str(duel.ui_pending).substr(0, 100)])
		return
	if str(act.get("kind", "activate")) == "fusion_list":
		var tot: int = CustomDuelOps.pile_count(eng, p, 12)
		for fi3 in tot:
			var fidx3: int = CustomDuelOps.pile_idx(eng, p, 12, fi3)
			var out3: int = eng.m.local(40)
			for q in 4: eng.m.set_u16(out3 + q * 2, 0)
			var ok3: int = eng.f591d10(p, fidx3, out3) if CustomDuelOps.is_joey(eng) else eng.f563e50(p, fidx3, out3)
			print("  FL target=%d result=%d out=%04x %04x %04x | hand=%s field=%s fusionpile=%s" % [CustomDuelOps.raw_id(eng, fidx3), ok3, eng.m.u16(out3), eng.m.u16(out3 + 2), eng.m.u16(out3 + 4), str(_pile(eng, p, 11)), str(_state(eng).substr(0, 0)), str(_pile(eng, p, 12))])
		if tot == 0: print("  FL no fusion pile")
		return
	if str(act.get("kind", "activate")) == "bom":
		var tp5: int = int(act.get("tp", 1 - p if CustomDuelOps.is_joey(eng) else 1))
		var tz5: int = int(act.get("tz", 0))
		var rd := func(tag: String) -> void:
			print("  BOM %s: tp=%d z=%d id=%d faceup=%s atkpos=%s flagbyte=0x%x phase=%d turn=%d" % [tag, tp5, tz5, CustomDuelOps.zone_id(eng, tp5, tz5), str(CustomDuelOps.is_face_up(eng, tp5, tz5)), str(CustomDuelOps.is_atk_pos(eng, tp5, tz5)), eng.m.u8(CustomDuelOps.zone_addr(eng, tp5, tz5) + 6), CustomDuelOps.phase(eng), CustomDuelOps.turn_number(eng)])
		rd.call("before")
		for sc5 in act.get("seq", [2520]):
			var rb: bool = CustomCardEffects.resolve_chain_link(eng, p, int(sc5), 11, 0, {})
			print("  BOM resolve(%d)=%s ui_pending=%s" % [int(sc5), str(rb), str(duel.ui_pending).substr(0, 80)])
			rd.call("right_after_resolve_%d" % int(sc5))
			for st6 in 12:
				duel.run_until_idle(1)
				duel.frame()
			rd.call("after_12_steps_%d" % int(sc5))
		for st5 in 40:
			duel.run_until_idle(1)
			duel.frame()
			if st5 < 6 or st5 % 8 == 0: rd.call("step%d" % st5)
		duel.run_until_idle(4000)
		for _k9 in 100: duel.frame()
		rd.call("after_idle_and_100_frames")
		return
	if str(act.get("kind", "activate")) == "fgate2":
		# Core: drive Fusion Gate (f5703c0) through the pick: taps = list of hand card ids to tap in order.
		var dumpf := func(tag: String) -> void:
			print("  FG2 %s: a15fe0=0x%x a1340d=%d a16104=0x%x a16106=0x%x mats(a16108)=%04x,%04x,%04x loc=%d/%d hand=%s fusion=%s gy=%s | %s" % [tag, eng.m.u8(0xa15fe0), eng.m.u8(0xa1340d), eng.m.u32(0xa16104), eng.m.u8(0xa16106), eng.m.u16(0xa16108), eng.m.u16(0xa1610a), eng.m.u16(0xa1610c), eng.m.u32(0xa161a8), eng.m.u32(0xa161ac), str(_pile(eng, p, 11)), str(_pile(eng, p, 12)), str(_pile(eng, p, 14)), _state(eng).substr(0, 0)])
		eng.m.set_u8(0xa1340d, 0)
		var fidxs: int = CustomDuelOps.pile_idx(eng, p, 12, 0)
		for st4 in 3:
			var r4: int = eng.f5703c0()
			dumpf.call("start%d" % st4)
		for tap in act.get("taps", []):
			var found := false
			for pj in CustomDuelOps.pile_count(eng, p, 11):
				var ei: int = CustomDuelOps.pile_idx(eng, p, 11, pj)
				if CustomDuelOps.raw_id(eng, ei) == int(tap):
					eng.m.set_u32(0xa161a8, 11); eng.m.set_u32(0xa161ac, pj)
					found = true; break
			if not found:
				for zz in 5:
					if CustomDuelOps.zone_id(eng, p, zz) == int(tap):
						eng.m.set_u32(0xa161a8, 0); eng.m.set_u32(0xa161ac, zz); found = true; break
			print("  FG2 TAP card %d found=%s" % [int(tap), str(found)])
			eng.m.set_u32(0xa114a8, eng.m.u32(0xa114a8) | 0x201)
			eng.ui_hover_object = true
			print("  FG2 conds: f5407e0=%d f579630=%d f579890=%d a161a4=%d a114a8=0x%x" % [eng.f5407e0(), eng.f579630(eng.m.u32(0xa161a4), eng.m.u32(0xa161a8), eng.m.u32(0xa161ac), 0xf1), eng.f579890(), eng.m.u32(0xa161a4), eng.m.u32(0xa114a8)])
			var rt: int = eng.f5703c0()
			eng.m.set_u32(0xa114a8, eng.m.u32(0xa114a8) & ~0x201)
			dumpf.call("after_tap_%d" % int(tap))
		for st4 in 10:
			var r5: int = eng.f5703c0()
			duel.run_until_idle(50)
			for _k in 5: duel.frame()
			dumpf.call("settle%d" % st4)
		var sm := func(tag: String) -> void:
			print("  FG2T %s: a15be0=0x%x a15be4=0x%x a15bec=0x%x a15bee=0x%x state=%d a16178=%d" % [tag, eng.m.u32(0xa15be0), eng.m.u16(0xa15be4), eng.m.u16(0xa15bec), eng.m.u16(0xa15bee), (eng.m.u16(0xa15bee) & 0xfe0) >> 5, eng.m.u16(0xa16178)])
		sm.call("pre")
		for i4 in 8:
			var rr4: int = eng.f57c440()
			sm.call("c440_%d ret=%d" % [i4, rr4])
			duel.run_until_idle(200)
			for _k in 5: duel.frame()
			if i4 == int(act.get("answer_at", 2)):
				eng.m.set_u16(0xa16178, int(act.get("pos", 0)))
				print("  FG2T answered pos=", int(act.get("pos", 0)))
		print("   STATE_after_trace ", _state(eng))
		print("   STATE_before_extra ", _state(eng))
		duel.run_until_idle(4000)
		for _k in 200: duel.frame()
		duel.run_until_idle(4000)
		print("   STATE ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "lock_check":
		# Direct-call: resolve the card's chain link, then print summon locks and the attack gate.
		var lcid: int = int(act["card"])
		var rr: bool = CustomCardEffects.resolve_chain_link(eng, p, lcid, 11 if str(act.get("loc", "hand")) == "hand" else 5, int(act.get("z", 0)), {})
		print("  LOCK resolve(%d)=%s" % [lcid, str(rr)])
		for lp in [0, 1]:
			print("  LOCK p=%d normal_locked=%s special_locked=%s" % [lp, str(CustomCardEffects.normal_locked(eng, lp)), str(CustomCardEffects.special_locked(eng, lp))])
		if act.has("attackers"):
			var az: Array = act["attackers"]
			for a_z in az:
				print("  ATK zone %d: can_attack=%s on_attack_declare=%s" % [int(a_z), str(CustomCardEffects.can_attack(eng, p, int(a_z))), str(CustomCardEffects.on_attack_declare(eng, p, int(a_z), 1 - p, 0))])
			for a_z in az:
				print("  ATK again zone %d: can_attack=%s" % [int(a_z), str(CustomCardEffects.can_attack(eng, p, int(a_z)))])
		return
	if str(act.get("kind", "activate")) == "joey_menu":
		# Joey only: hand action bitmask for the hand card (f5a02a0) and its parts.
		var pi3: int = int(ctx["pile_i"])
		for ep in [p, 1 - p]:
			var eidx2: int = CustomDuelOps.pile_idx(eng, ep, 11, pi3)
			if eidx2 == 0:
				continue
			eng.m.set_u8(JoeyMem.TURN, (eng.m.u8(JoeyMem.TURN) & ~0xe) | (int(act.get("phase", 2)) << 1))
			eng.recorded.clear()
			var a_menu: int = eng.f5a02a0(eidx2, ep, pi3)
			var a_norm: int = eng.f5aab90(ep, eidx2)
			var a_spec: int = eng.f5aae00(ep, eidx2)
			print("  MENU ep=%d idx=%d id=%d MODE=0x%x f5a02a0=0x%x f5aab90(normal/set)=0x%x f5aae00(special)=0x%x lvl=%d" % [ep, eidx2, CustomDuelOps.raw_id(eng, eidx2), eng.m.u8(JoeyMem.MODE), a_menu, a_norm, a_spec, eng.f4026c0(eidx2) & 0xffff])
			print("    custom: handles=%s can_normal(false)=%s can_normal(true)=%s can_ss(hand)=%s" % [str(CustomCardEffects.handles(CustomDuelOps.raw_id(eng, eidx2))), str(CustomCardEffects.can_normal_summon(eng, ep, CustomDuelOps.raw_id(eng, eidx2), false)), str(CustomCardEffects.can_normal_summon(eng, ep, CustomDuelOps.raw_id(eng, eidx2), true)), str(CustomCardEffects.can_special_summon(eng, ep, CustomDuelOps.raw_id(eng, eidx2), 11, pi3))])
		return
	if str(act.get("kind", "activate")) == "joey_hand_action":
		# Joey only: run the hand action handler f59df40 (summon/set/special) like the UI would after the menu pick.
		var pi4: int = int(ctx["pile_i"])
		var ep4: int = int(act.get("ep", p))
		var eidx4: int = CustomDuelOps.pile_idx(eng, ep4, 11, pi4)
		eng.m.set_u8(JoeyMem.TURN, (eng.m.u8(JoeyMem.TURN) & ~0xe) | (2 << 1))
		eng.m.set_u16(0xa57802, eidx4)
		eng.m.set_u8(0xa5780c, pi4)
		eng.m.set_u8(0xa5780b, (11 << 1) | (ep4 & 1))
		eng.m.set_u16(0xa57804, (eng.m.u16(0xa57804) & 0xff87) | (int(act.get("kind_code", 10)) << 3))
		eng.m.set_u8(0xa57809, 0)
		if bool(act.get("cpu", false)):
			eng.m.set_u8(JoeyMem.MODE, eng.m.u8(JoeyMem.MODE) | 0x6)
		eng.recorded.clear()
		print("  HANDACT ep=%d idx=%d id=%d lvl=%d kind_code=%d" % [ep4, eidx4, CustomDuelOps.raw_id(eng, eidx4), eng.f4026c0(eidx4) & 0xffff, int(act.get("kind_code", 10))])
		for it in 8:
			var rr4: int = eng.f59df40(int(act.get("face", 1)), int(act.get("set", 1)), 0)
			print("   iter %d ret=%d state=%d ui_pending=%s a558b4=%d" % [it, rr4, eng.m.u8(0xa57809), str(duel.ui_pending).substr(0, 120), eng.m.u16(0xa558b4)])
			if rr4 != 0: break
		print("   IMMEDIATE ", _state(eng))
		if bool(act.get("steps", false)):
			for st in 40:
				duel.run_until_idle(1)
				duel.frame()
				print("   STEP %d " % st, _state(eng))
		var menu6: int = eng.f5a02a0(eidx4, ep4, pi4)
		print("   menu_before=0x%x" % menu6)
		duel.run_until_idle(4000)
		for _k6 in 60: duel.frame()
		print("   AFTER ", _state(eng))
		print("   recorded cmds: ", eng.recorded.size())
		for c4 in eng.recorded.slice(0, 8): print("    cmd op=0x%x a=0x%x b=0x%x c=0x%x" % [c4[0], c4[1], c4[2], c4[3]])
		print("   unported: ", eng.unported_calls)
		var tm: int = int(act.get("then_menu_card", 0))
		if tm != 0:
			for ep5 in [0, 1]:
				for pj in CustomDuelOps.pile_count(eng, ep5, 11):
					var ei5: int = CustomDuelOps.pile_idx(eng, ep5, 11, pj)
					if ei5 != 0 and CustomDuelOps.raw_id(eng, ei5) == tm:
						print("   THEN_MENU ep=%d id=%d f5a02a0=0x%x normal/set=0x%x special=0x%x normal_locked=%s special_locked=%s" % [ep5, tm, eng.f5a02a0(ei5, ep5, pj), eng.f5aab90(ep5, ei5), eng.f5aae00(ep5, ei5), str(CustomCardEffects.normal_locked(eng, ep5)), str(CustomCardEffects.special_locked(eng, ep5))])
						break
		return
	if str(act.get("kind", "activate")) == "joey_sweep":
		var ep5: int = p
		eng.m.set_u8(JoeyMem.TURN, (eng.m.u8(JoeyMem.TURN) & ~0xe) | (2 << 1))
		for cid5 in range(int(act.get("lo", 2500)), int(act.get("hi", 3143))):
			var ix5: int = eng.cards.index_of(cid5)
			if ix5 <= 0 or not CustomCardEffects.handles(cid5):
				continue
			if (eng.f4025d0(ix5) & 0xffff) > 20:
				continue
			var cn: bool = CustomCardEffects.can_normal_summon(eng, ep5, cid5, false)
			var cs: bool = CustomCardEffects.can_normal_summon(eng, ep5, cid5, true)
			var css: bool = CustomCardEffects.can_special_summon(eng, ep5, cid5, 11, 0)
			var a_n: int = eng.f5aab90(ep5, ix5)
			var a_s: int = eng.f5aae00(ep5, ix5)
			var a_m: int = eng.f5a02a0(ix5, ep5, 0)
			var lvl5: int = eng.f4026c0(ix5) & 0xffff
			var verdict := ""
			if a_s & 0xc00:
				verdict = "SS_OFFERED" + (" TRIBUTE_PROMPT_UNPATCHED(lvl>=5)" if lvl5 >= 5 else "")
			print("SWEEP %d lvl=%d can_normal=%s can_set=%s can_ss=%s f5aab90=0x%x f5aae00=0x%x menu=0x%x %s" % [cid5, lvl5, str(cn), str(cs), str(css), a_n, a_s, a_m, verdict])
		return
	if str(act.get("kind", "activate")) == "joey_evolve":
		var fz: int = int(act.get("z", 0))
		var fid: int = int(act["from"]); var tid: int = int(act["to"])
		var tp: int = p  # engine index of the owner
		var dump := func(tag: String) -> void:
			var za: int = CustomDuelOps.zone_addr(eng, tp, fz)
			print("  [%s] zone%d entry=0x%x id=%d flags=0x%x faceup=%s atk_pos=%s gy=%s" % [tag, fz, eng.m.u32(za), CustomDuelOps.zone_id(eng, tp, fz), eng.m.u8(za + 6), str(CustomDuelOps.is_face_up(eng, tp, fz)), str(CustomDuelOps.is_atk_pos(eng, tp, fz)), str(_gy_ids(eng, tp))])
			var zs := []
			for zz in 5:
				var zaa: int = CustomDuelOps.zone_addr(eng, tp, zz)
				zs.append("z%d:id=%d,fl=0x%x" % [zz, CustomDuelOps.zone_id(eng, tp, zz), eng.m.u8(zaa + 6)])
			print("      zones: ", " ".join(zs))
			var ek := []
			for e in eng.events: ek.append(str(e.get("kind", e)))
			var dk := []
			for e in duel.events: dk.append(str(e.get("kind", e)))
			print("      eng.events(%d)=%s | adapter.events(%d)=%s | eng.recorded=%d" % [eng.events.size(), str(ek), duel.events.size(), str(dk), eng.recorded.size()])
		print("  same_obj(duel,eng)=", duel == eng)
		dump.call("start")
		eng.events.clear(); duel.events.clear(); eng.recorded.clear()
		var sk: int = int(act.get("mode", 0))
		if sk == 0:
			# step by step like _evolve_optional
			CustomDuelOps.send_zone_to_gy(eng, tp, fz)
			dump.call("after_send_zone_to_gy")
			var si: int = CustomDuelOps.find_pile_index_by_id(eng, tp, CustomDuelOps.LOC_DECK, tid)
			var sl: int = CustomDuelOps.LOC_DECK
			if si < 0:
				si = CustomDuelOps.find_pile_index_by_id(eng, tp, CustomDuelOps.LOC_HAND, tid); sl = CustomDuelOps.LOC_HAND
			print("  src loc=%d idx=%d" % [sl, si])
			var zr: int = CustomDuelOps.special_summon_from_pile(eng, tp, sl, si, tp, true, false)
			print("  special_summon_from_pile -> zone ", zr)
			dump.call("after_special_summon")
		if sk == 1:
			CustomEffectsMonsters1._evolve_optional(eng, tp, fz, fid, tid)
			dump.call("after__evolve_optional")
		duel.run_until_idle(4000)
		dump.call("after_idle")
		for _k7 in 30: duel.frame()
		dump.call("after_30_frames")
		duel.run_until_idle(4000)
		for _k8 in 120: duel.frame()
		duel.run_until_idle(4000)
		dump.call("after_150_frames_more_idle")
		print("   STATE ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "joey_resolve":
		# Joey only. Runs the effect-table resolve handler (f59de30 -> table 0x5ed0a8 slot +0x10) for the card at hand.
		for gz in act.get("gy_zones", []):
			CustomDuelOps.send_zone_to_gy(eng, p, int(gz))
			duel.run_until_idle(2000)
		var pi2: int = int(ctx["pile_i"])
		var eidx: int = CustomDuelOps.pile_idx(eng, p, 11, pi2)
		var at: int = eng.m.local(20)
		eng.m.set_u16(at, eidx)
		eng.m.set_u16(at + 2, (p & 1) | (11 << 1) | (pi2 << 6))
		eng.m.set_u16(at + 4, 0)
		print("effect idx=", eidx, " effect_id=0x%x" % (eng.effect_card_id(eidx) & 0xffff), " row=", eng.f59dbe0(eidx))
		if act.get("human", false):
			eng.m.set_u8(JoeyMem.MODE, eng.m.u8(JoeyMem.MODE) | (1 << (1 + p)))
		if act.get("clear_a54e5c", false):
			eng.m.set_u32(0xa54e5c, eng.m.u32(0xa54e5c) & ~6)
		print("MODE byte=0x%x human_bit_for_p=%d" % [eng.m.u8(JoeyMem.MODE), (eng.m.u8(JoeyMem.MODE) >> (1 + p)) & 1])
		print("BEFORE ", _state(eng))
		eng.recorded.clear()
		for it in int(act.get("iters", 12)):
			if act.has("force_a558b4"): eng.m.set_u16(0xa558b4, int(act["force_a558b4"]))
			var rr: int = eng.f59de30(at, 0)
			print("  iter %d ret=%d step=%d/%d list=0x%x n=%d choice=%d" % [it, rr, eng.m.u8(0xa55c8c), eng.m.u8(0xa55c8d), eng.m.u16(0xa582a0), eng.m.u16(0xa585a4), eng.m.u16(0xa582a2)])
			print("     f40cae0=%d list_hdr=0x%x mode=0x%x a55044=0x%x a5504c=0x%x a558b4=0x%x a54e5c=0x%x" % [eng.f40cae0(), eng.m.u16(0xa582a0), eng.m.u8(JoeyMem.MODE), eng.m.u32(0xa55044), eng.m.u32(0xa5504c), eng.m.u16(0xa558b4), eng.m.u32(0xa54e5c)])
			if rr != 0: break
			if eng.m.u16(0xa582a0) != 0 and act.get("pick_mark", false):
				eng.m.set_u16(0xa585a4, 1)
				eng.m.set_u16(0xa584a4, 0x0100)
				print("     a55c8f=%d" % eng.m.u8(0xa55c8f))
			if act.has("set_target"):
				eng.m.set_u32(0xa55044, int(act["set_target"][0]))
				eng.m.set_u32(0xa5504c, int(act["set_target"][1]))
			if eng.m.u16(0xa582a0) != 0 and act.has("choice"):
				eng.m.set_u16(0xa582a2, int(act["choice"]))
			if not act.get("no_idle", false): duel.run_until_idle(2000)
		if act.get("no_idle", false):
			for c in eng.recorded.slice(0, 40): print("  cmd op=0x%x a=0x%x b=0x%x c=0x%x" % [c[0], c[1], c[2], c[3]])
			var st0: int = eng.recorded.size()
			for _f in 300: duel.frame()
			print("  after 300 frames, cmds recorded: ", eng.recorded.size() - st0)
		for c in eng.recorded.slice(0, 40): print("  cmd op=0x%x a=0x%x b=0x%x c=0x%x" % [c[0], c[1], c[2], c[3]])
		if act.get("dump_row", false):
			var rw: int = eng.f59dbe0(eidx)
			for k in 8:
				var ad: int = eng.m.u32(0x5ed0a8 + rw * 24 + k * 4)
				print("  ROW%d u32[%d] @0x%x = 0x%x ported=%s" % [rw, k, 0x5ed0a8 + rw * 24 + k * 4, ad, str(eng.has_method(StringName("f%06x" % ad))) if ad > 0x400000 else "-"])
			for sl in act.get("call_slots", []):
				var ad2: int = eng.m.u32(0x5ed0a8 + eng.f59dbe0(eidx) * 24 + int(sl) * 4)
				eng.recorded.clear()
				var r2: int = eng._jy_effect(ad2, [at, (0 << 8) | (p ^ 1)])
				print("  CALL slot+%d addr=0x%x ret=%d a55044=0x%x a5504c=0x%x cmds=%d" % [int(sl), ad2, r2, eng.m.u32(0xa55044), eng.m.u32(0xa5504c), eng.recorded.size()])
				for c in eng.recorded.slice(0, 10): print("    cmd op=0x%x a=0x%x b=0x%x c=0x%x" % [c[0], c[1], c[2], c[3]])
			print("AFTER2 ", _state(eng))
		print("AFTER  ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "attr_list":
		for k in CustomDuelOps.pile_count(eng, p, 11):
			var ix: int = CustomDuelOps.pile_idx(eng, p, 11, k)
			print("  hand[%d] id=%d attr=%d level=%d" % [k, CustomDuelOps.raw_id(eng, ix), CustomDuelOps.monster_attr(eng, ix), CustomDuelOps.monster_level(eng, ix)])
		return
	if str(act.get("kind", "activate")) == "can_normal":
		print("can_normal_summon(%d)=%s tribute_req=%d level_f=%s" % [cid, str(CustomCardEffects.can_normal_summon(eng, p, cid, false)), CustomCardEffects.normal_tribute_requirement(cid), "n/a"])
		_check_expect(eng, sc)
		return
	if str(act.get("kind", "activate")) == "scan_u32":
		if act.has("dump_from"):
			var da: int = int(act["dump_from"])
			var line := ""
			for q in int(act.get("dump_n", 40)):
				line += "%x " % eng.m.u32(da + q * 4)
				if q % 8 == 7:
					print("  @0x%x: %s" % [da + (q - 7) * 4, line]); line = ""
			return
		var want: int = int(act["value"])
		var hits := []
		var a: int = JoeyMem.BASE
		while a < JoeyMem.END - 4:
			if eng.m.u32(a) == want: hits.append("0x%x" % a)
			a += 4
		print("scan hits for 0x%x: %s" % [want, str(hits.slice(0, 20))])
		return
	if str(act.get("kind", "activate")) == "joey_endphase_link":
		# Joey only. Puts a type-3 link (ref = linker card index) on the zone of act.target_card, then runs the
		# end phase step 6 of f5a5120 for engine player p. Logs f5b9170 commands and the zone memory before/after.
		var jp0: int = p
		var tz := -1
		var tc: int = _id(act["target_card"])
		for zz in 5:
			if CustomDuelOps.zone_id(eng, jp0, zz) == tc: tz = zz
		var lz := -1
		for zz in 5:
			if CustomDuelOps.zone_id(eng, jp0, zz) == cid: lz = zz
		print("linker zone=", lz, " target zone=", tz)
		var lidx: int = CustomDuelOps.zone_idx(eng, jp0, lz)
		var off: int = jp0 * JoeyMem.PLAYER_SIZE + tz * JoeyMem.ZONE_SIZE
		var n: int = eng.m.u16(0xa55d7e + off)
		eng.m.set_u16(0xa55d80 + off + n * 2, lidx)
		eng.m.set_u8(0xa55dc0 + off + n * 2, 3)
		eng.m.set_u16(0xa55d7e + off, n + 1)
		print("link added: count=", n + 1, " ref=idx ", lidx, " effect_id(ref)=0x%x" % (eng.effect_card_id(lidx) & 0xffff))
		var dump := func(tag: String) -> void:
			print(tag, " ", _state(eng))
			print("   zone mem t=%d: %s" % [tz, str(eng.m.slice(JoeyMem.zone(jp0, tz), JoeyMem.ZONE_SIZE) if eng.m.has_method("slice") else eng.m.u32(JoeyMem.zone(jp0, tz)))])
		dump.call("BEFORE")
		eng.recorded.clear()
		eng.m.set_u16(JoeyMem.TURN, (eng.m.u16(JoeyMem.TURN) & 0xfffe) | jp0)
		eng.m.set_u16(0xa577fe, 6 << 8)
		var r: int = eng.f5a5120()
		print("f5a5120 ret=", r, " phase now=", eng.m.u16(0xa577fe) >> 8)
		for c in eng.recorded: print("  cmd op=0x%x a=0x%x b=0x%x c=0x%x" % [c[0], c[1], c[2], c[3]])
		duel.run_until_idle(4000)
		dump.call("AFTER")
		print("linker still on field: ", CustomDuelOps.zone_id(eng, jp0, lz), " target zone id: ", CustomDuelOps.zone_id(eng, jp0, tz))
		return
	if str(act.get("kind", "activate")) == "m2_phase":
		if str(act.get("which", "ep")) == "ep":
			CustomEffectsMonsters2.on_end_phase(eng, p)
		else:
			CustomEffectsMonsters2.on_standby_tick(eng, p)
		duel.run_until_idle(4000)
		for _k in 100: duel.frame()
		print("  M2PHASE state: ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "ctx_probe":
		var stt: Dictionary = CustomDuelOps.state(eng)
		CustomDuelOps.state(eng).erase("last_destroyed_id")
		var rd: bool = CustomDuelOps.destroy_zone(eng, int(act.get("tp", 0)), int(act.get("tz", 0)), bool(act.get("by_battle", true)))
		print("  CTX destroyed=%s last_id=%s last_p=%s last_battle=%s" % [str(rd), str(stt.get("last_destroyed_id", "unset")), str(stt.get("last_destroyed_p", "unset")), str(stt.get("last_destroyed_battle", "unset"))])
		duel.run_until_idle(4000)
		print("  CTX after idle last_id=%s last_p=%s last_battle=%s | %s" % [str(stt.get("last_destroyed_id", "unset")), str(stt.get("last_destroyed_p", "unset")), str(stt.get("last_destroyed_battle", "unset")), _state(eng)])
		return
	if str(act.get("kind", "activate")) == "ns_check":
		var nsj := -1
		for pj in CustomDuelOps.pile_count(eng, p, 11):
			if CustomDuelOps.raw_id(eng, CustomDuelOps.pile_idx(eng, p, 11, pj)) == cid:
				nsj = CustomDuelOps.pile_idx(eng, p, 11, pj); break
		print("  NS can(f57a490)=", eng.f57a490(p, nsj), " free=", CustomCardEffects.necroshade_free(eng, p, nsj))
		if act.get("consume", false):
			CustomCardEffects.necroshade_consume(eng, p)
			print("  NS after consume: can(f57a490)=", eng.f57a490(p, nsj), " free=", CustomCardEffects.necroshade_free(eng, p, nsj))
		return
	if str(act.get("kind", "activate")) == "field_stats":
		var fr: bool = CustomCardEffects.resolve_chain_link(eng, p, cid, 5, z, {}) if act.get("resolve", false) else true
		for _k in 30: duel.frame()
		var fidx: int = CustomDuelOps.zone_idx(eng, p, z)
		print("  STATS id=%d atk=%d def=%d attr=%d resolved=%s" % [cid, CustomDuelOps.eff_atk(eng, p, z), CustomDuelOps.eff_def(eng, p, z), CustomDuelOps.monster_attr(eng, fidx), str(fr)])
		return
	if str(act.get("kind", "activate")) == "joey_ai":
		# Joey: make engine player p the AI attacker and let the real per-frame step (f5bc620) run its battle handler.
		var tb := ""
		for hi in 14: tb += "%d=0x%x " % [hi, eng.m.u32(0x5efb78 + hi * 4)]
		print("  JA AI handler table ", tb)
		var idx := -1
		for hi in 14:
			if eng.m.u32(0x5efb78 + hi * 4) == 0x5b7a50: idx = hi
		if act.has("ai_idx"): idx = int(act["ai_idx"])
		var mode: int = eng.m.u32(JoeyMem.MODE)
		eng.m.set_u32(JoeyMem.MODE, mode | (1 << (1 + p)))
		var tw0: int = eng.m.u16(JoeyMem.TURN)
		eng.m.set_u16(JoeyMem.TURN, (tw0 & 0xff00) | (p & 1) | (int(act.get("tphase", 4)) << 1))
		eng.m.set_u8(0xa577fe, idx)
		eng.m.set_u8(0xa579a2, 0)
		print("  JA idx=%d turn=0x%x mode=0x%x" % [idx, eng.m.u16(JoeyMem.TURN), eng.m.u32(JoeyMem.MODE)])
		var lastj := ""
		for fr in int(act.get("frames", 100)):
			if act.get("direct", false): eng.f5bc620()
			duel.run_until_idle(200)
			duel.frame()
			if duel.get("dialog_open") != null and not duel.dialog_open.is_empty():
				print("  JA DLG f%d %s" % [fr, str(duel.dialog_open).substr(0, 200)])
				if act.has("dlg_ans"): duel.answer_dialog(int(act["dlg_ans"]))
			if duel.ui_pending.size() > 0 and fr < 400:
				print("  JA f%d ui_pending=%s" % [fr, str(duel.ui_pending).substr(0, 200)])
			var lj := "turn=0x%x a577fe=%d a579a2=%d | %s" % [eng.m.u16(JoeyMem.TURN), eng.m.u8(0xa577fe), eng.m.u8(0xa579a2), _state(eng)]
			if lj != lastj:
				print("  JA f%d %s" % [fr, lj])
				lastj = lj
		return
	if str(act.get("kind", "activate")) == "joey_battle":
		# Joey: run the real battle sub-phase table (f5a4090) for attacker zone az vs defender zone dz.
		# act.p is the JSON attacker player (engine index is 1 - p, already applied to p above).
		var az: int = int(act.get("az", 0))
		var dz2: int = int(act.get("dz", 0))
		var op: int = 1 - p
		eng.m.set_u32(0xa57840, (p & 1) | (op << 1) | (az << 8) | (dz2 << 11))
		eng.m.set_u16(0xa57810, 0)
		eng.m.set_u16(0xa577fc, 0)
		eng.m.set_u16(0xa5799e, 0)
		var tw: int = eng.m.u16(0xa57800)
		var tpa: int = 0
		var tbl2 := ""
		for hi in 12: tbl2 += "%d=0x%x " % [hi, eng.m.u32(0x5efa68 + hi * 4)]
		print("  JB table ", tbl2)
		var last := ""
		for fr in int(act.get("frames", 200)):
			var rr: int = eng.f5a4090(p)
			var q0: int = (eng.m.u32(0xa55c94) >> 8) & 0x7f
			if q0 != 0 or eng.m.u32(0xa55c94) & 0x8000: print("  JB f%d POST-BATTLE-STEP queue=%d hold=0x%x ev0=0x%x" % [fr, q0, eng.m.u32(0xa55c94), eng.m.u8(0xa55c96)])
			if q0 != 0 and act.get("probe", false):
				var tpl: int = int(act.get("trap_engine_p", 1))
				for tz in range(5, 10):
					var za: int = CustomDuelOps.zone_addr(eng, tpl, tz)
					if eng.m.u16(za) & 0xfff == 0: continue
					var ef: int = eng.m.local(32)
					for bi in 32: eng.m.set_u8(ef + bi, 0)
					eng.m.set_u16(ef, eng.m.u16(za) & 0xfff)
					eng.m.set_u16(ef + 2, (tpl & 1) | (tz << 1))
					eng.m.set_u16(ef + 2, (tpl & 1) | (tz << 1) | ((eng.m.u8(0xa55c96) & 0x3f) << 6))
					var jc: Dictionary = CustomCardEffects.build_joey_ctx(eng, ef, 0, 0)
					var tcid: int = CustomDuelOps.zone_id(eng, tpl, tz)
					var ca: bool = CustomCardEffects.can_activate(eng, tpl, tcid, CustomDuelOps.LOC_FIELD_ST, tz, jc)
					print("  JB f%d CTXPROBE ev=%s dp=%s did=%s dbat=%s bnow=%s can_activate(%d)=%s" % [fr, str(jc.get("event")), str(jc.get("destroyed_p")), str(jc.get("destroyed_id")), str(jc.get("destroyed_battle")), str(jc.get("battle_destroyed_now")), tcid, str(ca)])
					var okp: int = 0
					print("  JB f%d PROBE ev=0x%x trap zone %d card %d -> can_respond=%d" % [fr, eng.m.u8(0xa55c96), tz, CustomDuelOps.zone_id(eng, tpl, tz), okp])
			if act.get("resp", false):
				var rb: int = 0
				if act.get("resp2", false):
					for gate in 6:
						var gr: int = [eng.f5bf9c0, eng.f5bc9b0, eng.f5ab820, eng.f5b8c00, eng.f5bbe40, eng.f5ba060][gate].call()
						if gr != 0:
							rb = gate * 10 + 1
							break
				else:
					rb = eng.f5bbe40()
				var q1: int = (eng.m.u32(0xa55c94) >> 8) & 0x7f
				if q0 != 0 or q1 != 0: print("  JB f%d f5bbe40 ret=%d queue %d->%d fce=0x%x c84=0x%x" % [fr, rb, q0, q1, eng.m.u32(0xa55ce8), eng.m.u32(0xa55c84)])
			duel.run_until_idle(200)
			var qn: int = (eng.m.u32(0xa55c94) >> 8) & 0x7f
			if qn != 0 or (act.get("resp", false) and duel.ui_pending.size() > 0):
				print("  JB f%d queue=%d ev0=0x%x hold=0x%x pending=%s" % [fr, qn, eng.m.u8(0xa55c96), eng.m.u32(0xa55c94), str(duel.ui_pending).substr(0, 160)])
			duel.frame()
			if act.get("dlg", false) and duel.get("dialog_open") != null and not duel.dialog_open.is_empty():
				print("  JB DLG f%d %s" % [fr, str(duel.dialog_open).substr(0, 200)])
				if act.has("dlg_ans"):
					duel.answer_dialog(int(act["dlg_ans"]))
			var ph := "turn=0x%x step=0x%x B=0x%x" % [eng.m.u16(0xa57800 if false else JoeyMem.TURN), eng.m.u16(0xa577fc), eng.m.u32(0xa57840)]
			var st: String = _state(eng)
			var line := ph + " | " + st
			if line != last:
				print("  JB f%d rr=%d %s" % [fr, rr, line])
				last = line
			if rr != 0 and fr > 2: pass
		return
	if str(act.get("kind", "activate")) == "ai_battle":
		if act.has("turn_p"):
			var v0 := duel.m.u16(0xa133f2)
			duel.m.set_u16(0xa133f2, (v0 & ~1) | (int(act["turn_p"]) & 1))
			duel.m.set_u8(0xa133f4, 0)
		var tbl := ""
		for hi in 12: tbl += "%d=0x%x " % [hi, eng.m.u32(eng.m.u32(0xa0faf8) + hi * 4)]
		print("  AIB handler table: ", tbl)
		if act.has("handler"):
			duel.m.set_u8(0xa16180, int(act["handler"]))
		if act.get("bp", false):
			duel.m.set_u8(0xa13402, duel.m.u8(0xa13402) & 0xfe)
			duel.m.set_u16(0xa133f2, duel.m.u16(0xa133f2) & 0x807f)
			duel.m.set_u8(0xa133fc, 0x15)
			duel.m.set_u8(0xa16180, 5)
		else:
			_set_phase(duel, int(act.get("phase", 3)))
		var stt2: Dictionary = CustomDuelOps.state(eng)
		print("  AIB start turn_p=", eng.m.u16(0xa133f2) & 1, " st=", eng.m.u8(0xa133f4), " phase=", (eng.m.u16(0xa133f2) >> 1) & 7, " turn=", CustomDuelOps.turn_number(eng), " | ", _state(eng))
		var lastst := ""
		for fr in int(act.get("frames", 600)):
			duel.run_until_idle(200)
			duel.frame()
			if act.get("dlg", false) and (not duel.dialog_open.is_empty() or not duel.list_open.is_empty() or duel.ui_pending.size() > 0):
				print("  AIB DLG f%d dialog=%s list=%s pending=%d" % [fr, str(duel.dialog_open.keys()), str(duel.list_open.keys()), duel.ui_pending.size()])
				if act.has("dlg_ans") and not duel.dialog_open.is_empty():
					print("   dialog f%d content: %s -> answer %d" % [fr, str(duel.dialog_open).substr(0, 200), int(act["dlg_ans"])])
					duel.answer_dialog(int(act["dlg_ans"]))
				elif not duel.dialog_open.is_empty() and fr < 3:
					print("   dialog content: ", str(duel.dialog_open).substr(0, 200))
			if act.has("pick") and fr >= 1 and fr <= int(act["pick"].get("click_at", 3)) + int(act["pick"].get("len", 1)):
				var pk: Dictionary = act["pick"]
				eng.ui_hover_object = true
				eng.m.set_u32(0xa161a4, int(pk.get("p", 0))); eng.m.set_u32(0xa161a8, int(pk.get("loc", 5))); eng.m.set_u32(0xa161ac, int(pk.get("idx", 0)))
				eng.m.set_u32(0xa114a8, eng.m.u32(0xa114a8) & ~2)
				if pk.get("natural", false):
					eng.ui_hover_card = CustomDuelOps.zone_idx(eng, int(pk.get("p", 0)), int(pk["hz"])) if pk.has("hz") else int(pk.get("hover", 1))
					if fr >= int(pk.get("click_at", 3)):
						eng.m.set_u32(0xa114a8, eng.m.u32(0xa114a8) | 0x201)
				elif fr >= int(pk.get("click_at", 3)):
					eng.m.set_u32(0xa13408, eng.m.u32(0xa13408) | 2)
					eng.m.set_u16(0xa1340e, (int(pk.get("loc", 5)) << 9) | (int(pk.get("p", 0)) << 8))
					eng.m.set_u8(0xa13410, int(pk.get("z", 0)))
				if pk.get("natural", false) and fr >= int(pk.get("click_at", 3)) + 2: eng.m.set_u32(0xa114a8, eng.m.u32(0xa114a8) & ~0x201)
				print("  AIB pk f%d a16091=%d a13408=0x%x a1340a=0x%x q=%d chain=%d a16180=%d" % [fr, eng.m.u8(0xa16091), eng.m.u32(0xa13408), eng.m.u16(0xa1340a), eng.m.u16(0xa15fc2), eng.m.u16(0xa15fc0), eng.m.u8(0xa16180)])
			if act.has("pick") and not act["pick"].get("natural", false) and fr == int(act["pick"].get("click_at", 3)) + 2:
				eng.m.set_u32(0xa13408, eng.m.u32(0xa13408) & ~3)
				eng.ui_hover_object = false
			if fr % int(act.get("every", 30)) == 0:
				var stn: String = _state(eng)
				if act.get("raw", false):
					print("  AIB raw f%d a133f2=0x%x a133f4=%d a114c0=0x%x a16180=%d handler=0x%x dlg=%d lst=%d" % [fr, eng.m.u16(0xa133f2), eng.m.u8(0xa133f4), eng.m.u32(0xa114c0), eng.m.u8(0xa16180), eng.m.u32(eng.m.u32(0xa0faf8) + eng.m.u8(0xa16180) * 4), duel.dialog_open.size(), duel.list_open.size()])
				if stn != lastst:
					print("  AIB f%d ph=%d turn=%d | %s | last_destroyed=%s/%s/%s" % [fr, (eng.m.u16(0xa133f2) >> 1) & 7, CustomDuelOps.turn_number(eng), stn, str(stt2.get("last_destroyed_id", "-")), str(stt2.get("last_destroyed_p", "-")), str(stt2.get("last_destroyed_battle", "-"))])
					lastst = stn
		print("  AIB FINAL ph=%d | %s | dlg=%s" % [(eng.m.u16(0xa133f2) >> 1) & 7, _state(eng), str(duel.dialog_open).substr(0, 120)])
		return
	if str(act.get("kind", "activate")) == "direct_check":
		CustomCardEffects.on_continuous_enforce(eng)
		print("DIRECT can_direct_attack=", CustomEffectsMonsters2.can_direct_attack(eng, p, z, cid))
		return
	if str(act.get("kind", "activate")) == "battle_end":
		# Direct call of on_battle_end for the attacker at (p, z); act keys: dz (-1 = direct), def_destroyed, atk_destroyed, repeat.
		for _r in int(act.get("repeat", 1)):
			CustomEffectsMonsters1.on_battle_end(eng, p, z, 1 - p, int(act.get("dz", 0)), bool(act.get("atk_destroyed", false)), bool(act.get("def_destroyed", false)))
			CustomEffectsMonsters2.on_battle_end(eng, p, z, 1 - p, int(act.get("dz", 0)), bool(act.get("atk_destroyed", false)), bool(act.get("def_destroyed", false)))
			duel.run_until_idle(4000)
			print("  after battle_end: max_attacks=", CustomEffectsMonsters1.max_attacks(eng, p, z, cid)); print("  state: ", _state(eng))
		_check_expect(eng, sc)
		return
	if str(act.get("kind", "activate")) == "prot":
		CustomCardEffects.on_continuous_enforce(eng)
		var tp: int = int(act.get("tp", 1))
		var tz: int = int(act.get("tz", 0))
		if act.has("choose_owner"):
			var ch: Dictionary = CustomDuelOps.choose_zone(eng, int(act["choose_owner"]), func(_d, _pl, zz, _idx): return zz < 5, true, true)
			print("PROT choose_owner=", act["choose_owner"], " -> ", ch)
		if act.has("src"):
			CustomDuelOps.state(eng)["effect_source"] = str(act["src"])
			var r: bool = CustomDuelOps.destroy_zone(eng, tp, tz, bool(act.get("by_battle", false)))
			print("PROT destroy src='%s' battle=%s -> destroyed=%s" % [str(act["src"]), str(act.get("by_battle", false)), r])
			CustomDuelOps.state(eng)["effect_source"] = ""
		if act.has("damage"):
			CustomDuelOps.damage(eng, int(act["damage"][0]), int(act["damage"][1]), false)
			duel.run_until_idle(4000)
		print("after:  ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "cc":
		var nz: int = CustomDuelOps.change_control(eng, int(act.get("from_p", 1)), int(act.get("from_z", 0)), p, bool(act.get("temp", true)))
		print("cc nz=", nz, " pending=", duel.ui_pending.size())
		print("after0: ", _state(eng))
		for c in eng.recorded.slice(0, 10): print("  rec op=0x%x a=0x%x b=0x%x c=0x%x" % [c[0], c[1], c[2], c[3]])
		duel.run_until_idle(4000)
		print("after1: ", _state(eng))
		for _k in 200: duel.frame()
		print("after2: ", _state(eng))
		return
	if str(act.get("kind", "activate")) == "control":
		# Direct call of the engine's control-change primitive: card at (p, z) goes to player `to`.
		var to: int = int(act.get("to", 1 - p))
		if eng != duel: to = 1 - to
		var fz := -1
		for k in 5:
			if CustomDuelOps.zone_id(eng, to, k) == 0:
				fz = k
				break
		print("control: src p%d z%d -> p%d z%d (engine indices)" % [p, z, to, fz])
		eng.f575750(p, ((z & 0xff) << 8) | (p & 1), ((fz & 0xff) << 8) | (to & 1))
		duel.run_until_idle(4000)
		for _k in int(sc.get("settle", 0)):
			duel.frame()
		print("after:  ", _state(eng))
		for q in 2:
			for k in 5:
				var zid: int = CustomDuelOps.zone_id(eng, q, k)
				if zid != 0:
					print("  engine p%d z%d id=%d atk_pos=%s face_up=%s" % [q, k, zid, CustomDuelOps.is_atk_pos(eng, q, k), CustomDuelOps.is_face_up(eng, q, k)])
		_check_expect(eng, sc)
		return
	if str(act.get("kind", "activate")) == "summon_trigger":
		CustomCardEffects.on_summon_or_flip(eng, p, z, cid, str(act.get("how", "normal")))
		duel.run_until_idle(4000)
		print("after:  ", _state(eng))
		if act.get("then_ep", false):
			for _k in 120: duel.frame()
			print("after120f: ", _state(eng))
			_set_phase(duel, 5)
			CustomCardEffects.on_phase_tick(eng, int(CustomDuelOps.turn_number(eng)) & 1 if false else p, 5)
			duel.run_until_idle(4000)
			for _k in 60: duel.frame()
			print("afterEP: ", _state(eng))
		_check_expect(eng, sc)
		return
	if str(act.get("kind", "activate")) == "standby":
		CustomEffectsMonsters1.on_standby_tick(eng, p)
		duel.run_until_idle(4000)
		print("after:  ", _state(eng))
		_check_expect(eng, sc)
		return
	if str(act.get("kind", "activate")) == "special_summon":
		var slot: int = int(ctx.get("pile_i", z))
		var ok: bool = CustomCardEffects.can_special_summon(eng, p, cid, loc, slot)
		print("can_special_summon: ", ok)
		var want_ss: Variant = sc.get("expect_can", null)
		if want_ss != null and bool(want_ss) != ok:
			print("  !! expected can_special_summon == ", want_ss)
			failures += 1
		if ok:
			var zone: int = CustomCardEffects.special_summon(eng, p, cid, loc, slot)
			duel.run_until_idle(4000)
			print("special_summon -> zone ", zone, " joey=", CustomDuelOps.is_joey(eng), " script=", duel.get_script().resource_path)
			for _k in int(sc.get("settle", 0)):
				duel.frame()
			print("  z0 flags=", CustomDuelOps.zone_entry(eng, p, 0) != 0 and eng.m.u8(CustomDuelOps.zone_addr(eng, p, 0) + 6), " atk_pos=", CustomDuelOps.is_atk_pos(eng, p, 0), " face_up=", CustomDuelOps.is_face_up(eng, p, 0))
			print("  unported(eng): ", eng.unported_calls, " unported(adapter): ", duel.unported_calls, " z0 idx=", CustomDuelOps.zone_idx(eng, p, 0), " hand_n=", CustomDuelOps.pile_count(eng, p, 11), " gy_n=", CustomDuelOps.pile_count(eng, p, 14))
			print("after:  ", _state(eng))
			_check_expect(eng, sc)
		return
	var can: bool = CustomCardEffects.can_activate(eng, p, cid, loc, z, ctx)
	print("can_activate: ", can)
	var expect_can: Variant = sc.get("expect_can", null)
	if expect_can != null and bool(expect_can) != can:
		print("  !! expected can_activate == ", expect_can)
		failures += 1
	if can and not bool(sc.get("skip_resolve", false)):
		var handled: bool = CustomCardEffects.resolve_chain_link(eng, p, cid, loc, z, ctx)
		var guard := 0
		while duel.ui_pending.size() > 0 and guard < 20:
			guard += 1
			print("  ui prompt pending: ", duel.ui_pending)
			break
		duel.run_until_idle(4000)
		print("resolved: ", handled)
		print("after:  ", _state(eng))
		_check_expect(eng, sc)
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
func _query(duel, q: String) -> Variant:
	var parts := q.split(".")
	var p := int(parts[0].substr(1))
	match parts[1]:
		"lp": return CustomDuelOps.get_lp(duel, p)
		"field": return CustomDuelOps.zone_id(duel, p, int(parts[2]))
		"atk": return CustomDuelOps.eff_atk(duel, p, int(parts[2]))
		"winner": return duel.winner()
		_:
			var loc: int = LOC[parts[1]]
			if parts[2] == "count":
				return CustomDuelOps.pile_count(duel, p, loc)
			if parts[2].begins_with("has:"):
				return CustomDuelOps.find_pile_index_by_id(duel, p, loc, int(parts[2].substr(4))) >= 0
	return null


func _pile(duel, p: int, loc: int) -> Array:
	var out := []
	for i in CustomDuelOps.pile_count(duel, p, loc):
		out.append(CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, loc, i)))
	return out


func _state(duel) -> String:
	var s := []
	for p in 2:
		var field := {}
		for z in 11:
			var id := CustomDuelOps.zone_id(duel, p, z)
			if id != 0 and CustomDuelOps.zone_idx(duel, p, z) != 0:
				field[z] = "%d%s%s" % [id, "" if CustomDuelOps.is_face_up(duel, p, z) else "(fd)", ("@%d" % CustomDuelOps.eff_atk(duel, p, z)) if z < 5 else ""]
		var hand := _pile(duel, p, 11)
		var gy := _pile(duel, p, 14)
		var bn := _pile(duel, p, 15)
		s.append("P%d lp=%d hand=%s field=%s gy=%s banish=%s deck=%d" % [p, CustomDuelOps.get_lp(duel, p), hand, field, gy, bn, CustomDuelOps.pile_count(duel, p, 13)])
	return " | ".join(s) + " | phase=%d turn=%d" % [CustomDuelOps.phase(duel), CustomDuelOps.turn_number(duel)]


func _check_expect(duel, sc: Dictionary) -> void:
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
	var logged_tops := false
	for i in int(flow.get("frames", 20000)):
		if flow.get("log_decks", false) and not logged_tops and duel.m.u32(0xa114c0) != 0:
			logged_tops = true
			for pp in 2:
				var top := []
				for k in mini(6, CustomDuelOps.pile_count(duel, pp, 13)):
					top.append(CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, pp, 13, k)))
				print("  attack declared, deck top (P%d): %s" % [pp, top])
		duel.set_frame_input(0, 0, {}, -1)
		for sa in flow.get("script", []):
			if int(sa.get("f", -1)) == i:
				print("  [script f%d] %s" % [i, str(sa)])
				if sa.has("click"):
					var hv: Dictionary = (sa["click"] as Dictionary).duplicate()
					hv["p"] = int(hv["p"]); hv["loc"] = int(hv["loc"]); hv["i"] = int(hv["i"])
					hv["card"] = duel.f5419b0(hv["p"], hv["loc"], hv["i"])
					duel.set_frame_input(0x200, 0, hv, -1)
				if sa.has("key"):
					duel.set_frame_input(int(sa["key"]), 0, sa.get("hover", {}), -1)
				if sa.has("answer"):
					duel.ui_answer(int(sa["answer"]))
		duel.ui_phase_hover = -1 if duel.ui_phase_hover < 0 or not flow.has("click_phase") else duel.ui_phase_hover
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
	if flow.has("dump_events") and duel is JoeyPresentationAdapter:
		var f := FileAccess.open(str(flow["dump_events"]), FileAccess.WRITE)
		for e in (duel as JoeyPresentationAdapter).events:
			f.store_line(JSON.stringify(e))
		f.close()


func _gy_ids(eng, p: int) -> Array:
	var r := []
	for i in CustomDuelOps.pile_count(eng, p, 14):
		r.append(CustomDuelOps.raw_id(eng, CustomDuelOps.pile_idx(eng, p, 14, i)))
	return r
