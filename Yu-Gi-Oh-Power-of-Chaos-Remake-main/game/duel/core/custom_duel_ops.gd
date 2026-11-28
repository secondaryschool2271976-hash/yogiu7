class_name CustomDuelOps
extends RefCounted
## Unified, zero-cycle runtime primitives and extended duel state tracker for custom YGOJSON cards
## across both the shared Core engine (Duel / DuelMem) and the native Joey engine (JoeyEngine / JoeyMem).

const PHASE_DP := 0
const PHASE_SP := 1
const PHASE_M1 := 2
const PHASE_BP := 3
const PHASE_M2 := 4
const PHASE_EP := 5

const LOC_FIELD_MONSTER := 0
const LOC_FIELD_ST := 5
const LOC_FIELD_SPELL := 10
const LOC_HAND := 11
const LOC_FUSION := 12
const LOC_DECK := 13
const LOC_GRAVE := 14
const LOC_BANISH := 15

## Known archetype & name-group IDs spanning both native (0..2499) and YGOJSON expansion (2500..3129).
const EXODIA_IDS := [0x10, 0x11, 0x12, 0x13, 0x14, 2530, 2573, 2574, 2575, 2657, 2660, 2674]
const FORBIDDEN_ONE_IDS := [0x10, 0x11, 0x12, 0x13, 0x14]
const HERO_IDS := [2555, 2556, 2557, 2558, 2559, 2560, 2561, 2562, 2563, 2564, 2565, 2566, 2567, 2568, 2569, 2570, 2646, 3108]
const ELEMENTAL_HERO_IDS := [2555, 2556, 2557, 2558, 2559, 2560, 2561, 2562, 2563, 2564, 2565, 2566, 2567, 2568, 2569, 2570]
const GRAVEKEEPER_IDS := [2820, 2822, 2823, 2826, 2848, 2855, 2857, 2890, 2891]
const AMAZONESS_IDS := [2907, 2940, 2945, 2955, 2968, 2972, 2981]
const SACRED_BEAST_IDS := [2513, 2514, 2525, 2577, 2589, 2594, 2595, 2624, 2677]
const PHANTASM_IDS := [2513, 2514, 2595, 2624, 2625]
const EGYPTIAN_GOD_IDS := [2500, 2501, 2502]
const WICKED_GOD_IDS := [2661, 2662, 2663]
const BLUE_EYES_IDS := [0, 2000, 379, 2518, 2519, 2620]
const RED_EYES_IDS := [81, 2081, 2627, 2628, 3131, 3132, 3133, 3134, 3135, 3136, 3138, 3139, 3140, 3141, 3142]
const DARK_MAGICIAN_IDS := [34, 2034, 759, 2542, 2543, 2544, 2669, 2970]
const TOON_IDS := [60, 61, 62, 63, 726, 727, 728, 766, 2667, 2668, 2669, 2670, 2671, 2672, 2673]
const HARPIE_IDS := [61, 62]
const KURIBOH_IDS := [2681, 2682, 2683, 2684, 2685]
const ARCHFIEND_IDS := [21, 2694, 2696, 2710, 2728, 2757, 2988, 2990, 2992, 3009, 3022, 3023, 3035, 3042, 3048, 3057, 3058]
const CYBER_DRAGON_IDS := [2531, 2532, 2533, 2534, 2535, 2536, 2537, 2623, 2668]
const CYBER_IDS := [2531, 2532, 2533, 2534, 2535, 2536, 2537, 2538, 2539, 2540, 2602, 2623, 2668, 3025]
const HORUS_IDS := [2590, 2591, 2592, 2593]
const ARMED_DRAGON_IDS := [2508, 2509, 2510, 2511, 2512]
const SILENT_MAGICIAN_IDS := [2635, 2636, 2637, 2638]
const SILENT_SWORDSMAN_IDS := [2639, 2640, 2641, 2642, 2643]
const GANDORA_IDS := [2581, 2582, 2583, 2584, 2585]
const LV_IDS := [2508, 2509, 2510, 2511, 2512, 2591, 2592, 2593, 2636, 2637, 2640, 2641, 2642, 2681, 2682, 2683, 2684, 2685]
const NINJA_IDS := [3098]
const MILLENNIUM_IDS := [2578, 2586, 2601, 2608, 2609, 2610, 2611, 2612, 2613, 2614, 2633, 2634, 2680]
const SHINING_SARC_IDS := [2543, 2582, 2618, 2638, 2640, 2643]
const GUARDIAN_IDS := [2588, 2835, 2993, 2995, 3026, 3028, 3060, 3062]
const ARSENAL_SUMMONER_EXCLUDED := [40, 6, 551, 235, 1076]
const OJAMA_IDS := [2999]
const UNION_IDS := [2690, 2692, 2914, 2915, 2939, 2941, 2947, 2959, 2974, 2975, 2989]
const SPIRIT_IDS := [2675, 2700, 2701, 2703, 2730, 2732, 2733, 2735, 2763, 2767, 2768, 2885]
const FLIP_IDS := [2728, 2754, 2770, 2800, 2805, 2818, 2819, 2820, 2826, 2842, 2882, 2898, 2900, 2923, 2933, 2960, 2967, 3059, 3065, 3069, 3098]
const DARK_SCORPION_IDS := [2550, 2836, 2894, 3006, 3032, 3049, 3050, 3061]
const NEPHTHYS_IDS := [2526, 2630]
const SUN_GOD_IDS := [2652, 2664]
const FAVORITE_IDS := [2683]
const EYES_RESTRICT_IDS := [730, 1334, 2614]
const SPHINX_IDS := [2835, 2909, 2910]
const GADGET_IDS := []
const MAGNET_IDS := []

const NATIVE_MONSTER_REBORN := 1008
const NATIVE_POT_OF_GREED := 1010
const NATIVE_POLYMERIZATION := 1003
const NATIVE_MIRROR_FORCE := 1056
const NATIVE_TOON_WORLD := 954
const NATIVE_CRUSH_CARD := 660
const NATIVE_UMI := 333
const NATIVE_UMIIRUKA := 1126
const NATIVE_GRADIUS := 1339
const NATIVE_BUSTER_BLADER := 808
const NATIVE_RELINQUISHED := 730
const NATIVE_DARK_MAGICIAN := [34, 2034]
const NATIVE_DARK_MAGICIAN_GIRL := 759
const NATIVE_MAGICIAN_BLACK_CHAOS := 721
const NATIVE_BLUE_EYES := [0, 2000]
const NATIVE_BEUD := 379
const NATIVE_RED_EYES := [81, 2081]
const NATIVE_HARPIE_LADY := 61
const NATIVE_SUMMONED_SKULL := 21
const NATIVE_FLAME_SWORDSMAN := 14

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


static func clear_all_states() -> void:
	_states.clear()


static func turn_player(duel) -> int:
	if is_joey(duel):
		return duel.m.u8(JoeyMem.TURN) & 1
	return duel.m.u8(0xa133f2) & 1


static func turn_number(duel) -> int:
	if is_joey(duel):
		var t: int = duel.m.u16(0xa577f8)
		return t if t > 0 else 1
	return maxi(1, duel.m.u16(0xa133f0))


## True when the player already Normal Summoned or Set a monster this turn (the engine's own flag:
## Core bit 0x10 of the player byte at +8, Joey bit 20 of the player flags at 0xa56430).
static func normal_summon_used(duel, p: int) -> bool:
	if is_joey(duel):
		return (duel.m.u32(0xa56430 + (p & 1) * JoeyMem.PLAYER_SIZE) & 0x100000) != 0
	return (duel.m.u8(DuelMem.pl(p & 1) + 8) & 0x10) != 0


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
	_guardian_slime_after_damage(duel, p)
	return amount


static func battle_damage(duel, p: int, amount: int) -> int:
	p &= 1
	if amount <= 0:
		return 0
	var pf = pflags(duel, p)
	if int(pf.get("no_battle_damage_turn", 0)) == turn_number(duel):
		return 0
	if int(pf.get("halve_damage_turn", 0)) == turn_number(duel):
		amount = int(amount / 2)
	if amount <= 0:
		return 0
	var st = state(duel)
	st["last_damage"][p] = amount
	if is_joey(duel):
		duel.f5784a0(p, mini(amount, 0xffff))
	else:
		duel.f54ef90(p, mini(amount, 0xffff))
	_guardian_slime_after_damage(duel, p)
	return amount


## Guardian Slime (2588): al recibir dano de batalla o de efecto puede Invocarse a si mismo
## desde la mano (una vez por turno, ranura 2 para no compartir limite con sus otros efectos).
static func _guardian_slime_after_damage(duel, p: int) -> void:
	p &= 1
	if not can_opt(duel, p, 2588, 2):
		return
	if free_monster_zone(duel, p) < 0:
		return
	if find_pile_index_by_id(duel, p, LOC_HAND, 2588) < 0:
		return
	var body := func() -> void:
		if not can_opt(duel, p, 2588, 2):
			return
		var hi := find_pile_index_by_id(duel, p, LOC_HAND, 2588)
		if hi < 0 or free_monster_zone(duel, p) < 0:
			return
		mark_opt(duel, p, 2588, 2)
		special_summon_from_pile(duel, p, LOC_HAND, hi, p, true, false)
	optional_effect(duel, p, 2588, body)


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


static func pay_lp(duel, p: int, amount: int) -> bool:
	p &= 1
	if amount <= 0:
		return true
	var cur = get_lp(duel, p)
	if cur <= amount and amount > 0:
		if cur < amount:
			return false
	if is_joey(duel):
		duel.f5784e0(p, mini(amount, 0xffff))
	else:
		var after = maxi(0, cur - amount)
		set_lp(duel, p, after)
		if duel.has_method("present"):
			duel.present("lp_total", {"p": p, "from": cur, "to": after, "amount": -amount, "native_silent": false})
	record_lp_paid(duel, p, amount)
	return true


static func can_pay_lp(duel, p: int, amount: int) -> bool:
	return get_lp(duel, p) > amount or (amount == 0)


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


static func clear_zone_state(duel, p: int, z: int) -> void:
	var st = state(duel)
	var k = "%d:%d" % [p & 1, z]
	st["temp_atk"].erase(k)
	st["temp_def"].erase(k)
	st["perm_atk"].erase(k)
	st["perm_def"].erase(k)
	st["set_atk"].erase(k)
	st["set_def"].erase(k)
	st["zone_flags"].erase(k)
	st["trap_monsters"].erase(k)
	for ck in st["counters"].keys():
		if str(ck).begins_with(k + ":"):
			st["counters"].erase(ck)
	for ek in st["equip_links"].keys():
		var link: Dictionary = st["equip_links"][ek]
		if (int(link.get("target_p", -1)) == (p & 1) and int(link.get("target_z", -1)) == z) or ek == k:
			st["equip_links"].erase(ek)


# --- Card & Prop Queries -------------------------------------------------------------------------

static func raw_id(duel, idx: int) -> int:
	idx &= 0xfff
	if idx == 0:
		return 0
	return duel.cards.id_of(idx) & 0xffff


static func card_idx(duel, cid: int) -> int:
	return duel.cards.index_of(cid & 0xffff)


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


static func is_trap(duel, idx: int) -> bool:
	return idx > 0 and ctype(duel, idx) == 0x15


static func is_extra_deck_monster(duel, idx: int) -> bool:
	if not is_monster(duel, idx):
		return false
	return ((prop_of(duel, idx) >> 18) & 3) == 2


static func is_ritual_monster(duel, idx: int) -> bool:
	if not is_monster(duel, idx):
		return false
	var cid = raw_id(duel, idx)
	if cid in [2526, 2966, 3046, 3071, 3084, 3129]:
		return true
	return ((prop_of(duel, idx) >> 18) & 3) == 3


static func is_effect_monster(duel, idx: int) -> bool:
	if not is_monster(duel, idx):
		return false
	return ((prop_of(duel, idx) >> 18) & 3) == 1


static func is_normal_monster(duel, idx: int) -> bool:
	if not is_monster(duel, idx):
		return false
	return ((prop_of(duel, idx) >> 18) & 3) == 0


static func monster_race(duel, idx: int) -> int:
	if idx == 0:
		return 0
	# D. Tribe (2796): todos los monstruos del campo son Dragon ese turno.
	var tn := turn_number(duel)
	if int(pflags(duel, 0).get("all_monsters_dragon_turn", -1)) == tn \
			or int(pflags(duel, 1).get("all_monsters_dragon_turn", -1)) == tn:
		return 1
	return ctype(duel, idx)


static func monster_attr(duel, idx: int) -> int:
	if is_monster(duel, idx):
		return (prop_of(duel, idx) >> 29) & 7
	return 0


static func monster_level(duel, idx: int) -> int:
	var t = ctype(duel, idx)
	if t == 0x18:
		return 10
	if t >= 0x15:
		return 0
	var lvl: int = (prop_of(duel, idx) >> 25) & 0xf
	# Cost Down (3010): los monstruos en la mano bajan 2 niveles durante ese turno.
	var cd_t := turn_number(duel)
	for cdp in 2:
		if int(pflags(duel, cdp).get("cost_down_turn", -1)) != cd_t:
			continue
		var cd_hand: int = (JoeyMem.pl(cdp) + JoeyMem.P_HAND) if is_joey(duel) else (DuelMem.pl(cdp) + DuelMem.P_HAND)
		var cd_n: int = duel.m.u8((JoeyMem.pl(cdp) + JoeyMem.P_HAND_N) if is_joey(duel) else (DuelMem.pl(cdp) + DuelMem.P_HAND_N))
		for cdi in cd_n:
			if (duel.m.u16(cd_hand + cdi * 4) & 0xfff) == idx:
				return maxi(1, lvl - 2)
	# Cyber Dragon Drei (2533): Cyber Dragons become Level 5 for the rest of that turn.
	var zf_all: Dictionary = state(duel).get("zone_flags", {})
	if zf_all.is_empty():
		return lvl
	for p in 2:
		for z in 5:
			if zone_idx(duel, p, z) != idx:
				continue
			var key := "%d:%d" % [p, z]
			if not zf_all.has(key):
				continue
			var zf: Dictionary = zf_all[key]
			if bool(zf.get("set_level_5", false)):
				return 5
			# Cyber Dragon Herz (2534): su Nivel pasa a 5 hasta el final de ese turno.
			if int(zf.get("set_level_5_turn", -1)) == turn_number(duel):
				return 5
	return lvl


static func base_atk(duel, idx: int) -> int:
	var t = ctype(duel, idx)
	if t == 0x18:
		return 4000
	if t >= 0x15 and t <= 0x17:
		return 0
	return ((prop_of(duel, idx) >> 9) & 0x1ff) * 10


static func base_def(duel, idx: int) -> int:
	var t = ctype(duel, idx)
	if t == 0x18:
		return 4000
	if t >= 0x15 and t <= 0x17:
		return 0
	return (prop_of(duel, idx) & 0x1ff) * 10


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


static func free_st_zone(duel, p: int) -> int:
	p &= 1
	for z in range(5, 10):
		if zone_idx(duel, p, z) == 0:
			return z
	return -1


static func count_monsters(duel, p: int, face_up_only := false) -> int:
	var n = 0
	for z in 5:
		if zone_idx(duel, p, z) != 0 and (not face_up_only or is_face_up(duel, p, z)):
			n += 1
	return n


static func count_st(duel, p: int, include_field := false) -> int:
	var n = 0
	var lim = 11 if include_field else 10
	for z in range(5, lim):
		if zone_idx(duel, p, z) != 0:
			n += 1
	return n


static func has_faceup_id(duel, p: int, cid: int) -> bool:
	for z in 11:
		if zone_idx(duel, p, z) != 0 and is_face_up(duel, p, z) and zone_id(duel, p, z) == cid:
			return true
	return false


static func count_faceup_id(duel, p: int, cid: int) -> int:
	var n = 0
	for z in 11:
		if zone_idx(duel, p, z) != 0 and is_face_up(duel, p, z) and zone_id(duel, p, z) == cid:
			n += 1
	return n


static func card_name(duel, cid: int) -> String:
	if Engine.get_main_loop() != null:
		var root = Engine.get_main_loop().get("root") as Node
		if root != null:
			var db = root.get_node_or_null("CardDB")
			if db != null and db.has_method("get_card_by_internal_id"):
				var info: Dictionary = db.get_card_by_internal_id(cid)
				if not info.is_empty():
					return str(info.get("name", ""))
	return ""


static func name_matches(duel, idx: int, substr: String) -> bool:
	var cid = raw_id(duel, idx)
	if cid <= 0:
		return false
	var low = substr.to_lower()
	match low:
		"exodia": return cid in EXODIA_IDS
		"forbidden one": return cid in FORBIDDEN_ONE_IDS
		"hero", "elemental hero": return cid in HERO_IDS
		"gravekeeper": return cid in GRAVEKEEPER_IDS
		"amazoness": return cid in AMAZONESS_IDS
		"sacred beast": return cid in SACRED_BEAST_IDS
		"egyptian god": return cid in EGYPTIAN_GOD_IDS
		"wicked": return cid in WICKED_GOD_IDS
		"blue-eyes": return cid in BLUE_EYES_IDS
		"red-eyes": return cid in RED_EYES_IDS
		"dark magician": return cid in DARK_MAGICIAN_IDS
		"toon": return cid in TOON_IDS
		"sphinx": return cid in SPHINX_IDS
		"harpie": return cid in HARPIE_IDS
		"kuriboh": return cid in KURIBOH_IDS
		"archfiend": return cid in ARCHFIEND_IDS
		"cyber dragon": return cid in CYBER_DRAGON_IDS
		"gadget": return cid in GADGET_IDS
		"magnet": return cid in MAGNET_IDS
		"lv": return cid in LV_IDS
		"ninja": return cid in NINJA_IDS
		"millennium": return cid in MILLENNIUM_IDS
		"shining sarcophagus": return cid in SHINING_SARC_IDS
		"guardian": return cid in GUARDIAN_IDS
		"ojama": return cid in OJAMA_IDS
		"union": return cid in UNION_IDS
		"dark scorpion": return cid in DARK_SCORPION_IDS
	var nm = card_name(duel, cid).to_lower()
	if nm != "":
		return nm.find(low) >= 0
	return false


# --- HOPT / OPT / OPD / Counters / Stat Mods -----------------------------------------------------

static func can_hopt(duel, p: int, cid: int) -> bool:
	var st = state(duel)
	var k = "%d:%d" % [p & 1, cid]
	return int(st["hopt"].get(k, -1)) != turn_number(duel)


static func mark_hopt(duel, p: int, cid: int) -> void:
	state(duel)["hopt"]["%d:%d" % [p & 1, cid]] = turn_number(duel)


static func can_opt(duel, p: int, cid: int, slot := 0) -> bool:
	var k = "%d:%d:%d" % [p & 1, cid, slot]
	return int(state(duel)["opt"].get(k, -1)) != turn_number(duel)


static func mark_opt(duel, p: int, cid: int, slot := 0) -> void:
	state(duel)["opt"]["%d:%d:%d" % [p & 1, cid, slot]] = turn_number(duel)


static func can_opd(duel, p: int, cid: int) -> bool:
	return not state(duel)["opd"].has("%d:%d" % [p & 1, cid])


static func mark_opd(duel, p: int, cid: int) -> void:
	state(duel)["opd"]["%d:%d" % [p & 1, cid]] = true


static func add_counter(duel, p: int, z: int, kind: String, delta := 1) -> int:
	var st = state(duel)
	var k = "%d:%d:%s" % [p & 1, z, kind]
	var val = maxi(0, int(st["counters"].get(k, 0)) + delta)
	st["counters"][k] = val
	if is_face_up(duel, p, z):
		if is_joey(duel):
			var zo = JoeyMem.zone(p & 1, z)
			duel.m.set_u16(zo + JoeyMem.Z_COUNTER, maxi(0, duel.m.u16(zo + JoeyMem.Z_COUNTER) + delta))
		else:
			var zn = DuelMem.zone(p & 1, z)
			var cur: int = duel.m.u16(zn + 6)
			var cnt = clampi(((cur >> 2) & 0xf) + delta, 0, 15)
			duel.m.set_u16(zn + 6, (cur & 0xffc3) | (cnt << 2))
	return val


static func get_counter(duel, p: int, z: int, kind: String) -> int:
	return int(state(duel)["counters"].get("%d:%d:%s" % [p & 1, z, kind], 0))


static func add_stat_mod(duel, p: int, z: int, atk_delta: int, def_delta: int, until_ep := true) -> void:
	var st = state(duel)
	var k = "%d:%d" % [p & 1, z]
	if until_ep:
		var t = turn_number(duel)
		if atk_delta != 0:
			if not st["temp_atk"].has(k):
				st["temp_atk"][k] = []
			st["temp_atk"][k].append([atk_delta, t])
		if def_delta != 0:
			if not st["temp_def"].has(k):
				st["temp_def"][k] = []
			st["temp_def"][k].append([def_delta, t])
	else:
		st["perm_atk"][k] = int(st["perm_atk"].get(k, 0)) + atk_delta
		st["perm_def"][k] = int(st["perm_def"].get(k, 0)) + def_delta


static func set_stat_val(duel, p: int, z: int, atk_val: int, def_val: int, until_ep := true) -> void:
	var st = state(duel)
	var k = "%d:%d" % [p & 1, z]
	var exp = turn_number(duel) if until_ep else -1
	if atk_val >= 0:
		st["set_atk"][k] = [atk_val, exp]
	if def_val >= 0:
		st["set_def"][k] = [def_val, exp]


static func schedule_delayed(duel, target_turn: int, target_phase: int, p: int, cid: int, action: String, data := {}) -> void:
	state(duel)["delayed"].append({
		"turn": target_turn,
		"phase": target_phase,
		"p": p & 1,
		"card_id": cid,
		"action": action,
		"data": data,
	})


# --- Deterministic RNG (Coin & Dice) -------------------------------------------------------------

static func coin_toss(duel, p := 0) -> int:
	var r = 0
	if duel.rng != null:
		r = duel.rng.rand() & 1
	else:
		r = randi() & 1
	# Second Coin Toss (if player controls 2921, could flip again favorably, handled when helpful)
	if has_faceup_id(duel, p, 2921) and r == 0 and can_opt(duel, p, 2921, 0):
		mark_opt(duel, p, 2921, 0)
		if duel.rng != null:
			r = duel.rng.rand() & 1
		else:
			r = randi() & 1
	state(duel)["last_coin"] = r # 1 = Heads, 0 = Tails
	return r


static func dice_roll(duel, p := 0) -> int:
	var r = 1
	if duel.rng != null:
		r = (duel.rng.rand() % 6) + 1
	else:
		r = (randi() % 6) + 1
	state(duel)["last_die"] = r
	if has_faceup_id(duel, p, 2750): # That Six!
		if r == 2 or r == 4 or r == 6:
			r = 6
		elif r == 1 or r == 3 or r == 5:
			r = 5
	return r


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


static func mill(duel, p: int, count: int, trigger := 1) -> int:
	p &= 1
	if count <= 0:
		return 0
	var deck_n = pile_count(duel, p, LOC_DECK)
	var actual = mini(count, deck_n)
	if actual <= 0:
		return 0
	if is_joey(duel):
		duel.f578bb0(p, actual, trigger)
	else:
		duel.f54f4c0(p, actual, trigger)
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


static func _count_dragon_discard(duel, p: int, idx: int) -> void:
	p &= 1
	if idx == 0 or int(pflags(duel, p).get("super_rejuv_turn", -1)) != turn_number(duel):
		return
	if ctype(duel, idx) == 1: # Dragon
		var pf = pflags(duel, p)
		pf["dragons_discarded_turn"] = int(pf.get("dragons_discarded_turn", 0)) + 1


static func discard_hand_slot(duel, p: int, hand_i: int, trigger := 1) -> int:
	p &= 1
	if hand_i < 0 or hand_i >= pile_count(duel, p, LOC_HAND):
		return 0
	var idx = pile_idx(duel, p, LOC_HAND, hand_i)
	_count_dragon_discard(duel, p, idx)
	if is_joey(duel):
		move_pile_card(duel, p, LOC_HAND, hand_i, p, LOC_GRAVE)
	else:
		duel.f54e680(p, hand_i, trigger, 1)
	return idx


static func discard_random(duel, p: int, count := 1) -> int:
	p &= 1
	var done = 0
	for _k in count:
		var n = pile_count(duel, p, LOC_HAND)
		if n <= 0:
			break
		var r: int = (duel.rng.rand() % n) if duel.rng != null else (randi() % n)
		if discard_hand_slot(duel, p, r, 1) > 0:
			done += 1
	return done


static func send_zone_to_gy(duel, p: int, z: int) -> bool:
	p &= 1
	var idx = zone_idx(duel, p, z)
	if idx == 0:
		return false
	var cid = raw_id(duel, idx)
	if is_joey(duel):
		duel.f577b30(p, z)
	else:
		var tmp: int = duel.m.local(4)
		duel.f541cb0(tmp, DuelMem.zone(p, z))
		var pbit = 0x8000 if p != 0 else 0
		if cid >= 0x780 and cid < 2000:
			duel.f54e250(p, z, 1)
		else:
			duel.f544300(tmp)
			duel.f54ca50(p, z, 1)
			duel.f542c40(p, z)
			if duel.has_method("present"):
				duel.present("zone_clear", {"p": p, "zone": z, "card": cid})
			duel.issue(pbit | 0x90, z, 0, 0)
	clear_zone_state(duel, p, z)
	state(duel)["sent_gy_this_turn"][p].append(cid)
	sync_visuals(duel)
	return true


## Negates the attack that is being declared and ends the battle, the same two commands the
## original issues for its own attack-cancelling cards (Core FUN_005595f0, Joey FUN_0058cf50):
## 0x35 releases the attacker, 0x37 closes the battle. Works for both engines.
static func negate_attack(duel, effect_p: int, atk_p: int, atk_z: int) -> bool:
	if atk_z < 0 or atk_z >= 5:
		return false
	var atk_bit: int = 0x8000 if (atk_p & 1) != 0 else 0
	var eff_bit: int = 0x8000 if (effect_p & 1) != 0 else 0
	if is_joey(duel):
		duel.f5b9170(atk_bit | 0x35, atk_z, 1, 0)
		duel.f5b9170(eff_bit | 0x37, 0, 0, 0)
	else:
		duel.issue(atk_bit | 0x35, atk_z, 1, 0)
		duel.issue(eff_bit | 0x37, 0, 0, 0)
	return true


## Battle damage that player recv_p would take from the attack atk_p/atk_z against def_p/def_z
## (def_z < 0 = direct attack). Mirrors the engine's own rule: ATK vs ATK, ATK vs DEF only with
## piercing. Used to decide whether Nutrient Z can be activated.
static func battle_damage_to(duel, recv_p: int, atk_p: int, atk_z: int, def_p: int, def_z: int) -> int:
	if atk_z < 0 or atk_z >= 5 or zone_idx(duel, atk_p, atk_z) == 0:
		return 0
	var atk: int = eff_atk(duel, atk_p, atk_z)
	if def_z < 0 or def_z >= 5 or zone_idx(duel, def_p, def_z) == 0:
		return atk if (recv_p & 1) == (def_p & 1) else 0
	if is_atk_pos(duel, def_p, def_z):
		var datk: int = eff_atk(duel, def_p, def_z)
		if atk > datk:
			return (atk - datk) if (recv_p & 1) == (def_p & 1) else 0
		if atk < datk:
			return (datk - atk) if (recv_p & 1) == (atk_p & 1) else 0
		return 0
	var ddef: int = eff_def(duel, def_p, def_z)
	if atk > ddef:
		if CustomCardEffects.has_pierce(duel, atk_p, atk_z) and (recv_p & 1) == (def_p & 1):
			return atk - ddef
		return 0
	if atk < ddef and (recv_p & 1) == (atk_p & 1):
		return ddef - atk
	return 0


static func destroy_zone(duel, p: int, z: int, by_battle := false) -> bool:
	p &= 1
	var idx = zone_idx(duel, p, z)
	if idx == 0:
		return false
	var zf = zflags(duel, p, z)
	if by_battle and bool(zf.get("indest_battle", false)):
		return false
	# Armityle the Chaos Phantasm (2513, 2514): no puede ser destruido en batalla.
	if by_battle and raw_id(duel, idx) in [2513, 2514]:
		return false
	if not by_battle and bool(zf.get("indest_effect", false)):
		return false
	# Sengenjin Wakes (2633): no puede ser destruido por efectos de monstruo.
	if not by_battle and str(state(duel).get("effect_source", "")) not in ["spell", "trap"] \
			and bool(zf.get("indest_monster_effect", false)):
		return false
	# Shield of the Millennium Dynasty (2634): no puede ser destruido por efectos de Magia/Trampa.
	if not by_battle and str(state(duel).get("effect_source", "")) in ["spell", "trap"] \
			and bool(zf.get("indest_st_effect", false)):
		return false
	# Blaze Cannon (2517) y el Ra revivido por Ancient Chant: el monstruo no puede ser afectado
	# por otras cartas ese turno, asi que no lo destruye ningun efecto.
	if not by_battle and int(zf.get("unaffected_until_turn", -1)) >= turn_number(duel):
		return false
	# D. D. Dragon (3036): a Spell/Trap effect that does not target it cannot destroy it.
	if not by_battle and str(state(duel).get("effect_source", "")) in ["spell", "trap"] \
			and not bool(state(duel).get("effect_targeted", false)) and bool(zf.get("nontarget_st_immune", false)):
		return false
	# Frontier Wiseman (2731): a Warrior protected from Spell effects is not destroyed by them.
	if not by_battle and str(state(duel).get("effect_source", "")) == "spell" and bool(zf.get("spell_immune", false)):
		return false
	# Timidity (2834): mientras esta activa nadie puede destruir Magias/Trampas boca abajo.
	if z >= 5 and z <= 9 and not is_face_up(duel, p, z) \
			and (int(pflags(duel, 0).get("timidity_until_turn", -1)) >= turn_number(duel) \
			or int(pflags(duel, 1).get("timidity_until_turn", -1)) >= turn_number(duel)):
		return false
	if bool(zf.get("indest_once", false)):
		zf["indest_once"] = false
		return false
	# Ojama Trio (3015): cada Ojama Token destruido hace 300 de dano a su controlador.
	if bool(zf.get("ojama_token", false)):
		damage(duel, p, 300, false)
	# Different Dimension Gate (3043): al ser destruida devuelve al campo los monstruos que desterro.
	var ddg: Array = zf.get("ddg_ids", [])
	if not ddg.is_empty():
		zf.erase("ddg_ids")
		for entry in ddg:
			var dp := int(entry[0]) & 1
			var bid := int(entry[1])
			if bid <= 0 or free_monster_zone(duel, dp) < 0:
				continue
			var gi := find_pile_index_by_id(duel, dp, LOC_BANISH, bid)
			if gi >= 0:
				special_summon_from_pile(duel, dp, LOC_BANISH, gi, dp)
	var cid = raw_id(duel, idx)
	if is_joey(duel):
		var info: int = duel.m.local(0x14)
		duel.m.set_u16(info, idx)
		duel.m.set_u16(info + 2, p)
		duel.f577880(info, p, z)
	else:
		duel.f54de00(p, z, 1, 1)
	clear_zone_state(duel, p, z)
	state(duel)["destroyed_this_turn"][p].append(cid)
	state(duel)["sent_gy_this_turn"][p].append(cid)
	return true


static func banish_zone(duel, p: int, z: int, face_down := false) -> bool:
	p &= 1
	if zone_idx(duel, p, z) == 0:
		return false
	if is_joey(duel):
		duel.f5778f0(p, z, 1 if face_down else 0)
	else:
		duel.f54e340(p, z, 1 if face_down else 0)
	clear_zone_state(duel, p, z)
	return true


static func banish_from_pile(duel, p: int, loc: int, i: int) -> int:
	return move_pile_card(duel, p, loc, i, p, LOC_BANISH)


static func bounce_zone(duel, p: int, z: int) -> bool:
	p &= 1
	if zone_idx(duel, p, z) == 0:
		return false
	if is_joey(duel):
		duel.f5779d0(p, z, p, 0)
	else:
		duel.f54e420(p, z, 0)
	clear_zone_state(duel, p, z)
	return true


static func spin_zone(duel, p: int, z: int, to_bottom := false) -> bool:
	p &= 1
	var idx: int = zone_idx(duel, p, z)
	if idx == 0:
		return false
	var cid: int = raw_id(duel, idx)
	var entry_val: int = zone_entry(duel, p, z)
	var owner: int = (entry_val >> 12) & 1
	var dst_slot: int = 0 if to_bottom else pile_count(duel, owner, LOC_DECK)
	if is_joey(duel):
		var tmp: int = duel.m.local(4)
		var entry: int = duel.m.u32(JoeyMem.zone(p, z))
		duel.m.set_u32(tmp, entry)
		duel.f570790(p, z, 0)
		duel.f5708d0(owner, LOC_DECK, 1 if to_bottom else 0, tmp)
		_present(duel, "move", {
			"p": p,
			"card": cid,
			"from": (p & 1) | ((z & 0xf) << 1),
			"to": (owner & 1) | ((LOC_DECK & 0xf) << 1) | ((dst_slot & 0xff) << 5),
			"reason": 0,
		})
	else:
		if to_bottom:
			var tmp: int = duel.m.local(4)
			var entry: int = duel.m.u32(DuelMem.zone(p, z))
			duel.m.set_u32(tmp, entry)
			duel.f54ca50(p, z, 0)
			duel.f542c40(p, z)
			duel.f5425a0(owner, tmp)
			_present(duel, "move", {
				"p": p,
				"card": cid,
				"from": (p & 1) | ((z & 0xf) << 1),
				"to": (owner & 1) | ((LOC_DECK & 0xf) << 1) | ((dst_slot & 0xff) << 5),
				"reason": 0,
			})
		else:
			duel.f54e510(p, z)
	clear_zone_state(duel, p, z)
	sync_visuals(duel)
	return true


static func tribute_zone(duel, p: int, z: int) -> bool:
	p &= 1
	var idx = zone_idx(duel, p, z)
	if idx == 0 or z >= 5:
		return false
	# Ojama Trio (3015) y Multiplication of Ants (3111): sus fichas no se pueden ofrendar.
	if bool(zflags(duel, p, z).get("cannot_tribute", false)):
		return false
	var cid = raw_id(duel, idx)
	if is_joey(duel):
		# f577cf0 solo encola el comando de ofrenda y no vacia la zona: se manda la carta
		# al cementerio por la misma ruta que la destruccion (576960) y se comprueba.
		duel.f577b90(p, z)
		if duel.m.u32(JoeyMem.zone(p, z)) & 0xfff != 0:
			duel.f577b30(p, z)
	else:
		duel.f54ea40(p, z)
	clear_zone_state(duel, p, z)
	state(duel)["sent_gy_this_turn"][p].append(cid)
	sync_visuals(duel)
	return true


static func add_from_pile_to_hand(duel, p: int, loc: int, i: int) -> int:
	var owner = p & 1
	var idx = move_pile_card(duel, owner, loc, i, owner, LOC_HAND)
	if idx > 0 and loc == LOC_DECK:
		shuffle_deck(duel, owner)
	return idx


static func send_from_deck_to_gy(duel, p: int, i: int) -> int:
	var owner = p & 1
	var idx = move_pile_card(duel, owner, LOC_DECK, i, owner, LOC_GRAVE)
	if idx > 0:
		shuffle_deck(duel, owner)
	return idx


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


static func special_summon_by_id(duel, p: int, cid: int, atk := -1, def_val := -1, face_up := true, def_pos := false) -> int:
	p &= 1
	var z = free_monster_zone(duel, p)
	if z < 0:
		return -1
	var idx = card_idx(duel, cid)
	if idx <= 0:
		idx = card_idx(duel, 0x780) # fallback token index
	if idx <= 0:
		return -1
	var tmp: int = duel.m.local(4)
	var entry = ((p & 1) << 12) | (idx & 0xfff)
	duel.m.set_u32(tmp, entry)
	if is_joey(duel):
		duel.f568610(p, z, tmp, 1 if def_pos else 0, 1 if face_up else 0)
	else:
		duel.f5422b0(p, z, tmp, 1 if def_pos else 0, 1 if face_up else 0)
		var zn = DuelMem.zone(p, z)
		if face_up:
			duel.m.set_u8(zn + 6, duel.m.u8(zn + 6) | 2)
	if atk >= 0 or def_val >= 0:
		set_stat_val(duel, p, z, atk, def_val, false)
	var flags: int = (1 if def_pos else 0) | ((1 if face_up else 0) << 1)
	_present(duel, "special", {"p": p, "zone": z, "card": cid, "flags": flags})
	sync_visuals(duel)
	return z


static func spawn_token(duel, p: int, token_type := 0, def_pos := false, custom_atk := -1, custom_def := -1) -> int:
	p &= 1
	var z = free_monster_zone(duel, p)
	if z < 0:
		return -1
	var tid = 0x780 + clampi(token_type, 0, 3)
	if is_joey(duel):
		var z2 = special_summon_by_id(duel, p, tid, custom_atk, custom_def, true, def_pos)
		return z2
	var b = (1 if def_pos else 0) if token_type == 0 else clampi(token_type, 0, 3)
	if def_pos and (b == 0 or b == 3):
		b = 1
	elif not def_pos and (b == 1 or b == 2):
		b = 0
	var pbit = 0x8000 if p != 0 else 0
	duel.issue(pbit | 0xa5, z, b, 0)
	if custom_atk >= 0 or custom_def >= 0:
		set_stat_val(duel, p, z, custom_atk, custom_def, false)
	return z


static func activate_trap_as_monster(duel, p: int, st_z: int, atk := 0, def_val := 0, type_id := 15, attr := 0, lv := 4) -> int:
	p &= 1
	var mz = free_monster_zone(duel, p)
	if mz < 0:
		return -1
	var st_idx = zone_idx(duel, p, st_z)
	if st_idx == 0:
		return -1
	var cid = raw_id(duel, st_idx)
	var tmp: int = duel.m.local(4)
	duel.m.set_u32(tmp, duel.m.u32(zone_addr(duel, p, st_z)))
	if is_joey(duel):
		duel.f570790(p, st_z, 0)
		duel.f568610(p, mz, tmp, 0, 1)
	else:
		duel.f542c40(p, st_z)
		duel.f5422b0(p, mz, tmp, 0, 1)
		duel.m.set_u8(DuelMem.zone(p, mz) + 6, duel.m.u8(DuelMem.zone(p, mz) + 6) | 2)
	set_stat_val(duel, p, mz, atk, def_val, false)
	state(duel)["trap_monsters"]["%d:%d" % [p, mz]] = {
		"card_id": cid, "type": type_id, "attr": attr, "lv": lv, "atk": atk, "def": def_val,
	}
	_present(duel, "move", {
		"p": p,
		"card": cid,
		"from": (p & 1) | ((st_z & 0xf) << 1),
		"to": (p & 1) | ((mz & 0xf) << 1) | 0x8000,
		"reason": 1,
	})
	_present(duel, "special", {"p": p, "zone": mz, "card": cid, "flags": 2})
	sync_visuals(duel)
	return mz


static func set_st_from_pile(duel, src_p: int, loc: int, i: int, target_p: int, face_up := false) -> int:
	src_p &= 1
	target_p &= 1
	var idx = pile_idx(duel, src_p, loc, i)
	if idx == 0:
		return -1
	var cid: int = raw_id(duel, idx)
	var is_field = (ctype(duel, idx) == 0x16 and csub(duel, idx) == 2)
	var tz = 10 if is_field else free_st_zone(duel, target_p)
	if tz < 0:
		return -1
	if is_field and zone_idx(duel, target_p, 10) != 0:
		destroy_zone(duel, target_p, 10)
	var tmp: int = duel.m.local(4)
	if is_joey(duel):
		var src: int = duel.f5700f0(src_p, loc, i)
		duel.f5675c0(tmp, src)
		duel.f570790(src_p, loc, i)
		duel.f5686e0(target_p, tz, tmp, 1 if face_up else 0)
	else:
		if not _core_take_pile_entry(duel, src_p, loc, i, tmp):
			return -1
		if is_field:
			duel.f5423a0(target_p, 0, tmp, 1 if face_up else 0)
		else:
			duel.f5423a0(target_p, tz - 5, tmp, 1 if face_up else 0)
	if loc == LOC_DECK:
		shuffle_deck(duel, src_p)
	_present(duel, "move", {
		"p": src_p,
		"card": cid,
		"from": (src_p & 1) | ((loc & 0xf) << 1) | ((i & 0xff) << 5),
		"to": (target_p & 1) | ((tz & 0xf) << 1) | (0x8000 if face_up else 0),
		"reason": 0,
	})
	_present(duel, "card_effect" if face_up else "set", {"p": target_p, "zone": tz, "card": cid, "flags": 2 if face_up else 0})
	sync_visuals(duel)
	return tz


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


static func change_control(duel, from_p: int, from_z: int, to_p: int, temporary_until_ep := true) -> int:
	from_p &= 1
	to_p &= 1
	if from_p == to_p or from_z < 0 or from_z >= 5:
		return -1
	var to_z = free_monster_zone(duel, to_p)
	if to_z < 0 or zone_idx(duel, from_p, from_z) == 0:
		return -1
	if bool(zflags(duel, from_p, from_z).get("cannot_switch_control", false)):
		return -1
	var cid: int = zone_id(duel, from_p, from_z)
	var was_face = is_face_up(duel, from_p, from_z)
	var was_def = not is_atk_pos(duel, from_p, from_z)
	var tmp: int = duel.m.local(4)
	duel.m.set_u32(tmp, zone_entry(duel, from_p, from_z))
	if is_joey(duel):
		duel.f570790(from_p, from_z, 0)
		duel.f568610(to_p, to_z, tmp, 1 if was_def else 0, 1 if was_face else 0)
		_present(duel, "move", {
			"p": from_p,
			"card": cid,
			"from": (from_p & 1) | ((from_z & 0xf) << 1),
			"to": (to_p & 1) | ((to_z & 0xf) << 1) | ((1 if was_def else 0) << 14) | ((1 if was_face else 0) << 15),
			"reason": 0,
		})
		sync_visuals(duel)
	else:
		var origin = ((from_z & 0xff) << 8) | from_p
		var target = ((to_z & 0xff) << 8) | to_p
		duel.f54d570(to_p, origin, target)
	if temporary_until_ep:
		schedule_delayed(duel, turn_number(duel), PHASE_EP, to_p, 0, "return_control", {"from_p": to_p, "from_z": to_z, "orig_p": from_p})
	return to_z


static func swap_control(duel, z0: int, z1: int) -> bool:
	if zone_idx(duel, 0, z0) == 0 or zone_idx(duel, 1, z1) == 0:
		return false
	if bool(zflags(duel, 0, z0).get("cannot_switch_control", false)) or bool(zflags(duel, 1, z1).get("cannot_switch_control", false)):
		return false
	if is_joey(duel):
		var e0 = zone_entry(duel, 0, z0)
		var e1 = zone_entry(duel, 1, z1)
		var f0 = is_face_up(duel, 0, z0)
		var d0 = not is_atk_pos(duel, 0, z0)
		var f1 = is_face_up(duel, 1, z1)
		var d1 = not is_atk_pos(duel, 1, z1)
		var t0: int = duel.m.local(4)
		var t1: int = duel.m.local(4)
		duel.m.set_u32(t0, e0)
		duel.m.set_u32(t1, e1)
		duel.f570790(0, z0, 0)
		duel.f570790(1, z1, 0)
		duel.f568610(1, z1, t0, 1 if d0 else 0, 1 if f0 else 0)
		duel.f568610(0, z0, t1, 1 if d1 else 0, 1 if f1 else 0)
		_present(duel, "zone_swap", {"p": 0, "a": (z0 << 8) | 0, "b": (z1 << 8) | 1})
		sync_visuals(duel)
	else:
		duel.f54d6c0(0, (z0 << 8) | 0, (z1 << 8) | 1)
	return true


static func link_equip(duel, eq_p: int, eq_z: int, tgt_p: int, tgt_z: int) -> void:
	eq_p &= 1
	tgt_p &= 1
	var cid = zone_id(duel, eq_p, eq_z)
	state(duel)["equip_links"]["%d:%d" % [eq_p, eq_z]] = {"target_p": tgt_p, "target_z": tgt_z, "card_id": cid}
	if not is_joey(duel):
		var origin = ((eq_z & 0xff) << 8) | eq_p
		var target = ((tgt_z & 0xff) << 8) | tgt_p
		duel.f54e730(eq_p, origin, target)
	else:
		var zo = JoeyMem.zone(tgt_p, tgt_z)
		var n: int = duel.m.u16(zo + JoeyMem.Z_LINKS_N)
		if n < 32:
			duel.m.set_u16(zo + JoeyMem.Z_LINK_REF + n * 2, ((eq_z & 0xff) << 8) | eq_p)
			duel.m.set_u8(zo + JoeyMem.Z_LINK_KIND + n * 2, 1)
			duel.m.set_u16(zo + JoeyMem.Z_LINKS_N, n + 1)
		_present(duel, "cmd84", {"p": eq_p, "a": ((eq_z & 0xff) << 8) | eq_p, "b": ((tgt_z & 0xff) << 8) | tgt_p, "card": cid})
		sync_visuals(duel)


static func get_equip_target(duel, eq_p: int, eq_z: int) -> Dictionary:
	var k = "%d:%d" % [eq_p & 1, eq_z]
	var st = state(duel)
	if st["equip_links"].has(k):
		return st["equip_links"][k]
	if not is_joey(duel):
		var t: int = duel.f546020(eq_p & 1, eq_z)
		if (t & 0xffff) != 0xffff:
			return {"target_p": t & 0xff, "target_z": (t >> 8) & 0xff}
	return {}


# --- Heuristic Target & Pile Selectors ------------------------------------------------------------

## Metalsilver Armor (2924): zona del monstruo equipado con la carta que controla `p`, o -1.
static func metalsilver_target_zone(duel, p: int) -> int:
	var links: Dictionary = state(duel).get("equip_links", {})
	for ek in links.keys():
		var link: Dictionary = links[ek]
		if int(link.get("card_id", 0)) == 2924 and int(link.get("target_p", -1)) == (p & 1):
			return int(link.get("target_z", -1))
	return -1


static func choose_zone(duel, owner_p: int, filter: Callable, prefer_highest := true, target_opp := true) -> Dictionary:
	var sides: Array = [1 - (owner_p & 1), owner_p & 1] if target_opp else [owner_p & 1, 1 - (owner_p & 1)]
	var best_score = -999999
	var best = {}
	var tn := turn_number(duel)
	for pl in sides:
		for z in 11:
			var idx = zone_idx(duel, pl, z)
			if idx == 0:
				continue
			# Mayakashi Metamorphosis (2605): el monstruo elegido no puede ser objetivo ese turno.
			# Obelisk (2500) y Sphere Mode (2503): el rival no puede elegirlos como objetivo de efectos.
			var zf_t := zflags(duel, pl, z)
			if pl != (owner_p & 1) and (int(zf_t.get("untargetable_until_turn", -1)) >= tn or bool(zf_t.get("untargetable", false))):
				continue
			# Metalsilver Armor (2924): contra su controlador solo se puede elegir el monstruo equipado.
			if pl != (owner_p & 1) and z < 5:
				var armor_z := metalsilver_target_zone(duel, pl)
				if armor_z >= 0 and z != armor_z:
					continue
			if filter.call(duel, pl, z, idx):
				var score = 0
				if z < 5:
					score = eff_atk(duel, pl, z) + monster_level(duel, idx) * 10
				else:
					score = 2000 if is_face_up(duel, pl, z) else 1500
				if pl == (owner_p & 1) and target_opp:
					score -= 10000
				elif pl != (owner_p & 1) and not target_opp:
					score -= 10000
				if not prefer_highest:
					score = -score
				if score > best_score:
					best_score = score
					best = {"p": pl, "z": z, "idx": idx}
	# Elegir zona es la primitiva de "seleccionar objetivo": marca el efecto como dirigido.
	if not best.is_empty() and str(state(duel).get("effect_source", "")) != "":
		state(duel)["effect_targeted"] = true
	return best


## Pregunta Si/No al jugador local para un efecto opcional ("puedes"). Si se puede preguntar
## (duelo normal Yugi/Kaiba, turno del jugador 0, con ventana) devuelve true y `on_yes` se
## ejecuta SOLO si contesta Si (el motor queda en espera mientras el cuadro esta abierto).
## Si no se puede preguntar (CPU, LAN/online, repeticion, Joey o sin pantalla) devuelve false y
## quien llama debe aplicar el comportamiento automatico de siempre.
## Texto de la pregunta Si/No de un efecto opcional ("puedes") de una carta.
static func effect_prompt(duel, cid: int) -> String:
	var nm: String = card_name(duel, cid)
	if Assets.lang == "a":
		return "هل تريد تفعيل تأثير %s؟" % nm
	if Assets.lang == "s":
		return "¿Activar el efecto de %s?" % nm
	return "Activate the effect of %s?" % nm


## Cola de preguntas pendientes: la del motor Joey vive en el propio motor.
static func optional_queue(duel) -> Array:
	if is_joey(duel):
		return duel.custom_prompt_queue
	return state(duel).get_or_add("optional_prompts", [])


static func ask_optional(duel, p: int, text: String, on_yes: Callable, on_no := Callable()) -> bool:
	if is_joey(duel):
		var hook: Callable = duel.custom_prompt
		if hook.is_valid():
			return bool(hook.call(p & 1, text, on_yes, on_no))
		return false
	if not (duel is Duel):
		return false
	if (p & 1) != 0 or int(duel.game_mode) != DuelBase.GAME_NORMAL or int(duel.auto_answer) != -1:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	var st = state(duel)
	var queue: Array = st.get_or_add("optional_prompts", [])
	var busy: bool = not duel.dialog_open.is_empty() or not duel.list_open.is_empty()
	if busy:
		# Solo se encola detras de otra pregunta propia; con un dialogo del motor se actua solo.
		if duel.dialog_open.has("custom_yes") or duel.dialog_open.has("custom_done") or not queue.is_empty():
			queue.append({"text": text, "yes": on_yes, "no": on_no})
			return true
		return false
	_open_optional_prompt(duel, text, on_yes, on_no)
	return true


## Efecto "puedes" sin pila de eleccion: al jugador local se le pregunta Si/No; en los demas
## casos (CPU, online, repeticion, headless) se ejecuta solo, como antes.
static func optional_effect(duel, p: int, cid: int, body: Callable) -> void:
	if not ask_optional(duel, p, effect_prompt(duel, cid), body):
		body.call()


## Igual, con un texto propio.
static func optional_text(duel, p: int, text: String, body: Callable) -> void:
	if not ask_optional(duel, p, text, body):
		body.call()


## El jugador local elige UNA entre varias cartas (Si = esta, No = la siguiente; la ultima se toma
## sola). `tokens` es lo que recibe on_pick (indice de pila, zona...); `labels`, el texto de cada una.
## Devuelve false si no se puede preguntar (menos de 2 opciones, CPU, red, repeticion, Joey de demo
## o sin pantalla): quien llama aplica entonces la eleccion automatica de siempre.
static func ask_pick(duel, p: int, title: String, labels: Array, tokens: Array, on_pick: Callable, k := 0) -> bool:
	if labels.size() < 2 or labels.size() != tokens.size():
		return false
	var text: String = lang_text(
		"%s\n%s\nنعم = هذه البطاقة، لا = البطاقة التالية." % [title, str(labels[k])],
		"%s\n%s\nSí = esta carta, No = la siguiente." % [title, str(labels[k])],
		"%s\n%s\nYes = this card, No = the next one." % [title, str(labels[k])])
	var pick := func() -> void:
		on_pick.call(tokens[k])
	var nxt := func() -> void:
		if k + 2 >= labels.size():
			on_pick.call(tokens[labels.size() - 1])
		elif not ask_pick(duel, p, title, labels, tokens, on_pick, k + 1):
			on_pick.call(tokens[k + 1])
	return ask_optional(duel, p, text, pick, nxt)


## Igual que ask_pick sobre las cartas de la mano que cumplen el filtro.
static func ask_hand_pick(duel, p: int, title: String, filter: Callable, on_pick: Callable) -> bool:
	var idxs: Array[int] = matching_pile_indices(duel, p, LOC_HAND, filter)
	var labels: Array = []
	var tokens: Array = []
	for i in idxs:
		labels.append(card_name(duel, raw_id(duel, pile_idx(duel, p, LOC_HAND, i))))
		tokens.append(i)
	return ask_pick(duel, p, title, labels, tokens, on_pick)


## Texto en el idioma activo (arabe, espanol, ingles).
static func lang_text(ar: String, es: String, en: String) -> String:
	if Assets.lang == "a":
		return ar
	if Assets.lang == "s":
		return es
	return en


## "Activa 1 de estos efectos": se pregunta cada opcion en orden y solo vale la primera que se
## acepte. Sin jugador local se ejecuta la opcion auto_index.
static func optional_one_of(duel, p: int, texts: Array, bodies: Array, auto_index: int) -> void:
	var done: Array = [false]
	var first := true
	for i in texts.size():
		var body: Callable = bodies[i]
		var gated := func() -> void:
			if bool(done[0]):
				return
			done[0] = true
			# Quita de la cola las demas opciones del mismo grupo.
			var q: Array = optional_queue(duel)
			for k in range(q.size() - 1, -1, -1):
				if (q[k] as Dictionary).get("group", null) == done:
					q.remove_at(k)
			body.call()
		if not ask_optional(duel, p, str(texts[i]), gated):
			if first:
				(bodies[auto_index] as Callable).call()
			return
		if not first:
			var qq: Array = optional_queue(duel)
			if not qq.is_empty():
				(qq.back() as Dictionary)["group"] = done
		first = false


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


static func choose_pile_card(duel, p: int, loc: int, filter: Callable, prefer_highest := true) -> int:
	p &= 1
	var n = pile_count(duel, p, loc)
	var best_i = -1
	var best_score = -999999
	for i in n:
		var idx = pile_idx(duel, p, loc, i)
		if idx == 0:
			continue
		if filter.call(duel, idx, i):
			var s = base_atk(duel, idx) + monster_level(duel, idx) * 50 + (500 if is_spell(duel, idx) else 300)
			if not prefer_highest:
				s = -s
			if s > best_score:
				best_score = s
				best_i = i
	return best_i


## Borra la marca de "ya ataco" del motor para (p, z). Con ella el monstruo puede volver a
## atacar este turno (Gray Wing, Cyber Twin Dragon y demas cartas de dos ataques).
static func clear_attacked(duel, p: int, z: int) -> void:
	if z < 0 or z >= 5:
		return
	var m = duel.m
	var bit: int = 1 << (z & 31)
	if is_joey(duel):
		var at := JoeyMem.pl(p & 1) + 0x10
		m.set_u16(at, (m.u16(at) & ~bit) & 0xffff)
	else:
		var at2 := DuelMem.pl(p & 1) - 2
		m.set_u16(at2, (m.u16(at2) & ~bit) & 0xffff)


static func matching_pile_indices(duel, p: int, loc: int, filter: Callable) -> Array[int]:
	var out: Array[int] = []
	for i in pile_count(duel, p, loc):
		var idx = pile_idx(duel, p, loc, i)
		if idx != 0 and filter.call(duel, idx, i):
			out.append(i)
	return out


static func collect_matching_zones(duel, filter: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pl in 2:
		for z in 11:
			var idx = zone_idx(duel, pl, z)
			if idx != 0 and filter.call(duel, pl, z, idx):
				out.append({"p": pl, "z": z, "idx": idx})
	return out


# --- Shared Helpers for Custom Effects ----------------------------------------------------------

static func is_skill_drain_active(duel) -> bool:
	return has_faceup_id(duel, 0, 2644) or has_faceup_id(duel, 1, 2644)


## Timidity (2834): hasta el proximo End Phase del rival nadie puede destruir Magias/Trampas
## boca abajo. Lo consulta destroy_zone.
static func set_timidity(duel) -> void:
	var until := turn_number(duel) + 1
	pflags(duel, 0)["timidity_until_turn"] = until
	pflags(duel, 1)["timidity_until_turn"] = until


## Dark Ruler Ha Des (2744): niega los efectos de los monstruos destruidos en batalla con
## monstruos Demonio que controles. El monstruo destruido ya esta en el cementerio cuando se
## disparan sus efectos, asi que se consulta aqui, no en la zona.
static func ha_des_negates(duel, owner_p: int, cid: int) -> bool:
	var opp := 1 - (owner_p & 1)
	if not has_faceup_id(duel, opp, 2744) or is_skill_drain_active(duel):
		return false
	for z in 5:
		var idx = zone_idx(duel, opp, z)
		if idx != 0 and is_face_up(duel, opp, z) and monster_race(duel, idx) == 3:
			return true
	return false


static func is_necrovalley_active(duel) -> bool:
	return has_faceup_id(duel, 0, 2846) or has_faceup_id(duel, 1, 2846)


static func is_umi_active(duel) -> bool:
	return (
		has_faceup_id(duel, 0, 2697) or has_faceup_id(duel, 1, 2697)
		or has_faceup_id(duel, 0, NATIVE_UMI) or has_faceup_id(duel, 1, NATIVE_UMI)
		or (has_faceup_id(duel, 0, 2816) or has_faceup_id(duel, 1, 2816))
	)


static func has_toon_world(duel, p := -1) -> bool:
	if p >= 0:
		return has_faceup_id(duel, p & 1, NATIVE_TOON_WORLD)
	return has_faceup_id(duel, 0, NATIVE_TOON_WORLD) or has_faceup_id(duel, 1, NATIVE_TOON_WORLD)


static func is_divine_beast(duel, idx: int) -> bool:
	var cid = raw_id(duel, idx)
	return ctype(duel, idx) == 0x18 or cid in EGYPTIAN_GOD_IDS or cid in [2503, 2504, 2505, 2664]


static func total_field_cards(duel, p: int) -> int:
	return count_monsters(duel, p, false) + count_st(duel, p, true)


static func count_total_monsters_on_field(duel) -> int:
	return count_monsters(duel, 0, false) + count_monsters(duel, 1, false)


static func find_zone_of_id(duel, p: int, cid: int, face_up_only := true) -> int:
	for z in 11:
		if zone_idx(duel, p, z) != 0 and (not face_up_only or is_face_up(duel, p, z)) and zone_id(duel, p, z) == cid:
			return z
	return -1


static func find_pile_index_by_id(duel, p: int, loc: int, cid: int) -> int:
	for i in pile_count(duel, p, loc):
		if raw_id(duel, pile_idx(duel, p, loc, i)) == cid:
			return i
	return -1


static func pay_half_lp(duel, p: int) -> int:
	var lp = get_lp(duel, p)
	var cost := int(lp / 2)
	if is_joey(duel):
		if cost > 0:
			duel.f5784e0(p & 1, mini(cost, 0xffff))
	else:
		set_lp(duel, p, lp - cost)
		if duel.has_method("present"):
			duel.present("lp_total", {"p": p & 1, "from": lp, "to": lp - cost, "amount": -cost, "native_silent": false})
	record_lp_paid(duel, p, cost)
	return cost


static func record_lp_paid(duel, p: int, amount: int) -> void:
	if amount <= 0:
		return
	var pf = pflags(duel, p)
	var t = turn_number(duel)
	if int(pf.get("lp_paid_turn_id", -1)) != t:
		pf["lp_paid_last_turn"] = int(pf.get("lp_paid_this_turn", 0))
		pf["lp_paid_this_turn"] = 0
		pf["lp_paid_turn_id"] = t
	pf["lp_paid_this_turn"] = int(pf.get("lp_paid_this_turn", 0)) + amount


static func roll_raw_die(duel) -> int:
	if duel.rng != null:
		return (duel.rng.rand() % 6) + 1
	return (randi() % 6) + 1


static func total_spell_counters(duel, p := -1) -> int:
	var st = state(duel)
	var total = 0
	for k in st["counters"].keys():
		var parts := str(k).split(":")
		if parts.size() >= 3 and parts[2] == "spell":
			if p < 0 or int(parts[0]) == (p & 1):
				total += int(st["counters"][k])
	return total


static func remove_spell_counters(duel, p: int, need: int) -> bool:
	if total_spell_counters(duel, p) < need:
		return false
	var st = state(duel)
	var rem = need
	for k in st["counters"].keys():
		if rem <= 0:
			break
		var parts := str(k).split(":")
		if parts.size() >= 3 and parts[2] == "spell" and (p < 0 or int(parts[0]) == (p & 1)):
			var cur := int(st["counters"][k])
			if cur <= 0:
				continue
			var take = mini(cur, rem)
			st["counters"][k] = cur - take
			rem -= take
			var owner_p := int(parts[0])
			var tz := int(parts[1])
			if tz >= 5 and zone_id(duel, owner_p, tz) == 2927 and st["counters"][k] == 0:
				destroy_zone(duel, owner_p, tz)
	return rem == 0


static func equip_count_on_monster(duel, p: int, z: int) -> int:
	var st = state(duel)
	var n = 0
	for ek in st["equip_links"].keys():
		var link: Dictionary = st["equip_links"][ek]
		if int(link.get("target_p", -1)) == (p & 1) and int(link.get("target_z", -1)) == z:
			n += 1
	if not is_joey(duel):
		var zn = DuelMem.zone(p & 1, z)
		n = maxi(n, duel.m.u16(zn + 0x88))
	else:
		var zo = JoeyMem.zone(p & 1, z)
		n = maxi(n, duel.m.u16(zo + JoeyMem.Z_LINKS_N))
	return n


static func discard_matching_hand(duel, p: int, filter: Callable) -> int:
	var i = choose_pile_card(duel, p, LOC_HAND, filter, false)
	if i < 0:
		return 0
	return discard_hand_slot(duel, p, i, 1)


static func negate_chain_entry(duel, target_entry_idx: int, destroy_card := true) -> void:
	if is_joey(duel):
		if target_entry_idx < 0:
			return
		var j_entry: int = target_entry_idx if target_entry_idx >= 0xa55b40 else (0xa55b40 + target_entry_idx * 20)
		duel.m.set_u16(j_entry + 4, duel.m.u16(j_entry + 4) | 4)
		if destroy_card:
			var j_ref: int = duel.m.u16(j_entry + 2)
			var j_tp: int = ((j_ref >> 14) & 1) ^ (j_ref & 1)
			var j_tz: int = (j_ref >> 1) & 31
			if j_tz <= 10:
				destroy_zone(duel, j_tp, j_tz)
		return
	if target_entry_idx < 0:
		return
	var entry: int = target_entry_idx if target_entry_idx >= 0xa15e80 else (0xa15e80 + target_entry_idx * 0x14)
	duel.m.set_u8(entry + 4, duel.m.u8(entry + 4) | (0x0c if destroy_card else 0x04))
	if destroy_card:
		var flags: int = duel.m.u16(entry + 2)
		var tp = flags & 1
		var tloc = (flags >> 4) & 0x3f
		if tloc <= 10:
			destroy_zone(duel, tp, tloc)
