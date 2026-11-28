class_name CustomEffectsMonsters2
extends RefCounted
## Faithful implementations for all 162 custom Monster cards with internal_id >= 2800 (2800..3129)
## across both Core (Duel / DuelMem) and Joey (JoeyEngine / JoeyMem).

const IDS: Array[int] = [
	2800, 2803, 2805, 2811, 2812, 2813, 2814, 2816, 2817, 2818,
	2819, 2820, 2822, 2823, 2826, 2833, 2835, 2836, 2839, 2840,
	2841, 2842, 2843, 2844, 2847, 2848, 2849, 2850, 2854, 2855,
	2857, 2861, 2864, 2865, 2866, 2870, 2874, 2876, 2877, 2878,
	2881, 2882, 2883, 2884, 2885, 2886, 2889, 2890, 2891, 2894,
	2895, 2898, 2899, 2900, 2903, 2905, 2906, 2907, 2908, 2911,
	2914, 2915, 2922, 2923, 2925, 2931, 2933, 2935, 2936, 2937,
	2938, 2939, 2940, 2941, 2942, 2945, 2947, 2959, 2960, 2962,
	2965, 2966, 2967, 2968, 2969, 2970, 2974, 2975, 2981, 2983,
	2986, 2987, 2989, 2990, 2991, 2992, 2993, 2994, 2995, 2996,
	2997, 3000, 3001, 3002, 3019, 3020, 3021, 3022, 3023, 3025,
	3026, 3027, 3028, 3030, 3032, 3034, 3036, 3038, 3039, 3046,
	3048, 3049, 3056, 3057, 3058, 3059, 3060, 3061, 3062, 3063,
	3064, 3065, 3066, 3069, 3070, 3071, 3074, 3084, 3085, 3086,
	3087, 3088, 3089, 3090, 3092, 3093, 3097, 3098, 3100, 3109,
	3113, 3115, 3116, 3121, 3122, 3123, 3124, 3125, 3126, 3127,
	3128, 3129, 3133, 3136, 3138, 3139, 3140, 3141, 3142,
]

const FLIP_DOWN_CYCLE_IDS := [2811, 2812, 2814, 2833, 2835, 2839, 2841, 2864, 2874, 3089]
const UNION_PAIR_IDS := {
	2914: [2937],        # Des Dendle -> Vampiric Orchis
	2915: [2969],        # Second Goblin -> Giant Orc
	2939: [2910],        # Pitch-Dark Dragon -> Dark Blade
	2941: [2905],        # Zombie Tiger -> Decayed Commander
	2947: [2975],        # Burning Beast -> Freezing Beast
	2959: [2943],        # Koitsu -> Aitsu
	2974: [2910],        # Kiryu -> Dark Blade
	2975: [2947],        # Freezing Beast -> Burning Beast
	2989: [],            # Metallizing Parasite - Lunatite -> any face-up monster you control
}
const ARCHFIEND_UPKEEP := {
	2990: 500, # Infernalqueen Archfiend
	2992: 900, # Shadowknight Archfiend
	3022: 500, # Darkbishop Archfiend
	3023: 800, # Terrorking Archfiend
	3048: 500, # Skull Archfiend of Lightning
	3057: 500, # Desrook Archfiend
	3058: 500, # Vilepawn Archfiend
}
const GUARDIAN_EQUIP_REQ := {
	2993: 3081, # Guardian Kay'est <- Rod of Silence - Kay'est
	2995: 3082, # Guardian Ceal <- Shooting Star Bow - Ceal
	3026: 3008, # Guardian Tryce <- Twin Swords of Flashing Light - Tryce
	3028: 3016, # Guardian Grarl <- Gravity Axe - Grarl
	3060: 3052, # Guardian Baou <- Wicked-Breaking Flamberge - Baou
	3062: 3054, # Guardian Elma <- Butterfly Dagger - Elma
}


static func handles(cid: int) -> bool:
	return cid in IDS


## Black Metal Dragon / Red-Eyes Baby Dragon: equip the card in `loc`/`slot` (hand, GY or its own
## Monster Zone) to the Monster Zone `tz` as an equipped monster, the way Union monsters do.
static func _equip_monster_to(duel, p: int, loc: int, slot: int, tz: int) -> bool:
	var eq_z: int = CustomDuelOps.free_st_zone(duel, p)
	if eq_z < 0 or tz < 0:
		return false
	if loc == CustomDuelOps.LOC_FIELD_MONSTER:
		var tmp: int = duel.m.local(4)
		duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, slot))
		if CustomDuelOps.is_joey(duel):
			duel.f570790(p, slot, 0)
			duel.f5686e0(p, eq_z, tmp, 1)
		else:
			duel.f542c40(p, slot)
			duel.f5423a0(p, eq_z - 5, tmp, 1)
	else:
		eq_z = CustomDuelOps.set_st_from_pile(duel, p, loc, slot, p, true)
		if eq_z < 5:
			return false
	CustomDuelOps.link_equip(duel, p, eq_z, p, tz)
	CustomDuelOps.zflags(duel, p, eq_z)["union_equipped"] = true
	return true


## Black Metal Dragon: the face-up "Red-Eyes" monster it can be equipped to (other than itself).
static func _bmd_target(duel, p: int, self_z: int) -> int:
	var pick: Dictionary = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and zz != self_z and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.name_matches(d, idx, "red-eyes"), true, false)
	if pick.is_empty():
		return -1
	return int(pick["z"])


## The Black Stone of Legend: a Level 7 or lower "Red-Eyes" monster (except "Red-Eyes B. Chick").
static func _stone_pred() -> Callable:
	return func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes") and CustomDuelOps.monster_level(d, idx) <= 7 and CustomDuelOps.raw_id(d, idx) != 3136


## Red-Eyes Black Meteor Dragon: a Level 5 or higher Normal Monster in the hand or Deck, as (location, index).
static func _meteor_cost(duel, p: int) -> Vector2i:
	var pred := func(d, idx, _i): return CustomDuelOps.is_normal_monster(d, idx) and CustomDuelOps.monster_level(d, idx) >= 5
	var hi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, pred, false)
	if hi >= 0:
		return Vector2i(CustomDuelOps.LOC_HAND, hi)
	var di: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, pred, false)
	if di >= 0:
		return Vector2i(CustomDuelOps.LOC_DECK, di)
	return Vector2i(-1, -1)


## Red-Eyes Alternative Black Dragon: the "Red-Eyes" card to Tribute, as (location, zone or hand
## index). The field is preferred, then the hand (never the card being summoned). (-1, -1) if none.
static func _alt_black_tribute(duel, p: int, self_slot: int) -> Vector2i:
	var pick: Dictionary = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.name_matches(d, idx, "red-eyes"), false, false)
	if not pick.is_empty():
		return Vector2i(CustomDuelOps.LOC_FIELD_MONSTER, int(pick["z"]))
	var hi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, i): return i != self_slot and CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes"), false)
	if hi >= 0:
		return Vector2i(CustomDuelOps.LOC_HAND, hi)
	return Vector2i(-1, -1)


## Monstruos Red-Eyes que se pueden ofrendar: campo (boca arriba) y mano, sin la propia carta.
static func _alt_black_candidates(duel, p: int, self_slot: int) -> Array:
	var out: Array = []
	for z in 5:
		var idx: int = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.name_matches(duel, idx, "red-eyes"):
			out.append(Vector2i(CustomDuelOps.LOC_FIELD_MONSTER, z))
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
		var hidx: int = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)
		if i != self_slot and hidx != 0 and CustomDuelOps.is_monster(duel, hidx) and CustomDuelOps.name_matches(duel, hidx, "red-eyes"):
			out.append(Vector2i(CustomDuelOps.LOC_HAND, i))
	return out


static func _alt_black_ask(duel, p: int, cid: int, loc: int, slot: int, cands: Array, k: int) -> bool:
	var c: Vector2i = cands[k]
	var cidx: int = CustomDuelOps.zone_idx(duel, p, c.y) if c.x == CustomDuelOps.LOC_FIELD_MONSTER else CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, c.y)
	var nm: String = CustomDuelOps.card_name(duel, CustomDuelOps.raw_id(duel, cidx))
	var where_ar: String = "من الملعب" if c.x == CustomDuelOps.LOC_FIELD_MONSTER else "من اليد"
	var where_es: String = "del campo" if c.x == CustomDuelOps.LOC_FIELD_MONSTER else "de la mano"
	var where_en: String = "from the field" if c.x == CustomDuelOps.LOC_FIELD_MONSTER else "from your hand"
	var text: String = CustomDuelOps.lang_text(
		"ضحِّ بـ %s (%s) للاستدعاء الخاص؟\nنعم = هذه البطاقة، لا = البطاقة التالية." % [nm, where_ar],
		"¿Ofrendar a %s (%s) para la Invocación Especial?\nSí = esta carta, No = la siguiente." % [nm, where_es],
		"Tribute %s (%s) for the Special Summon?\nYes = this card, No = the next candidate." % [nm, where_en])
	var pick := func() -> void:
		_alt_black_finish(duel, p, cid, loc, slot, c)
	var nxt := func() -> void:
		if k + 2 >= cands.size():
			_alt_black_finish(duel, p, cid, loc, slot, cands[cands.size() - 1])
		elif not _alt_black_ask(duel, p, cid, loc, slot, cands, k + 1):
			_alt_black_finish(duel, p, cid, loc, slot, cands[k + 1])
	return CustomDuelOps.ask_optional(duel, p, text, pick, nxt)


static func _alt_black_finish(duel, p: int, cid: int, loc: int, slot: int, alt_tr: Vector2i) -> int:
	if alt_tr.x < 0 or not can_special_summon(duel, p, cid, loc, slot):
		return -1
	CustomDuelOps.mark_hopt(duel, p, 3133)
	var alt_slot: int = slot
	if alt_tr.x == CustomDuelOps.LOC_FIELD_MONSTER:
		CustomDuelOps.tribute_zone(duel, p, alt_tr.y)
	else:
		CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, alt_tr.y, p, CustomDuelOps.LOC_GRAVE)
		if alt_tr.y < slot:
			alt_slot -= 1
	var alt_z: int = CustomDuelOps.special_summon_from_pile(duel, p, loc, alt_slot, p, true, false)
	if alt_z >= 0:
		on_summon_or_flip(duel, p, alt_z, cid, "special")
	return alt_z


static func is_spirit(_cid: int) -> bool:
	return false


static func can_normal_summon(duel, p: int, cid: int, is_set := false) -> bool:
	p &= 1
	if cid in [2833, 3034, 3070, 3133]:
		return false
	if cid == 2885 and not is_set: # Dark Dust Spirit cannot be SS, can NS
		return true
	if cid == 3023 and not is_set: # Terrorking Archfiend requires Archfiend on field
		return _has_archfiend_on_field(duel, p)
	if GUARDIAN_EQUIP_REQ.has(cid):
		var eq_id := int(GUARDIAN_EQUIP_REQ[cid])
		return CustomDuelOps.has_faceup_id(duel, p, eq_id)
	return true


static func can_special_summon(duel, p: int, cid: int, loc: int, _slot: int) -> bool:
	p &= 1
	if cid == 2885:
		return false
	if CustomDuelOps.free_monster_zone(duel, p) < 0 and cid != 2833 and cid != 3133:
		return false
	if GUARDIAN_EQUIP_REQ.has(cid):
		var eq_id := int(GUARDIAN_EQUIP_REQ[cid])
		if not CustomDuelOps.has_faceup_id(duel, p, eq_id):
			return false
	match cid:
		3133: # Red-Eyes Alternative Black Dragon: Tribute 1 "Red-Eyes" from hand or field
			if loc != CustomDuelOps.LOC_HAND or not CustomDuelOps.can_hopt(duel, p, 3133):
				return false
			var alt_cost: Vector2i = _alt_black_tribute(duel, p, _slot)
			if alt_cost.x < 0:
				return false
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 or alt_cost.x == CustomDuelOps.LOC_FIELD_MONSTER
		2833: # Fushioh Richie: Tribute Great Dezard w/ 2 kills
			if loc != CustomDuelOps.LOC_HAND and loc != CustomDuelOps.LOC_DECK:
				return false
			var dz = CustomDuelOps.find_zone_of_id(duel, p, 2884, true)
			return dz >= 0 and int(CustomDuelOps.zflags(duel, p, dz).get("dezard_kills", 0)) >= 2
		3028: # Guardian Grarl: only card in hand
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 1
		3085: # Fenrir: banish 2 WATER monsters from GY
			return loc == CustomDuelOps.LOC_HAND and _collect_attr_indices_in_gy(duel, p, 3).size() >= 2
	return false


static func special_summon(duel, p: int, cid: int, loc: int, slot: int) -> int:
	p &= 1
	if not can_special_summon(duel, p, cid, loc, slot):
		return -1
	match cid:
		3133:
			# El coste es "1 monstruo Red-Eyes de tu mano o campo": con mas de uno el jugador local
			# elige cual (Si = este, No = el siguiente). Sin jugador local se elige solo, como antes.
			var cands: Array = _alt_black_candidates(duel, p, slot)
			if cands.size() > 1 and _alt_black_ask(duel, p, cid, loc, slot, cands, 0):
				return -1
			return _alt_black_finish(duel, p, cid, loc, slot, _alt_black_tribute(duel, p, slot))
		2833:
			var dz = CustomDuelOps.find_zone_of_id(duel, p, 2884, true)
			CustomDuelOps.tribute_zone(duel, p, dz)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		3028:
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		3085:
			var wis = _collect_attr_indices_in_gy(duel, p, 3)
			wis.sort()
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, wis[wis.size() - 1])
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, wis[wis.size() - 2])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
	return -1


static func can_activate(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	var ev := str(ctx.get("event", "free"))
	if z >= 0 and z < 5 and loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.is_skill_drain_active(duel) and CustomDuelOps.is_face_up(duel, p, z):
		return false
	if z >= 0 and z < 5 and bool(CustomDuelOps.zflags(duel, p, z).get("negated", false)):
		return false
	# Goblin of Greed blocks discard-cost activation
	if cid == 2925 and _has_goblin_of_greed(duel):
		return false
	if cid == 2974 and loc == CustomDuelOps.LOC_FIELD_ST: # Kiryu: only while it is equipped to a monster
		return CustomDuelOps.can_opt(duel, p, cid, z) and CustomDuelOps.union_host_zone(duel, p, z) >= 0
	if cid in FLIP_DOWN_CYCLE_IDS and loc == CustomDuelOps.LOC_FIELD_MONSTER:
		if not CustomDuelOps.can_opt(duel, p, cid, z):
			return false
		if cid == 2833 and int(CustomDuelOps.zflags(duel, p, z).get("lock_pos_until_turn", -1)) >= t:
			return false
		return CustomDuelOps.is_face_up(duel, p, z)
	if UNION_PAIR_PAIR_MATCH(cid):
		if loc == CustomDuelOps.LOC_FIELD_MONSTER:
			return CustomDuelOps.can_opt(duel, p, cid, z) and CustomDuelOps.free_st_zone(duel, p) >= 0 and _find_union_host(duel, p, z, cid) >= 0
		if loc == CustomDuelOps.LOC_FIELD_ST:
			return CustomDuelOps.can_opt(duel, p, cid, z) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and not bool(CustomDuelOps.zflags(duel, p, z).get("union_stolen", false))
		return false
	match cid:
		3140: # Black Metal Dragon: equip itself from the hand or field to a Red-Eyes monster
			if loc != CustomDuelOps.LOC_HAND and loc != CustomDuelOps.LOC_FIELD_MONSTER:
				return false
			if loc == CustomDuelOps.LOC_FIELD_MONSTER and not CustomDuelOps.is_face_up(duel, p, z):
				return false
			return CustomDuelOps.free_st_zone(duel, p) >= 0 and _bmd_target(duel, p, z if loc == CustomDuelOps.LOC_FIELD_MONSTER else -1) >= 0
		3136: # Black Dragon's Chick: send itself to the GY; SS "Red-Eyes B. Dragon" from the hand
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.is_face_up(duel, p, z) and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.NATIVE_RED_EYES) >= 0
		3138: # The Black Stone of Legend: Tribute -> SS from the Deck, or from the GY -> add to hand
			if not CustomDuelOps.can_hopt(duel, p, 3138):
				return false
			if loc == CustomDuelOps.LOC_FIELD_MONSTER:
				return CustomDuelOps.is_face_up(duel, p, z) and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, _stone_pred()) >= 0
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, i): return _stone_pred().call(d, idx, i) and CustomDuelOps.raw_id(d, idx) != 3138) >= 0
			return false
		3139: # Red-Eyes Black Meteor Dragon: hand SS by sending a Normal Monster; GY banish -> add Red-Eyes Fusion
			if loc == CustomDuelOps.LOC_HAND:
				return CustomDuelOps.can_hopt(duel, p, 3139) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _meteor_cost(duel, p) != Vector2i(-1, -1)
			if loc == CustomDuelOps.LOC_GRAVE:
				if not CustomDuelOps.can_hopt(duel, p, 13139) or CustomDuelOps.is_necrovalley_active(duel):
					return false
				if 3139 in (CustomDuelOps.state(duel)["sent_gy_this_turn"][p] as Array):
					return false
				var mp: int = CustomDuelOps.phase(duel)
				if CustomDuelOps.turn_player(duel) != p or (mp != CustomDuelOps.PHASE_M1 and mp != CustomDuelOps.PHASE_M2):
					return false
				return CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 3143) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 3143) >= 0
			return false
		2823: # Gravekeeper's Watcher (hand negate opp discard effect)
			return ev == "chain_negate" and loc == CustomDuelOps.LOC_HAND and bool(ctx.get("opp_discards", false)) and int(ctx.get("chain_p", -1)) == opp
		2847: # Charm of Shabti (hand Quick -> Gravekeepers battle indest until EP)
			return loc == CustomDuelOps.LOC_HAND and _has_archetype_on_field(duel, p, CustomDuelOps.GRAVEKEEPER_IDS)
		2884: # Great Dezard w/ 2 kills -> Tribute to SS Fushioh Richie
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and int(CustomDuelOps.zflags(duel, p, z).get("dezard_kills", 0)) >= 2 and (CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2833) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2833) >= 0)
		2891: # Gravekeeper's Cannonholder: Tribute 1 other GK -> 700 dmg
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and _collect_monster_zones(duel, p, func(d, _pl, zz, idx): return zz != z and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.GRAVEKEEPER_IDS).size() >= 1
		2899: # Magical Marionette: remove 2 Spell Counters -> destroy 1 monster
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.get_counter(duel, p, z, "spell") >= 2 and CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2911: # Union Rider: steal opp Union monster & equip
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.free_st_zone(duel, p) >= 0 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == opp and zz < 5 and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.UNION_IDS, true, true).is_empty()
		2915: # Second Goblin equipped to Giant Orc -> change equipped battle pos once per turn
			return false
		2925: # Tribe-Infecting Virus: discard 1 -> destroy all of declared Type
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2935: # Roulette Barrel
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2935, z)
		2936, 2970: # Skilled White / Dark Magician: Tribute w/ 3 Spell Counters -> SS Buster Blader / DM
			if loc != CustomDuelOps.LOC_FIELD_MONSTER or CustomDuelOps.get_counter(duel, p, z, "spell") < 3:
				return false
			var targets = [CustomDuelOps.NATIVE_BUSTER_BLADER] if cid == 2936 else CustomDuelOps.NATIVE_DARK_MAGICIAN
			return _find_any_in_piles(duel, p, [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE], targets) >= 0
		2962: # Royal Magical Library: remove 3 Spell Counters -> draw 1
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.get_counter(duel, p, z, "spell") >= 3 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0
		2965: # Chaos Command Magician (chain target negate)
			return ev == "chain_negate" and bool(ctx.get("is_monster", false)) and bool(ctx.get("targets_single_monster", false))
		2966: # Paladin of White Dragon: Tribute -> SS BEWD from hand or Deck
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and _find_any_in_piles(duel, p, [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK], CustomDuelOps.NATIVE_BLUE_EYES) >= 0
		2995: # Guardian Ceal: send 1 Equip equipped to it -> destroy 1 opp monster
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.equip_count_on_monster(duel, p, z) > 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2997: # Sasuke Samurai #2: pay 800 LP -> S/T cannot be activated until EP
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2997, z) and CustomDuelOps.can_pay_lp(duel, p, 800)
		3046: # Legendary Flame Lord: remove 3 Spell Counters -> destroy all other monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.get_counter(duel, p, z, "spell") >= 3 and CustomDuelOps.count_total_monsters_on_field(duel) > 1
		3084: # Dark Master - Zorc: roll die destroy monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 3084, z)
		3100: # Freed the Brave Wanderer: banish 2 LIGHT from GY -> destroy monster w/ higher ATK
			var my_atk = CustomDuelOps.eff_atk(duel, p, z)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 3100, z) and _collect_attr_indices_in_gy(duel, p, 1).size() >= 2 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_atk(d, pl, zz) > my_atk, true, true).is_empty()
		3122: # Levia-Dragon - Daedalus: send face-up Umi -> destroy all other cards
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and (CustomDuelOps.has_faceup_id(duel, p, CustomDuelOps.NATIVE_UMI) or CustomDuelOps.has_faceup_id(duel, p, 2697))
	return false


static func resolve(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	if cid == 2974 and loc == CustomDuelOps.LOC_FIELD_ST: # Kiryu: Tribute itself so the equipped monster can attack directly
		var khost := CustomDuelOps.union_host_zone(duel, p, z)
		if khost >= 0 and CustomDuelOps.can_opt(duel, p, cid, z):
			CustomDuelOps.mark_opt(duel, p, cid, z)
			CustomDuelOps.zflags(duel, p, khost)["direct_atk_turn"] = t
			CustomDuelOps.send_zone_to_gy(duel, p, z)
		return
	if cid in FLIP_DOWN_CYCLE_IDS and loc == CustomDuelOps.LOC_FIELD_MONSTER:
		CustomDuelOps.mark_opt(duel, p, cid, z)
		CustomDuelOps.change_position(duel, p, z, 1, 0)
		if cid == 2841: # Wandering Mummy: shuffle face-down monsters
			pass
		return
	if UNION_PAIR_PAIR_MATCH(cid):
		CustomDuelOps.mark_opt(duel, p, cid, z)
		if loc == CustomDuelOps.LOC_FIELD_MONSTER:
			var tz = _find_union_host(duel, p, z, cid)
			var eq_z = CustomDuelOps.free_st_zone(duel, p)
			if tz >= 0 and eq_z >= 0:
				var tmp: int = duel.m.local(4)
				duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, z))
				if CustomDuelOps.is_joey(duel):
					duel.f570790(p, z, 0)
					duel.f5686e0(p, eq_z, tmp, 1)
				else:
					duel.f542c40(p, z)
					duel.f5423a0(p, eq_z - 5, tmp, 1)
				CustomDuelOps.link_equip(duel, p, eq_z, p, tz)
				CustomDuelOps.zflags(duel, p, eq_z)["union_equipped"] = true
		elif loc == CustomDuelOps.LOC_FIELD_ST:
			var mz = CustomDuelOps.free_monster_zone(duel, p)
			if mz >= 0:
				var tmp: int = duel.m.local(4)
				duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, z))
				if CustomDuelOps.is_joey(duel):
					duel.f570790(p, z, 0)
					duel.f568610(p, mz, tmp, 0, 1)
				else:
					duel.f542c40(p, z)
					duel.f5422b0(p, mz, tmp, 0, 1)
					duel.m.set_u8(DuelMem.zone(p, mz) + 6, duel.m.u8(DuelMem.zone(p, mz) + 6) | 2)
		return
	match cid:
		3140: # Black Metal Dragon
			var bmd_self: int = z if loc == CustomDuelOps.LOC_FIELD_MONSTER else CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 3140)
			var bmd_t: int = _bmd_target(duel, p, z if loc == CustomDuelOps.LOC_FIELD_MONSTER else -1)
			if bmd_self >= 0 and bmd_t >= 0:
				_equip_monster_to(duel, p, loc, bmd_self, bmd_t)
		3136: # Black Dragon's Chick
			CustomDuelOps.send_zone_to_gy(duel, p, z)
			var ch_i: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.NATIVE_RED_EYES)
			if ch_i >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, ch_i, p, true, false)
		3138: # The Black Stone of Legend
			CustomDuelOps.mark_hopt(duel, p, 3138)
			if loc == CustomDuelOps.LOC_FIELD_MONSTER:
				CustomDuelOps.tribute_zone(duel, p, z)
				var bs_i: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, _stone_pred())
				if bs_i >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, bs_i, p, true, false)
					CustomDuelOps.shuffle_deck(duel, p)
			else:
				var bs_g: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, i): return _stone_pred().call(d, idx, i) and CustomDuelOps.raw_id(d, idx) != 3138)
				if bs_g >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, bs_g, p, CustomDuelOps.LOC_DECK)
					CustomDuelOps.shuffle_deck(duel, p)
					var bs_s: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 3138)
					if bs_s >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, bs_s)
		3139: # Red-Eyes Black Meteor Dragon
			if loc == CustomDuelOps.LOC_HAND:
				CustomDuelOps.mark_hopt(duel, p, 3139)
				var mt_cost: Vector2i = _meteor_cost(duel, p)
				if mt_cost != Vector2i(-1, -1):
					if mt_cost.x == CustomDuelOps.LOC_HAND:
						CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, mt_cost.y, p, CustomDuelOps.LOC_GRAVE)
					else:
						CustomDuelOps.send_from_deck_to_gy(duel, p, mt_cost.y)
					var mt_h: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 3139)
					if mt_h >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, mt_h, p, true, false)
			else:
				CustomDuelOps.mark_hopt(duel, p, 13139)
				var mt_g: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 3139)
				if mt_g >= 0:
					CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, mt_g)
				for mt_loc in [CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
					var mt_f: int = CustomDuelOps.find_pile_index_by_id(duel, p, mt_loc, 3143)
					if mt_f >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, mt_loc, mt_f)
						break
		2823: # Gravekeeper's Watcher
			var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2823)
			if hi >= 0:
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, hi, p, CustomDuelOps.LOC_GRAVE)
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_entry", -1)), true)
		2847: # Charm of Shabti
			var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2847)
			if hi >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.GRAVEKEEPER_IDS:
						CustomDuelOps.zflags(duel, p, zz)["indest_battle"] = CustomDuelOps.turn_number(duel)
		2884: # Great Dezard -> Tribute -> SS Fushioh Richie
			CustomDuelOps.tribute_zone(duel, p, z)
			for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK]:
				var fi = CustomDuelOps.find_pile_index_by_id(duel, p, srcloc, 2833)
				if fi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, srcloc, fi, p, true, false)
					break
		2891: # Gravekeeper's Cannonholder
			var gkz = _collect_monster_zones(duel, p, func(d, _pl, zz, idx): return zz != z and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.GRAVEKEEPER_IDS)
			if not gkz.is_empty():
				CustomDuelOps.tribute_zone(duel, p, gkz[0])
				CustomDuelOps.damage(duel, opp, 700, false)
		2899: # Magical Marionette
			if CustomDuelOps.get_counter(duel, p, z, "spell") >= 2:
				CustomDuelOps.add_counter(duel, p, z, "spell", -2)
				var pick_run471 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true, pick_run471)
		2911: # Union Rider
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == opp and zz < 5 and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.UNION_IDS, true, true)
			var eq_z = CustomDuelOps.free_st_zone(duel, p)
			if not pick.is_empty() and eq_z >= 0:
				var tmp: int = duel.m.local(4)
				duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, opp, int(pick["z"])))
				if CustomDuelOps.is_joey(duel):
					duel.f570790(opp, int(pick["z"]), 0)
					duel.f5686e0(p, eq_z, tmp, 1)
				else:
					duel.f542c40(opp, int(pick["z"]))
					duel.f5423a0(p, eq_z - 5, tmp, 1)
				CustomDuelOps.link_equip(duel, p, eq_z, p, z)
				CustomDuelOps.zflags(duel, p, eq_z)["union_stolen"] = true
		2925: # Tribe-Infecting Virus
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				var tv_after := func() -> void:
					var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
					if pick.is_empty():
						pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
					if not pick.is_empty():
						var target_race = CustomDuelOps.monster_race(duel, int(pick["idx"]))
						for pl in 2:
							for zz in 5:
								var idx = CustomDuelOps.zone_idx(duel, pl, zz)
								if idx != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.monster_race(duel, idx) == target_race:
									CustomDuelOps.destroy_zone(duel, pl, zz)
				CustomDuelOps.discard_cost(duel, p, tv_after)
		2935: # Roulette Barrel
			CustomDuelOps.mark_opt(duel, p, 2935, z)
			var r1 = CustomDuelOps.dice_roll(duel, p)
			var r2 = CustomDuelOps.dice_roll(duel, p)
			var pred_rb = func(d, pl, zz, idx):
				var lv = CustomDuelOps.monster_level(d, idx)
				return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and (lv == r1 or lv == r2)
			var pick_run509 := func(pick) -> void:
				CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
			CustomDuelOps.choose_zone_then(duel, p, pred_rb, true, true, pick_run509)
		2936, 2970: # Skilled White / Dark Magician
			CustomDuelOps.tribute_zone(duel, p, z)
			var targets = [CustomDuelOps.NATIVE_BUSTER_BLADER] if cid == 2936 else CustomDuelOps.NATIVE_DARK_MAGICIAN
			for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
				var idx_i = _find_any_in_piles(duel, p, [srcloc], targets)
				if idx_i >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, srcloc, idx_i, p, true, false)
					break
		2962: # Royal Magical Library
			if CustomDuelOps.get_counter(duel, p, z, "spell") >= 3:
				CustomDuelOps.add_counter(duel, p, z, "spell", -3)
				CustomDuelOps.draw(duel, p, 1)
		2965:
			CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_entry", -1)), false)
		2966: # Paladin of White Dragon
			CustomDuelOps.tribute_zone(duel, p, z)
			for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK]:
				var bi = _find_any_in_piles(duel, p, [srcloc], CustomDuelOps.NATIVE_BLUE_EYES)
				if bi >= 0:
					var bz = CustomDuelOps.special_summon_from_pile(duel, p, srcloc, bi, p, true, false)
					if bz >= 0:
						CustomDuelOps.zflags(duel, p, bz)["cannot_atk_turn"] = t
					break
		2995: # Guardian Ceal
			var st = CustomDuelOps.state(duel)
			for ek in st["equip_links"].keys():
				var link: Dictionary = st["equip_links"][ek]
				if int(link.get("target_p", -1)) == p and int(link.get("target_z", -1)) == z:
					var parts := str(ek).split(":")
					CustomDuelOps.send_zone_to_gy(duel, int(parts[0]), int(parts[1]))
					var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
					if not pick.is_empty():
						CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
					break
		2997: # Sasuke Samurai #2
			CustomDuelOps.mark_opt(duel, p, 2997, z)
			if CustomDuelOps.pay_lp(duel, p, 800):
				CustomDuelOps.pflags(duel, 0)["locked_st_until_ep"] = t
				CustomDuelOps.pflags(duel, 1)["locked_st_until_ep"] = t
		3046: # Legendary Flame Lord
			if CustomDuelOps.get_counter(duel, p, z, "spell") >= 3:
				CustomDuelOps.add_counter(duel, p, z, "spell", -3)
				for pl in 2:
					for zz in 5:
						if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							CustomDuelOps.destroy_zone(duel, pl, zz)
		3084: # Dark Master - Zorc
			CustomDuelOps.mark_opt(duel, p, 3084, z)
			var r = CustomDuelOps.dice_roll(duel, p)
			if r <= 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
						CustomDuelOps.destroy_zone(duel, opp, zz)
			elif r <= 5:
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
			else:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, p, zz) != 0:
						CustomDuelOps.destroy_zone(duel, p, zz)
		3100: # Freed the Brave Wanderer
			CustomDuelOps.mark_opt(duel, p, 3100, z)
			var my_atk = CustomDuelOps.eff_atk(duel, p, z)
			var lis = _collect_attr_indices_in_gy(duel, p, 1)
			if lis.size() >= 2:
				lis.sort()
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, lis[lis.size() - 1])
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, lis[lis.size() - 2])
				var pick_run581 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_atk(d, pl, zz) > my_atk, true, true, pick_run581)
		3122: # Levia-Dragon - Daedalus
			var uz = CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_UMI, true)
			if uz < 0: uz = CustomDuelOps.find_zone_of_id(duel, p, 2697, true)
			if uz >= 0:
				CustomDuelOps.send_zone_to_gy(duel, p, uz)
				for pl in 2:
					for zz in 11:
						if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							CustomDuelOps.destroy_zone(duel, pl, zz)


static func on_summon_or_flip(duel, p: int, z: int, cid: int, kind: String) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	var zf = CustomDuelOps.zflags(duel, p, z)
	zf["summoned_turn"] = t

	# King Tiger Wanghu (2878) reactive trigger
	var my_atk_now = CustomDuelOps.eff_atk(duel, p, z)
	if (kind == "normal" or kind == "tribute" or kind == "special") and my_atk_now <= 1400:
		if CustomDuelOps.has_faceup_id(duel, 0, 2878) or CustomDuelOps.has_faceup_id(duel, 1, 2878):
			if not CustomDuelOps.is_skill_drain_active(duel):
				CustomDuelOps.destroy_zone(duel, p, z)
				return

	# Reactive Insect Princess forces opponent Insect monsters to ATK position
	if CustomDuelOps.has_faceup_id(duel, opp, 3123) and CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, p, z)) == 10:
		CustomDuelOps.change_position(duel, p, z, 0, -1)

	if CustomDuelOps.is_skill_drain_active(duel):
		return

	match cid:
		2800: # Dice Jar FLIP
			if kind == "flip_summon" or kind == "flipped":
				var r0 = CustomDuelOps.dice_roll(duel, 0)
				var r1 = CustomDuelOps.dice_roll(duel, 1)
				var guard = 0
				while r0 == r1 and guard < 12:
					r0 = CustomDuelOps.dice_roll(duel, 0)
					r1 = CustomDuelOps.dice_roll(duel, 1)
					guard += 1
				if r0 < r1:
					CustomDuelOps.damage(duel, 0, 6000 if r1 == 6 else r1 * 500, false)
				elif r1 < r0:
					CustomDuelOps.damage(duel, 1, 6000 if r0 == 6 else r0 * 500, false)
		2805: # Jowls of Dark Demise FLIP
			if kind == "flip_summon" or kind == "flipped":
				var pick_run633 := func(pick) -> void:
					var nz = CustomDuelOps.change_control(duel, opp, int(pick["z"]), p, true)
					if nz >= 0:
						CustomDuelOps.zflags(duel, p, nz)["direct_atk_turn"] = t
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run633)
		2812: # Swarm of Scarabs: Flip Summon destroy 1 monster
			if kind == "flip_summon":
				var pick_run640 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run640)
		2814: # Royal Keeper: flipped -> +300 ATK/DEF until EP
			if kind == "flip_summon" or kind == "flipped":
				CustomDuelOps.add_stat_mod(duel, p, z, 300, 300, true)
		2817: # Byser Shock: Summoned -> bounce all Set cards
			for pl in 2:
				for zz in 10:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and not CustomDuelOps.is_face_up(duel, pl, zz):
						CustomDuelOps.bounce_zone(duel, pl, zz)
		2818, 2819: # Owl of Luck / Cat of Ill Omen FLIP
			if kind == "flip_summon" or kind == "flipped":
				var pred_owl = func(d, idx, _s):
					if cid == 2818:
						return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 2
					return CustomDuelOps.is_trap(d, idx)
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, pred_owl, true)
				if si >= 0:
					if CustomDuelOps.is_necrovalley_active(duel):
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, si)
					else:
						CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_DECK, si, p, CustomDuelOps.LOC_DECK)
		2820: # Gravekeeper's Spy FLIP: SS GK w/ <=1500 ATK
			if (kind == "flip_summon" or kind == "flipped") and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.GRAVEKEEPER_IDS and CustomDuelOps.base_atk(d, idx) <= 1500, true)
				if di >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, di, p, true, false)
		2826: # Gravekeeper's Guard FLIP: bounce 1 opp monster
			if kind == "flip_summon" or kind == "flipped":
				var pick_run670 := func(pick) -> void:
					CustomDuelOps.bounce_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run670)
		2833: # Fushioh Richie flipped: SS 1 Zombie from GY
			if (kind == "flip_summon" or kind == "flipped") and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 2, true)
				if gi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		2835: # Guardian Sphinx Flip Summon -> bounce all opp monsters
			if kind == "flip_summon":
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
						CustomDuelOps.bounce_zone(duel, opp, zz)
		2839: # Swarm of Locusts Flip Summon -> destroy 1 opp S/T
			if kind == "flip_summon":
				var pick_run685 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz >= 5, true, true, pick_run685)
		2842: # Poison Mummy FLIP: 500 dmg
			if kind == "flip_summon" or kind == "flipped":
				CustomDuelOps.damage(duel, opp, 500, false)
		2848: # Gravekeeper's Curse: 500 dmg
			CustomDuelOps.damage(duel, opp, 500, false)
		2855: # Gravekeeper's Chief: Tribute Summon -> SS GK from GY
			if kind == "tribute" and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.GRAVEKEEPER_IDS, true)
				if gi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		2865: # Moisture Creature: 3-Tribute Summon -> destroy all opp S/T
			if kind == "tribute" and bool(zf.get("tribute_3", false)):
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz + 5) != 0:
						CustomDuelOps.destroy_zone(duel, opp, zz + 5)
				if CustomDuelOps.zone_idx(duel, opp, 10) != 0:
					CustomDuelOps.destroy_zone(duel, opp, 10)
		2882: # Cobra Jar FLIP -> Poisonous Snake Token (1200/1200)
			if kind == "flip_summon" or kind == "flipped":
				var tz = CustomDuelOps.spawn_token(duel, p, 0, false, 1200, 1200)
				if tz >= 0:
					CustomDuelOps.zflags(duel, p, tz)["poisonous_snake_token"] = true
		2885: # Dark Dust Spirit: destroy all other face-up monsters
			for pl in 2:
				for zz in 5:
					if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz):
						CustomDuelOps.destroy_zone(duel, pl, zz)
			zf["spirit_return_turn"] = t
		2886: # Dark Jeroid: -800 ATK to 1 face-up monster
			var pick_run717 := func(pick) -> void:
				CustomDuelOps.add_stat_mod(duel, int(pick["p"]), int(pick["z"]), -800, 0, false)
			CustomDuelOps.choose_zone_then(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true, pick_run717)
		2898: # Magical Plant Mandragola FLIP: +1 Spell Counter on each eligible card
			if kind == "flip_summon" or kind == "flipped":
				for pl in 2:
					for zz in 11:
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.zone_id(duel, pl, zz) in [2524, 2636, 2899, 2927, 2936, 2962, 2970, 3046]:
							CustomDuelOps.add_counter(duel, pl, zz, "spell", 1)
		2900: # Dark Cat with White Tail FLIP: bounce 2 opp + 1 yours
			if kind == "flip_summon" or kind == "flipped":
				for _i in 2:
					var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
					if pick.is_empty():
						break
					CustomDuelOps.bounce_zone(duel, opp, int(pick["z"]))
				var my_pick_run733 := func(my_pick) -> void:
					CustomDuelOps.bounce_zone(duel, p, int(my_pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false, my_pick_run733)
		2903: # Apprentice Magician: Summoned -> +1 Spell Counter
			var pick_run737 := func(pick) -> void:
				CustomDuelOps.add_counter(duel, int(pick["p"]), int(pick["z"]), "spell", 1)
			CustomDuelOps.choose_zone_then(duel, p, func(d, pl, zz, _idx): return CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.zone_id(d, pl, zz) in [2524, 2636, 2899, 2927, 2936, 2962, 2970, 3046], false, false, pick_run737)
		2905: # Decayed Commander: Normal -> SS Zombie Tiger from hand
			if kind == "normal" and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2941) >= 0:
					var dc_run := func() -> void:
						var hi: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2941)
						if hi >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
							CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
					CustomDuelOps.optional_effect(duel, p, 2905, dc_run)
		2923: # Magical Merchant FLIP: mill until S/T, add it to hand
			if kind == "flip_summon" or kind == "flipped":
				while CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0:
					var top_i = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) - 1
					var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_DECK, top_i)
					if CustomDuelOps.is_spell(duel, idx) or CustomDuelOps.is_trap(duel, idx):
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, top_i)
						break
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_DECK, top_i, p, CustomDuelOps.LOC_GRAVE)
		2933: # Old Vindictive Magician FLIP: destroy 1 opp monster
			if kind == "flip_summon" or kind == "flipped":
				var pick_run759 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run759)
		2937: # Vampiric Orchis: Normal -> SS Des Dendle from hand
			if kind == "normal" and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2914) >= 0:
					var vo_run := func() -> void:
						var hi: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2914)
						if hi >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
							CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
					CustomDuelOps.optional_effect(duel, p, 2937, vo_run)
		2960: # Des Koala FLIP: 400 * opp hand
			if kind == "flip_summon" or kind == "flipped":
				CustomDuelOps.damage(duel, opp, CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) * 400, false)
		2967: # Dimension Jar FLIP: banish up to 3 from each GY
			if (kind == "flip_summon" or kind == "flipped") and not CustomDuelOps.is_necrovalley_active(duel):
				for pl in 2:
					for _i in 3:
						var gi = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), true)
						if gi < 0:
							break
						CustomDuelOps.banish_from_pile(duel, pl, CustomDuelOps.LOC_GRAVE, gi)
		3025: # Cyber Raider: Summoned -> destroy 1 Equip
			var pick_run782 := func(pick) -> void:
				CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
			CustomDuelOps.choose_zone_then(duel, p, func(d, pl, zz, idx): return zz >= 5 and zz < 10 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.ctype(d, idx) == 0x16 and CustomDuelOps.csub(d, idx) == 1, true, true, pick_run782)
		3059: # Iron Blacksmith Kotetsu FLIP: add 1 Equip Spell from Deck
			if kind == "flip_summon" or kind == "flipped":
				var ei = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 1, true)
				if ei >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, ei)
		3062: # Guardian Elma: Summoned -> equip 1 Equip Spell from GY
			if not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_st_zone(duel, p) >= 0:
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 1, true)
				if gi >= 0:
					var eq_z = CustomDuelOps.set_st_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true)
					if eq_z >= 5:
						CustomDuelOps.link_equip(duel, p, eq_z, p, z)
		3065: # Des Feral Imp FLIP: shuffle 1 from GY into Deck
			if (kind == "flip_summon" or kind == "flipped") and not CustomDuelOps.is_necrovalley_active(duel):
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(_d, _idx, _s): return true, true)
				if gi >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, CustomDuelOps.LOC_DECK)
					CustomDuelOps.shuffle_deck(duel, p)
		3069: # Arsenal Summoner FLIP: add 1 Guardian card
			if kind == "flip_summon" or kind == "flipped":
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.GUARDIAN_IDS and CustomDuelOps.raw_id(d, idx) not in CustomDuelOps.ARSENAL_SUMMONER_EXCLUDED, true)
				if gi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, gi)
		3088: # Don Turtle: Normal/Flip Summon -> SS Don Turtles from hand
			if (kind == "normal" or kind == "tribute" or kind == "flip_summon") and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 3088) >= 0:
				var dt_run := func() -> void:
					while CustomDuelOps.free_monster_zone(duel, p) >= 0:
						var hi: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 3088)
						if hi < 0:
							break
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
				CustomDuelOps.optional_effect(duel, p, 3088, dt_run)
		3089: # Stealth Bird: Flip Summon -> 1000 dmg
			if kind == "flip_summon":
				CustomDuelOps.damage(duel, opp, 1000, false)
		3092: # Molten Zombie: SS from GY -> draw 1
			if kind == "special":
				CustomDuelOps.draw(duel, p, 1)
		3097: # Granadora: Summoned -> +1000 LP
			CustomDuelOps.heal(duel, p, 1000)
		3098: # Crimson Ninja FLIP: destroy 1 Trap on field
			if kind == "flip_summon" or kind == "flipped":
				var pick_run827 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(d, _pl, zz, idx): return zz >= 5 and CustomDuelOps.is_trap(d, idx), false, true, pick_run827)
		3116: # Sacred Crane: SS -> draw 1
			if kind == "special":
				CustomDuelOps.draw(duel, p, 1)
		3123: # Insect Princess: Summon -> opp Insects ATK pos
			for zz in 5:
				var idx = CustomDuelOps.zone_idx(duel, opp, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.monster_race(duel, idx) == 10:
					CustomDuelOps.change_position(duel, opp, zz, 0, -1)
		2991: # Maju Garzett: ATK = combined original ATK of the 2 Tributed monsters
			if kind == "normal" or kind == "tribute" or kind == "normal_summon":
				zf["garrzett_pending"] = 2
		3030: # Great Maju Garzett: ATK = 2x original ATK of the 1 Tributed monster
			if kind == "normal" or kind == "tribute" or kind == "normal_summon":
				zf["garrzett_pending"] = 1
		3128: # Chopman: Flip Summon -> equip 1 Equip Spell from GY
			if kind == "flip_summon" and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_st_zone(duel, p) >= 0:
				var ch_pred := func(d, idx, _s): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 1
				if CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, ch_pred, true) >= 0:
					var ch_run := func() -> void:
						var gi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, ch_pred, true)
						if gi < 0 or CustomDuelOps.free_st_zone(duel, p) < 0 or CustomDuelOps.zone_id(duel, p, z) != 3128:
							return
						var eq_z: int = CustomDuelOps.set_st_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true)
						if eq_z >= 5:
							CustomDuelOps.link_equip(duel, p, eq_z, p, z)
					CustomDuelOps.optional_effect(duel, p, 3128, ch_run)


static func on_attack_declare(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> bool:
	atk_p &= 1
	def_p &= 1
	var cid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	if not can_attack(duel, atk_p, atk_z, cid):
		return false
	if cid == 2822 and CustomDuelOps.has_faceup_id(duel, atk_p, 2846): # Gravekeeper's Assailant
		if not CustomDuelOps.choose_zone(duel, atk_p, func(d, pl, zz, _idx): return pl == def_p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true).is_empty():
			var ga_run := func() -> void:
				var pk := CustomDuelOps.choose_zone(duel, atk_p, func(d, pl, zz, _idx): return pl == def_p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
				if not pk.is_empty():
					var cur_def: bool = not CustomDuelOps.is_atk_pos(duel, def_p, int(pk["z"]))
					CustomDuelOps.change_position(duel, def_p, int(pk["z"]), 0 if cur_def else 1, -1)
			CustomDuelOps.optional_effect(duel, atk_p, 2822, ga_run)
	if (cid == 2813 or cid == 2966) and def_z >= 0 and not CustomDuelOps.is_face_up(duel, def_p, def_z) and not CustomDuelOps.is_atk_pos(duel, def_p, def_z):
		CustomDuelOps.destroy_zone(duel, def_p, def_z)
	if cid == 2811 and def_z >= 0 and not CustomDuelOps.is_face_up(duel, def_p, def_z):
		CustomDuelOps.set_stat_val(duel, atk_p, atk_z, 2400, -1, true)
	return true


static func on_damage_calc(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> void:
	atk_p &= 1
	def_p &= 1
	var acid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	var dcid = CustomDuelOps.zone_id(duel, def_p, def_z) if def_z >= 0 else 0
	if acid == 3034 and def_z >= 0: # Mirage Knight
		CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, def_p, def_z)), 0, true)
	if dcid == 3034:
		CustomDuelOps.add_stat_mod(duel, def_p, def_z, CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, atk_p, atk_z)), 0, true)
	if dcid == 2983 and CustomDuelOps.turn_player(duel) == atk_p: # Cat's Ear Tribe
		CustomDuelOps.set_stat_val(duel, atk_p, atk_z, 200, -1, true)
	if dcid == 2987 and CustomDuelOps.is_atk_pos(duel, def_p, def_z): # Reflect Bounder
		CustomDuelOps.damage(duel, atk_p, CustomDuelOps.eff_atk(duel, atk_p, atk_z), false)
		CustomDuelOps.zflags(duel, def_p, def_z)["reflect_bounder_pop"] = true
	if acid == 3036 and def_z >= 0: # Different Dimension Dragon: cannot be destroyed by battle with <=1900 ATK monster
		CustomDuelOps.zflags(duel, atk_p, atk_z)["indest_battle"] = CustomDuelOps.eff_atk(duel, def_p, def_z) <= 1900
	if dcid == 3036:
		CustomDuelOps.zflags(duel, def_p, def_z)["indest_battle"] = CustomDuelOps.eff_atk(duel, atk_p, atk_z) <= 1900
	if acid == 3038 and def_z >= 0: # Kaiser Glider: cannot be destroyed by battle with a monster that has the same ATK
		CustomDuelOps.zflags(duel, atk_p, atk_z)["indest_battle"] = CustomDuelOps.eff_atk(duel, def_p, def_z) == CustomDuelOps.eff_atk(duel, atk_p, atk_z)
	if dcid == 3038:
		CustomDuelOps.zflags(duel, def_p, def_z)["indest_battle"] = CustomDuelOps.eff_atk(duel, atk_p, atk_z) == CustomDuelOps.eff_atk(duel, def_p, def_z)


static func on_battle_damage(duel, dmg_p: int, dmg_z: int, opp_p: int, amount: int, is_direct: bool) -> void:
	if amount <= 0:
		return
	var cid = CustomDuelOps.zone_id(duel, dmg_p, dmg_z)
	var t = CustomDuelOps.turn_number(duel)
	match cid:
		2836: # Dark Scorpion Burglars: opp sends 1 Spell from Deck to GY
			var si = CustomDuelOps.choose_pile_card(duel, opp_p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx), false)
			if si >= 0:
				CustomDuelOps.send_from_deck_to_gy(duel, opp_p, si)
		2861: # Mucus Yolk: next Standby +1000 ATK
			CustomDuelOps.schedule_delayed(duel, t + 1, CustomDuelOps.PHASE_SP, dmg_p, 2861, "mucus_boost", {"z": dmg_z})
		2881: # Reaper on the Nightmare: direct -> discard 1 random
			if is_direct:
				CustomDuelOps.discard_random(duel, opp_p, 1)
		2894: # Cliff the Trap Remover
			var cl_pick := CustomDuelOps.choose_zone(duel, dmg_p, func(_d, _pl, zz, _idx): return zz >= 5, true, true)
			var cl_a := func() -> void:
				var pk := CustomDuelOps.choose_zone(duel, dmg_p, func(_d, _pl, zz, _idx): return zz >= 5, true, true)
				if not pk.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pk["p"]), int(pk["z"]))
			var cl_b := func() -> void:
				CustomDuelOps.mill(duel, opp_p, 2, 1)
			var cl_texts: Array = [
				CustomDuelOps.lang_text("هل تريد تدمير بطاقة سحر/فخ على الملعب؟", "¿Destruir 1 carta de Magia/Trampa del campo?", "Destroy 1 Spell/Trap Card on the field?"),
				CustomDuelOps.lang_text("هل تريد إرسال أول بطاقتين من مجموعة الخصم إلى المقبرة؟", "¿Enviar las 2 cartas de arriba del Deck del rival al Cementerio?", "Send the top 2 cards of your opponent's Deck to the Graveyard?")]
			if cl_pick.is_empty():
				CustomDuelOps.optional_text(duel, dmg_p, str(cl_texts[1]), cl_b)
			else:
				CustomDuelOps.optional_one_of(duel, dmg_p, cl_texts, [cl_a, cl_b], 0)
		2905: # Decayed Commander: direct -> discard 1 random
			if is_direct:
				CustomDuelOps.discard_random(duel, opp_p, 1)
		2906: # Great Phantom Thief: discard matching card in hand
			if CustomDuelOps.pile_count(duel, opp_p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, opp_p, 0, 1)
		3027: # Mefist: discard 1 random
			CustomDuelOps.discard_random(duel, opp_p, 1)
		3032: # Dark Scorpion - Gorg the Strong
			var gg_pick := CustomDuelOps.choose_zone(duel, dmg_p, func(_d, pl, zz, _idx): return pl == opp_p and zz < 5, true, true)
			var gg_a := func() -> void:
				var pk := CustomDuelOps.choose_zone(duel, dmg_p, func(_d, pl, zz, _idx): return pl == opp_p and zz < 5, true, true)
				if not pk.is_empty():
					CustomDuelOps.spin_zone(duel, opp_p, int(pk["z"]), false)
			var gg_b := func() -> void:
				CustomDuelOps.mill(duel, opp_p, 1, 1)
			var gg_texts: Array = [
				CustomDuelOps.lang_text("هل تريد إعادة وحش من الخصم إلى أعلى المجموعة؟", "¿Devolver 1 monstruo del rival al tope del Deck?", "Return 1 monster your opponent controls to the top of the Deck?"),
				CustomDuelOps.lang_text("هل تريد إرسال أول بطاقة من مجموعة الخصم إلى المقبرة؟", "¿Enviar la carta de arriba del Deck del rival al Cementerio?", "Send the top card of your opponent's Deck to the Graveyard?")]
			if gg_pick.is_empty():
				CustomDuelOps.optional_text(duel, dmg_p, str(gg_texts[1]), gg_b)
			else:
				CustomDuelOps.optional_one_of(duel, dmg_p, gg_texts, [gg_a, gg_b], 0)
		3049: # Dark Scorpion - Chick the Yellow
			if not CustomDuelOps.choose_zone(duel, dmg_p, func(_d, pl, _zz, _idx): return pl == opp_p, true, true).is_empty():
				var dsc_run := func() -> void:
					var pk := CustomDuelOps.choose_zone(duel, dmg_p, func(_d, pl, _zz, _idx): return pl == opp_p, true, true)
					if not pk.is_empty():
						CustomDuelOps.bounce_zone(duel, opp_p, int(pk["z"]))
				CustomDuelOps.optional_text(duel, dmg_p, CustomDuelOps.lang_text("هل تريد إعادة بطاقة من الملعب إلى اليد؟", "¿Devolver 1 carta del campo a la mano?", "Return 1 card on the field to the hand?"), dsc_run)
		3061: # Dark Scorpion - Meanae the Thorn
			var dm_pred := func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.DARK_SCORPION_IDS
			if CustomDuelOps.choose_pile_card(duel, dmg_p, CustomDuelOps.LOC_DECK, dm_pred, true) >= 0:
				var dm_run := func() -> void:
					var di: int = CustomDuelOps.choose_pile_card(duel, dmg_p, CustomDuelOps.LOC_DECK, dm_pred, true)
					if di >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, dmg_p, CustomDuelOps.LOC_DECK, di)
				CustomDuelOps.optional_effect(duel, dmg_p, 3061, dm_run)


static func on_battle_end(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, atk_destroyed: bool, def_destroyed: bool) -> void:
	var acid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	var dcid = CustomDuelOps.zone_id(duel, def_p, def_z) if def_z >= 0 else 0
	var t = CustomDuelOps.turn_number(duel)
	if acid in [3034] or dcid in [3034]: # Mirage Knight battled -> banish EP
		if acid == 3034:
			CustomDuelOps.zflags(duel, atk_p, atk_z)["mirage_banish_turn"] = t
		if dcid == 3034 and def_z >= 0:
			CustomDuelOps.zflags(duel, def_p, def_z)["mirage_banish_turn"] = t
	if acid == 2969: # Giant Orc -> DEF pos locked
		CustomDuelOps.change_position(duel, atk_p, atk_z, 1, -1)
		CustomDuelOps.zflags(duel, atk_p, atk_z)["lock_pos_until_turn"] = t + 2
	if dcid == 2987 and bool(CustomDuelOps.zflags(duel, def_p, def_z).get("reflect_bounder_pop", false)):
		CustomDuelOps.destroy_zone(duel, def_p, def_z)
	if def_z >= 0 and not atk_destroyed and not def_destroyed:
		if (acid == 3087 or dcid == 3087): # Hyper Hammerhead bounce opponent monster
			if acid == 3087:
				CustomDuelOps.bounce_zone(duel, def_p, def_z)
			else:
				CustomDuelOps.bounce_zone(duel, atk_p, atk_z)
		if dcid == 3039 and not def_destroyed: # Kelbek bounce attacker
			CustomDuelOps.bounce_zone(duel, atk_p, atk_z)
		if (dcid == 3019 or dcid == 2874) and not CustomDuelOps.is_atk_pos(duel, def_p, def_z):
			if CustomDuelOps.eff_def(duel, def_p, def_z) > CustomDuelOps.eff_atk(duel, atk_p, atk_z):
				CustomDuelOps.destroy_zone(duel, atk_p, atk_z)
	if (acid == 3109 or dcid == 3109) and def_z >= 0: # Getsu Fuhma destroys Fiend/Zombie
		var target_p = def_p if acid == 3109 else atk_p
		var target_z = def_z if acid == 3109 else atk_z
		var tr = CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, target_p, target_z))
		if tr in [3, 4]:
			CustomDuelOps.destroy_zone(duel, target_p, target_z)
	if def_destroyed and def_z >= 0:
		var def_idx = CustomDuelOps.zone_idx(duel, def_p, def_z)
		if acid == 2843: # Timeater: skip opp next MP1
			CustomDuelOps.pflags(duel, def_p)["skip_mp1_turn"] = t + 1
		if acid == 2883 and CustomDuelOps.is_atk_pos(duel, def_p, def_z): # Winged Sage Falcos
			if CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid) >= 0:
				var fa_run := func() -> void:
					var gi: int = CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid)
					if gi >= 0:
						CustomDuelOps.move_pile_card(duel, def_p, CustomDuelOps.LOC_GRAVE, gi, def_p, CustomDuelOps.LOC_DECK)
				CustomDuelOps.optional_effect(duel, atk_p, 2883, fa_run)
		if acid == 2884: # Great Dezard increment kill count
			var dzf = CustomDuelOps.zflags(duel, atk_p, atk_z)
			dzf["dezard_kills"] = int(dzf.get("dezard_kills", 0)) + 1
		if acid == 2889: # Mystical Knight of Jackal
			if CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid) >= 0:
				var jk_run := func() -> void:
					var gi: int = CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid)
					if gi >= 0:
						CustomDuelOps.move_pile_card(duel, def_p, CustomDuelOps.LOC_GRAVE, gi, def_p, CustomDuelOps.LOC_DECK)
				CustomDuelOps.optional_effect(duel, atk_p, 2889, jk_run)
		if acid == 2938: # Helping Robo for Combat: draw 1 then return 1 to bottom
			if CustomDuelOps.draw(duel, atk_p, 1) > 0 and CustomDuelOps.pile_count(duel, atk_p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.move_pile_card(duel, atk_p, CustomDuelOps.LOC_HAND, 0, atk_p, CustomDuelOps.LOC_DECK, true)
		if acid == 2942: # D.D. Crazy Beast banish destroyed
			var gi = CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid)
			if gi >= 0:
				CustomDuelOps.banish_from_pile(duel, def_p, CustomDuelOps.LOC_GRAVE, gi)
		if acid == 3060: # Guardian Baou +1000 ATK
			CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 1000, 0, false)
		if acid == 3071 and not CustomDuelOps.is_atk_pos(duel, def_p, def_z): # Shinato burn = orig ATK
			CustomDuelOps.damage(duel, def_p, CustomDuelOps.base_atk(duel, def_idx), false)
		if acid == 3085: # Fenrir: skip opp next Draw Phase
			CustomDuelOps.pflags(duel, def_p)["skip_dp_turn"] = t + 1
		if acid == 3123 and CustomDuelOps.monster_race(duel, def_idx) == 10: # Insect Princess +500 ATK
			CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 500, 0, false)


static func on_destroyed(duel, p: int, cid: int, by_battle: bool, opp_effect: bool, _was_tributed_for_p: int) -> void:
	p &= 1
	var opp = 1 - p
	match cid:
		3141: # Red-Eyes Baby Dragon: destroyed by battle -> SS a Red-Eyes from the Deck, equip itself to it
			if by_battle and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var bb_di: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes") and CustomDuelOps.monster_level(d, idx) <= 7)
				if bb_di >= 0:
					var bb_summon: Callable = func() -> void:
						var bb_nz: int = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, bb_di, p, true, false)
						CustomDuelOps.shuffle_deck(duel, p)
						var bb_gi: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 3141)
						if bb_nz >= 0 and bb_gi >= 0:
							_equip_monster_to(duel, p, CustomDuelOps.LOC_GRAVE, bb_gi, bb_nz)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 3141), bb_summon):
						bb_summon.call()
		3133: # Red-Eyes Alternative Black Dragon: SS a Level 7 or lower Red-Eyes from the GY
			if (by_battle or opp_effect) and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var alt_gi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes") and CustomDuelOps.monster_level(d, idx) <= 7 and CustomDuelOps.raw_id(d, idx) != 3133 and CustomDuelOps.raw_id(d, idx) != 2627, true)
				if alt_gi >= 0:
					var alt_summon: Callable = func() -> void:
						var alt_rid: int = CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, alt_gi))
						var alt_nz: int = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, alt_gi, p, true, false)
						if alt_nz >= 0 and alt_rid in CustomDuelOps.NATIVE_RED_EYES:
							# Its original ATK becomes doubled.
							var alt_atk: int = CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, p, alt_nz))
							CustomDuelOps.add_stat_mod(duel, p, alt_nz, alt_atk, 0, false)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 3133), alt_summon):
						alt_summon.call()
		2803: # Newdoria
			if by_battle:
				var pick_run1069 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true, pick_run1069)
		2844: # Birdface: efecto opcional ("puedes")
			if by_battle:
				var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_HARPIE_LADY)
				if hi >= 0:
					var birdface_take: Callable = func() -> void:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, hi)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 2844), birdface_take):
						birdface_take.call()
		2850: # Yomi Ship
			if by_battle:
				var pick_run1082 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run1082)
		2866: # Helpoemer: at end of opp BP discard 1 random
			if by_battle:
				CustomDuelOps.schedule_delayed(duel, CustomDuelOps.turn_number(duel), CustomDuelOps.PHASE_M2, p, 2866, "helpoemer_discard", {})
		2870: # Pyramid Turtle: SS Zombie <= 2000 DEF from Deck; efecto opcional ("puedes")
			if by_battle and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var turtle_summon: Callable = func() -> void:
					var zi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 2 and CustomDuelOps.base_def(d, idx) <= 2000, true)
					if zi >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, zi, p, true, false)
				if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 2870), turtle_summon):
					turtle_summon.call()
		2877: # Kryuel: coin toss destroy 1 opp monster
			if by_battle and CustomDuelOps.coin_toss(duel, p) == 1:
				var pick_run1098 := func(pick) -> void:
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
				CustomDuelOps.choose_zone_then(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true, pick_run1098)
		2903: # Apprentice Magician: SS Lv<=2 Spellcaster FD DEF
			if by_battle and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 18 and CustomDuelOps.monster_level(d, idx) <= 2, true)
				if si >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, si, p, false, true)
		2931: # Pixie Knight: Spell from GY to top of Deck
			if by_battle and not CustomDuelOps.is_necrovalley_active(duel):
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx), false)
				if si >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, si, p, CustomDuelOps.LOC_DECK)
		3000: # Dark Flare Knight: SS Mirage Knight from hand or Deck
			if by_battle and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK]:
					var mi = CustomDuelOps.find_pile_index_by_id(duel, p, srcloc, 3034)
					if mi >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, srcloc, mi, p, true, false)
						break
		3001: # Agido: roll die SS Fairy of matching Lv from GY
			if by_battle and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var droll = CustomDuelOps.dice_roll(duel, p)
				var pred_agido = func(d, idx, _s):
					var lv = CustomDuelOps.monster_level(d, idx)
					return CustomDuelOps.monster_race(d, idx) == 17 and (lv == droll or (droll == 6 and lv >= 6))
				var fi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, pred_agido, true)
				if fi >= 0:
					var agido_summon: Callable = func() -> void:
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, fi, p, true, false)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 3001), agido_summon):
						agido_summon.call()
		3038: # Kaiser Glider: bounce 1 monster
			var pick_run1131 := func(pick) -> void:
				CustomDuelOps.bounce_zone(duel, int(pick["p"]), int(pick["z"]))
			CustomDuelOps.choose_zone_then(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true, pick_run1131)
		3064: # Keldo: shuffle 2 from opp GY into Deck
			if by_battle and not CustomDuelOps.is_necrovalley_active(duel):
				for _i in 2:
					var gi = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(_d, _idx, _s): return true, true)
					if gi < 0:
						break
					CustomDuelOps.move_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, gi, opp, CustomDuelOps.LOC_DECK)
				CustomDuelOps.shuffle_deck(duel, opp)
		3097: # Granadora: take 2000 dmg
			CustomDuelOps.damage(duel, p, 2000, false)
		3126: # Balloon Lizard: 400 dmg per counter
			CustomDuelOps.damage(duel, opp, 400, false)
		3127: # Lord Poison: SS Plant from GY except Lord Poison
			if by_battle and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var pi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 13 and CustomDuelOps.raw_id(d, idx) != 3127, true)
				if pi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, pi, p, true, false)


static func on_sent_to_gy(duel, p: int, cid: int, from_loc: int, opp_effect: bool) -> void:
	p &= 1
	var opp = 1 - p
	match cid:
		3140: # Black Metal Dragon: sent from the field to the GY -> add a Red-Eyes card from the Deck
			if from_loc < 11:
				var bm_i: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.name_matches(d, idx, "red-eyes"))
				if bm_i >= 0:
					var bm_add: Callable = func() -> void:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, bm_i)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 3140), bm_add):
						bm_add.call()
		3141: # Red-Eyes Baby Dragon: sent to the GY while equipped -> add a Level 1 Dragon
			if from_loc == CustomDuelOps.LOC_FIELD_ST:
				for bd_loc in [CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
					var bd_i: int = CustomDuelOps.choose_pile_card(duel, p, bd_loc, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_race(d, idx) == 1 and CustomDuelOps.monster_level(d, idx) == 1 and CustomDuelOps.raw_id(d, idx) != 3141)
					if bd_i >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, bd_loc, bd_i)
						break
		2908: # Neko Mane King: during opp turn if sent to GY by opp effect -> End Phase
			if opp_effect and CustomDuelOps.turn_player(duel) == opp:
				CustomDuelOps.pflags(duel, opp)["force_ep_turn"] = CustomDuelOps.turn_number(duel)
		2996: # Outstanding Dog Marron: shuffle into Deck
			var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2996)
			if gi >= 0:
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, CustomDuelOps.LOC_DECK)
				CustomDuelOps.shuffle_deck(duel, p)
		3002: # Zolga: Tributed for a Tribute Summon -> gain 2000 LP
			if from_loc < 5:
				CustomDuelOps.heal(duel, p, 2000)
		3020, 3056: # Fear from the Dark / Despair from the Dark: opp effect -> SS
			if opp_effect and (from_loc == CustomDuelOps.LOC_HAND or from_loc == CustomDuelOps.LOC_DECK) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, cid)
				if gi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		3090: # D.D. Scout Plane banished tracking handled via banish scan on EP
			pass
		3115: # Pinch Hopper: sent from field to GY -> SS Insect from hand
			if from_loc < 11 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var ph_pred := func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 10
				if CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, ph_pred, true) >= 0:
					var ph_run := func() -> void:
						var hi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, ph_pred, true)
						if hi >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
							CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
					CustomDuelOps.optional_effect(duel, p, 3115, ph_run)


static func on_spell_resolved(duel, _cast_p: int) -> void:
	if CustomDuelOps.is_skill_drain_active(duel):
		return
	var cast_p = _cast_p & 1
	var gy_n = CustomDuelOps.pile_count(duel, cast_p, CustomDuelOps.LOC_GRAVE)
	var is_pot = gy_n > 0 and CustomDuelOps.name_matches(duel, CustomDuelOps.pile_idx(duel, cast_p, CustomDuelOps.LOC_GRAVE, gy_n - 1), "pot of greed")
	for pl in 2:
		for z in 5:
			if CustomDuelOps.zone_idx(duel, pl, z) == 0 or not CustomDuelOps.is_face_up(duel, pl, z):
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			if cid in [2899, 3046]:
				CustomDuelOps.add_counter(duel, pl, z, "spell", 1)
			elif cid in [2936, 2962, 2970]:
				if CustomDuelOps.get_counter(duel, pl, z, "spell") < 3:
					CustomDuelOps.add_counter(duel, pl, z, "spell", 1)
			elif cid == 3093 and is_pot and CustomDuelOps.is_atk_pos(duel, pl, z): # Spirit of the Pot of Greed: Pot of Greed activator draws 1 extra card
				CustomDuelOps.draw(duel, cast_p, 1)


static func on_standby_tick(duel, turn_p: int) -> void:
	turn_p &= 1
	var opp = 1 - turn_p
	var t = CustomDuelOps.turn_number(duel)
	# Armor Exe (2895): also during the OPPONENT's Standby Phase its controller removes a Spell Counter or it is destroyed.
	if not CustomDuelOps.is_skill_drain_active(duel):
		for az in 5:
			if CustomDuelOps.zone_idx(duel, opp, az) != 0 and CustomDuelOps.is_face_up(duel, opp, az) and CustomDuelOps.zone_id(duel, opp, az) == 2895:
				if not CustomDuelOps.remove_spell_counters(duel, opp, 1):
					CustomDuelOps.destroy_zone(duel, opp, az)
	for z in 5:
		if CustomDuelOps.zone_idx(duel, turn_p, z) == 0 or not CustomDuelOps.is_face_up(duel, turn_p, z):
			continue
		var cid = CustomDuelOps.zone_id(duel, turn_p, z)
		if ARCHFIEND_UPKEEP.has(cid):
			var cost := int(ARCHFIEND_UPKEEP[cid])
			if CustomDuelOps.has_faceup_id(duel, turn_p, 3078) or CustomDuelOps.has_faceup_id(duel, opp, 3078):
				pass # Pandemonium waives Standby LP cost
			elif CustomDuelOps.can_pay_lp(duel, turn_p, cost):
				CustomDuelOps.pay_lp(duel, turn_p, cost)
			else:
				CustomDuelOps.destroy_zone(duel, turn_p, z)
				continue
		if CustomDuelOps.is_skill_drain_active(duel):
			continue
		match cid:
			2849: # A Man with Wdjat (passive reveal)
				pass
			2895: # Armor Exe: remove 1 Spell Counter or destroy
				if not CustomDuelOps.remove_spell_counters(duel, turn_p, 1):
					CustomDuelOps.destroy_zone(duel, turn_p, z)
			2968: # Amazoness Blowpiper: opp monster -500 ATK until EP
				var pick = CustomDuelOps.choose_zone(duel, turn_p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
				if not pick.is_empty():
					CustomDuelOps.add_stat_mod(duel, opp, int(pick["z"]), -500, 0, true)
			2990: # Infernalqueen Archfiend: +1000 ATK to 1 Archfiend until EP
				var pick = CustomDuelOps.choose_zone(duel, turn_p, func(d, _pl, zz, idx): return zz < 5 and CustomDuelOps.is_face_up(d, turn_p, zz) and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ARCHFIEND_IDS, true, false)
				if not pick.is_empty():
					CustomDuelOps.add_stat_mod(duel, int(pick["p"]), int(pick["z"]), 1000, 0, true)
			3126: # Balloon Lizard: +1 counter
				CustomDuelOps.add_counter(duel, turn_p, z, "balloon", 1)
	# Also Armor Exe triggers during opponent Standby Phase too
	for z in 5:
		if CustomDuelOps.zone_idx(duel, opp, z) != 0 and CustomDuelOps.is_face_up(duel, opp, z) and CustomDuelOps.zone_id(duel, opp, z) == 2895:
			if not CustomDuelOps.remove_spell_counters(duel, opp, 1):
				CustomDuelOps.destroy_zone(duel, opp, z)


static func on_end_phase(duel, turn_p: int) -> void:
	turn_p &= 1
	var t = CustomDuelOps.turn_number(duel)
	for pl in 2:
		for z in range(4, -1, -1):
			if CustomDuelOps.zone_idx(duel, pl, z) == 0:
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			var zf = CustomDuelOps.zflags(duel, pl, z)
			if zf.has("indest_battle") and not (zf["indest_battle"] is bool):
				zf.erase("indest_battle")
			if cid == 3034 and int(zf.get("mirage_banish_turn", -1)) == t:
				CustomDuelOps.banish_zone(duel, pl, z)
				continue
			if pl == turn_p:
				if cid == 3070: # Berserk Dragon: -500 ATK
					CustomDuelOps.add_stat_mod(duel, pl, z, -500, 0, false)
				elif cid == 3074: # Little-Winguard: toggle to DEF if low ATK
					if CustomDuelOps.is_atk_pos(duel, pl, z):
						CustomDuelOps.change_position(duel, pl, z, 1, -1)
		# Red-Eyes Wyvern (3142): in your End Phase, if you did not Normal Summon/Set, banish it from the
		# GY to Special Summon a "Red-Eyes" monster from the GY, except "Red-Eyes B. Chick".
		if pl == turn_p and CustomDuelOps.can_hopt(duel, pl, 3142) and not CustomDuelOps.normal_summon_used(duel, pl) and CustomDuelOps.free_monster_zone(duel, pl) >= 0 and not CustomDuelOps.is_necrovalley_active(duel):
			var wy_gi: int = CustomDuelOps.find_pile_index_by_id(duel, pl, CustomDuelOps.LOC_GRAVE, 3142)
			if wy_gi >= 0 and CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes") and CustomDuelOps.raw_id(d, idx) != 3142 and CustomDuelOps.raw_id(d, idx) != 3136) >= 0:
				var wy_run: Callable = func() -> void:
					CustomDuelOps.mark_hopt(duel, pl, 3142)
					var wy_self: int = CustomDuelOps.find_pile_index_by_id(duel, pl, CustomDuelOps.LOC_GRAVE, 3142)
					if wy_self >= 0:
						CustomDuelOps.banish_from_pile(duel, pl, CustomDuelOps.LOC_GRAVE, wy_self)
					var wy_t: int = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.name_matches(d, idx, "red-eyes") and CustomDuelOps.raw_id(d, idx) != 3136)
					if wy_t >= 0:
						CustomDuelOps.special_summon_from_pile(duel, pl, CustomDuelOps.LOC_GRAVE, wy_t, pl, true, false)
				if not CustomDuelOps.ask_optional(duel, pl, CustomDuelOps.effect_prompt(duel, 3142), wy_run):
					wy_run.call()
		# D.D. Scout Plane in Banished -> SS Attack Position
		if CustomDuelOps.free_monster_zone(duel, pl) >= 0 and CustomDuelOps.can_hopt(duel, pl, 3090):
			var bi = CustomDuelOps.find_pile_index_by_id(duel, pl, CustomDuelOps.LOC_BANISH, 3090)
			if bi >= 0:
				CustomDuelOps.mark_hopt(duel, pl, 3090)
				CustomDuelOps.special_summon_from_pile(duel, pl, CustomDuelOps.LOC_BANISH, bi, pl, true, false)


static func on_continuous_enforce(duel) -> void:
	var sd = CustomDuelOps.is_skill_drain_active(duel)
	for pl in 2:
		var has_watchbear = false
		for z in 5:
			if CustomDuelOps.zone_idx(duel, pl, z) == 0 or not CustomDuelOps.is_face_up(duel, pl, z):
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			if cid == 3125 and not CustomDuelOps.is_atk_pos(duel, pl, z) and not sd:
				CustomDuelOps.destroy_zone(duel, pl, z)
				continue
			if cid == 3021: # Blindly Loyal Goblin: cannot switch control
				CustomDuelOps.zflags(duel, pl, z)["cannot_switch_control"] = not sd
			elif cid == 3036: # Different Dimension Dragon: immune to non-targeting S/T destruction
				CustomDuelOps.zflags(duel, pl, z)["nontarget_st_immune"] = not sd
			elif cid == 3063 and not sd: # Pandemonium Watchbear
				has_watchbear = true
		if CustomDuelOps.zone_idx(duel, pl, 10) != 0 and CustomDuelOps.is_face_up(duel, pl, 10) and CustomDuelOps.zone_id(duel, pl, 10) == 3078:
			CustomDuelOps.zflags(duel, pl, 10)["indest_effect"] = has_watchbear


static func modify_continuous(duel, p: int, z: int, cid: int, out: Dictionary) -> void:
	p &= 1
	if CustomDuelOps.is_skill_drain_active(duel) or bool(CustomDuelOps.zflags(duel, p, z).get("negated", false)):
		return
	var opp = 1 - p
	match cid:
		2840: # Arsenal Bug: if no other Insect -> ATK/DEF 1000
			var has_other = false
			for zz in 5:
				if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, p, zz)) == 10:
					has_other = true
					break
			if not has_other:
				out["atk_set"] = 1000
				out["def_set"] = 1000
		2899: # Magical Marionette: +200 per Spell Counter
			out["atk_delta"] = int(out.get("atk_delta", 0)) + CustomDuelOps.get_counter(duel, p, z, "spell") * 200
		2907: # Amazoness Tiger: +400 per Amazoness
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_archetype_on_field(duel, p, CustomDuelOps.AMAZONESS_IDS) * 400
		2940: # Amazoness Paladin: +100 per Amazoness
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_archetype_on_field(duel, p, CustomDuelOps.AMAZONESS_IDS) * 100
		2994: # Gyaku-Gire Panda: +500 per opp monster
			out["atk_delta"] = int(out.get("atk_delta", 0)) + CustomDuelOps.count_monsters(duel, opp, false) * 500
		3066: # Mudora: +200 per Fairy in GY
			var fc = 0
			for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
				if CustomDuelOps.monster_race(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)) == 17:
					fc += 1
			out["atk_delta"] = int(out.get("atk_delta", 0)) + fc * 200
		3086: # Chaos Necromancer: 300 * monsters in GY
			var mc = 0
			for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
				if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)):
					mc += 1
			out["atk_set"] = mc * 300
		3121: # Gren Maju Da Eiza: banished * 400
			var bn = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_BANISH) * 400
			out["atk_set"] = bn
			out["def_set"] = bn


static func can_attack(duel, p: int, z: int, cid: int) -> bool:
	p &= 1
	var t = CustomDuelOps.turn_number(duel)
	var zf = CustomDuelOps.zflags(duel, p, z)
	if cid == 2895 and int(zf.get("summoned_turn", -1)) == t:
		return false
	if cid == 2922 and (CustomDuelOps.total_field_cards(duel, p) > 1 or CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0):
		return false
	if (CustomDuelOps.has_faceup_id(duel, 0, 2876) or CustomDuelOps.has_faceup_id(duel, 1, 2876)) and CustomDuelOps.eff_atk(duel, p, z) >= 1900:
		return false
	return true


static func can_direct_attack(duel, p: int, z: int, cid: int) -> bool:
	var t = CustomDuelOps.turn_number(duel)
	if cid in [2854, 2861, 2881]:
		return true
	if int(CustomDuelOps.zflags(duel, p, z).get("direct_atk_turn", -1)) == t:
		return true
	if cid == 3124: # Black Tyranno: only when every card the opponent controls is a Defense Position monster
		var opp = 1 - (p & 1)
		var opp_monsters := 0
		for zz in 5:
			if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
				opp_monsters += 1
				if CustomDuelOps.is_atk_pos(duel, opp, zz):
					return false
		for zz in range(5, 11):
			if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
				return false
		return opp_monsters > 0
	return false


static func has_pierce(duel, p: int, z: int, cid: int) -> bool:
	# Pitch-Dark Dragon (2939) and Koitsu (2959): the equipped monster inflicts piercing damage.
	if CustomDuelOps.union_equipped_to(duel, p, z, 2939) or CustomDuelOps.union_equipped_to(duel, p, z, 2959):
		return true
	return cid in [2857, 2994, 3027] or bool(CustomDuelOps.zflags(duel, p, z).get("pierce", false))


static func max_attacks(_duel, _p: int, _z: int, cid: int) -> int:
	if cid == 3113:
		return 2
	if cid == 3070:
		return 5
	return 1


# --- Private Helpers -----------------------------------------------------------------------------

static func UNION_PAIR_PAIR_MATCH(cid: int) -> bool:
	return UNION_PAIR_IDS.has(cid)


static func _find_union_host(duel, p: int, self_z: int, cid: int) -> int:
	var targets: Array = UNION_PAIR_IDS.get(cid, [])
	for zz in 5:
		if zz == self_z or CustomDuelOps.zone_idx(duel, p, zz) == 0 or not CustomDuelOps.is_face_up(duel, p, zz):
			continue
		if targets.is_empty() or CustomDuelOps.zone_id(duel, p, zz) in targets:
			return zz
	return -1


static func _has_archfiend_on_field(duel, p: int) -> bool:
	return _has_archetype_on_field(duel, p, CustomDuelOps.ARCHFIEND_IDS)


static func _has_archetype_on_field(duel, p: int, id_list: Array) -> bool:
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.raw_id(duel, idx) in id_list:
			return true
	return false


static func _count_archetype_on_field(duel, p: int, id_list: Array) -> int:
	var n = 0
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.raw_id(duel, idx) in id_list:
			n += 1
	return n


static func _has_goblin_of_greed(duel) -> bool:
	return CustomDuelOps.has_faceup_id(duel, 0, 2986) or CustomDuelOps.has_faceup_id(duel, 1, 2986)


static func _collect_attr_indices_in_gy(duel, p: int, attr: int) -> Array[int]:
	var out: Array[int] = []
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
		if CustomDuelOps.is_monster(duel, idx) and CustomDuelOps.monster_attr(duel, idx) == attr:
			out.append(i)
	return out


static func _collect_monster_zones(duel, p: int, pred: Callable) -> Array[int]:
	var out: Array[int] = []
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and pred.call(duel, p, z, idx):
			out.append(z)
	return out


static func _find_any_in_piles(duel, p: int, locs: Array, target_ids: Array) -> int:
	for srcloc in locs:
		for tid in target_ids:
			var idx = CustomDuelOps.find_pile_index_by_id(duel, p, int(srcloc), int(tid))
			if idx >= 0:
				return idx
	return -1
