class_name CustomDuelOps
extends RefCounted
## Shared duel primitives used by both the shared Core engine (Duel / DuelMem) and the native
## Joey engine (JoeyEngine / JoeyMem): per-duel state flags, zone/pile access, stat reads,
## movement helpers, optional prompts and ritual monster matching.

const LOC_HAND := 11
const LOC_FUSION := 12
const LOC_DECK := 13
const LOC_GRAVE := 14
const LOC_BANISH := 15

static var _states := {}


static func is_joey(duel) -> bool:
	return duel != null and (duel.has_method("f5b9170") or (duel.m != null and duel.m is JoeyMem))


static func _new_state() -> Dictionary:
	return {
		"hopt": {},           # "<p>:<card_id>" -> turn_number
		"opt": {},            # "<p>:<card_id>:<z_or_key>" -> turn_number
		"opd": {},            # "<p>:<card_id>" -> true
		"counters": {},       # "<p>:<z>:<kind>" -> int
		"temp_atk": {},       # "<p>:<z>" -> Array of [delta, until_turn, owner]
		"temp_def": {},       # "<p>:<z>" -> Array of [delta, until_turn, owner]
		"perm_atk": {},       # "<p>:<z>" -> int
		"perm_def": {},       # "<p>:<z>" -> int
		"set_atk": {},        # "<p>:<z>" -> [val, until_turn] (-1 if perm)
		"set_def": {},        # "<p>:<z>" -> [val, until_turn] (-1 if perm)
		"zone_flags": {},     # "<p>:<z>" -> Dictionary of booleans/ints (pierce, multi_atk, immune, cannot_atk, direct_atk, battle_immune, effect_immune, indest_battle, indest_effect, cannot_pos, negated)
		"player_flags": {0: {}, 1: {}}, # turn-scoped & duel-scoped player lingering flags
		"delayed": [],        # Array of {"turn": int, "phase": int, "p": int, "card_id": int, "action": String, "data": Dictionary}
		"trap_monsters": {},  # "<p>:<z>" -> Dictionary {"card_id": int, "src_z": int, "type": int, "attr": int, "lv": int, "atk": int, "def": int}
		"equip_links": {},    # "<eq_p>:<eq_z>" -> {"target_p": int, "target_z": int, "card_id": int}
		"last_coin": -1,
		"last_die": 0,
		"last_damage": {0: 0, 1: 0},
		"summoned_this_turn": {0: [], 1: []},
		"destroyed_this_turn": {0: [], 1: []},
		"sent_gy_this_turn": {0: [], 1: []},
		"last_turn_seen": -1,
		"last_phase_seen": -1,
		"pending_win": -1,    # -1 none, 0 p0 wins, 1 p1 wins, 2 draw
	}


static func state(duel) -> Dictionary:
	var key: int = duel.get_instance_id()
	if not _states.has(key):
		_states[key] = _new_state()
	return _states[key]


static func reset_duel(duel) -> void:
	if duel == null:
		return
	_states[duel.get_instance_id()] = _new_state()


static func turn_number(duel) -> int:
	if is_joey(duel):
		var t: int = duel.m.u16(0xa577f8)
		return t if t > 0 else 1
	return maxi(1, duel.m.u16(0xa133f0))


## True when the player already Normal Summoned or Set a monster this turn (the engine's own flag:
## Core bit 0x10 of the player byte at +8, Joey bit 20 of the player flags at 0xa56430).


static func phase(duel) -> int:
	if is_joey(duel):
		return (duel.m.u8(JoeyMem.TURN) >> 1) & 7
	return (duel.m.u8(0xa133f2) >> 1) & 7


static func get_lp(duel, p: int) -> int:
	p &= 1
	if is_joey(duel):
		return duel.m.u16(JoeyMem.pl(p) + JoeyMem.P_LP)
	return duel.m.u16(DuelMem.pl(p) + DuelMem.P_LP)


static func set_lp(duel, p: int, value: int) -> void:
	p &= 1
	var clamped = clampi(value, 0, 65535)
	if is_joey(duel):
		duel.m.set_u16(JoeyMem.pl(p) + JoeyMem.P_LP, clamped)
	else:
		duel.m.set_u16(DuelMem.pl(p) + DuelMem.P_LP, clamped)


static func damage(duel, p: int, amount: int, is_battle := false) -> int:
	p &= 1
	if amount <= 0:
		return 0
	var pf = pflags(duel, p)
	if not is_battle and int(pf.get("no_effect_damage_turn", 0)) == turn_number(duel):
		return 0
	# Trap of Board Eraser (2798): niega el proximo dano de efecto que iba a recibir el jugador.
	if not is_battle and bool(pf.get("negate_next_effect_damage", false)):
		pf["negate_next_effect_damage"] = false
		return 0
	# Barrel Behind the Door (2875): ese dano de efecto lo recibe el rival en su lugar.
	if not is_battle and bool(pflags(duel, 1 - p).get("reflect_effect_damage_once", false)):
		pflags(duel, 1 - p)["reflect_effect_damage_once"] = false
		return damage(duel, 1 - p, amount, false)
	if int(pf.get("effect_dmg_to_heal_turn", 0)) == turn_number(duel) and not is_battle:
		return heal(duel, p, amount)
	if int(pf.get("halve_damage_turn", 0)) == turn_number(duel):
		amount = int(amount / 2)
	if amount <= 0:
		return 0
	var st = state(duel)
	st["last_damage"][p] = amount
	if is_joey(duel):
		duel.f5784e0(p, mini(amount, 0xffff))
	else:
		duel.f54ef90(p, mini(amount, 0xffff))
	return amount


static func heal(duel, p: int, amount: int) -> int:
	p &= 1
	if amount <= 0:
		return 0
	var opp = 1 - p
	# Bad Reaction to Simochi / Nurse Reficule equivalent
	if has_faceup_id(duel, opp, 2777) or has_faceup_id(duel, 0, 2777):
		return damage(duel, p, amount, false)
	if is_joey(duel):
		duel.f5787f0(p, mini(amount, 0xffff))
	else:
		var before = get_lp(duel, p)
		set_lp(duel, p, before + amount)
		if duel.has_method("present"):
			duel.present("lp_total", {"p": p, "from": before, "to": get_lp(duel, p), "amount": amount, "native_silent": false})
	return amount


static func pflags(duel, p: int) -> Dictionary:
	var st = state(duel)
	var pf: Dictionary = st["player_flags"]
	if not pf.has(p & 1):
		pf[p & 1] = {}
	return pf[p & 1]


static func zflags(duel, p: int, z: int) -> Dictionary:
	var st = state(duel)
	var k = "%d:%d" % [p & 1, z]
	if not st["zone_flags"].has(k):
		st["zone_flags"][k] = {}
	return st["zone_flags"][k]


static func raw_id(duel, idx: int) -> int:
	idx &= 0xfff
	if idx == 0:
		return 0
	return duel.cards.id_of(idx) & 0xffff


static func prop_of(duel, idx: int) -> int:
	idx &= 0xfff
	if idx == 0:
		return 0
	return duel.cards.prop(idx)


static func ctype(duel, idx: int) -> int:
	return (prop_of(duel, idx) >> 20) & 0x1f


static func csub(duel, idx: int) -> int:
	return (prop_of(duel, idx) >> 17) & 7


static func is_monster(duel, idx: int) -> bool:
	var t = ctype(duel, idx)
	return idx > 0 and (t > 0 and t < 0x15 or t == 0x18)


static func is_spell(duel, idx: int) -> bool:
	return idx > 0 and ctype(duel, idx) == 0x16


static func zone_addr(duel, p: int, z: int) -> int:
	if is_joey(duel):
		return JoeyMem.zone(p & 1, z)
	return DuelMem.zone(p & 1, z)


static func zone_entry(duel, p: int, z: int) -> int:
	return duel.m.u32(zone_addr(duel, p, z))


static func zone_idx(duel, p: int, z: int) -> int:
	return zone_entry(duel, p, z) & 0xfff


static func zone_id(duel, p: int, z: int) -> int:
	return raw_id(duel, zone_idx(duel, p, z))


static func is_face_up(duel, p: int, z: int) -> bool:
	var addr = zone_addr(duel, p, z)
	if (duel.m.u32(addr) & 0xfff) == 0:
		return false
	return (duel.m.u8(addr + 6) & 2) != 0


static func is_atk_pos(duel, p: int, z: int) -> bool:
	var addr = zone_addr(duel, p, z)
	return (duel.m.u8(addr + 6) & 1) == 0


static func eff_atk(duel, p: int, z: int) -> int:
	var idx = zone_idx(duel, p, z)
	if idx == 0 or z >= 5:
		return 0
	var out: int = duel.m.local(12)
	if is_joey(duel):
		duel.f56dd30(p & 1, z, out)
		return maxi(0, duel.m.s16(out + 4) if duel.m.u32(out + 4) > 0x7fffffff else int(duel.m.u32(out + 4)))
	duel.f546470(p & 1, z, out)
	return maxi(0, int(duel.m.u32(out + 4))) if duel.m.u32(out + 4) < 0x80000000 else 0


static func eff_def(duel, p: int, z: int) -> int:
	var idx = zone_idx(duel, p, z)
	if idx == 0 or z >= 5:
		return 0
	var out: int = duel.m.local(12)
	if is_joey(duel):
		duel.f56dd30(p & 1, z, out)
		return maxi(0, int(duel.m.u32(out + 8))) if duel.m.u32(out + 8) < 0x80000000 else 0
	duel.f546470(p & 1, z, out)
	return maxi(0, int(duel.m.u32(out + 8))) if duel.m.u32(out + 8) < 0x80000000 else 0


static func pile_count(duel, p: int, loc: int) -> int:
	p &= 1
	if is_joey(duel):
		var base = JoeyMem.pl(p)
		match loc:
			LOC_HAND: return duel.m.u8(base + JoeyMem.P_HAND_N)
			LOC_FUSION: return duel.m.u8(base + JoeyMem.P_FUSION_N)
			LOC_DECK: return duel.m.u8(base + JoeyMem.P_DECK_N)
			LOC_GRAVE: return duel.m.u8(base + JoeyMem.P_GRAVE_N)
			LOC_BANISH: return duel.m.u8(base + JoeyMem.P_BANISH_N)
		return 0
	var base = DuelMem.pl(p)
	match loc:
		LOC_HAND: return duel.m.u8(base + DuelMem.P_HAND_N)
		LOC_FUSION: return duel.m.u8(base + DuelMem.P_FUSION_N)
		LOC_DECK: return duel.m.u8(base + DuelMem.P_DECK_N)
		LOC_GRAVE: return duel.m.u8(base + DuelMem.P_GRAVE_N)
		LOC_BANISH: return duel.m.u8(base + DuelMem.P_BANISH_N)
	return 0


static func pile_addr(duel, p: int, loc: int, i: int) -> int:
	p &= 1
	if is_joey(duel):
		return duel.f5700f0(p, loc, i)
	return duel.f5419b0(p, loc, i)


static func pile_entry(duel, p: int, loc: int, i: int) -> int:
	if i < 0 or i >= pile_count(duel, p, loc):
		return 0
	return duel.m.u32(pile_addr(duel, p, loc, i))


static func pile_idx(duel, p: int, loc: int, i: int) -> int:
	return pile_entry(duel, p, loc, i) & 0xfff


static func free_monster_zone(duel, p: int) -> int:
	p &= 1
	for z in 5:
		if monster_zone_usable(duel, p, z):
			return z
	return -1


## 1 si la zona de monstruo se puede usar: vacia y sin inutilizar. Algunas cartas dejan zonas
## destruidas (ahi no se puede colocar nada); el motor guarda esa marca en los cinco bits bajos
## de la ficha de jugador (Yugi) o en las marcas de su lista de bloqueos (Joey), asi que la
## comprobacion se delega en la rutina del motor que ya mira las dos cosas.


## 1 si la zona de monstruo se puede usar: vacia y sin inutilizar. Algunas cartas dejan zonas
## destruidas (ahi no se puede colocar nada); el motor guarda esa marca en los cinco bits bajos
## de la ficha de jugador (Yugi) o en las marcas de su lista de bloqueos (Joey), asi que la
## comprobacion se delega en la rutina del motor que ya mira las dos cosas.
static func monster_zone_usable(duel, p: int, z: int) -> bool:
	p &= 1
	if z < 0 or z > 4 or zone_idx(duel, p, z) != 0:
		return false
	if is_joey(duel):
		if duel.has_method("f569f70"):
			return int(duel.f569f70(p, z)) != 0
		return true
	if duel.has_method("f543260"):
		return int(duel.f543260(p, z)) != 0
	return true


static func has_faceup_id(duel, p: int, cid: int) -> bool:
	for z in 11:
		if zone_idx(duel, p, z) != 0 and is_face_up(duel, p, z) and zone_id(duel, p, z) == cid:
			return true
	return false


static func declare_win(duel, winner_p: int) -> void:
	winner_p &= 1
	var st = state(duel)
	st["pending_win"] = winner_p
	if is_joey(duel):
		set_lp(duel, 1 - winner_p, 0)
	else:
		set_lp(duel, 1 - winner_p, 0)
		duel.f53d730(1)


# --- Card & Zone Mutations (Core + Joey Safe Primitives) -----------------------------------------


static func draw(duel, p: int, count: int) -> int:
	p &= 1
	if count <= 0:
		return 0
	var deck_n = pile_count(duel, p, LOC_DECK)
	if deck_n <= 0:
		declare_win(duel, 1 - p)
		return 0
	var actual = mini(count, deck_n)
	if is_joey(duel):
		duel.f578b60(p, actual)
	else:
		duel.f54f470(p, actual)
	if count > deck_n:
		declare_win(duel, 1 - p)
	return actual


static func shuffle_deck(duel, p: int) -> void:
	p &= 1
	if pile_count(duel, p, LOC_DECK) <= 1:
		return
	if is_joey(duel):
		duel.f568d80(p, 3)
	else:
		duel.f5426d0(p, 3)


static func _core_take_pile_entry(duel, p: int, loc: int, i: int, out_addr: int) -> bool:
	p &= 1
	var m: DuelMem = duel.m
	var q = p * DuelMem.PLAYER_SIZE
	if i < 0 or i >= pile_count(duel, p, loc):
		return false
	match loc:
		LOC_HAND:
			var addr: int = duel.f5419b0(p, LOC_HAND, i)
			duel.f541cb0(out_addr, addr)
			m.set_u32(addr, m.u32(addr) & 0xfffff000)
			duel.f544e00(p)
			return true
		LOC_DECK:
			return duel.f542790(p, i, out_addr) != 0
		LOC_GRAVE:
			return duel.f544740(p, i, out_addr) != 0
		LOC_BANISH:
			duel.f541cb0(out_addr, duel.f5419b0(p, LOC_BANISH, i))
			return duel.f544a80(p, i) != 0
		LOC_FUSION:
			var count_at = 0xa11949 + q
			var n: int = m.u8(count_at)
			if i >= n:
				return false
			var at = 0xa12378 + q + i * 4
			duel.f541cb0(out_addr, at)
			m.set_u8(count_at, n - 1)
			var j = i
			while j < m.u8(count_at):
				duel.f541cb0(at, at + 4)
				j += 1
				at += 4
			return true
	return false


static func _core_put_pile_entry(duel, p: int, loc: int, entry_addr: int, to_bottom := false) -> void:
	p &= 1
	match loc:
		LOC_HAND:
			duel.f544c50(p, entry_addr)
		LOC_DECK:
			if to_bottom:
				duel.f5425a0(p, entry_addr)
			else:
				duel.f542520(p, entry_addr)
		LOC_GRAVE:
			# Preserve original owner bit
			var owner: int = (duel.m.u32(entry_addr) >> 12) & 1
			var old: int = duel.m.u32(entry_addr)
			duel.m.set_u32(entry_addr, (old & 0xffffefff) | (p << 12))
			duel.f544300(entry_addr)
			if owner != p:
				pass
		LOC_BANISH:
			duel.f5443a0(entry_addr)
		LOC_FUSION:
			duel.f5425e0(p, entry_addr)


static func _present(duel, kind: String, data: Dictionary = {}) -> void:
	if duel == null:
		return
	if is_joey(duel):
		var ev: Dictionary = data.duplicate(true)
		ev["kind"] = kind
		duel.events.append(ev)
	elif duel.has_method("present"):
		duel.present(kind, data)


static func move_pile_card(duel, from_p: int, from_loc: int, i: int, to_p: int, to_loc: int, to_bottom := false) -> int:
	from_p &= 1
	to_p &= 1
	if i < 0 or i >= pile_count(duel, from_p, from_loc):
		return 0
	var tmp: int = duel.m.local(4)
	var idx: int = pile_idx(duel, from_p, from_loc, i)
	var cid: int = raw_id(duel, idx)
	if is_joey(duel):
		var src: int = duel.f5700f0(from_p, from_loc, i)
		duel.f5675c0(tmp, src)
		duel.f570790(from_p, from_loc, i)
		var arg = 1 if (to_loc == LOC_DECK and to_bottom) else 0
		duel.f5708d0(to_p, to_loc, arg, tmp)
	else:
		if not _core_take_pile_entry(duel, from_p, from_loc, i, tmp):
			return 0
		_core_put_pile_entry(duel, to_p, to_loc, tmp, to_bottom)
	if to_loc == LOC_GRAVE:
		var list: Array = state(duel)["sent_gy_this_turn"][to_p]
		list.append(cid)
		# Skull Invitation (0x51a): el motor lo avisa en sus envios al Cementerio, pero estos
		# movimientos (mazo, mano...) no pasan por el, asi que se avisa aqui: 300 por carta.
		if is_joey(duel):
			duel.f59d6e0(to_p, 1)
		else:
			duel.f56e2e0(to_p, 1)
	var dst_slot: int = 0 if to_bottom else maxi(0, pile_count(duel, to_p, to_loc) - 1)
	_present(duel, "move", {
		"p": from_p,
		"card": cid,
		"from": (from_p & 1) | ((from_loc & 0xf) << 1) | ((i & 0xff) << 5),
		"to": (to_p & 1) | ((to_loc & 0xf) << 1) | ((dst_slot & 0xff) << 5) | 0x8000,
		"reason": 0,
	})
	sync_visuals(duel)
	return idx


static func sync_visuals(duel) -> void:
	if duel == null:
		return
	if is_joey(duel):
		duel.events.append({"kind": "table_sync"})
	elif duel.has_method("present"):
		duel.present("table_sync", {})


static func special_summon_from_pile(duel, src_p: int, loc: int, i: int, target_p: int, face_up := true, def_pos := false) -> int:
	src_p &= 1
	target_p &= 1
	var z = free_monster_zone(duel, target_p)
	if z < 0:
		return -1
	var idx = pile_idx(duel, src_p, loc, i)
	if idx == 0:
		return -1
	var cid: int = raw_id(duel, idx)
	var tmp: int = duel.m.local(4)
	if is_joey(duel):
		var src: int = duel.f5700f0(src_p, loc, i)
		duel.f5675c0(tmp, src)
		duel.f570790(src_p, loc, i)
		duel.f568610(target_p, z, tmp, 1 if def_pos else 0, 1 if face_up else 0)
	else:
		if not _core_take_pile_entry(duel, src_p, loc, i, tmp):
			return -1
		duel.f5422b0(target_p, z, tmp, 1 if def_pos else 0, 1 if face_up else 0)
		var zn = DuelMem.zone(target_p, z)
		if face_up:
			duel.m.set_u8(zn + 6, duel.m.u8(zn + 6) | 2)
		else:
			duel.m.set_u8(zn + 6, duel.m.u8(zn + 6) & ~2)
	if loc == LOC_DECK:
		shuffle_deck(duel, src_p)
	state(duel)["summoned_this_turn"][target_p].append(cid)
	var flags: int = (1 if def_pos else 0) | ((1 if face_up else 0) << 1)
	_present(duel, "move", {
		"p": src_p,
		"card": cid,
		"from": (src_p & 1) | ((loc & 0xf) << 1) | ((i & 0xff) << 5),
		"to": (target_p & 1) | ((z & 0xf) << 1) | ((1 if def_pos else 0) << 14) | ((1 if face_up else 0) << 15),
		"reason": 1,
	})
	_present(duel, "special", {"p": target_p, "zone": z, "card": cid, "flags": flags})
	sync_visuals(duel)
	return z


static func change_position(duel, p: int, z: int, def_pos: int, face_up := -1) -> void:
	p &= 1
	var zf_pos: Dictionary = zflags(duel, p, z)
	if int(zf_pos.get("lock_pos_until_turn", -1)) > turn_number(duel):
		return
	if bool(zf_pos.get("cannot_pos", false)):
		return
	if int(zf_pos.get("cannot_pos_turn", -1)) == turn_number(duel):
		return
	var addr = zone_addr(duel, p, z)
	if (duel.m.u32(addr) & 0xfff) == 0 or z >= 5:
		return
	var cur: int = duel.m.u16(addr + 6)
	var next = cur
	if def_pos >= 0:
		if def_pos != 0:
			next |= 1
		else:
			next &= ~1
	if face_up >= 0:
		if face_up != 0:
			next |= 2
		else:
			next &= ~2
	var was_up: bool = (cur & 2) != 0
	var was_def: bool = (cur & 1) != 0
	var now_up: bool = (next & 2) != 0
	var now_def: bool = (next & 1) != 0
	duel.m.set_u16(addr + 6, next)
	if not is_joey(duel):
		if def_pos >= 0:
			duel.f54e660(p, z, def_pos, 1)
	if was_up != now_up:
		_present(duel, "flip", {"p": p, "zone": z, "b": 1 if now_up else 0, "flags": cur & 3, "native_target_flags": next & 3})
	elif was_def != now_def and is_joey(duel):
		_present(duel, "change_position", {"p": p, "zone": z, "b": 1 if now_up else 0, "flags": cur & 3, "native_target_flags": next & 3})
	sync_visuals(duel)


static func _open_optional_prompt(duel, text: String, on_yes: Callable, on_no := Callable()) -> void:
	duel.dialog_open = {"type": 1, "msg": -1, "literal": text, "subs": [], "buttons": 2, "default": -1, "custom_yes": on_yes, "custom_no": on_no}
	duel.present("dialog_open", duel.dialog_open.duplicate())


static func next_optional_prompt(duel) -> void:
	var st = state(duel)
	var queue: Array = st.get_or_add("optional_prompts", [])
	if queue.is_empty() or not duel.dialog_open.is_empty():
		return
	var nxt: Dictionary = queue.pop_front()
	_open_optional_prompt(duel, str(nxt["text"]), nxt["yes"], nxt.get("no", Callable()))


## Pide al jugador que elija una carta de una pila con la ventana de lista del motor
## (FUN_00407580). Devuelve true si la pregunta quedo abierta: al elegir, on_pick recibe el
## indice de la carta en la pila, o -1 si cerro sin elegir. Solo para el jugador humano.


## Pide al jugador que elija una carta de una pila con la ventana de lista del motor
## (FUN_00407580). Devuelve true si la pregunta quedo abierta: al elegir, on_pick recibe el
## indice de la carta en la pila, o -1 si cerro sin elegir. Solo para el jugador humano.
static func ask_pile_card(duel, p: int, loc: int, filter: Callable, on_pick: Callable) -> bool:
	if not (duel is Duel):
		return false
	if (p & 1) != 0 or int(duel.game_mode) != DuelBase.GAME_NORMAL or int(duel.auto_answer) != -1:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	if not duel.list_open.is_empty() or not duel.dialog_open.is_empty():
		return false
	duel.f407580(p & 1, loc, 0, 0)
	var m = duel.m
	var n: int = m.u16(0xa11924)
	var keep: Array = []
	var w := 0
	for i in n:
		var idx: int = m.u16(0xa11624 + i * 4) & 0xfff
		if idx == 0 or not filter.call(duel, idx, i):
			continue
		if w != i:
			m.set_u16(0xa11624 + w * 4, m.u16(0xa11624 + i * 4))
			m.set_u16(0xa11824 + w * 2, m.u16(0xa11824 + i * 2))
		keep.append(i)
		w += 1
	m.set_u16(0xa11924, w)
	if w == 0:
		on_pick.call(-1)
		return true
	duel.list_open = {"p": p & 1, "loc": loc, "mode": 1, "native_selection": true,
		"selection_limit": 1, "custom_pick": {"keep": keep, "cb": on_pick}}
	duel.present("list_open", duel.list_open.duplicate())
	return true


## Cierra la lista de ask_pile_card: pasa la marca del jugador a la carta de la pila.


## Cierra la lista de ask_pile_card: pasa la marca del jugador a la carta de la pila.
static func finish_pile_pick(duel, marks: int, pick: Dictionary) -> void:
	var cb: Variant = pick.get("cb", null)
	var keep: Array = pick.get("keep", [])
	var idx := -1
	if marks > 0:
		for k in mini(duel.f4073e0(), keep.size()):
			if duel.f407570(k) != 0:
				idx = int(keep[k])
				break
	for k in duel.f4073e0():
		duel.f407540(k, 0)
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call(idx)


static func find_pile_index_by_id(duel, p: int, loc: int, cid: int) -> int:
	for i in pile_count(duel, p, loc):
		if raw_id(duel, pile_idx(duel, p, loc, i)) == cid:
			return i
	return -1


## Whether the card at card_index is the Ritual Monster that ritual_id summons (the card itself
## or its effect alias must match).
static func matches_ritual_monster_core(duel, card_index: int, ritual_id: int) -> bool:
	var idx = card_index & 0xfff
	if idx == 0 or ritual_id <= 0:
		return false
	return duel.cards.id_of(idx) == ritual_id or (duel.effect_card_id(idx) & 0xffff) == ritual_id


static func matches_ritual_monster_joey(duel, card_index: int, ritual_id: int) -> bool:
	var idx = card_index & 0xfff
	if idx == 0 or ritual_id <= 0:
		return false
	return duel.cards.id_of(idx) == ritual_id or (duel.effect_card_id(idx) & 0xffff) == ritual_id
