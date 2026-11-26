class_name CustomCardEffects
extends RefCounted
## Unified entry-point facade coordinating all 589 custom YGOJSON cards (2500..3129)
## across CustomEffectsTraps (97), CustomEffectsSpells (146), CustomEffectsMonsters1 (184),
## CustomEffectsMonsters2 (162), and CustomDuelOps across both Core and Joey engines.


static func all_registered_ids() -> Array[int]:
	var out: Array[int] = []
	for cid in CustomEffectsTraps.IDS:
		out.append(cid)
	for cid in CustomEffectsSpells.IDS:
		out.append(cid)
	for cid in CustomEffectsMonsters1.IDS:
		out.append(cid)
	for cid in CustomEffectsMonsters2.IDS:
		out.append(cid)
	return out


static func handles(cid: int) -> bool:
	return (
		CustomEffectsTraps.handles(cid)
		or CustomEffectsSpells.handles(cid)
		or CustomEffectsMonsters1.handles(cid)
		or CustomEffectsMonsters2.handles(cid)
	)


static func on_duel_reset(duel) -> void:
	CustomDuelOps.reset_duel(duel)


static func can_activate(duel, p: int, cid: int, loc: int, z: int, ctx := {}) -> bool:
	if CustomEffectsTraps.handles(cid):
		return CustomEffectsTraps.can_activate(duel, p, cid, loc, z, ctx)
	if CustomEffectsSpells.handles(cid):
		return CustomEffectsSpells.can_activate(duel, p, cid, loc, z, ctx)
	if CustomEffectsMonsters1.handles(cid):
		return CustomEffectsMonsters1.can_activate(duel, p, cid, loc, z, ctx)
	if CustomEffectsMonsters2.handles(cid):
		return CustomEffectsMonsters2.can_activate(duel, p, cid, loc, z, ctx)
	return false


static func resolve_chain_link(duel, p: int, cid: int, loc: int, z: int, ctx := {}) -> bool:
	p &= 1
	var handled := false
	if CustomEffectsTraps.handles(cid):
		handled = CustomEffectsTraps.resolve(duel, p, cid, loc, z, ctx)
	elif CustomEffectsSpells.handles(cid):
		handled = CustomEffectsSpells.resolve(duel, p, cid, loc, z, ctx)
		if handled:
			CustomEffectsMonsters2.on_spell_resolved(duel, p)
	elif CustomEffectsMonsters1.handles(cid):
		CustomEffectsMonsters1.resolve(duel, p, cid, loc, z, ctx)
		handled = true
	elif CustomEffectsMonsters2.handles(cid):
		CustomEffectsMonsters2.resolve(duel, p, cid, loc, z, ctx)
		handled = true
	if handled:
		on_continuous_enforce(duel)
		check_and_apply_win(duel)
	return handled


static func can_normal_summon(duel, p: int, cid: int, is_set := false) -> bool:
	if CustomEffectsMonsters1.handles(cid):
		return CustomEffectsMonsters1.can_normal_summon(duel, p, cid, is_set)
	if CustomEffectsMonsters2.handles(cid):
		return CustomEffectsMonsters2.can_normal_summon(duel, p, cid, is_set)
	return true


static func normal_tribute_requirement(cid: int) -> int:
	if CustomEffectsMonsters1.handles(cid):
		return CustomEffectsMonsters1.normal_tribute_requirement(cid)
	return -1


static func can_special_summon(duel, p: int, cid: int, loc: int, slot: int) -> bool:
	if CustomEffectsMonsters1.handles(cid):
		return CustomEffectsMonsters1.can_special_summon(duel, p, cid, loc, slot)
	if CustomEffectsMonsters2.handles(cid):
		return CustomEffectsMonsters2.can_special_summon(duel, p, cid, loc, slot)
	return false


static func special_summon(duel, p: int, cid: int, loc: int, slot: int) -> int:
	var z := -1
	if CustomEffectsMonsters1.handles(cid):
		z = CustomEffectsMonsters1.special_summon(duel, p, cid, loc, slot)
	elif CustomEffectsMonsters2.handles(cid):
		z = CustomEffectsMonsters2.special_summon(duel, p, cid, loc, slot)
	if z >= 0:
		on_continuous_enforce(duel)
		check_and_apply_win(duel)
	return z


static func on_summon_or_flip(duel, p: int, z: int, cid: int, kind: String) -> void:
	CustomEffectsMonsters1.on_summon_or_flip(duel, p, z, cid, kind)
	CustomEffectsMonsters2.on_summon_or_flip(duel, p, z, cid, kind)
	on_continuous_enforce(duel)
	check_and_apply_win(duel)


static func on_phase_tick(duel, turn_p: int, ph: int) -> void:
	if duel == null:
		return
	var st := CustomDuelOps.state(duel)
	var t := CustomDuelOps.turn_number(duel)
	var prev_t := int(st.get("last_turn_seen", -1))
	var prev_ph := int(st.get("last_phase_seen", -1))
	if prev_t != t or prev_ph != ph:
		st["last_turn_seen"] = t
		st["last_phase_seen"] = ph
		if prev_t != t:
			st["summoned_this_turn"] = {0: [], 1: []}
			st["destroyed_this_turn"] = {0: [], 1: []}
			st["sent_gy_this_turn"] = {0: [], 1: []}
		if ph == CustomDuelOps.PHASE_SP:
			CustomEffectsTraps.on_standby_tick(duel, turn_p)
			CustomEffectsSpells.on_standby_tick(duel, turn_p)
			CustomEffectsMonsters1.on_standby_tick(duel, turn_p)
			CustomEffectsMonsters2.on_standby_tick(duel, turn_p)
		elif ph == CustomDuelOps.PHASE_EP:
			CustomEffectsTraps.on_end_phase(duel, turn_p)
			CustomEffectsSpells.on_end_phase(duel, turn_p)
			CustomEffectsMonsters1.on_end_phase(duel, turn_p)
			CustomEffectsMonsters2.on_end_phase(duel, turn_p)
			_expire_temp_stats(st, t)
		_run_delayed_tasks(duel, t, ph)
	on_continuous_enforce(duel)
	check_and_apply_win(duel)


static func on_continuous_enforce(duel) -> void:
	CustomEffectsTraps.on_continuous_enforce(duel)
	CustomEffectsSpells.on_continuous_enforce(duel)
	CustomEffectsMonsters1.on_continuous_enforce(duel)
	CustomEffectsMonsters2.on_continuous_enforce(duel)


static func on_attack_declare(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> bool:
	var cid := CustomDuelOps.zone_id(duel, atk_p, atk_z)
	if not can_attack(duel, atk_p, atk_z, cid):
		return false
	if not CustomEffectsMonsters1.on_attack_declare(duel, atk_p, atk_z, def_p, def_z):
		return false
	if not CustomEffectsMonsters2.on_attack_declare(duel, atk_p, atk_z, def_p, def_z):
		return false
	# Also check opponent attack-trigger traps automatically if needed
	return true


static func on_damage_calc(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, _is_direct := false) -> void:
	CustomEffectsMonsters1.on_damage_calc(duel, atk_p, atk_z, def_p, def_z)
	CustomEffectsMonsters2.on_damage_calc(duel, atk_p, atk_z, def_p, def_z)


static func on_battle_damage(duel, dmg_p: int, dmg_z: int, opp_p: int, amount: int, is_direct := false) -> void:
	CustomEffectsMonsters1.on_battle_damage(duel, dmg_p, dmg_z, opp_p, amount, is_direct)
	CustomEffectsMonsters2.on_battle_damage(duel, dmg_p, dmg_z, opp_p, amount, is_direct)


static func on_battle_end(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, atk_destroyed: bool, def_destroyed: bool) -> void:
	CustomEffectsMonsters1.on_battle_end(duel, atk_p, atk_z, def_p, def_z, atk_destroyed, def_destroyed)
	CustomEffectsMonsters2.on_battle_end(duel, atk_p, atk_z, def_p, def_z, atk_destroyed, def_destroyed)
	check_and_apply_win(duel)


static func on_destroyed(duel, p: int, cid: int, by_battle: bool, opp_effect := false, was_tributed_for_p := -1) -> void:
	CustomEffectsMonsters1.on_destroyed(duel, p, cid, by_battle, opp_effect, was_tributed_for_p)
	CustomEffectsMonsters2.on_destroyed(duel, p, cid, by_battle, opp_effect, was_tributed_for_p)
	check_and_apply_win(duel)


static func on_sent_to_gy(duel, p: int, cid: int, from_loc: int, opp_effect := false) -> void:
	CustomEffectsTraps.on_monster_sent_to_gy(duel, p, cid, from_loc < 11)
	CustomEffectsMonsters1.on_sent_to_gy(duel, p, cid, from_loc, opp_effect)
	CustomEffectsMonsters2.on_sent_to_gy(duel, p, cid, from_loc, opp_effect)
	check_and_apply_win(duel)


static func on_draw(duel, draw_p: int, count: int) -> void:
	CustomEffectsMonsters1.on_draw(duel, draw_p, count)


static func can_attack(duel, p: int, z: int, cid := -1) -> bool:
	var id := cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	return CustomEffectsMonsters1.can_attack(duel, p, z, id) and CustomEffectsMonsters2.can_attack(duel, p, z, id)


static func can_direct_attack(duel, p: int, z: int, cid := -1) -> bool:
	var id := cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	return CustomEffectsMonsters1.can_direct_attack(duel, p, z, id) or CustomEffectsMonsters2.can_direct_attack(duel, p, z, id)


static func has_pierce(duel, p: int, z: int, cid := -1) -> bool:
	var id := cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	return CustomEffectsMonsters1.has_pierce(duel, p, z, id) or CustomEffectsMonsters2.has_pierce(duel, p, z, id)


static func max_attacks(duel, p: int, z: int, cid := -1) -> int:
	var id := cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	return maxi(CustomEffectsMonsters1.max_attacks(duel, p, z, id), CustomEffectsMonsters2.max_attacks(duel, p, z, id))


static func check_win(duel) -> int:
	var st := CustomDuelOps.state(duel)
	var pending := int(st.get("pending_win", -1))
	if pending >= 0:
		return pending
	var w1 := CustomEffectsMonsters1.check_win(duel)
	if w1 >= 0:
		return w1
	return -1


static func check_and_apply_win(duel) -> int:
	var w := check_win(duel)
	if w == 0 or w == 1:
		CustomDuelOps.declare_win(duel, w)
	return w


static func modify_post_stats(duel, p: int, z: int, cur_atk: int, cur_def: int) -> Vector2i:
	p &= 1
	var cid := CustomDuelOps.zone_id(duel, p, z)
	var st := CustomDuelOps.state(duel)
	var k := "%d:%d" % [p, z]
	var t := CustomDuelOps.turn_number(duel)
	var atk := cur_atk
	var df := cur_def

	if st["trap_monsters"].has(k):
		var tm: Dictionary = st["trap_monsters"][k]
		atk = int(tm.get("atk", atk))
		df = int(tm.get("def", df))

	var mod := {}
	if CustomEffectsMonsters1.handles(cid) or cid != 0:
		CustomEffectsMonsters1.modify_continuous(duel, p, z, cid, mod)
	if CustomEffectsMonsters2.handles(cid):
		CustomEffectsMonsters2.modify_continuous(duel, p, z, cid, mod)

	if mod.has("atk_set"):
		atk = int(mod["atk_set"])
	if mod.has("def_set"):
		df = int(mod["def_set"])
	atk += int(mod.get("atk_delta", 0))
	df += int(mod.get("def_delta", 0))
	if bool(mod.get("half", false)):
		atk = int(atk / 2)
		df = int(df / 2)

	if st["set_atk"].has(k):
		var sa: Array = st["set_atk"][k]
		if int(sa[1]) < 0 or int(sa[1]) >= t:
			atk = int(sa[0])
	if st["set_def"].has(k):
		var sd: Array = st["set_def"][k]
		if int(sd[1]) < 0 or int(sd[1]) >= t:
			df = int(sd[0])

	atk += int(st["perm_atk"].get(k, 0))
	df += int(st["perm_def"].get(k, 0))

	if st["temp_atk"].has(k):
		for entry in st["temp_atk"][k]:
			if int(entry[1]) >= t:
				atk += int(entry[0])
	if st["temp_def"].has(k):
		for entry in st["temp_def"][k]:
			if int(entry[1]) >= t:
				df += int(entry[0])

	return Vector2i(maxi(0, atk), maxi(0, df))


static func _expire_temp_stats(st: Dictionary, t: int) -> void:
	for map_name in ["temp_atk", "temp_def"]:
		var mp: Dictionary = st[map_name]
		for k in mp.keys():
			var kept: Array = []
			for e in mp[k]:
				if int(e[1]) > t:
					kept.append(e)
			if kept.is_empty():
				mp.erase(k)
			else:
				mp[k] = kept
	for map_name2 in ["set_atk", "set_def"]:
		var mp2: Dictionary = st[map_name2]
		for k in mp2.keys():
			var e: Array = mp2[k]
			if int(e[1]) >= 0 and int(e[1]) <= t:
				mp2.erase(k)


static func _run_delayed_tasks(duel, cur_t: int, cur_ph: int) -> void:
	var st := CustomDuelOps.state(duel)
	var rem: Array = []
	for task in st["delayed"]:
		var tt := int(task.get("turn", 0))
		var tp := int(task.get("phase", 0))
		if cur_t > tt or (cur_t == tt and cur_ph >= tp):
			_execute_delayed(duel, task)
		else:
			rem.append(task)
	st["delayed"] = rem


static func _execute_delayed(duel, task: Dictionary) -> void:
	var action := str(task.get("action", ""))
	var p := int(task.get("p", 0)) & 1
	var cid := int(task.get("card_id", 0))
	var data: Dictionary = task.get("data", {})
	match action:
		"return_control":
			var fz := int(data.get("from_z", -1))
			var fp := int(data.get("from_p", p))
			var orig_p := int(data.get("orig_p", 1 - fp))
			if fz >= 0 and CustomDuelOps.zone_idx(duel, fp, fz) != 0:
				CustomDuelOps.change_control(duel, fp, fz, orig_p, false)
		"return_sphere":
			var sz := int(data.get("z", -1))
			var orig_p := int(data.get("orig_p", 1 - p))
			if sz >= 0 and CustomDuelOps.zone_id(duel, p, sz) == 2503:
				CustomDuelOps.change_control(duel, p, sz, orig_p, false)
		"revive_phoenix", "revive_vampire_lord", "revive_behemoth":
			if CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, cid)
				if gi >= 0:
					var nz := CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
					if nz >= 0:
						if action == "revive_phoenix" and cid == 2630:
							for pl in 2:
								for zz in range(5, 11):
									if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
										CustomDuelOps.destroy_zone(duel, pl, zz)
						elif action == "revive_behemoth":
							CustomDuelOps.set_stat_val(duel, p, nz, 1000, 1000, false)
		"mucus_boost":
			var mz := int(data.get("z", -1))
			if mz >= 0 and CustomDuelOps.zone_id(duel, p, mz) == 2861 and CustomDuelOps.is_face_up(duel, p, mz):
				CustomDuelOps.add_stat_mod(duel, p, mz, 1000, 0, false)
		"helpoemer_discard":
			if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2866) >= 0:
				CustomDuelOps.discard_random(duel, 1 - p, 1)
