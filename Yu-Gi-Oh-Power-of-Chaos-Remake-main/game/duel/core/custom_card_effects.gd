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


## Cartas del juego original (id < 2500) cuyo efecto nativo no funciona y se sustituye por uno
## personalizado: los dos motores las tratan como cartas sin fila nativa (ver f59dbe0 / f56e540).
const NATIVE_OVERRIDES: Array[int] = [1532]


static func overrides(cid: int) -> bool:
	return cid in NATIVE_OVERRIDES


static func handles(cid: int) -> bool:
	if cid < 2500:
		return overrides(cid)
	return (
		CustomEffectsTraps.handles(cid)
		or CustomEffectsSpells.handles(cid)
		or CustomEffectsMonsters1.handles(cid)
		or CustomEffectsMonsters2.handles(cid)
	)


static func map_core_event(reason: int, other: int) -> String:
	if other != 0:
		return "chain_negate"
	match reason:
		5:
			return "normal_summon"
		6, 7:
			return "summon"
		13, 14, 15:
			return "effect_damage_incoming"
		16:
			return "attack_declare"
		17:
			return "damage_step"
		18:
			return "destroyed_battle_gy"
		19:
			return "damage_calc"
		20, 21, 27, 30:
			return "destroyed_set"
		25, 26, 29:
			return "draw"
	return "free"


static func map_joey_event(ev_code: int, target: int) -> String:
	if target != 0:
		return "chain_negate"
	match ev_code:
		5:
			return "normal_summon"
		6, 7:
			return "summon"
		13, 14, 19, 20, 21:
			return "damage_step"
		16:
			return "effect_damage_incoming"
		18:
			return "attack_declare"
		22:
			return "draw"
		28:
			return "destroyed_battle_gy"
	return "free"


static func build_core_ctx(duel, e: int, other: int, hand: int) -> Dictionary:
	var flags: int = duel.m.u16(e + 2)
	var p: int = flags & 1
	var reason: int = (flags >> 10) & 0x3f
	var ev: String = map_core_event(reason, other)
	var ctx: Dictionary = {"event": ev, "other": other, "hand": hand, "target_link": -1, "target_card_id": 0,
			"destroyed_id": int(CustomDuelOps.state(duel).get("last_destroyed_id", 0))}
	if other != 0:
		var oidx: int = duel.m.u16(other) & 0xfff
		ctx["chain_p"] = duel.m.u8(other + 2) & 1
		ctx["chain_cid"] = duel.cards.id_of(oidx) & 0xffff
		ctx["target_card_id"] = ctx["chain_cid"]
		if other >= 0xa15e80:
			ctx["target_link"] = int((other - 0xa15e80) / 0x14)
		var ot: int = CustomDuelOps.ctype(duel, oidx)
		ctx["is_spell"] = (ot == 0x16)
		ctx["is_trap"] = (ot == 0x15)
		ctx["is_monster"] = (ot < 0x15)
	if ev == "normal_summon" or ev == "summon":
		var sdesc: int = duel.m.u32(0xa15be0)
		var sp: int = sdesc & 1
		var sz: int = (sdesc >> 1) & 31
		ctx["summon_p"] = sp
		ctx["summon_z"] = sz
		ctx["summon_atk"] = CustomDuelOps.eff_atk(duel, sp, sz) if sz < 5 and CustomDuelOps.zone_idx(duel, sp, sz) != 0 else 0
	elif ev == "attack_declare" or ev == "damage_step" or ev == "damage_calc":
		var bflags: int = duel.m.u32(0xa114c0)
		var ap: int = bflags & 1
		var az: int = (bflags >> 8) & 7
		var dp: int = (bflags >> 1) & 1
		var dz: int = (bflags >> 11) & 7
		ctx["atk_p"] = ap
		ctx["atk_z"] = az
		ctx["def_p"] = dp
		ctx["def_z"] = dz
		ctx["recv_p"] = p
		ctx["amount"] = CustomDuelOps.battle_damage_to(duel, p, ap, az, dp, -1 if (bflags & 4) != 0 else dz)
		if az < 5:
			ctx["tribute_summoned"] = bool(CustomDuelOps.zflags(duel, ap, az).get("tribute_summoned", false))
	elif ev == "draw":
		ctx["draw_p"] = CustomDuelOps.turn_player(duel)
	elif ev == "effect_damage_incoming":
		ctx["recv_p"] = p
	elif ev == "destroyed_battle_gy":
		ctx["owner_p"] = p
	return ctx


static func build_joey_ctx(duel, effect: int, target: int, flag: int) -> Dictionary:
	var bits: int = duel.m.u16(effect + 2)
	var p: int = ((bits >> 14) & 1) ^ (bits & 1)
	var ev_code: int = (bits >> 6) & 0x3f
	var ev: String = map_joey_event(ev_code, target)
	var ctx: Dictionary = {"event": ev, "other": target, "hand": flag, "target_link": -1, "target_card_id": 0}
	if target != 0:
		var tidx: int = duel.m.u16(target) & 0xfff
		var tbits: int = duel.m.u16(target + 2)
		ctx["chain_p"] = ((tbits >> 14) & 1) ^ (tbits & 1)
		ctx["chain_cid"] = duel.cards.id_of(tidx) & 0xffff
		ctx["target_card_id"] = ctx["chain_cid"]
		if target >= 0xa55b40:
			ctx["target_link"] = int((target - 0xa55b40) / 20)
		var tt: int = CustomDuelOps.ctype(duel, tidx)
		ctx["is_spell"] = (tt == 0x16)
		ctx["is_trap"] = (tt == 0x15)
		ctx["is_monster"] = (tt < 0x15)
	if ev == "normal_summon" or ev == "summon":
		var sdesc: int = duel.m.u32(0xa55080)
		var sp: int = sdesc & 1
		var sz: int = (sdesc >> 1) & 0x1f
		ctx["summon_p"] = sp
		ctx["summon_z"] = sz
		ctx["summon_atk"] = CustomDuelOps.eff_atk(duel, sp, sz) if sz < 5 and CustomDuelOps.zone_idx(duel, sp, sz) != 0 else 0
	elif ev == "attack_declare" or ev == "damage_step" or ev == "damage_calc":
		var bflags: int = duel.m.u32(0xa57840)
		var ap: int = bflags & 1
		var az: int = (bflags >> 8) & 7
		var dp: int = (bflags >> 1) & 1
		var dz: int = (bflags >> 11) & 7
		ctx["atk_p"] = ap
		ctx["atk_z"] = az
		ctx["def_p"] = dp
		ctx["def_z"] = dz
		ctx["recv_p"] = p
		ctx["amount"] = CustomDuelOps.battle_damage_to(duel, p, ap, az, dp, -1 if (bflags & 4) != 0 else dz)
		if az < 5:
			ctx["tribute_summoned"] = bool(CustomDuelOps.zflags(duel, ap, az).get("tribute_summoned", false))
	elif ev == "draw":
		ctx["draw_p"] = CustomDuelOps.turn_player(duel)
	elif ev == "effect_damage_incoming":
		ctx["recv_p"] = p
	elif ev == "destroyed_battle_gy":
		ctx["owner_p"] = p
	return ctx


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
	if z >= 0 and z <= 10:
		CustomDuelOps._present(duel, "card_effect", {"p": p, "zone": z, "card": cid, "flags": 2})
	var handled = false
	# Etiqueta de origen: destroy_zone la lee para las inmunidades a Magia/Trampa.
	var st_src = CustomDuelOps.state(duel)
	# Quien resuelve: destroy_zone lo lee para las inmunidades "del rival".
	st_src["effect_source_p"] = p
	if CustomEffectsTraps.handles(cid):
		st_src["effect_source"] = "trap"
		st_src["effect_targeted"] = false
		handled = CustomEffectsTraps.resolve(duel, p, cid, loc, z, ctx)
		st_src["effect_source"] = ""
	elif CustomEffectsSpells.handles(cid):
		st_src["effect_source"] = "spell"
		st_src["effect_targeted"] = false
		# Timidity (2834): su resolucion solo deja la marca que consulta destroy_zone.
		if cid == 2834:
			CustomDuelOps.set_timidity(duel)
		handled = CustomEffectsSpells.resolve(duel, p, cid, loc, z, ctx)
		st_src["effect_source"] = ""
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
		CustomDuelOps.sync_visuals(duel)
	st_src["effect_source_p"] = -1
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
	var z = -1
	if CustomEffectsMonsters1.handles(cid):
		z = CustomEffectsMonsters1.special_summon(duel, p, cid, loc, slot)
	elif CustomEffectsMonsters2.handles(cid):
		z = CustomEffectsMonsters2.special_summon(duel, p, cid, loc, slot)
	if z >= 0:
		on_continuous_enforce(duel)
		check_and_apply_win(duel)
		CustomDuelOps.sync_visuals(duel)
	return z


static func on_summon_or_flip(duel, p: int, z: int, cid: int, kind: String) -> void:
	var norm_kind: String = "flip_summon" if kind == "flip" else kind
	if norm_kind == "tribute" and z >= 0 and z < 5:
		CustomDuelOps.zflags(duel, p & 1, z)["tribute_summoned"] = true
	CustomEffectsMonsters1.on_summon_or_flip(duel, p, z, cid, norm_kind)
	CustomEffectsMonsters2.on_summon_or_flip(duel, p, z, cid, norm_kind)
	if norm_kind in ["flip_summon", "flipped"] and cid in [2713, 2716, 2739, 2751, 2765, 2788, 2819, 2823, 2832, 2850, 2982, 3107, 3120]:
		resolve_chain_link(duel, p, cid, CustomDuelOps.LOC_FIELD_MONSTER, z, {"event": norm_kind})
	on_continuous_enforce(duel)
	check_and_apply_win(duel)
	if handles(cid):
		CustomDuelOps.sync_visuals(duel)


static func on_phase_tick(duel, turn_p: int, ph: int) -> void:
	if duel == null:
		return
	var st = CustomDuelOps.state(duel)
	var t = CustomDuelOps.turn_number(duel)
	var prev_t := int(st.get("last_turn_seen", -1))
	var prev_ph := int(st.get("last_phase_seen", -1))
	if prev_t != t or prev_ph != ph:
		st["last_turn_seen"] = t
		st["last_phase_seen"] = ph
		if prev_t != t:
			st["summoned_this_turn"] = {0: [], 1: []}
			st["destroyed_this_turn"] = {0: [], 1: []}
			st["sent_gy_this_turn"] = {0: [], 1: []}
			st["battled_this_turn"] = []
		if ph == CustomDuelOps.PHASE_DP:
			_prepare_draw_phase(duel, turn_p, t)
		elif ph == CustomDuelOps.PHASE_SP:
			_reconcile_skipped_draw(duel, turn_p)
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
			_clear_turn_level_flags(st)
			_destroy_battled_monsters(duel, t)
		_run_delayed_tasks(duel, t, ph)
	on_continuous_enforce(duel)
	check_and_apply_win(duel)


## After the Struggle (2716): every monster that battled this turn is destroyed at the End Phase.
static func _destroy_battled_monsters(duel, t: int) -> void:
	var st = CustomDuelOps.state(duel)
	var keys: Array = st.get("battled_this_turn", [])
	if keys.is_empty():
		return
	var armed := false
	for p in 2:
		var pf: Dictionary = CustomDuelOps.pflags(duel, p)
		if int(pf.get("destroy_battled_ep", -1)) == t:
			pf.erase("destroy_battled_ep")
			armed = true
	if not armed:
		return
	for key in keys:
		var parts: PackedStringArray = str(key).split(":")
		if parts.size() != 2:
			continue
		var bp: int = int(parts[0])
		var bz: int = int(parts[1])
		if bz < 0 or bz >= 5:
			continue
		if CustomDuelOps.zone_idx(duel, bp, bz) != 0:
			CustomDuelOps.destroy_zone(duel, bp, bz)


## Cyber Dragon Drei makes Cyber Dragons Level 5 only until the end of the turn.
static func _clear_turn_level_flags(st: Dictionary) -> void:
	var zf_all: Dictionary = st.get("zone_flags", {})
	for key in zf_all.keys():
		var zf: Dictionary = zf_all[key]
		if zf.has("set_level_5"):
			zf.erase("set_level_5")


static func on_continuous_enforce(duel) -> void:
	CustomEffectsTraps.on_continuous_enforce(duel)
	CustomEffectsSpells.on_continuous_enforce(duel)
	CustomEffectsMonsters1.on_continuous_enforce(duel)
	CustomEffectsMonsters2.on_continuous_enforce(duel)


static func on_attack_declare(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> bool:
	var cid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	if not can_attack(duel, atk_p, atk_z, cid):
		return false
	if not CustomEffectsMonsters1.on_attack_declare(duel, atk_p, atk_z, def_p, def_z):
		return false
	if not CustomEffectsMonsters2.on_attack_declare(duel, atk_p, atk_z, def_p, def_z):
		return false
	# Also check opponent attack-trigger traps automatically if needed
	return true


static func on_damage_calc(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, _is_direct := false) -> void:
	# Dark Scorpion Combination (3006): esos monstruos hacen exactamente 400 de dano de batalla
	# cuando atacan directamente ese turno.
	var fbd = CustomDuelOps.zflags(duel, atk_p & 1, atk_z).get("fixed_battle_dmg_turn", [])
	if fbd is Array and fbd.size() == 2 and int(fbd[0]) == CustomDuelOps.turn_number(duel):
		CustomDuelOps.set_stat_val(duel, atk_p & 1, atk_z, int(fbd[1]), -1, true)
	CustomEffectsMonsters1.on_damage_calc(duel, atk_p, atk_z, def_p, def_z)
	CustomEffectsMonsters2.on_damage_calc(duel, atk_p, atk_z, def_p, def_z)


static func on_battle_damage(duel, dmg_p: int, dmg_z: int, opp_p: int, amount: int, is_direct := false) -> void:
	# The Secret of the Bandit (2789): el monstruo elegido hace descartar al rival cada vez que le
	# hace dano de batalla ese turno.
	if amount > 0 and not CustomDuelOps.is_joey(duel):
		var bf: int = duel.m.u32(0xa114c0)
		var bap := bf & 1
		var baz := (bf >> 8) & 7
		if baz < 5 and (dmg_p & 1) != bap \
				and int(CustomDuelOps.zflags(duel, bap, baz).get("bandit_discard_turn", -1)) == CustomDuelOps.turn_number(duel):
			CustomDuelOps.discard_random(duel, dmg_p & 1, 1)
	CustomEffectsMonsters1.on_battle_damage(duel, dmg_p, dmg_z, opp_p, amount, is_direct)
	CustomEffectsMonsters2.on_battle_damage(duel, dmg_p, dmg_z, opp_p, amount, is_direct)
	CustomDuelOps.sync_visuals(duel)


static func on_battle_end(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, atk_destroyed: bool, def_destroyed: bool) -> void:
	var st_battle = CustomDuelOps.state(duel)
	var battled: Array = st_battle.get("battled_this_turn", [])
	battled.append("%d:%d" % [atk_p & 1, atk_z])
	if def_z >= 0 and def_z < 5:
		battled.append("%d:%d" % [def_p & 1, def_z])
	st_battle["battled_this_turn"] = battled
	CustomEffectsMonsters1.on_battle_end(duel, atk_p, atk_z, def_p, def_z, atk_destroyed, def_destroyed)
	CustomEffectsMonsters2.on_battle_end(duel, atk_p, atk_z, def_p, def_z, atk_destroyed, def_destroyed)
	# Un atacante con dos ataques recupera la accion una vez por turno, despues de la batalla y de
	# sus efectos de batalla (BLS Envoy concede su segundo ataque ahi, al destruir un monstruo).
	if atk_z >= 0 and atk_z < 5 and CustomDuelOps.zone_idx(duel, atk_p & 1, atk_z) != 0:
		var acid: int = CustomDuelOps.zone_id(duel, atk_p & 1, atk_z)
		if max_attacks(duel, atk_p & 1, atk_z, acid) > 1:
			var azf: Dictionary = CustomDuelOps.zflags(duel, atk_p & 1, atk_z)
			if int(azf.get("extra_atk_used_turn", -1)) != CustomDuelOps.turn_number(duel):
				azf["extra_atk_used_turn"] = CustomDuelOps.turn_number(duel)
				CustomDuelOps.clear_attacked(duel, atk_p & 1, atk_z)
	check_and_apply_win(duel)
	CustomDuelOps.sync_visuals(duel)


static func on_destroyed(duel, p: int, cid: int, by_battle: bool, opp_effect := false, was_tributed_for_p := -1) -> void:
	# Ultima carta destruida: la usan las Trampas que reaccionan a una destruccion (Rope of Life).
	CustomDuelOps.state(duel)["last_destroyed_id"] = cid
	# Dark Ruler Ha Des (2744): un monstruo destruido en batalla por un Demonio del rival ve su
	# efecto anulado, asi que no se dispara.
	if by_battle and CustomDuelOps.ha_des_negates(duel, p, cid):
		check_and_apply_win(duel)
		return
	CustomEffectsMonsters1.on_destroyed(duel, p, cid, by_battle, opp_effect, was_tributed_for_p)
	CustomEffectsMonsters2.on_destroyed(duel, p, cid, by_battle, opp_effect, was_tributed_for_p)
	check_and_apply_win(duel)
	if handles(cid):
		CustomDuelOps.sync_visuals(duel)


static func on_sent_to_gy(duel, p: int, cid: int, from_loc: int, opp_effect := false) -> void:
	CustomEffectsTraps.on_monster_sent_to_gy(duel, p, cid, from_loc < 11)
	CustomEffectsMonsters1.on_sent_to_gy(duel, p, cid, from_loc, opp_effect)
	CustomEffectsMonsters2.on_sent_to_gy(duel, p, cid, from_loc, opp_effect)
	check_and_apply_win(duel)
	if handles(cid):
		CustomDuelOps.sync_visuals(duel)


static func on_draw(duel, draw_p: int, count: int) -> void:
	if _cancel_skipped_draw(duel, draw_p, count):
		return
	CustomEffectsMonsters1.on_draw(duel, draw_p, count)


## Yata-Garasu (2703) and Fenrir (3085) skip the opponent's next Draw Phase and Reckless Greed
## (2827) skips two; Hino-Kagu-Tsuchi (2763) makes the opponent discard their hand there.
## The engine draws on its own, so a skipped draw is undone: the card goes back on top of the
## deck and nothing sees it.
static func _prepare_draw_phase(duel, turn_p: int, t: int) -> void:
	var st = CustomDuelOps.state(duel)
	var p: int = turn_p & 1
	var pf: Dictionary = CustomDuelOps.pflags(duel, p)
	var skip := false
	if int(pf.get("skip_dp_turn", -1)) == t:
		pf.erase("skip_dp_turn")
		skip = true
	elif int(pf.get("skip_draw_phases", 0)) > 0:
		pf["skip_draw_phases"] = int(pf["skip_draw_phases"]) - 1
		skip = true
	st["dp_skip_p"] = p if skip else -1
	st["dp_hand_before"] = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
	if int(pf.get("discard_all_dp_turn", -1)) == t:
		pf.erase("discard_all_dp_turn")
		var hc: int = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
		for i in hc:
			CustomDuelOps.discard_hand_slot(duel, p, 0, 1)


## Si el motor ya habia robado antes de nuestro tick del Draw Phase, se deshace aqui.
static func _reconcile_skipped_draw(duel, turn_p: int) -> void:
	var st = CustomDuelOps.state(duel)
	var p: int = int(st.get("dp_skip_p", -1))
	if p < 0:
		return
	st["dp_skip_p"] = -1
	var before: int = int(st.get("dp_hand_before", -1))
	st["dp_hand_before"] = -1
	if p != (turn_p & 1) or before < 0:
		return
	var now: int = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
	if now <= before:
		return
	CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, now - 1, p, CustomDuelOps.LOC_DECK, false)


## Cancela el robo del Draw Phase cuando llega antes de que lo deshagamos en el Standby.
static func _cancel_skipped_draw(duel, draw_p: int, count: int) -> bool:
	var st = CustomDuelOps.state(duel)
	if int(st.get("dp_skip_p", -1)) != (draw_p & 1):
		return false
	if CustomDuelOps.phase(duel) != CustomDuelOps.PHASE_DP:
		return false
	if int(st.get("dp_hand_before", -1)) != CustomDuelOps.pile_count(duel, draw_p & 1, CustomDuelOps.LOC_HAND):
		return false
	st["dp_skip_p"] = -1
	st["dp_hand_before"] = -1
	var n: int = count
	while n > 0:
		var hc: int = CustomDuelOps.pile_count(duel, draw_p & 1, CustomDuelOps.LOC_HAND)
		if hc <= 0:
			break
		if CustomDuelOps.move_pile_card(duel, draw_p & 1, CustomDuelOps.LOC_HAND, hc - 1, draw_p & 1, CustomDuelOps.LOC_DECK, false) <= 0:
			break
		n -= 1
	return true


static func can_attack(duel, p: int, z: int, cid := -1) -> bool:
	var id = cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	var zf: Dictionary = CustomDuelOps.zflags(duel, p & 1, z)
	if bool(zf.get("cannot_attack", false)):
		return false
	if int(zf.get("cannot_attack_turn", -1)) == CustomDuelOps.turn_number(duel):
		return false
	# Inferno Fire Blast (3135): "Red-Eyes B. Dragon" cannot attack the turn it was activated.
	if id in CustomDuelOps.NATIVE_RED_EYES and int(CustomDuelOps.pflags(duel, p & 1).get("inferno_fire_blast_turn", -1)) == CustomDuelOps.turn_number(duel):
		return false
	return CustomEffectsMonsters1.can_attack(duel, p, z, id) and CustomEffectsMonsters2.can_attack(duel, p, z, id)


## Whether the monster at atk_p/atk_z may attack the monster at def_p/def_z. Called from the
## engines' attack-target checks (human selection, CPU choice, Joey FUN_0056bd80).
## A Feint Plan (2759): nobody can attack face-down monsters this turn.
## Marshmallon Glasses (2604): while its controller has "Marshmallon" (2603) in a Monster Zone,
## only "Marshmallon" can be attacked.
static func can_attack_target(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> bool:
	if def_z < 0 or def_z >= 5 or CustomDuelOps.zone_idx(duel, def_p, def_z) == 0:
		return true
	var t: int = CustomDuelOps.turn_number(duel)
	if not CustomDuelOps.is_face_up(duel, def_p, def_z):
		if int(CustomDuelOps.pflags(duel, 0).get("cannot_attack_facedown_turn", -1)) == t \
				or int(CustomDuelOps.pflags(duel, 1).get("cannot_attack_facedown_turn", -1)) == t:
			return false
	if (atk_p & 1) != (def_p & 1) and CustomDuelOps.has_faceup_id(duel, def_p, 2604) \
			and CustomDuelOps.zone_id(duel, def_p, def_z) != 2603:
		for z in 5:
			if CustomDuelOps.zone_idx(duel, def_p, z) != 0 and CustomDuelOps.zone_id(duel, def_p, z) == 2603:
				# the Glasses only count as a Spell/Trap in the back row
				for sz in range(5, 10):
					if CustomDuelOps.zone_idx(duel, def_p, sz) != 0 and CustomDuelOps.is_face_up(duel, def_p, sz) \
							and CustomDuelOps.zone_id(duel, def_p, sz) == 2604:
						return false
	return true


## Hieroglyph Lithograph (2808): the hand size limit of that player is 7 instead of 6.
static func hand_limit(duel, p: int) -> int:
	return 7 if bool(CustomDuelOps.pflags(duel, p & 1).get("hand_limit_7", false)) else 6


## Dimension Fusion Destruction (2548): the controller takes no battle damage from attacks
## involving the monster it Special Summoned. True when the monster at p/z carries that mark.
static func battle_damage_blocked(duel, p: int, z: int) -> bool:
	if z < 0 or z >= 5:
		return false
	return bool(CustomDuelOps.zflags(duel, p & 1, z).get("no_battle_dmg_to_controller", false))


static func can_direct_attack(duel, p: int, z: int, cid := -1) -> bool:
	var id = cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	var zf: Dictionary = CustomDuelOps.zflags(duel, p & 1, z)
	if int(zf.get("cannot_direct_turn", -1)) == CustomDuelOps.turn_number(duel):
		return false
	if bool(zf.get("direct_atk", false)):
		return true
	return CustomEffectsMonsters1.can_direct_attack(duel, p, z, id) or CustomEffectsMonsters2.can_direct_attack(duel, p, z, id)


static func has_pierce(duel, p: int, z: int, cid := -1) -> bool:
	# Meteorain (2953): los monstruos del jugador perforan durante ese turno.
	if int(CustomDuelOps.pflags(duel, p & 1).get("piercing_turn", -1)) == CustomDuelOps.turn_number(duel):
		return true
	var id = cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	# Dragon's Rage (2745): los monstruos Dragon del jugador perforan mientras la trampa siga boca arriba.
	if CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, p, z)) == 1 and CustomDuelOps.has_faceup_id(duel, p, 2745):
		return true
	return CustomEffectsMonsters1.has_pierce(duel, p, z, id) or CustomEffectsMonsters2.has_pierce(duel, p, z, id)


static func max_attacks(duel, p: int, z: int, cid := -1) -> int:
	var id = cid if cid >= 0 else CustomDuelOps.zone_id(duel, p, z)
	var granted: int = int(CustomDuelOps.zflags(duel, p & 1, z).get("max_attacks", 0))
	return maxi(maxi(CustomEffectsMonsters1.max_attacks(duel, p, z, id), CustomEffectsMonsters2.max_attacks(duel, p, z, id)), granted)


static func check_win(duel) -> int:
	var st = CustomDuelOps.state(duel)
	var pending := int(st.get("pending_win", -1))
	if pending >= 0:
		return pending
	var w1 = CustomEffectsMonsters1.check_win(duel)
	if w1 >= 0:
		return w1
	return -1


static func check_and_apply_win(duel) -> int:
	var w = check_win(duel)
	if w == 0 or w == 1:
		CustomDuelOps.declare_win(duel, w)
	return w


## Exodius, Inferno Uria, Legendary Exodia Incarnate, Winged Kuriboh LV9, Maju Garzett, Great Maju
## Garzett, Chaos Necromancer y Gren Maju Da Eiza: ATK/DEF impresos 0 y valor fijado por una cuenta.
const STAT_SET_KEEPS_BONUS := [2575, 2594, 2657, 2684, 2991, 3030, 3086, 3121]


static func modify_post_stats(duel, p: int, z: int, cur_atk: int, cur_def: int) -> Vector2i:
	p &= 1
	var cid = CustomDuelOps.zone_id(duel, p, z)
	var st = CustomDuelOps.state(duel)
	var k = "%d:%d" % [p, z]
	var t = CustomDuelOps.turn_number(duel)
	var atk = cur_atk
	var df = cur_def

	if st["trap_monsters"].has(k):
		var tm: Dictionary = st["trap_monsters"][k]
		atk = int(tm.get("atk", atk))
		df = int(tm.get("def", df))

	var mod = {}
	if CustomEffectsMonsters1.handles(cid) or cid != 0:
		CustomEffectsMonsters1.modify_continuous(duel, p, z, cid, mod)
	if CustomEffectsMonsters2.handles(cid):
		CustomEffectsMonsters2.modify_continuous(duel, p, z, cid, mod)

	# Monstruos con ATK/DEF impresos 0 cuyo valor sale de una cuenta: el equipo y demas bonos del
	# motor (cur_atk/cur_def, sin base) se suman encima en vez de perderse (Axe of Despair...).
	var keep_atk: int = cur_atk if cid in STAT_SET_KEEPS_BONUS else 0
	var keep_def: int = cur_def if cid in STAT_SET_KEEPS_BONUS else 0
	if mod.has("atk_set"):
		atk = int(mod["atk_set"]) + keep_atk
	if mod.has("def_set"):
		df = int(mod["def_set"]) + keep_def
	atk += int(mod.get("atk_delta", 0))
	df += int(mod.get("def_delta", 0))
	if bool(mod.get("half", false)):
		atk = int(atk / 2)
		df = int(df / 2)

	# Maju Garzett (2991) y Great Maju Garzett (3030): su ATK sale de los monstruos ofrendados,
	# que pueden llegar al Cementerio despues del aviso de invocacion. Por eso el valor se fija
	# la primera vez que ya estan ahi, y no en el momento de la invocacion.
	if cid == 2991 or cid == 3030:
		# El valor se guarda por instancia de carta (indice de memoria), no por zona: los flags de
		# zona se borran cuando otro monstruo sale del campo, y antes eso hacia que el ATK se
		# recalculara con otro Cementerio y cambiara a mitad del duelo.
		var st_g: Dictionary = CustomDuelOps.state(duel)
		var fixed_g: Dictionary = st_g.get_or_add("garrzett_fixed", {})
		var idx_g: int = CustomDuelOps.zone_idx(duel, p, z)
		var key_g: String = "%d" % idx_g
		if not fixed_g.has(key_g) and int(CustomDuelOps.zflags(duel, p, z).get("garrzett_pending", 0)) != 0:
			var need_g: int = 2 if cid == 2991 else 1
			var gy_n: int = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE)
			var total_g: int = 0
			var found_g: int = 0
			for i in range(gy_n - 1, -1, -1):
				var idx_pile: int = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
				if CustomDuelOps.is_monster(duel, idx_pile):
					total_g += CustomDuelOps.base_atk(duel, idx_pile)
					found_g += 1
					if found_g >= need_g:
						break
			if found_g >= need_g and total_g > 0:
				fixed_g[key_g] = {"cid": cid, "atk": total_g * 2 if cid == 3030 else total_g}
		if fixed_g.has(key_g):
			var rec_g: Dictionary = fixed_g[key_g]
			if int(rec_g.get("cid", 0)) == cid:
				atk = int(rec_g.get("atk", atk)) + keep_atk

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
	var st = CustomDuelOps.state(duel)
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
				var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, cid)
				if gi >= 0:
					var nz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
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
		"capsule_resolve":
			var cz := int(data.get("z", -1))
			var bcid := int(data.get("card_id", 0))
			if cz >= 0 and bcid > 0 and CustomDuelOps.zone_id(duel, p, cz) == 2809:
				CustomDuelOps.destroy_zone(duel, p, cz)
				var bi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_BANISH, bcid)
				if bi >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_BANISH, bi, p, CustomDuelOps.LOC_HAND)
		"final_countdown_win":
			CustomDuelOps.declare_win(duel, p)
		"banish_zone":
			var bz := int(data.get("z", -1))
			if bz >= 0 and CustomDuelOps.zone_idx(duel, p, bz) != 0:
				CustomDuelOps.banish_zone(duel, p, bz)
		"destroy_zone":
			var dz := int(data.get("z", -1))
			if dz >= 0 and CustomDuelOps.zone_idx(duel, p, dz) != 0:
				CustomDuelOps.destroy_zone(duel, p, dz)
		"return_banished_id":
			var rid := int(data.get("card_id", 0))
			if rid > 0:
				var ri := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_BANISH, rid)
				if ri >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_BANISH, ri, p)
	CustomDuelOps.sync_visuals(duel)
