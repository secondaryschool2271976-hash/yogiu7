class_name CustomEffectsMonsters1
extends RefCounted
## Faithful implementations for all 184 custom Monster cards with internal_id < 2800 (2500..2795)
## across both Core (Duel / DuelMem) and Joey (JoeyEngine / JoeyMem).

const IDS: Array[int] = [
	2500, 2501, 2502, 2503, 2504, 2505, 2506, 2508, 2509, 2510,
	2511, 2512, 2513, 2514, 2515, 2516, 2518, 2519, 2523, 2524,
	2525, 2526, 2527, 2528, 2531, 2532, 2533, 2534, 2535, 2536,
	2537, 2538, 2539, 2540, 2541, 2542, 2543, 2544, 2545, 2546,
	2550, 2551, 2552, 2554, 2556, 2559, 2560, 2562, 2563, 2564,
	2565, 2567, 2568, 2569, 2570, 2572, 2573, 2574, 2575, 2578,
	2580, 2581, 2582, 2583, 2584, 2585, 2586, 2587, 2588, 2589,
	2590, 2591, 2592, 2593, 2594, 2595, 2596, 2600, 2601, 2602,
	2603, 2611, 2612, 2613, 2614, 2616, 2617, 2618, 2620, 2623,
	2624, 2625, 2626, 2627, 2628, 2630, 2633, 2634, 2635, 2636,
	2637, 2638, 2639, 2640, 2641, 2642, 2643, 2648, 2651, 2657,
	2660, 2661, 2662, 2663, 2664, 2665, 2667, 2668, 2669, 2670,
	2671, 2672, 2674, 2675, 2676, 2677, 2678, 2681, 2682, 2683,
	2684, 2685, 2687, 2688, 2689, 2690, 2691, 2692, 2693, 2694,
	2699, 2700, 2701, 2702, 2703, 2705, 2706, 2709, 2710, 2712,
	2713, 2721, 2723, 2728, 2730, 2731, 2732, 2733, 2735, 2738,
	2739, 2741, 2742, 2744, 2746, 2754, 2757, 2758, 2761, 2762,
	2763, 2765, 2767, 2768, 2770, 2771, 2772, 2777, 2778, 2782,
	2785, 2790, 2794, 2795,
]

const TOON_MONSTERS_M1 := [2667, 2668, 2669, 2670, 2671, 2672]
const SPIRIT_MONSTERS_M1 := [2675, 2700, 2701, 2703, 2730, 2732, 2733, 2735, 2763, 2767, 2768]
const MILLENNIUM_ST_MONSTERS := [2578, 2586, 2601, 2633, 2634]
const UNION_MONSTERS_M1 := [2690, 2692]


static func handles(cid: int) -> bool:
	return cid in IDS


static func is_spirit(cid: int) -> bool:
	return cid in SPIRIT_MONSTERS_M1


static func normal_tribute_requirement(cid: int) -> int:
	if cid in [2500, 2501, 2502, 2503, 2661, 2662, 2663]:
		return 3
	return -1


static func can_normal_summon(duel, p: int, cid: int, is_set := false) -> bool:
	p &= 1
	if cid in [2500, 2501, 2502, 2503, 2661, 2662, 2663] and is_set:
		return false
	if cid in [2504, 2505, 2508, 2509, 2512, 2515, 2516, 2518, 2525, 2527, 2528, 2573, 2574, 2575, 2581, 2585, 2589, 2593, 2594, 2595, 2602, 2624, 2625, 2627, 2635, 2637, 2639, 2642, 2648, 2657, 2669, 2677, 2682, 2683, 2706, 2790]:
		if cid == 2574 and not is_set:
			return CustomDuelOps.count_monsters(duel, p, false) >= 5
		if cid == 2581 and not is_set:
			return CustomDuelOps.count_monsters(duel, p, false) >= 2
		return false
	if cid == 2782: # Cave Dragon: Cannot be Normal Summoned while you control a monster.
		return CustomDuelOps.count_monsters(duel, p, false) == 0
	return true


static func can_special_summon(duel, p: int, cid: int, loc: int, _slot: int) -> bool:
	p &= 1
	var opp = 1 - p
	var pf = CustomDuelOps.pflags(duel, p)
	if int(pf.get("ss_lock_until_ep", -1)) == CustomDuelOps.turn_number(duel):
		if str(pf.get("ss_lock_kind", "")) == "divine" and cid not in CustomDuelOps.EGYPTIAN_GOD_IDS:
			return false
		if str(pf.get("ss_lock_kind", "")) == "machine":
			var idx_tmp = CustomDuelOps.card_idx(duel, cid)
			if CustomDuelOps.monster_race(duel, idx_tmp) != 7:
				return false
	if CustomDuelOps.free_monster_zone(duel, p) < 0 and cid not in [2505, 2508, 2513, 2518, 2554, 2589, 2594, 2624, 2625, 2627, 2628, 2635, 2639, 2648, 2657, 2669, 2677, 2790]:
		return false
	if cid in [2501, 2503, 2661, 2662, 2663, 2574, 2581] or cid in SPIRIT_MONSTERS_M1:
		return false
	if cid == 2744 and loc == CustomDuelOps.LOC_GRAVE: # Dark Ruler Ha Des: Cannot be Special Summoned from the GY
		return false
	match cid:
		2505: # Holactie: Tribute Slifer, Obelisk, Ra
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.has_faceup_id(duel, p, 2500) and CustomDuelOps.has_faceup_id(duel, p, 2501) and CustomDuelOps.has_faceup_id(duel, p, 2502)
		2508: # Armed Dragon LV10: Tribute Armed Dragon LV7
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.find_zone_of_id(duel, p, 2512, true) >= 0
		2509: # Armed Dragon LV10 White: Banish Armed Dragons field/GY total Lv=10
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2509) and _find_armed_lv10_combo(duel, p).size() > 0
		2513, 2514: # Armityle contact fusion (Uria + Hamon + Raviel)
			if loc != CustomDuelOps.LOC_FUSION:
				return false
			return (CustomDuelOps.find_zone_of_id(duel, p, 2677, true) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, 2594, true) >= 0) \
				and (CustomDuelOps.find_zone_of_id(duel, p, 2589, true) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, 2525, true) >= 0) \
				and (CustomDuelOps.find_zone_of_id(duel, p, 2624, true) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, 2595, true) >= 0)
		2515, 2527, 2528: # BLS Envoy / CED / Chaos Sorcerer (banish 1 LIGHT + 1 DARK from GY)
			return loc == CustomDuelOps.LOC_HAND and _find_attr_in_gy(duel, p, 1) >= 0 and _find_attr_in_gy(duel, p, 2) >= 0
		2516: # BLS Envoy of Evening Twilight: equal number LIGHT & DARK in GY (>0)
			if loc != CustomDuelOps.LOC_HAND:
				return false
			var lc = _count_attr_in_gy(duel, p, 1)
			var dc = _count_attr_in_gy(duel, p, 2)
			return lc > 0 and lc == dc
		2518: # Blue-Eyes Shining Dragon: Tribute 1 BEUD
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_BEUD, true) >= 0
		2531: # Cyber Dragon: only opp controls monster
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.count_monsters(duel, p, false) == 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2535: # Cyber Dragon Nachster: discard 1 other monster
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 2 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, s): return s != _slot and CustomDuelOps.is_monster(d, idx), false) >= 0
		2543: # DMG Magician's Apprentice: discard 1 card
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2543) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 2
		2554: # Egyptian God Slime (Extra Deck): Tribute 1 Lv10 Aqua with 0 ATK
			return loc == CustomDuelOps.LOC_FUSION and _find_god_slime_tribute(duel, p) >= 0
		2556: # Bubbleman: only card in hand
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 1
		2575: # Exodius: shuffle all monsters in GY into Deck
			return loc == CustomDuelOps.LOC_HAND and _count_monsters_in_gy(duel, p) > 0
		2582: # Gandora-G: control Shining Sarcophagus
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2582) and _has_shining_sarc(duel, p)
		2585: # Gigarays Gandora: send 2 other monsters from hand/field to GY
			return loc == CustomDuelOps.LOC_HAND and _count_other_monsters_hand_field(duel, p, _slot) >= 2
		2589: # Hamon: send 3 face-up Continuous Spells
			return loc == CustomDuelOps.LOC_HAND and _collect_faceup_st_sub(duel, p, 0x16, 4).size() >= 3
		2602: # Malefic Cyber End: banish Cyber End Dragon from Extra Deck
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2538) >= 0 and not _has_malefic_on_field(duel)
		2624: # Raviel: Tribute 3 Fiends
			return loc == CustomDuelOps.LOC_HAND and _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.monster_race(d, idx) == 3).size() >= 3
		2625: # Raviel Shimmering Scraper: Tribute 3 monsters
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.count_monsters(duel, p, false) >= 3
		2627: # Red-Eyes Darkness Dragon: Tribute 1 Red-Eyes Black Dragon
			return loc == CustomDuelOps.LOC_HAND and _find_red_eyes_zone(duel, p) >= 0
		2628: # Red-Eyes Darkness Metal Dragon: banish 1 face-up Dragon you control
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2628) and not CustomDuelOps.choose_zone(duel, p, func(d, pl, z, idx): return pl == p and z < 5 and CustomDuelOps.is_face_up(d, pl, z) and CustomDuelOps.monster_race(d, idx) == 1, false, false).is_empty()
		2635: # Silent Magician: Tribute 1 Spellcaster
			return loc == CustomDuelOps.LOC_HAND and not CustomDuelOps.choose_zone(duel, p, func(d, pl, z, idx): return pl == p and z < 5 and CustomDuelOps.monster_race(d, idx) == 18, false, false).is_empty()
		2639: # Silent Swordsman: Tribute 1 Warrior
			return loc == CustomDuelOps.LOC_HAND and not CustomDuelOps.choose_zone(duel, p, func(d, pl, z, idx): return pl == p and z < 5 and CustomDuelOps.monster_race(d, idx) == 15, false, false).is_empty()
		2648: # Sorcerer of Dark Magic: Tribute 2 Lv6+ Spellcasters
			return loc == CustomDuelOps.LOC_HAND and _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.monster_race(d, idx) == 18 and CustomDuelOps.monster_level(d, idx) >= 6).size() >= 2
		2657: # Legendary Exodia Incarnate: Tribute 1 Forbidden One
			return loc == CustomDuelOps.LOC_HAND and _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.FORBIDDEN_ONE_IDS).size() >= 1
		2668: # Toon Cyber Dragon
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.count_monsters(duel, p, false) == 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2669: # Toon Dark Magician Girl
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.has_toon_world(duel, p) and CustomDuelOps.count_monsters(duel, p, false) >= 1
		2677: # Uria: send 3 face-up Traps
			return loc == CustomDuelOps.LOC_HAND and _collect_faceup_st_sub(duel, p, 0x15, -1).size() >= 3
		2683: # Winged Kuriboh LV6: banish 1 E-HERO Fusion or Winged Kuriboh from hand/face-up field/GY
			return (loc == CustomDuelOps.LOC_HAND or loc == CustomDuelOps.LOC_GRAVE) and CustomDuelOps.can_hopt(duel, p, 2683) and _can_summon_wk6(duel, p, loc, _slot)
		2687: # XY-Dragon Cannon (2686 + 2690)
			return loc == CustomDuelOps.LOC_FUSION and _has_all_zones(duel, p, [2686, 2690])
		2688: # XYZ-Dragon Cannon (2686 + 2690 + 2692)
			return loc == CustomDuelOps.LOC_FUSION and _has_all_zones(duel, p, [2686, 2690, 2692])
		2689: # XZ-Tank Cannon (2686 + 2692)
			return loc == CustomDuelOps.LOC_FUSION and _has_all_zones(duel, p, [2686, 2692])
		2691: # YZ-Tank Dragon (2690 + 2692)
			return loc == CustomDuelOps.LOC_FUSION and _has_all_zones(duel, p, [2690, 2692])
		2706: # Gradius' Option: control face-up Gradius
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.has_faceup_id(duel, p, CustomDuelOps.NATIVE_GRADIUS)
		2790: # Lava Golem: Tribute 2 opp monsters to SS to opp field
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.count_monsters(duel, opp, false) >= 2 and int(pf.get("normal_summoned_turn", -1)) != CustomDuelOps.turn_number(duel)
	return false


static func special_summon(duel, p: int, cid: int, loc: int, slot: int) -> int:
	p &= 1
	var opp = 1 - p
	if not can_special_summon(duel, p, cid, loc, slot):
		return -1
	match cid:
		2505: # Holactie
			for req in [2500, 2501, 2502]:
				CustomDuelOps.tribute_zone(duel, p, CustomDuelOps.find_zone_of_id(duel, p, req, true))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2508: # Armed Dragon LV10
			CustomDuelOps.tribute_zone(duel, p, CustomDuelOps.find_zone_of_id(duel, p, 2512, true))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2509: # Armed Dragon LV10 White
			var combo = _find_armed_lv10_combo(duel, p)
			if combo.is_empty():
				return -1
			CustomDuelOps.mark_hopt(duel, p, 2509)
			for step in combo:
				if str(step["where"]) == "field":
					CustomDuelOps.banish_zone(duel, p, int(step["idx"]))
				else:
					CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, int(step["idx"]))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2513, 2514: # Armityle
			var uria = CustomDuelOps.find_zone_of_id(duel, p, 2677, true)
			if uria < 0: uria = CustomDuelOps.find_zone_of_id(duel, p, 2594, true)
			var hamon = CustomDuelOps.find_zone_of_id(duel, p, 2589, true)
			if hamon < 0: hamon = CustomDuelOps.find_zone_of_id(duel, p, 2525, true)
			var raviel = CustomDuelOps.find_zone_of_id(duel, p, 2624, true)
			if raviel < 0: raviel = CustomDuelOps.find_zone_of_id(duel, p, 2595, true)
			CustomDuelOps.banish_zone(duel, p, uria)
			CustomDuelOps.banish_zone(duel, p, hamon)
			CustomDuelOps.banish_zone(duel, p, raviel)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2515, 2527, 2528:
			var li = _find_attr_in_gy(duel, p, 1)
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, li)
			var di = _find_attr_in_gy(duel, p, 2)
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, di)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2516: # BLS Envoy Evening Twilight
			var attr = 1
			if _count_attr_in_gy(duel, p, 1) > 0:
				attr = 1
			while true:
				var gi = _find_attr_in_gy(duel, p, attr)
				if gi < 0:
					break
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				CustomDuelOps.zflags(duel, p, z)["evening_banished_attr"] = attr
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2518:
			CustomDuelOps.tribute_zone(duel, p, CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_BEUD, true))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2531, 2556, 2668:
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2535: # Nachster
			var di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, s): return s != slot and CustomDuelOps.is_monster(d, idx), false)
			if di < 0:
				return -1
			var new_slot = slot - 1 if di < slot else slot
			CustomDuelOps.discard_hand_slot(duel, p, di, 1)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, new_slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2543: # DMG Apprentice
			CustomDuelOps.mark_hopt(duel, p, 2543)
			var di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(_d, _idx, s): return s != slot, false)
			if di < 0:
				return -1
			var new_slot = slot - 1 if di < slot else slot
			CustomDuelOps.discard_hand_slot(duel, p, di, 1)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, new_slot, p, true, false)
			if z >= 0:
				CustomDuelOps.zflags(duel, p, z)["name_is_dmg"] = true
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2554: # Egyptian God Slime
			var tz = _find_god_slime_tribute(duel, p)
			if tz < 0:
				return -1
			CustomDuelOps.tribute_zone(duel, p, tz)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2575: # Exodius
			for i in range(CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE) - 1, -1, -1):
				var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
				if CustomDuelOps.is_monster(duel, idx):
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, i, p, CustomDuelOps.LOC_DECK)
			CustomDuelOps.shuffle_deck(duel, p)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2582: # Gandora-G
			CustomDuelOps.mark_hopt(duel, p, 2582)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2585: # Gigarays Gandora
			var sent = 0
			var fzs = _collect_monster_zones(duel, p, func(_d, _pl, _z, _idx): return true)
			while sent < 2 and not fzs.is_empty():
				CustomDuelOps.send_zone_to_gy(duel, p, fzs.pop_back())
				sent += 1
			var cur_slot = slot
			while sent < 2:
				var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, s): return s != cur_slot and CustomDuelOps.is_monster(d, idx), false)
				if hi < 0:
					break
				if hi < cur_slot:
					cur_slot -= 1
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, hi, p, CustomDuelOps.LOC_GRAVE)
				sent += 1
			var z = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, cur_slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2589, 2677:
			var sub = 4 if cid == 2589 else -1
			var cat = 0x16 if cid == 2589 else 0x15
			var zones = _collect_faceup_st_sub(duel, p, cat, sub)
			for i in 3:
				CustomDuelOps.send_zone_to_gy(duel, p, zones[i])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2602:
			var ei = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2538)
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_FUSION, ei)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2624, 2625:
			var zs = _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return cid == 2625 or CustomDuelOps.monster_race(d, idx) == 3)
			for i in 3:
				CustomDuelOps.tribute_zone(duel, p, zs[i])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2627:
			CustomDuelOps.tribute_zone(duel, p, _find_red_eyes_zone(duel, p))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2628:
			CustomDuelOps.mark_hopt(duel, p, 2628)
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 1, false, false)
			CustomDuelOps.banish_zone(duel, p, int(pick["z"]))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2635, 2639:
			var need_race = 18 if cid == 2635 else 15
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.monster_race(d, idx) == need_race, false, false)
			CustomDuelOps.tribute_zone(duel, p, int(pick["z"]))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2648:
			var zs = _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.monster_race(d, idx) == 18 and CustomDuelOps.monster_level(d, idx) >= 6)
			for i in 2:
				CustomDuelOps.tribute_zone(duel, p, zs[i])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2657:
			var zs = _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.FORBIDDEN_ONE_IDS)
			CustomDuelOps.tribute_zone(duel, p, zs[0])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2669:
			var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			CustomDuelOps.tribute_zone(duel, p, int(pick["z"]))
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2683: # Winged Kuriboh LV6
			CustomDuelOps.mark_hopt(duel, p, 2683)
			var cur_slot = slot
			var banished = false
			var pred_gy = func(d, idx, i):
				var rid = CustomDuelOps.raw_id(d, idx)
				return not (loc == CustomDuelOps.LOC_GRAVE and i == cur_slot) and (rid == 2681 or (rid in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.is_extra_deck_monster(d, idx)))
			var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, pred_gy, false)
			if gi >= 0:
				if loc == CustomDuelOps.LOC_GRAVE and gi < cur_slot:
					cur_slot -= 1
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
				banished = true
			if not banished:
				var pred_fz = func(d, pl, zz, idx):
					var rid = CustomDuelOps.raw_id(d, idx)
					return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and (rid == 2681 or (rid in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.is_extra_deck_monster(d, idx)))
				var fz = CustomDuelOps.choose_zone(duel, p, pred_fz, false, false)
				if not fz.is_empty():
					CustomDuelOps.banish_zone(duel, p, int(fz["z"]))
					banished = true
			if not banished:
				var pred_hand = func(d, idx, i):
					return not (loc == CustomDuelOps.LOC_HAND and i == cur_slot) and CustomDuelOps.raw_id(d, idx) == 2681
				var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, pred_hand, false)
				if hi >= 0:
					if loc == CustomDuelOps.LOC_HAND and hi < cur_slot:
						cur_slot -= 1
					CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi)
					banished = true
			if not banished:
				return -1
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, cur_slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2687, 2688, 2689, 2691:
			var mats = [2686, 2690] if cid == 2687 else ([2686, 2690, 2692] if cid == 2688 else ([2686, 2692] if cid == 2689 else [2690, 2692]))
			for m_id in mats:
				var mz = CustomDuelOps.find_zone_of_id(duel, p, m_id, true)
				if mz >= 0:
					CustomDuelOps.banish_zone(duel, p, mz)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0:
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2706: # Gradius' Option
			var gz = CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_GRADIUS, true)
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, p, true, false)
			if z >= 0 and gz >= 0:
				CustomDuelOps.zflags(duel, p, z)["gradius_link"] = gz
				on_summon_or_flip(duel, p, z, cid, "special")
			return z
		2790: # Lava Golem
			var opp_zs = _collect_monster_zones(duel, opp, func(_d, _pl, _z, _idx): return true)
			for i in 2:
				CustomDuelOps.tribute_zone(duel, opp, opp_zs[i])
			var z = CustomDuelOps.special_summon_from_pile(duel, p, loc, slot, opp, true, false)
			if z >= 0:
				CustomDuelOps.pflags(duel, p)["cannot_normal_summon_turn"] = CustomDuelOps.turn_number(duel)
				on_summon_or_flip(duel, opp, z, cid, "special")
			return z
	return -1


static func can_activate(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp = 1 - p
	var ev := str(ctx.get("event", "free"))
	var t = CustomDuelOps.turn_number(duel)
	if z >= 0 and z < 5 and loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.is_skill_drain_active(duel) and CustomDuelOps.is_face_up(duel, p, z):
		return false
	if z >= 0 and z < 5 and bool(CustomDuelOps.zflags(duel, p, z).get("negated", false)):
		return false
	match cid:
		2500: # Obelisk: Tribute 2 monsters, destroy all opp monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.count_monsters(duel, p, false) >= 3
		2501: # Ra: Pay 1000 LP destroy 1 monster (or LP->100 on summon handled in trigger)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_pay_lp(duel, p, 1000) and CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2503: # Sphere Mode: Tribute to SS Ra
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and (CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2501) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2501) >= 0)
		2504: # Immortal Phoenix: Pay 1000 LP send 1 monster to GY
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_pay_lp(duel, p, 1000) and CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2508: # Armed Dragon LV10: Send 1 hand card, destroy all face-up opp monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2511, 2512: # Armed Dragon LV5 / LV7
			if loc != CustomDuelOps.LOC_FIELD_MONSTER or CustomDuelOps.count_monsters(duel, opp, false) == 0:
				return false
			return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), true) >= 0
		2514: # Armityle Phantom of Fury: give control to opponent
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2514, z) and CustomDuelOps.free_monster_zone(duel, opp) >= 0
		2515, 2528: # BLS Envoy / Chaos Sorcerer banish 1 monster
			if loc != CustomDuelOps.LOC_FIELD_MONSTER or not CustomDuelOps.can_opt(duel, p, cid, z):
				return false
			if cid == 2515 and int(CustomDuelOps.zflags(duel, p, z).get("bls_effect_turn", -1)) == t:
				return false
			if cid == 2528:
				return CustomDuelOps.count_monsters(duel, opp, true) + CustomDuelOps.count_monsters(duel, p, true) > 0
			return CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2519: # BEUD God-Surpassing Servant
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP and (int(CustomDuelOps.zflags(duel, p, z).get("beud_uses_turn", -1)) != t or int(CustomDuelOps.zflags(duel, p, z).get("beud_uses_count", 0)) < 3)
		2524: # Breaker the Magical Warrior
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.get_counter(duel, p, z, "spell") >= 1 and (CustomDuelOps.count_st(duel, opp, true) + CustomDuelOps.count_st(duel, p, true)) > 0
		2525: # Calamity Hamon: reveal in hand add Sacred Beast Spell & discard 1
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2525) and _has_sacred_beast_st_in_deck(duel, p, true)
		2526: # Cerulean Sacred Phoenix: destroy Nephthys cards, destroy opp monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_hopt(duel, p, 2526) and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2527: # CED Envoy of End
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2527, z) and CustomDuelOps.can_pay_lp(duel, p, 1000) and int(CustomDuelOps.pflags(duel, p).get("ced_locked_turn", -1)) != t
		2532: # Cyber Dragon Core GY effect
			return loc == CustomDuelOps.LOC_GRAVE and CustomDuelOps.can_hopt(duel, p, 2532) and CustomDuelOps.count_monsters(duel, p, false) == 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.CYBER_DRAGON_IDS, true) >= 0
		2537: # Cyber Dragon Zwei: reveal Spell -> name becomes Cyber Dragon
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2537, z) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx), false) >= 0
		2539: # Cyber End Decisive Strike (Quick/Chain handled)
			return false
		2542: # DMG Dragon Knight: discard 1, destroy 1 face-up card
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2542, z) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return CustomDuelOps.is_face_up(d, pl, zz), true, true).is_empty()
		2545, 2546, 2593, 2635, 2638, 2639, 2643, 2648, 2660, 2741, 2772, 2785:
			# Chain negates
			if ev != "chain_negate":
				return false
			var is_sp := bool(ctx.get("is_spell", false))
			var is_tr := bool(ctx.get("is_trap", false))
			if cid == 2545:
				return is_sp and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0
			if cid == 2546:
				return is_sp and int(ctx.get("chain_p", -1)) == opp and CustomDuelOps.can_opt(duel, p, 2546, z)
			if cid in [2593]:
				return is_sp
			if cid in [2635, 2639]:
				return is_sp and CustomDuelOps.can_opt(duel, p, cid, z)
			if cid == 2638:
				return is_sp and int(ctx.get("chain_p", -1)) == opp and CustomDuelOps.can_hopt(duel, p, 2638) and _has_shining_sarc(duel, p)
			if cid == 2643:
				return int(ctx.get("chain_p", -1)) == opp and CustomDuelOps.can_hopt(duel, p, 2643) and bool(ctx.get("targets_sarc_or_mentor", false))
			if cid == 2648:
				return is_tr
			if cid == 2660:
				return (is_sp or is_tr) and CustomDuelOps.can_opt(duel, p, 2660, z)
			if cid == 2741:
				return is_tr and bool(ctx.get("is_normal_trap", true)) and CustomDuelOps.can_pay_lp(duel, p, 1000)
			if cid == 2772:
				return is_sp and bool(ctx.get("is_normal_spell", true)) and CustomDuelOps.can_pay_lp(duel, p, 1000)
			return false
		2560: # Flame Wingman - Infernal Rage: Tribute if Fusion w/ Normal -> SS E-HERO <= Lv7
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_hopt(duel, p, 2560) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.monster_level(d, idx) <= 7, true) >= 0
		2567: # E-HERO Tempest: send 1 other card you control to GY, protect 1 monster from battle
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and (CustomDuelOps.total_field_cards(duel, p) >= 2)
		2568: # E-HERO Thunder Giant: discard 1, destroy monster < ATK
			var my_atk = CustomDuelOps.eff_atk(duel, p, z)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2568, z) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz < 5 and not (pl == p and zz == z) and CustomDuelOps.base_atk(d, idx) < my_atk, true, true).is_empty()
		2569: # Voltic Thunder Tribute
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_hopt(duel, p, 2569) and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ELEMENTAL_HERO_IDS, true) >= 0
		2572: # Exiled Force
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.count_total_monsters_on_field(duel) >= 1
		2578, 2586, 2601, 2633, 2634: # Millennium monsters: hand -> Continuous Spell, or Continuous Spell -> SS
			if loc == CustomDuelOps.LOC_HAND:
				return CustomDuelOps.can_hopt(duel, p, cid) and CustomDuelOps.free_st_zone(duel, p) >= 0
			if loc == CustomDuelOps.LOC_FIELD_ST:
				var has_ankh = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2608) >= 0
				return CustomDuelOps.can_hopt(duel, p, cid) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and (has_ankh or CustomDuelOps.can_pay_lp(duel, p, 2000))
			return false
		2581, 2582, 2585: # Gandora / Gandora-G / Gigarays
			if cid == 2582 and not CustomDuelOps.can_hopt(duel, p, 2582):
				return false
			if cid == 2585 and not CustomDuelOps.can_opt(duel, p, 2585, z):
				return false
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.get_lp(duel, p) > 1
		2590: # Horus Black Flame Deity (hand reveal -> send 1, send 1 on field)
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2590) and _has_faceup_name(duel, p, "king's sarcophagus") and _has_archetype_on_field(duel, p, CustomDuelOps.HORUS_IDS)
		2594: # Inferno Uria: hand search Trap OR field Quick destroy S/T
			if loc == CustomDuelOps.LOC_HAND:
				return CustomDuelOps.can_hopt(duel, p, 2594) and _has_sacred_beast_st_in_deck(duel, p, false)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2594, z) and (CustomDuelOps.count_st(duel, opp, true) + CustomDuelOps.count_st(duel, p, true)) > 0
		2595: # Infinity Raviel: hand search SB monster OR field Tribute 2 SB destroy all opp monsters
			if loc == CustomDuelOps.LOC_HAND:
				return CustomDuelOps.can_hopt(duel, p, 2595) and _has_sacred_beast_monster_in_deck(duel, p, 2595)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2595, z) and _collect_monster_zones(duel, p, func(d, _pl, zz, idx): return zz != z and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SACRED_BEAST_IDS).size() >= 2
		2596: # King of the Swamp: discard to add Polymerization
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_POLYMERIZATION) >= 0
		2600: # Magical Scientist: pay 1000 LP, SS Lv<=6 Fusion
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_pay_lp(duel, p, 1000) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(d, idx, _s): return CustomDuelOps.monster_level(d, idx) <= 6, true) >= 0
		2612: # Millennium Seeker: GY swap target
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_hopt(duel, p, 2612) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0
		2613: # Millennium-Eyes Illusionist: discard -> equip opp monster to Relinquished/Eyes Restrict
			return loc == CustomDuelOps.LOC_HAND and CustomDuelOps.can_hopt(duel, p, 2613) and CustomDuelOps.free_st_zone(duel, p) >= 0 and _has_archetype_on_field(duel, p, CustomDuelOps.EYES_RESTRICT_IDS) and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2614: # Millennium-Eyes Restrict
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2614, z) and CustomDuelOps.free_st_zone(duel, p) >= 0 and (CustomDuelOps.count_monsters(duel, opp, false) > 0 or CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0)
		2624: # Raviel: Tribute 1 monster gain ATK
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2624, z) and CustomDuelOps.count_monsters(duel, p, false) >= 2
		2625: # Raviel Shimmering Scraper: hand discard double ATK OR GY tribute 1 add to hand
			if loc == CustomDuelOps.LOC_HAND:
				return CustomDuelOps.can_hopt(duel, p, 2625) and CustomDuelOps.has_faceup_id(duel, p, 2624)
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.can_hopt(duel, p, 2625) and CustomDuelOps.count_monsters(duel, p, false) > 0
			return false
		2626: # Reactor Slime: MP spawn 2 Tokens OR BP Quick Tribute set Metal Reflect Slime
			if loc != CustomDuelOps.LOC_FIELD_MONSTER or not CustomDuelOps.can_hopt(duel, p, 2626):
				return false
			if CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP:
				return CustomDuelOps.free_st_zone(duel, p) >= 0 and _find_metal_reflect(duel, p) >= 0
			return CustomDuelOps.free_monster_zone(duel, p) >= 0
		2628: # Red-Eyes Darkness Metal Dragon: SS 1 Dragon from hand or GY
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2628, z) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and (_find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 1, 2628) >= 0 or (not CustomDuelOps.is_necrovalley_active(duel) and _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 1, 2628) >= 0))
		2663: # The Wicked Eraser: MP self-destruct
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.turn_player(duel) == p
		2664: # Ra Sun God of Darkness: discard Sun God cards -> opp sends monsters
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2664, z) and CustomDuelOps.count_monsters(duel, opp, false) > 0 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SUN_GOD_IDS, false) >= 0
		2667: # Toon Cannon Soldier: Tribute 1 monster, 500 dmg
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.count_monsters(duel, p, false) >= 1
		2676: # Tyrant Burst Dragon: equip to 1 monster you control
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.free_st_zone(duel, p) >= 0 and CustomDuelOps.count_monsters(duel, p, true) >= 2
		2677: # Uria: destroy 1 Set S/T opp controls
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2677, z) and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and zz < 10 and not CustomDuelOps.is_face_up(d, pl, zz), false, true).is_empty()
		2682: # Winged Kuriboh LV10: Opp BP Tribute -> destroy ATK pos & burn
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP
		2685: # Winged Kuriboh Sabatiel LV10: reveal in hand pay half LP search Poly/Fusion OR opp turn LP<=1000 SS
			if loc != CustomDuelOps.LOC_HAND or not CustomDuelOps.can_hopt(duel, p, 2685):
				return false
			if CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.get_lp(duel, p) <= 1000 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				return true
			return CustomDuelOps.get_lp(duel, p) > 1 and _find_fusion_spell_in_deck(duel, p) >= 0
		2687, 2688, 2689, 2691: # Union Contact Fusions discard 1 -> destroy target
			if loc != CustomDuelOps.LOC_FIELD_MONSTER or CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 0:
				return false
			if cid == 2687:
				return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and CustomDuelOps.is_face_up(d, pl, zz), false, true).is_empty()
			if cid == 2688:
				return (CustomDuelOps.count_monsters(duel, opp, false) + CustomDuelOps.count_st(duel, opp, true)) > 0
			if cid == 2689:
				return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and zz < 10 and not CustomDuelOps.is_face_up(d, pl, zz), false, true).is_empty()
			return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and not CustomDuelOps.is_face_up(d, pl, zz), false, true).is_empty()
		2690, 2692: # Union equip/unequip
			if loc == CustomDuelOps.LOC_FIELD_MONSTER:
				return CustomDuelOps.can_opt(duel, p, cid, z) and CustomDuelOps.free_st_zone(duel, p) >= 0 and ((cid == 2690 and CustomDuelOps.has_faceup_id(duel, p, 2686)) or (cid == 2692 and (CustomDuelOps.has_faceup_id(duel, p, 2686) or CustomDuelOps.has_faceup_id(duel, p, 2690))))
			if loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.can_opt(duel, p, cid, z) and CustomDuelOps.free_monster_zone(duel, p) >= 0
			return false
		2705: # Woodland Sprite: send 1 Equip Card equipped to this card -> 500 dmg
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.equip_count_on_monster(duel, p, z) > 0
		2721: # Gray Wing: MP1 discard 1 -> double attack
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_M1 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and int(CustomDuelOps.zflags(duel, p, z).get("multi_atk_2", -1)) != t
		2742: # Possessed Dark Soul: Tribute -> take all opp face-up Lv<=3
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_level(d, idx) <= 3, false, true).is_empty()
		2758: # Spirit Ryu (Battle Step)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 1, false) >= 0
		2765: # Throwstone Unit: Tribute 1 Warrior, destroy monster w/ DEF <= this ATK
			var my_atk2 = CustomDuelOps.eff_atk(duel, p, z)
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.monster_race(d, idx) == 15).size() >= 1 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_def(d, pl, zz) <= my_atk2, true, true).is_empty()
		2778: # Winged Minion: Tribute -> +700 ATK/DEF to 1 Fiend
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz < 5 and not (pl == p and zz == z) and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 3, true, false).is_empty()
		2794: # Des Lacooda: flip face-down DEF
			return loc == CustomDuelOps.LOC_FIELD_MONSTER and CustomDuelOps.can_opt(duel, p, 2794, z)
	return false


static func resolve(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	match cid:
		2500: # Obelisk destroy all opp monsters
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and zz != z:
					pass
			var to_trib = _collect_monster_zones(duel, p, func(_d, _pl, zz, _idx): return zz != z)
			if to_trib.size() >= 2:
				CustomDuelOps.tribute_zone(duel, p, to_trib[0])
				CustomDuelOps.tribute_zone(duel, p, to_trib[1])
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
						CustomDuelOps.destroy_zone(duel, opp, zz)
				CustomDuelOps.zflags(duel, p, z)["cannot_atk_turn"] = t
		2501: # Ra pay 1000 LP destroy 1
			if CustomDuelOps.pay_lp(duel, p, 1000):
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return zz < 5 and not (pl == p and zz == z), true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2503: # Sphere Mode -> Tribute to SS Ra (4000/4000)
			var controller = p
			CustomDuelOps.tribute_zone(duel, controller, z)
			var ri = CustomDuelOps.find_pile_index_by_id(duel, controller, CustomDuelOps.LOC_HAND, 2501)
			var rloc = CustomDuelOps.LOC_HAND
			if ri < 0:
				ri = CustomDuelOps.find_pile_index_by_id(duel, controller, CustomDuelOps.LOC_DECK, 2501)
				rloc = CustomDuelOps.LOC_DECK
			if ri >= 0:
				var rz = CustomDuelOps.special_summon_from_pile(duel, controller, rloc, ri, controller, true, false)
				if rz >= 0:
					CustomDuelOps.set_stat_val(duel, controller, rz, 4000, 4000, false)
		2504: # Immortal Phoenix pay 1000 LP send 1 monster to GY
			if CustomDuelOps.pay_lp(duel, p, 1000):
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return zz < 5 and not (pl == p and zz == z), true, true)
				if not pick.is_empty():
					CustomDuelOps.send_zone_to_gy(duel, int(pick["p"]), int(pick["z"]))
		2508: # Armed Dragon LV10 send 1 card -> destroy all face-up opp
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz):
						CustomDuelOps.destroy_zone(duel, opp, zz)
		2511: # Armed Dragon LV5 send 1 monster -> destroy opp monster w/ ATK <= sent
			var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), true)
			if hi >= 0:
				var satk = CustomDuelOps.base_atk(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, hi))
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, hi, p, CustomDuelOps.LOC_GRAVE)
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_atk(d, pl, zz) <= satk, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2512: # Armed Dragon LV7 send 1 monster -> destroy all opp monsters w/ ATK <= sent
			var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), true)
			if hi >= 0:
				var satk = CustomDuelOps.base_atk(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, hi))
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, hi, p, CustomDuelOps.LOC_GRAVE)
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.eff_atk(duel, opp, zz) <= satk:
						CustomDuelOps.destroy_zone(duel, opp, zz)
		2514: # Phantom of Fury give control to opp
			CustomDuelOps.mark_opt(duel, p, 2514, z)
			var nz = CustomDuelOps.change_control(duel, p, z, opp, false)
			if nz >= 0:
				CustomDuelOps.zflags(duel, opp, nz)["control_changed_turn"] = t
				CustomDuelOps.zflags(duel, opp, nz)["orig_owner"] = p
		2515, 2528:
			CustomDuelOps.mark_opt(duel, p, cid, z)
			if cid == 2515:
				CustomDuelOps.zflags(duel, p, z)["bls_effect_turn"] = t
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and not (pl == p and zz == z) and (cid == 2515 or CustomDuelOps.is_face_up(d, pl, zz)), true, true)
			if not pick.is_empty():
				CustomDuelOps.banish_zone(duel, int(pick["p"]), int(pick["z"]))
			CustomDuelOps.zflags(duel, p, z)["cannot_atk_turn"] = t
		2519: # BEUD God-Surpassing Servant
			var zf = CustomDuelOps.zflags(duel, p, z)
			if int(zf.get("beud_uses_turn", -1)) != t:
				zf["beud_uses_turn"] = t
				zf["beud_uses_count"] = 0
			zf["beud_uses_count"] = int(zf.get("beud_uses_count", 0)) + 1
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and ((zz < 5 and t in CustomDuelOps.zflags(d, pl, zz).get("ss_turn_hist", [])) or not CustomDuelOps.is_face_up(d, pl, zz)), true, true)
			if not pick.is_empty():
				CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2524: # Breaker remove 1 spell counter -> destroy 1 S/T
			if CustomDuelOps.get_counter(duel, p, z, "spell") >= 1:
				CustomDuelOps.add_counter(duel, p, z, "spell", -1)
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz >= 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2525, 2594, 2595:
			if loc == CustomDuelOps.LOC_HAND:
				CustomDuelOps.mark_hopt(duel, p, cid)
				var di = -1
				if cid == 2525:
					di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.raw_id(d, idx) in [2548, 2577, 2629], true)
				elif cid == 2594:
					di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_trap(d, idx) and CustomDuelOps.raw_id(d, idx) in [2553, 2707], true)
				else:
					di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SACRED_BEAST_IDS and CustomDuelOps.raw_id(d, idx) != 2595, true)
				if di >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, di)
					if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
						CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
			elif cid == 2594:
				CustomDuelOps.mark_opt(duel, p, 2594, z)
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz >= 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
			elif cid == 2595:
				CustomDuelOps.mark_opt(duel, p, 2595, z)
				var sb = _collect_monster_zones(duel, p, func(d, _pl, zz, idx): return zz != z and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SACRED_BEAST_IDS)
				if sb.size() >= 2:
					CustomDuelOps.tribute_zone(duel, p, sb[0])
					CustomDuelOps.tribute_zone(duel, p, sb[1])
					var cnt = 0
					for zz in 5:
						if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.destroy_zone(duel, opp, zz):
							cnt += 1
					CustomDuelOps.add_stat_mod(duel, p, z, cnt * 1000, 0, false)
		2526: # Cerulean Sacred Phoenix
			CustomDuelOps.mark_hopt(duel, p, 2526)
			var dest = 0
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.raw_id(duel, CustomDuelOps.zone_idx(duel, p, zz)) in CustomDuelOps.NEPHTHYS_IDS:
					if CustomDuelOps.destroy_zone(duel, p, zz):
						dest += 1
						break
			if dest == 0:
				var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.NEPHTHYS_IDS, false)
				if hi >= 0:
					CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
					dest = 1
			for _k in dest:
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2527: # Chaos Emperor Dragon
			CustomDuelOps.mark_opt(duel, p, 2527, z)
			if CustomDuelOps.pay_lp(duel, p, 1000):
				CustomDuelOps.pflags(duel, p)["ced_locked_turn"] = t
				var opp_sent = 0
				for pl in 2:
					for zz in 11:
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							if CustomDuelOps.send_zone_to_gy(duel, pl, zz) and pl == opp:
								opp_sent += 1
					for hi in range(CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) - 1, -1, -1):
						if CustomDuelOps.move_pile_card(duel, pl, CustomDuelOps.LOC_HAND, hi, pl, CustomDuelOps.LOC_GRAVE) > 0 and pl == opp:
							opp_sent += 1
				CustomDuelOps.damage(duel, opp, opp_sent * 300, false)
		2532: # Cyber Dragon Core GY banish
			CustomDuelOps.mark_hopt(duel, p, 2532)
			var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2532)
			if gi >= 0:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
				var di = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.CYBER_DRAGON_IDS, true)
				if di >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, di, p, true, false)
		2537: # Cyber Dragon Zwei reveal Spell
			CustomDuelOps.mark_opt(duel, p, 2537, z)
			CustomDuelOps.zflags(duel, p, z)["name_cyber_dragon_turn"] = t
		2542: # DMG Dragon Knight discard 1 destroy 1 face-up
			CustomDuelOps.mark_opt(duel, p, 2542, z)
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return CustomDuelOps.is_face_up(d, pl, zz) and not (pl == p and zz == z), true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2545, 2546, 2593, 2635, 2638, 2639, 2643, 2648, 2660, 2741, 2772:
			var target_entry := int(ctx.get("target_entry", -1))
			if cid == 2545 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
			elif cid in [2546, 2635, 2639, 2660]:
				CustomDuelOps.mark_opt(duel, p, cid, z)
			elif cid in [2638, 2643]:
				CustomDuelOps.mark_hopt(duel, p, cid)
				var zf = CustomDuelOps.zflags(duel, p, z)
				zf["lv_bonus"] = int(zf.get("lv_bonus", 0)) + 1
			elif cid in [2741, 2772]:
				CustomDuelOps.pay_lp(duel, p, 1000)
			if target_entry >= 0:
				var destroy_neg = cid not in [2635, 2638, 2639, 2643, 2660, 2741, 2772]
				CustomDuelOps.negate_chain_entry(duel, target_entry, destroy_neg)
			if cid == 2546:
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, _zz, _idx): return pl == opp, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2560: # Infernal Rage Tribute -> SS E-HERO <= Lv7
			CustomDuelOps.mark_hopt(duel, p, 2560)
			CustomDuelOps.tribute_zone(duel, p, z)
			var ei = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.monster_level(d, idx) <= 7, true)
			if ei >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, ei, p, true, false)
		2567: # Tempest send 1 other card -> battle protect
			var pick_cost = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz != z, false, false)
			if not pick_cost.is_empty():
				CustomDuelOps.send_zone_to_gy(duel, p, int(pick_cost["z"]))
				CustomDuelOps.zflags(duel, p, z)["indest_battle"] = true
		2568: # Thunder Giant discard 1 destroy < ATK
			CustomDuelOps.mark_opt(duel, p, 2568, z)
			var my_atk = CustomDuelOps.eff_atk(duel, p, z)
			CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz < 5 and not (pl == p and zz == z) and CustomDuelOps.base_atk(d, idx) < my_atk, true, true)
			if not pick.is_empty():
				CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2569: # Voltic Thunder
			CustomDuelOps.mark_hopt(duel, p, 2569)
			CustomDuelOps.tribute_zone(duel, p, z)
			var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ELEMENTAL_HERO_IDS, true)
			if gi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		2572: # Exiled Force
			CustomDuelOps.tribute_zone(duel, p, z)
			var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true)
			if not pick.is_empty():
				CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2578, 2586, 2601, 2633, 2634: # Millennium hand <-> S/T
			CustomDuelOps.mark_hopt(duel, p, cid)
			if loc == CustomDuelOps.LOC_HAND:
				var slot_i := int(ctx.get("hand_slot", CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, cid)))
				if slot_i >= 0:
					CustomDuelOps.set_st_from_pile(duel, p, CustomDuelOps.LOC_HAND, slot_i, p, true)
			elif loc == CustomDuelOps.LOC_FIELD_ST:
				var has_ankh = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2608) >= 0
				if has_ankh or CustomDuelOps.pay_lp(duel, p, 2000):
					var mz = CustomDuelOps.free_monster_zone(duel, p)
					if mz >= 0:
						var tmp: int = duel.m.local(4)
						duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, z))
						if CustomDuelOps.is_joey(duel):
							duel.f570790(p, z, 0)
							duel.f568610(p, mz, tmp, 1, 0)
						else:
							duel.f542c40(p, z)
							duel.f5422b0(p, mz, tmp, 0, 1)
							duel.m.set_u8(DuelMem.zone(p, mz) + 6, duel.m.u8(DuelMem.zone(p, mz) + 6) | 2)
						if cid == 2578:
							var best = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true)
							if not best.is_empty():
								CustomDuelOps.heal(duel, p, int(CustomDuelOps.eff_atk(duel, int(best["p"]), int(best["z"])) / 2))
						elif cid == 2586:
							var wi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2680)
							if wi >= 0:
								CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, wi)
						elif cid == 2633:
							var mi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.MILLENNIUM_IDS and CustomDuelOps.is_monster(d, idx), true)
							if mi >= 0:
								CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, mi)
						elif cid == 2634:
							var ai = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2608)
							if ai >= 0:
								CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, ai)
		2581, 2582: # Gandora / Gandora-G pay half LP banish all other cards
			if cid == 2582:
				CustomDuelOps.mark_hopt(duel, p, 2582)
			CustomDuelOps.pay_half_lp(duel, p)
			var cnt = 0
			for pl in 2:
				for zz in 11:
					if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						if CustomDuelOps.banish_zone(duel, pl, zz):
							cnt += 1
			if cid == 2581:
				CustomDuelOps.add_stat_mod(duel, p, z, cnt * 300, 0, false)
			elif cid == 2582 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SHINING_SARC_IDS and CustomDuelOps.monster_level(d, idx) <= 7, true)
				if si >= 0:
					var sz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, si, p, true, false)
					if sz >= 0:
						CustomDuelOps.zflags(duel, p, sz)["lv_bonus"] = int(CustomDuelOps.zflags(duel, p, sz).get("lv_bonus", 0)) + cnt
		2585: # Gigarays Gandora
			CustomDuelOps.mark_opt(duel, p, 2585, z)
			CustomDuelOps.pay_half_lp(duel, p)
			var g_count = _count_distinct_ids_in_gy(duel, p, CustomDuelOps.GANDORA_IDS)
			for pl in 2:
				for zz in 11:
					if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						if g_count >= 2:
							CustomDuelOps.banish_zone(duel, pl, zz)
						else:
							CustomDuelOps.destroy_zone(duel, pl, zz)
			if g_count >= 3:
				for pl in 2:
					for gi in range(CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE) - 1, -1, -1):
						CustomDuelOps.banish_from_pile(duel, pl, CustomDuelOps.LOC_GRAVE, gi)
		2590: # Horus Deity
			CustomDuelOps.mark_hopt(duel, p, 2590)
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 2:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, _zz, _idx): return true, true, true)
				if not pick.is_empty():
					CustomDuelOps.send_zone_to_gy(duel, int(pick["p"]), int(pick["z"]))
		2596: # King of the Swamp discard -> add Polymerization
			var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2596)
			if hi >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
				var pi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_POLYMERIZATION)
				if pi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, pi)
		2600: # Magical Scientist
			if CustomDuelOps.pay_lp(duel, p, 1000):
				var fi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(d, idx, _s): return CustomDuelOps.monster_level(d, idx) <= 6, true)
				if fi >= 0:
					var fz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p, true, false)
					if fz >= 0:
						CustomDuelOps.zflags(duel, p, fz)["cannot_direct_turn"] = t
						CustomDuelOps.zflags(duel, p, fz)["return_extra_ep"] = t
		2612: # Millennium Seeker
			CustomDuelOps.mark_hopt(duel, p, 2612)
			var gi = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), true)
			if gi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		2613, 2614:
			if cid == 2613:
				CustomDuelOps.mark_hopt(duel, p, 2613)
				var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2613)
				if hi >= 0:
					CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
			else:
				CustomDuelOps.mark_opt(duel, p, 2614, z)
			var ez = CustomDuelOps.find_zone_of_id(duel, p, 2614, true)
			if ez < 0: ez = CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_RELINQUISHED, true)
			if ez >= 0:
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
				if not pick.is_empty():
					var tidx = CustomDuelOps.zone_idx(duel, opp, int(pick["z"]))
					var eq_z = CustomDuelOps.free_st_zone(duel, p)
					if eq_z >= 0 and tidx > 0:
						var tatk = CustomDuelOps.base_atk(duel, tidx)
						var tdef = CustomDuelOps.base_def(duel, tidx)
						var tmp: int = duel.m.local(4)
						duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, opp, int(pick["z"])))
						if CustomDuelOps.is_joey(duel):
							duel.f570790(opp, int(pick["z"]), 0)
							duel.f5686e0(p, eq_z, tmp, 1)
						else:
							duel.f542c40(opp, int(pick["z"]))
							duel.f5423a0(p, eq_z - 5, tmp, 1)
						CustomDuelOps.link_equip(duel, p, eq_z, p, ez)
						CustomDuelOps.add_stat_mod(duel, p, ez, tatk, tdef, false)
		2624: # Raviel Tribute 1 -> gain ATK until EP
			CustomDuelOps.mark_opt(duel, p, 2624, z)
			var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5 and zz != z, false, false)
			if not pick.is_empty():
				var gain = CustomDuelOps.base_atk(duel, int(pick["idx"]))
				CustomDuelOps.tribute_zone(duel, p, int(pick["z"]))
				CustomDuelOps.add_stat_mod(duel, p, z, gain, 0, true)
		2625: # Raviel Shimmering Scraper
			CustomDuelOps.mark_hopt(duel, p, 2625)
			if loc == CustomDuelOps.LOC_HAND:
				var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2625)
				if hi >= 0:
					CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
					var rz = CustomDuelOps.find_zone_of_id(duel, p, 2624, true)
					if rz >= 0:
						var cur = CustomDuelOps.eff_atk(duel, p, rz)
						CustomDuelOps.add_stat_mod(duel, p, rz, cur, 0, true)
						CustomDuelOps.zflags(duel, p, rz)["attack_all_turn"] = t
			elif loc == CustomDuelOps.LOC_GRAVE:
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
				if not pick.is_empty():
					CustomDuelOps.tribute_zone(duel, p, int(pick["z"]))
					var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2625)
					if gi >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, gi)
		2626: # Reactor Slime
			CustomDuelOps.mark_hopt(duel, p, 2626)
			if CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP:
				CustomDuelOps.tribute_zone(duel, p, z)
				for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
					var si = CustomDuelOps.find_pile_index_by_id(duel, p, srcloc, 2606)
					if si >= 0:
						var tz = CustomDuelOps.set_st_from_pile(duel, p, srcloc, si, p, false)
						if tz >= 5:
							CustomDuelOps.zflags(duel, p, tz)["can_activate_set_turn"] = t
						break
			else:
				for _i in 2:
					CustomDuelOps.spawn_token(duel, p, 0, false, 500, 500)
				CustomDuelOps.pflags(duel, p)["ss_lock_until_ep"] = t
				CustomDuelOps.pflags(duel, p)["ss_lock_kind"] = "divine"
		2628: # Red-Eyes Darkness Metal Dragon
			CustomDuelOps.mark_opt(duel, p, 2628, z)
			var si = _find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 1, 2628)
			if si >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, si, p, true, false)
			elif not CustomDuelOps.is_necrovalley_active(duel):
				si = _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 1, 2628)
				if si >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, si, p, true, false)
		2663: # Wicked Eraser self-destruct
			CustomDuelOps.destroy_zone(duel, p, z)
		2664: # Sun God of Darkness
			CustomDuelOps.mark_opt(duel, p, 2664, z)
			var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.SUN_GOD_IDS, false)
			if hi >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.send_zone_to_gy(duel, opp, int(pick["z"]))
		2667: # Toon Cannon Soldier
			var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			if not pick.is_empty():
				CustomDuelOps.tribute_zone(duel, p, int(pick["z"]))
				CustomDuelOps.damage(duel, opp, 500, false)
		2676: # Tyrant Burst Dragon equip
			var pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5 and zz != z, true, false)
			var eq_z = CustomDuelOps.free_st_zone(duel, p)
			if not pick.is_empty() and eq_z >= 0:
				var tz := int(pick["z"])
				var tmp: int = duel.m.local(4)
				duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, z))
				if CustomDuelOps.is_joey(duel):
					duel.f570790(p, z, 0)
					duel.f5686e0(p, eq_z, tmp, 1)
				else:
					duel.f542c40(p, z)
					duel.f5423a0(p, eq_z - 5, tmp, 1)
				CustomDuelOps.link_equip(duel, p, eq_z, p, tz)
		2677: # Uria destroy 1 Set S/T
			CustomDuelOps.mark_opt(duel, p, 2677, z)
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and zz < 10 and not CustomDuelOps.is_face_up(d, pl, zz), false, true)
			if not pick.is_empty():
				CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2682: # Winged Kuriboh LV10 nuke
			CustomDuelOps.tribute_zone(duel, p, z)
			var total = 0
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_atk_pos(duel, opp, zz):
					var batk = CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, opp, zz))
					if CustomDuelOps.destroy_zone(duel, opp, zz):
						total += batk
			CustomDuelOps.damage(duel, opp, total, false)
		2685: # Winged Kuriboh Sabatiel LV10
			CustomDuelOps.mark_hopt(duel, p, 2685)
			if CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.get_lp(duel, p) <= 1000:
				var hi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2685)
				if hi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
					var best = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
					if not best.is_empty():
						CustomDuelOps.damage(duel, opp, CustomDuelOps.eff_atk(duel, opp, int(best["z"])), false)
			else:
				CustomDuelOps.pay_half_lp(duel, p)
				var fi = _find_fusion_spell_in_deck(duel, p)
				if fi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, fi)
				var hi2 = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2685)
				if hi2 >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, hi2, p, CustomDuelOps.LOC_DECK)
					CustomDuelOps.shuffle_deck(duel, p)
		2687, 2688, 2689, 2691:
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
				var pick = {}
				if cid == 2687:
					pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and CustomDuelOps.is_face_up(d, pl, zz), false, true)
				elif cid == 2688:
					pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, _zz, _idx): return pl == opp, true, true)
				elif cid == 2689:
					pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz >= 5 and zz < 10 and not CustomDuelOps.is_face_up(d, pl, zz), false, true)
				else:
					pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and not CustomDuelOps.is_face_up(d, pl, zz), false, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, int(pick["z"]))
		2690, 2692: # Union equip / unequip
			CustomDuelOps.mark_opt(duel, p, cid, z)
			if loc == CustomDuelOps.LOC_FIELD_MONSTER:
				var tz = CustomDuelOps.find_zone_of_id(duel, p, 2686, true)
				if tz < 0 and cid == 2692:
					tz = CustomDuelOps.find_zone_of_id(duel, p, 2690, true)
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
			elif loc == CustomDuelOps.LOC_FIELD_ST:
				var mz = CustomDuelOps.free_monster_zone(duel, p)
				if mz >= 0:
					var tmp: int = duel.m.local(4)
					duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, z))
					if CustomDuelOps.is_joey(duel):
						duel.f570790(p, z, 0)
						duel.f568610(p, mz, tmp, 1, 0)
					else:
						duel.f542c40(p, z)
						duel.f5422b0(p, mz, tmp, 0, 1)
						duel.m.set_u8(DuelMem.zone(p, mz) + 6, duel.m.u8(DuelMem.zone(p, mz) + 6) | 2)
		2705: # Woodland Sprite
			var st = CustomDuelOps.state(duel)
			for ek in st["equip_links"].keys():
				var link: Dictionary = st["equip_links"][ek]
				if int(link.get("target_p", -1)) == p and int(link.get("target_z", -1)) == z:
					var parts := str(ek).split(":")
					CustomDuelOps.send_zone_to_gy(duel, int(parts[0]), int(parts[1]))
					CustomDuelOps.damage(duel, opp, 500, false)
					break
		2721: # Gray Wing
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0, 1)
				CustomDuelOps.zflags(duel, p, z)["multi_atk_2"] = t
		2742: # Possessed Dark Soul
			CustomDuelOps.tribute_zone(duel, p, z)
			for zz in 5:
				var idx = CustomDuelOps.zone_idx(duel, opp, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.monster_level(duel, idx) <= 3:
					CustomDuelOps.change_control(duel, opp, zz, p, false)
		2758: # Spirit Ryu
			var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 1, false)
			if hi >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, hi, 1)
				CustomDuelOps.add_stat_mod(duel, p, z, 1000, 1000, true)
		2765: # Throwstone Unit
			var wz = _collect_monster_zones(duel, p, func(d, _pl, _z, idx): return CustomDuelOps.monster_race(d, idx) == 15)
			if not wz.is_empty():
				var my_atk = CustomDuelOps.eff_atk(duel, p, z)
				CustomDuelOps.tribute_zone(duel, p, wz[0])
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_def(d, pl, zz) <= my_atk, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2778: # Winged Minion
			CustomDuelOps.tribute_zone(duel, p, z)
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 3, true, false)
			if not pick.is_empty():
				CustomDuelOps.add_stat_mod(duel, int(pick["p"]), int(pick["z"]), 700, 700, false)
		2794: # Des Lacooda
			CustomDuelOps.mark_opt(duel, p, 2794, z)
			CustomDuelOps.change_position(duel, p, z, 1, 0)


static func on_summon_or_flip(duel, p: int, z: int, cid: int, kind: String) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	var zf = CustomDuelOps.zflags(duel, p, z)
	zf["summoned_turn"] = t
	if kind == "special":
		var hist: Array = zf.get("ss_turn_hist", [])
		hist.append(t)
		zf["ss_turn_hist"] = hist
	if cid in SPIRIT_MONSTERS_M1 and (kind == "normal" or kind == "tribute" or kind == "flip_summon" or kind == "flipped"):
		zf["spirit_return_turn"] = t

	# Reactive Slifer on opponent's summoned Attack Position monster
	if (kind == "normal" or kind == "tribute" or kind == "special") and CustomDuelOps.is_atk_pos(duel, p, z) and CustomDuelOps.has_faceup_id(duel, opp, 2502):
		if not CustomDuelOps.is_skill_drain_active(duel):
			CustomDuelOps.add_stat_mod(duel, p, z, -2000, 0, false)
			if CustomDuelOps.eff_atk(duel, p, z) <= 0:
				CustomDuelOps.destroy_zone(duel, p, z)
				return

	# Reactive Cyber Dragon Vier when Cyber Dragon is Summoned
	if cid in CustomDuelOps.CYBER_DRAGON_IDS and CustomDuelOps.can_hopt(duel, p, 2536) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
		var vi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2536)
		if vi >= 0:
			var vier_run := func() -> void:
				var vi2: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2536)
				if vi2 >= 0 and CustomDuelOps.can_hopt(duel, p, 2536) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
					CustomDuelOps.mark_hopt(duel, p, 2536)
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, vi2, p, true, true)
			CustomDuelOps.optional_effect(duel, p, 2536, vier_run)

	# Reactive Millennium-Eyes Illusionist in GY when Relinquished/Eyes Restrict is Special Summoned
	if kind == "special" and cid in CustomDuelOps.EYES_RESTRICT_IDS and CustomDuelOps.can_hopt(duel, p, 2613) and not CustomDuelOps.is_necrovalley_active(duel):
		var mi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2613)
		if mi >= 0:
			CustomDuelOps.mark_hopt(duel, p, 2613)
			CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, mi)

	# Reactive Wicked Avatar normal summon lockdown
	if cid == 2661 and kind == "tribute":
		CustomDuelOps.pflags(duel, opp)["cannot_activate_st_until_turn"] = t + 3

	if CustomDuelOps.is_skill_drain_active(duel):
		return

	match cid:
		2501: # Ra LP -> 100 ATK boost on Normal/Tribute Summon
			if kind == "normal" or kind == "tribute":
				var cur_lp = CustomDuelOps.get_lp(duel, p)
				if cur_lp > 100:
					var pay = cur_lp - 100
					CustomDuelOps.set_lp(duel, p, 100)
					CustomDuelOps.record_lp_paid(duel, p, pay)
					CustomDuelOps.add_stat_mod(duel, p, z, pay, pay, false)
		2503: # Sphere Mode: shift to owner at next turn EP
			CustomDuelOps.schedule_delayed(duel, t + 1, CustomDuelOps.PHASE_EP, p, 2503, "return_sphere", {"z": z, "orig_p": 1 - p})
		2506: # Amulet Dragon: banish Spells from GYs +100 each
			if kind == "special" and not CustomDuelOps.is_necrovalley_active(duel):
				var ban = 0
				for pl in 2:
					for gi in range(CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE) - 1, -1, -1):
						if CustomDuelOps.is_spell(duel, CustomDuelOps.pile_idx(duel, pl, CustomDuelOps.LOC_GRAVE, gi)):
							CustomDuelOps.banish_from_pile(duel, pl, CustomDuelOps.LOC_GRAVE, gi)
							ban += 1
				CustomDuelOps.add_stat_mod(duel, p, z, ban * 100, 0, false)
		2516: # BLS Envoy Evening Twilight
			if kind == "special":
				CustomDuelOps.pflags(duel, p)["skip_bp_turn"] = t
				var battr := int(zf.get("evening_banished_attr", 1))
				if battr == 1:
					var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true)
					if not pick.is_empty():
						CustomDuelOps.banish_zone(duel, int(pick["p"]), int(pick["z"]))
				elif CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0:
					CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_HAND, 0)
		2523: # Brain Controller: search Brain Control
			if CustomDuelOps.can_hopt(duel, p, 2523) and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2522) >= 0:
				var bc_run := func() -> void:
					var bi: int = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2522)
					if bi >= 0 and CustomDuelOps.can_hopt(duel, p, 2523):
						CustomDuelOps.mark_hopt(duel, p, 2523)
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, bi)
				CustomDuelOps.optional_effect(duel, p, 2523, bc_run)
		2524: # Breaker: +1 Spell Counter
			if kind == "normal" or kind == "tribute":
				CustomDuelOps.add_counter(duel, p, z, "spell", 1)
		2532: # Cyber Dragon Core: Normal Summon -> add Cyber S/T or Cyber support
			if kind == "normal" and CustomDuelOps.can_hopt(duel, p, 2532):
				var pred_cyber = func(d, idx, _s):
					var nm = CustomDuelOps.card_name(d, CustomDuelOps.raw_id(d, idx)).to_lower()
					return (CustomDuelOps.is_spell(d, idx) or CustomDuelOps.is_trap(d, idx)) and nm.find("cyber") >= 0
				if CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, pred_cyber, false) >= 0:
					var cc_run := func() -> void:
						var si: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, pred_cyber, false)
						if si >= 0 and CustomDuelOps.can_hopt(duel, p, 2532):
							CustomDuelOps.mark_hopt(duel, p, 2532)
							CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, si)
					CustomDuelOps.optional_effect(duel, p, 2532, cc_run)
		2533: # Cyber Dragon Drei: Normal -> Cyber Dragons Lv5
			if kind == "normal":
				var drei_run := func() -> void:
					for zz in 5:
						if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.CYBER_DRAGON_IDS:
							CustomDuelOps.zflags(duel, p, zz)["set_level_5"] = true
					CustomDuelOps.pflags(duel, p)["ss_lock_until_ep"] = t
					CustomDuelOps.pflags(duel, p)["ss_lock_kind"] = "machine"
				CustomDuelOps.optional_effect(duel, p, 2533, drei_run)
		2534: # Cyber Dragon Herz: SS -> Lv5
			if kind == "special" and CustomDuelOps.can_hopt(duel, p, 2534):
				var herz_run := func() -> void:
					if not CustomDuelOps.can_hopt(duel, p, 2534):
						return
					CustomDuelOps.mark_hopt(duel, p, 2534)
					zf["set_level_5_turn"] = t
					CustomDuelOps.pflags(duel, p)["ss_lock_until_ep"] = t
					CustomDuelOps.pflags(duel, p)["ss_lock_kind"] = "machine"
				CustomDuelOps.optional_effect(duel, p, 2534, herz_run)
		2535: # Nachster: SS 2100 ATK/DEF Machine from GY
			if not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.can_hopt(duel, p, 2535):
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 7 and (CustomDuelOps.base_atk(d, idx) == 2100 or CustomDuelOps.base_def(d, idx) == 2100), true)
				if gi >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
					var nach_run := func() -> void:
						if not CustomDuelOps.can_hopt(duel, p, 2535):
							return
						var gi2: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 7 and (CustomDuelOps.base_atk(d, idx) == 2100 or CustomDuelOps.base_def(d, idx) == 2100), true)
						if gi2 < 0 or CustomDuelOps.free_monster_zone(duel, p) < 0:
							return
						CustomDuelOps.mark_hopt(duel, p, 2535)
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi2, p, true, false)
						CustomDuelOps.pflags(duel, p)["ss_lock_until_ep"] = t
						CustomDuelOps.pflags(duel, p)["ss_lock_kind"] = "machine"
					CustomDuelOps.optional_effect(duel, p, 2535, nach_run)
		2539: # Cyber End Decisive Strike: search Limiter Removal for 4000 LP
			if kind == "special" and CustomDuelOps.can_hopt(duel, p, 2539) and CustomDuelOps.can_pay_lp(duel, p, 4000):
				var li = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.name_matches(d, idx, "limiter removal"), true)
				if li >= 0:
					CustomDuelOps.mark_hopt(duel, p, 2539)
					CustomDuelOps.pay_lp(duel, p, 4000)
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, li)
		2543: # DMG Apprentice: add Shining Sarcophagus
			if CustomDuelOps.can_hopt(duel, p, 2543):
				CustomDuelOps.mark_hopt(duel, p, 2543)
		2551: # Doom Virus Dragon: Crush Card Virus effect
			if kind == "special":
				CustomDuelOps.pflags(duel, opp)["crush_virus_until_turn"] = t + 6
				for zz in 5:
					var idx = CustomDuelOps.zone_idx(duel, opp, zz)
					if idx != 0 and CustomDuelOps.eff_atk(duel, opp, zz) >= 1500:
						CustomDuelOps.destroy_zone(duel, opp, zz)
				for hi in range(CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) - 1, -1, -1):
					var hidx = CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_HAND, hi)
					if CustomDuelOps.is_monster(duel, hidx) and CustomDuelOps.base_atk(duel, hidx) >= 1500:
						CustomDuelOps.move_pile_card(duel, opp, CustomDuelOps.LOC_HAND, hi, opp, CustomDuelOps.LOC_GRAVE)
		2556: # Bubbleman: draw 2 if only card
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 0 and CustomDuelOps.total_field_cards(duel, p) == 1:
				var bub_run := func() -> void:
					if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 0 and CustomDuelOps.total_field_cards(duel, p) == 1:
						CustomDuelOps.draw(duel, p, 2)
				CustomDuelOps.optional_effect(duel, p, 2556, bub_run)
		2560: # Flame Wingman Infernal Rage: add Favorite card
			if kind == "special" and CustomDuelOps.can_hopt(duel, p, 2560):
				var fi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2683)
				if fi >= 0:
					CustomDuelOps.mark_hopt(duel, p, 2560)
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, fi)
		2569: # Voltic Thunder: if opp has more cards, nuke field
			if kind == "special" and CustomDuelOps.can_hopt(duel, p, 2569) and CustomDuelOps.total_field_cards(duel, opp) > CustomDuelOps.total_field_cards(duel, p):
				CustomDuelOps.mark_hopt(duel, p, 2569)
				for pl in 2:
					for zz in 11:
						if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							CustomDuelOps.destroy_zone(duel, pl, zz)
		2583: # Gandora-X Blackmetal Rampaging Dragon
			if kind == "special" and CustomDuelOps.can_hopt(duel, p, 2583) and CustomDuelOps.get_lp(duel, p) > 1:
				CustomDuelOps.mark_hopt(duel, p, 2583)
				CustomDuelOps.pay_half_lp(duel, p)
				var max_atk = 0
				for pl in 2:
					for zz in 5:
						if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							var oa = CustomDuelOps.eff_atk(duel, pl, zz) if (pl == opp and CustomDuelOps.is_face_up(duel, pl, zz)) else 0
							if CustomDuelOps.destroy_zone(duel, pl, zz) and oa > max_atk:
								max_atk = oa
				if max_atk > 0:
					CustomDuelOps.damage(duel, opp, max_atk, false)
					CustomDuelOps.add_stat_mod(duel, p, z, max_atk, 0, false)
		2584: # Gandora-X Dragon of Demolition
			if kind != "flip_summon" and kind != "flipped":
				var gx_run := func() -> void:
					if CustomDuelOps.zone_id(duel, p, z) != 2584:
						return
					var max_o: int = 0
					for pl in 2:
						for zz in 5:
							if not (pl == p and zz == z) and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
								var ba: int = CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, pl, zz)) if CustomDuelOps.is_face_up(duel, pl, zz) else 0
								if CustomDuelOps.destroy_zone(duel, pl, zz) and ba > max_o:
									max_o = ba
					var dealt: int = CustomDuelOps.damage(duel, opp, max_o, false)
					CustomDuelOps.set_stat_val(duel, p, z, dealt, -1, false)
				CustomDuelOps.optional_effect(duel, p, 2584, gx_run)
		2587: # Granmarg: Tribute Summon destroy 1 Set card
			if kind == "tribute":
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return not CustomDuelOps.is_face_up(d, pl, zz), false, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2617: # Mobius: Tribute Summon destroy up to 2 S/T
			if kind == "tribute" and not CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz >= 5, true, true).is_empty():
				var mob_run := func() -> void:
					for _i in 2:
						var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz >= 5, true, true)
						if pick.is_empty():
							break
						CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
				CustomDuelOps.optional_effect(duel, p, 2617, mob_run)
		2665: # Thestalos: Tribute Summon discard 1 random & burn lv*100
			if kind == "tribute" and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0:
				var hi = 0
				var hidx = CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_HAND, hi)
				var dmg = CustomDuelOps.monster_level(duel, hidx) * 100 if CustomDuelOps.is_monster(duel, hidx) else 0
				CustomDuelOps.discard_hand_slot(duel, opp, hi, 1)
				if dmg > 0:
					CustomDuelOps.damage(duel, opp, dmg, false)
		2675: # Tsukuyomi: Normal/Flipped -> Book of Moon 1 monster
			if kind != "special":
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
				if not pick.is_empty():
					CustomDuelOps.change_position(duel, int(pick["p"]), int(pick["z"]), 1, 0)
		2693: # Zaborg: Tribute Summon destroy 1 monster
			if kind == "tribute":
				var pick = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5, true, true)
				if not pick.is_empty():
					CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2699: # Hunter with 7 Weapons: declare most common opp race (default Warrior/Dragon)
			if kind == "normal" or kind == "tribute":
				var best_r = 1
				var opp_pick = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
				if not opp_pick.is_empty():
					best_r = CustomDuelOps.monster_race(duel, int(opp_pick["idx"]))
				zf["declared_race"] = best_r
		2702: # Marauding Captain: Normal Summon -> SS Lv<=4 from hand
			if kind == "normal" and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var mc_pred := func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_level(d, idx) <= 4
				if CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, mc_pred, true) >= 0:
					var mc_run := func() -> void:
						var hi: int = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, mc_pred, true)
						if hi >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
							CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true, false)
					CustomDuelOps.optional_effect(duel, p, 2702, mc_run)
		2728: # Shadow Tamer FLIP: control opp Fiend until EP
			if kind == "flip_summon" or kind == "flipped":
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == opp and zz < 5 and CustomDuelOps.monster_race(d, idx) == 3, true, true)
				if not pick.is_empty():
					CustomDuelOps.change_control(duel, opp, int(pick["z"]), p, true)
		2732: # Otohime: toggle opp monster battle pos
			if kind != "special":
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
				if not pick.is_empty():
					var cur_def = not CustomDuelOps.is_atk_pos(duel, opp, int(pick["z"]))
					CustomDuelOps.change_position(duel, opp, int(pick["z"]), 0 if cur_def else 1, -1)
		2735: # Maharaghi: mark scry before next Draw Phase
			if kind != "special":
				CustomDuelOps.pflags(duel, p)["maharaghi_scry_turn"] = t + 1
		2738: # Ryu-Kishin Clown: toggle 1 face-up monster pos
			var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
			if not pick.is_empty():
				var tz := int(pick["z"])
				var tp := int(pick["p"])
				var cur_def = not CustomDuelOps.is_atk_pos(duel, tp, tz)
				CustomDuelOps.change_position(duel, tp, tz, 0 if cur_def else 1, -1)
		2754: # Dragon Manipulator FLIP: control opp face-up Dragon until EP
			if kind == "flip_summon" or kind == "flipped":
				var pick = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 1, true, true)
				if not pick.is_empty():
					CustomDuelOps.change_control(duel, opp, int(pick["z"]), p, true)
		2770: # Fiber Jar FLIP: shuffle all hands/fields/GYs & draw 5 each
			if kind == "flip_summon" or kind == "flipped":
				for pl in 2:
					for zz in 11:
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
							CustomDuelOps.spin_zone(duel, pl, zz, false)
					for hi in range(CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) - 1, -1, -1):
						CustomDuelOps.move_pile_card(duel, pl, CustomDuelOps.LOC_HAND, hi, pl, CustomDuelOps.LOC_DECK)
					for gi in range(CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE) - 1, -1, -1):
						CustomDuelOps.move_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, gi, pl, CustomDuelOps.LOC_DECK)
					CustomDuelOps.shuffle_deck(duel, pl)
				for pl in 2:
					CustomDuelOps.draw(duel, pl, 5)
		2794: # Des Lacooda: Flip Summon -> draw 1
			if kind == "flip_summon":
				CustomDuelOps.draw(duel, p, 1)


static func on_attack_declare(duel, atk_p: int, atk_z: int, _def_p: int, _def_z: int) -> bool:
	atk_p &= 1
	var def_p = 1 - atk_p
	var cid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	if not can_attack(duel, atk_p, atk_z, cid):
		return false
	if not CustomDuelOps.is_skill_drain_active(duel):
		if _def_z >= 0 and CustomDuelOps.has_faceup_id(duel, def_p, 2616): # Mirror Force Dragon: destroy all opp cards when a monster you control is targeted for an attack
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, atk_p, zz) != 0:
					CustomDuelOps.destroy_zone(duel, atk_p, zz)
			for sz in range(5, 11):
				if CustomDuelOps.zone_idx(duel, atk_p, sz) != 0:
					CustomDuelOps.destroy_zone(duel, atk_p, sz)
			return false
		if _def_z >= 0 and CustomDuelOps.has_faceup_id(duel, def_p, 2713): # Patrician of Darkness: defender redirects attack to their strongest face-up monster
			var tgt_atk = CustomDuelOps.eff_atk(duel, def_p, _def_z)
			var best_atk = tgt_atk
			for zz in 5:
				if zz != _def_z and CustomDuelOps.zone_idx(duel, def_p, zz) != 0 and CustomDuelOps.is_face_up(duel, def_p, zz):
					best_atk = maxi(best_atk, CustomDuelOps.eff_atk(duel, def_p, zz))
			if best_atk > tgt_atk:
				CustomDuelOps.add_stat_mod(duel, def_p, _def_z, best_atk - tgt_atk, best_atk - tgt_atk, true)
	match cid:
		2509: # Armed Dragon LV10 White: start of Damage Step destroy 1 card
			var pick = CustomDuelOps.choose_zone(duel, atk_p, func(_d, pl, _zz, _idx): return pl == 1 - atk_p, true, true)
			if not pick.is_empty():
				CustomDuelOps.destroy_zone(duel, int(pick["p"]), int(pick["z"]))
		2537: # Cyber Dragon Zwei: +300 ATK during Damage Step
			if _def_z >= 0:
				CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 300, 0, true)
		2575: # Exodius: send 1 monster from hand or Deck to GY
			var di = CustomDuelOps.choose_pile_card(duel, atk_p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.FORBIDDEN_ONE_IDS, false)
			if di < 0:
				di = CustomDuelOps.choose_pile_card(duel, atk_p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx), false)
			if di >= 0:
				var idx = CustomDuelOps.send_from_deck_to_gy(duel, atk_p, di)
				if idx > 0 and CustomDuelOps.raw_id(duel, idx) in CustomDuelOps.FORBIDDEN_ONE_IDS:
					var sent_f: Array = CustomDuelOps.zflags(duel, atk_p, atk_z).get("exodius_forbidden", [])
					var rid = CustomDuelOps.raw_id(duel, idx)
					if rid not in sent_f:
						sent_f.append(rid)
					CustomDuelOps.zflags(duel, atk_p, atk_z)["exodius_forbidden"] = sent_f
		2664: # Ra Sun God of Darkness: pay LP to 1 -> gain LP paid + GY Sun Gods ATK
			var lp = CustomDuelOps.get_lp(duel, atk_p)
			if lp > 1:
				var paid = lp - 1
				CustomDuelOps.set_lp(duel, atk_p, 1)
				CustomDuelOps.record_lp_paid(duel, atk_p, paid)
				var gy_sum = 0
				for i in CustomDuelOps.pile_count(duel, atk_p, CustomDuelOps.LOC_GRAVE):
					var idx = CustomDuelOps.pile_idx(duel, atk_p, CustomDuelOps.LOC_GRAVE, i)
					if CustomDuelOps.raw_id(duel, idx) in CustomDuelOps.SUN_GOD_IDS:
						gy_sum += CustomDuelOps.base_atk(duel, idx)
				CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, paid + gy_sum, paid + gy_sum, false)
	return true


static func on_damage_calc(duel, atk_p: int, atk_z: int, def_p: int, def_z: int) -> void:
	atk_p &= 1
	def_p &= 1
	var acid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	var dcid = CustomDuelOps.zone_id(duel, def_p, def_z) if def_z >= 0 else 0
	if acid == 2580 and def_z >= 0: # Five-Headed Dragon: cannot be destroyed by battle with DARK/WATER/FIRE/EARTH/WIND
		var opp_attr = CustomDuelOps.monster_attr(duel, CustomDuelOps.zone_idx(duel, def_p, def_z))
		CustomDuelOps.zflags(duel, atk_p, atk_z)["indest_battle"] = opp_attr in [2, 3, 4, 5, 6]
	if dcid == 2580:
		var opp_attr2 = CustomDuelOps.monster_attr(duel, CustomDuelOps.zone_idx(duel, atk_p, atk_z))
		CustomDuelOps.zflags(duel, def_p, def_z)["indest_battle"] = opp_attr2 in [2, 3, 4, 5, 6]
	if acid == 2563 and def_z >= 0: # Neos Kluger pre-damage burn
		CustomDuelOps.damage(duel, def_p, CustomDuelOps.eff_atk(duel, def_p, def_z), false)
	if acid == 2660 and CustomDuelOps.can_opt(duel, atk_p, 2660, atk_z): # Unstoppable Exodia
		CustomDuelOps.mark_opt(duel, atk_p, 2660, atk_z)
		CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, CustomDuelOps.get_lp(duel, atk_p), 0, true)
	if dcid == 2660 and CustomDuelOps.can_opt(duel, def_p, 2660, def_z):
		CustomDuelOps.mark_opt(duel, def_p, 2660, def_z)
		CustomDuelOps.add_stat_mod(duel, def_p, def_z, CustomDuelOps.get_lp(duel, def_p), 0, true)
	if acid == 2699 and def_z >= 0: # Hunter with 7 Weapons
		var dr := int(CustomDuelOps.zflags(duel, atk_p, atk_z).get("declared_race", -1))
		if dr == CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, def_p, def_z)):
			CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 1000, 0, true)
	if acid == 2771 and CustomDuelOps.can_pay_lp(duel, atk_p, 2000) and CustomDuelOps.can_opt(duel, atk_p, 2771, atk_z):
		CustomDuelOps.mark_opt(duel, atk_p, 2771, atk_z)
		CustomDuelOps.pay_lp(duel, atk_p, 2000)
		CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 3000, 0, true)
	if dcid == 2771 and CustomDuelOps.can_pay_lp(duel, def_p, 2000) and CustomDuelOps.can_opt(duel, def_p, 2771, def_z):
		CustomDuelOps.mark_opt(duel, def_p, 2771, def_z)
		CustomDuelOps.pay_lp(duel, def_p, 2000)
		CustomDuelOps.add_stat_mod(duel, def_p, def_z, 3000, 0, true)
	if dcid == 2588 and CustomDuelOps.can_hopt(duel, def_p, 2588): # Guardian Slime +opp ATK to DEF
		var gs_run1 := func() -> void:
			if CustomDuelOps.can_hopt(duel, def_p, 2588):
				CustomDuelOps.mark_hopt(duel, def_p, 2588)
				CustomDuelOps.add_stat_mod(duel, def_p, def_z, 0, CustomDuelOps.eff_atk(duel, atk_p, atk_z), true)
		CustomDuelOps.optional_effect(duel, def_p, 2588, gs_run1)
	if acid == 2588 and def_z >= 0 and CustomDuelOps.can_hopt(duel, atk_p, 2588):
		var gs_run2 := func() -> void:
			if CustomDuelOps.can_hopt(duel, atk_p, 2588):
				CustomDuelOps.mark_hopt(duel, atk_p, 2588)
				CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 0, CustomDuelOps.eff_atk(duel, def_p, def_z), true)
		CustomDuelOps.optional_effect(duel, atk_p, 2588, gs_run2)


static func on_battle_damage(duel, dmg_p: int, dmg_z: int, opp_p: int, amount: int, is_direct: bool) -> void:
	if amount <= 0:
		return
	var cid = CustomDuelOps.zone_id(duel, dmg_p, dmg_z)
	var t = CustomDuelOps.turn_number(duel)
	match cid:
		2550: # Don Zaloog
			var zal_a := func() -> void:
				if CustomDuelOps.pile_count(duel, opp_p, CustomDuelOps.LOC_HAND) > 0:
					CustomDuelOps.discard_random(duel, opp_p, 1)
			var zal_b := func() -> void:
				CustomDuelOps.mill(duel, opp_p, 2, 1)
			var zal_texts: Array = [
				CustomDuelOps.lang_text("هل تريد أن يتخلص الخصم من بطاقة عشوائية من يده؟", "¿Hacer que el rival descarte 1 carta al azar de su mano?", "Make your opponent discard 1 random card from their hand?"),
				CustomDuelOps.lang_text("هل تريد إرسال أول بطاقتين من مجموعة الخصم إلى المقبرة؟", "¿Enviar las 2 cartas de arriba del Deck del rival al Cementerio?", "Send the top 2 cards of your opponent's Deck to the Graveyard?")]
			var zal_auto_i: int = 0 if CustomDuelOps.pile_count(duel, opp_p, CustomDuelOps.LOC_HAND) > 0 else 1
			CustomDuelOps.optional_one_of(duel, dmg_p, zal_texts, [zal_a, zal_b], zal_auto_i)
		2641: # Silent Swordsman LV5
			if is_direct:
				CustomDuelOps.zflags(duel, dmg_p, dmg_z)["lv5_direct_turn"] = t
		2651: # Spirit Reaper
			if is_direct:
				CustomDuelOps.discard_random(duel, opp_p, 1)
		2670: # Toon Gemini Elf
			CustomDuelOps.discard_random(duel, opp_p, 1)
		2672, 2712: # Toon Masked Sorcerer / Airknight Parshath
			CustomDuelOps.draw(duel, dmg_p, 1)
		2678: # Vampire Lord: mill 1 Trap/Spell
			var si = CustomDuelOps.choose_pile_card(duel, opp_p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_trap(d, idx) or CustomDuelOps.is_spell(d, idx), false)
			if si >= 0:
				CustomDuelOps.send_from_deck_to_gy(duel, opp_p, si)
		2701: # Great Long Nose: skip opp next Battle Phase
			CustomDuelOps.pflags(duel, opp_p)["skip_bp_turn"] = t + 1
		2703: # Yata-Garasu: skip opp next Draw Phase
			CustomDuelOps.pflags(duel, opp_p)["skip_dp_turn"] = t + 1
		2730: # Fushi No Tori: heal = dmg
			CustomDuelOps.heal(duel, dmg_p, amount)
		2763: # Hino-Kagu-Tsuchi: opp discards hand at next Draw Phase
			CustomDuelOps.pflags(duel, opp_p)["discard_all_dp_turn"] = t + 1
		2767: # Yamata Dragon: draw until 5 cards in hand
			var hn = CustomDuelOps.pile_count(duel, dmg_p, CustomDuelOps.LOC_HAND)
			if hn < 5:
				CustomDuelOps.draw(duel, dmg_p, 5 - hn)


static func on_battle_end(duel, atk_p: int, atk_z: int, def_p: int, def_z: int, atk_destroyed: bool, def_destroyed: bool) -> void:
	var acid = CustomDuelOps.zone_id(duel, atk_p, atk_z)
	var dcid = CustomDuelOps.zone_id(duel, def_p, def_z) if def_z >= 0 else 0
	var t = CustomDuelOps.turn_number(duel)
	# Position changes after battle
	if acid == 2671 or acid == 2723: # Toon Goblin Attack Force / Spear Dragon
		CustomDuelOps.change_position(duel, atk_p, atk_z, 1, -1)
		if acid == 2671:
			CustomDuelOps.zflags(duel, atk_p, atk_z)["lock_pos_until_turn"] = t + 2
	# Marshmallon face-down burn 1000
	if dcid == 2603 and bool(CustomDuelOps.zflags(duel, def_p, def_z).get("was_fd_before_ds", false)):
		CustomDuelOps.damage(duel, atk_p, 1000, false)
	# D.D. Warrior Lady banish both
	if (acid == 2541 or dcid == 2541) and def_z >= 0:
		var ddl_p: int = atk_p if acid == 2541 else def_p
		var ddl_run := func() -> void:
			if not atk_destroyed:
				CustomDuelOps.banish_zone(duel, atk_p, atk_z)
			if not def_destroyed:
				CustomDuelOps.banish_zone(duel, def_p, def_z)
		CustomDuelOps.optional_effect(duel, ddl_p, 2541, ddl_run)
	# Battle destruction triggers
	if def_destroyed and def_z >= 0:
		var def_idx = CustomDuelOps.zone_idx(duel, def_p, def_z)
		if acid == 2511 or acid == 2591 or acid == 2592:
			CustomDuelOps.zflags(duel, atk_p, atk_z)["evolve_ready_turn"] = t
		if acid == 2515 and int(CustomDuelOps.zflags(duel, atk_p, atk_z).get("bls_effect_turn", -1)) != t and CustomDuelOps.can_opt(duel, atk_p, 2515, atk_z * 10 + 1): # BLS Envoy double attack (one effect per turn)
			CustomDuelOps.mark_opt(duel, atk_p, 2515, atk_z * 10 + 1)
			CustomDuelOps.zflags(duel, atk_p, atk_z)["bls_effect_turn"] = t
			CustomDuelOps.zflags(duel, atk_p, atk_z)["extra_atk_grant"] = t
		if acid == 2544 or acid == 2710: # Dark Magician of Chaos / Lesser Fiend -> banish destroyed monster
			var gi = CustomDuelOps.find_pile_index_by_id(duel, def_p, CustomDuelOps.LOC_GRAVE, dcid)
			if gi >= 0:
				CustomDuelOps.banish_from_pile(duel, def_p, CustomDuelOps.LOC_GRAVE, gi)
		if acid == 2559 or acid == 2565: # Flame Wingman / Shining Flare Wingman burn = destroyed ATK
			var dmg = CustomDuelOps.base_atk(duel, def_idx)
			CustomDuelOps.damage(duel, def_p, dmg, false)
		if acid == 2589: # Hamon: 1000 dmg
			CustomDuelOps.damage(duel, def_p, 1000, false)
		if acid == 2611: # Millennium Scorpion: +500 ATK
			CustomDuelOps.add_stat_mod(duel, atk_p, atk_z, 500, 0, false)
		if acid == 2574 and CustomDuelOps.monster_attr(duel, def_idx) == 2 and CustomDuelOps.monster_race(duel, def_idx) == 3:
			CustomDuelOps.declare_win(duel, atk_p)
		if CustomDuelOps.has_faceup_id(duel, atk_p, 2744) and not CustomDuelOps.is_skill_drain_active(duel): # Dark Ruler Ha Des: negate monsters destroyed by Fiends
			var atk_idx = CustomDuelOps.zone_idx(duel, atk_p, atk_z)
			if atk_idx != 0 and CustomDuelOps.monster_race(duel, atk_idx) == 3 and dcid > 0:
				var neg_ids: Array = CustomDuelOps.pflags(duel, def_p).get("ha_des_negated_ids", [])
				if dcid not in neg_ids:
					neg_ids.append(dcid)
				CustomDuelOps.pflags(duel, def_p)["ha_des_negated_ids"] = neg_ids
	if atk_destroyed:
		if def_z >= 0 and CustomDuelOps.has_faceup_id(duel, def_p, 2744) and not CustomDuelOps.is_skill_drain_active(duel):
			var def_idx2 = CustomDuelOps.zone_idx(duel, def_p, def_z)
			if def_idx2 != 0 and CustomDuelOps.monster_race(duel, def_idx2) == 3 and acid > 0:
				var neg_ids2: Array = CustomDuelOps.pflags(duel, atk_p).get("ha_des_negated_ids", [])
				if acid not in neg_ids2:
					neg_ids2.append(acid)
				CustomDuelOps.pflags(duel, atk_p)["ha_des_negated_ids"] = neg_ids2
		if atk_p != def_p and (acid == 2635 or acid == 2639):
			pass
	if CustomDuelOps.zflags(duel, atk_p, atk_z).get("atk_count_turn", -1) != t:
		CustomDuelOps.zflags(duel, atk_p, atk_z)["atk_count_turn"] = t
		CustomDuelOps.zflags(duel, atk_p, atk_z)["atk_count"] = 0
	CustomDuelOps.zflags(duel, atk_p, atk_z)["atk_count"] = int(CustomDuelOps.zflags(duel, atk_p, atk_z).get("atk_count", 0)) + 1


static func on_destroyed(duel, p: int, cid: int, by_battle: bool, opp_effect: bool, was_tributed_for_p: int) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	match cid:
		2506: # Amulet Dragon: SS 1 Spellcaster from GY
			if not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == 18, true)
				if gi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
		2525: # Calamity Hamon: take no damage this turn
			CustomDuelOps.pflags(duel, p)["no_battle_damage_turn"] = t
			CustomDuelOps.pflags(duel, p)["no_effect_damage_turn"] = t
		2526, 2630: # Cerulean / Sacred Phoenix revive next Standby Phase
			if cid == 2526 or not by_battle:
				CustomDuelOps.schedule_delayed(duel, t + 1, CustomDuelOps.PHASE_SP, p, cid, "revive_phoenix", {})
		2563: # Neos Kluger -> SS Neos Wiseman
			if (by_battle or opp_effect) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				CustomDuelOps.spawn_token(duel, p, 0, false, 2500, 2000)
		2583: # Gandora-X Blackmetal Rampaging Dragon -> search Final Geas
			if CustomDuelOps.can_hopt(duel, p, 2583):
				var fi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.name_matches(d, idx, "final geas"), true)
				if fi >= 0:
					var gandora_search: Callable = func() -> void:
						CustomDuelOps.mark_hopt(duel, p, 2583)
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, fi)
					if not CustomDuelOps.ask_optional(duel, p, CustomDuelOps.effect_prompt(duel, 2583), gandora_search):
						gandora_search.call()
		2618: # Moremarshmallon: if destroyed by card effect -> SS another + 1000 dmg
			if not by_battle and CustomDuelOps.can_hopt(duel, p, 2618) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				CustomDuelOps.mark_hopt(duel, p, 2618)
				for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE, CustomDuelOps.LOC_BANISH]:
					var mi = CustomDuelOps.find_pile_index_by_id(duel, p, srcloc, 2618)
					if mi >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, srcloc, mi, p, true, false)
						CustomDuelOps.damage(duel, opp, 1000, false)
						break
		2635, 2639: # Silent Magician / Silent Swordsman float
			if (by_battle or opp_effect) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var list = CustomDuelOps.SILENT_MAGICIAN_IDS if cid == 2635 else CustomDuelOps.SILENT_SWORDSMAN_IDS
				for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK]:
					var si = CustomDuelOps.choose_pile_card(duel, p, srcloc, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in list and CustomDuelOps.raw_id(d, idx) != cid, true)
					if si >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, srcloc, si, p, true, false)
						break
		2657: # Legendary Exodia Incarnate: reveal Forbidden Ones in hand, draw 1 each
			if by_battle:
				var cnt = 0
				for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
					if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)) in CustomDuelOps.FORBIDDEN_ONE_IDS:
						cnt += 1
				if cnt > 0:
					CustomDuelOps.draw(duel, p, cnt)
		2663: # Wicked Eraser: destroy all cards on the field
			for pl in 2:
				for zz in 11:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						CustomDuelOps.destroy_zone(duel, pl, zz)
		2678: # Vampire Lord: if opp card effect -> revive next Standby Phase
			if opp_effect and not by_battle:
				CustomDuelOps.schedule_delayed(duel, t + 1, CustomDuelOps.PHASE_SP, p, 2678, "revive_vampire_lord", {})
		2681: # Winged Kuriboh: take no battle damage this turn
			CustomDuelOps.pflags(duel, p)["no_battle_damage_turn"] = t
		2709: # Skull Knight #2: if Tributed for Fiend Tribute Summon -> SS Skull Knight #2 from Deck
			if was_tributed_for_p >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var si = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2709)
				if si >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, si, p, true, false)
		2739: # Twin-Headed Behemoth: End Phase revive (Once per Duel) as 1000/1000
			if CustomDuelOps.can_opd(duel, p, 2739):
				CustomDuelOps.mark_opd(duel, p, 2739)
				CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 2739, "revive_behemoth", {})
		2746: # Troop Dragon: battle destroyed -> SS Troop Dragon from Deck
			if by_battle and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var si = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2746)
				if si >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, si, p, true, false)


static func on_sent_to_gy(duel, p: int, cid: int, from_loc: int, _opp_effect: bool) -> void:
	p &= 1
	match cid:
		2534: # Cyber Dragon Herz: add 1 other Cyber Dragon from Deck or GY
			if CustomDuelOps.can_hopt(duel, p, 2534):
				CustomDuelOps.mark_hopt(duel, p, 2534)
				for srcloc in [CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
					var ci = CustomDuelOps.choose_pile_card(duel, p, srcloc, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.CYBER_DRAGON_IDS and CustomDuelOps.raw_id(d, idx) != 2534, true)
					if ci >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, srcloc, ci)
						break
		2544, 2575: # Dark Magician of Chaos / Exodius leave field -> banish instead
			if from_loc < 11:
				var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, cid)
				if gi >= 0:
					CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
		2588: # Guardian Slime: sent from hand or field to GY -> add Ra S/T
			if (from_loc < 11 or from_loc == CustomDuelOps.LOC_HAND) and CustomDuelOps.can_hopt(duel, p, 2588):
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in [2507, 2517, 2604, 2652, 2659], true)
				if si >= 0:
					CustomDuelOps.mark_hopt(duel, p, 2588)
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, si)


static func on_draw(duel, draw_p: int, count: int) -> void:
	var opp = 1 - (draw_p & 1)
	if count <= 0:
		return
	for z in 5:
		if CustomDuelOps.zone_idx(duel, opp, z) != 0 and CustomDuelOps.is_face_up(duel, opp, z):
			var cid = CustomDuelOps.zone_id(duel, opp, z)
			if cid == 2636: # Silent Magician LV4
				var cur = CustomDuelOps.get_counter(duel, opp, z, "spell")
				if cur < 5:
					var add = mini(count, 5 - cur)
					CustomDuelOps.add_counter(duel, opp, z, "spell", add)
					if CustomDuelOps.get_counter(duel, opp, z, "spell") >= 5:
						CustomDuelOps.zflags(duel, opp, z)["lv4_ready_turn"] = CustomDuelOps.turn_number(duel)
			elif cid == 2638: # Silent Magician Zero
				var zf = CustomDuelOps.zflags(duel, opp, z)
				zf["lv_bonus"] = int(zf.get("lv_bonus", 0)) + count


## Evolucion de Armed Dragon (LV3 -> LV5, LV5 -> LV7): efecto opcional. Al jugador local se le
## pregunta Si/No; en los demas casos (CPU, online, repeticion, Joey) se activa solo, como antes.
static func _evolve_optional(duel, p: int, z: int, from_id: int, to_id: int) -> void:
	var do_evolve := func() -> void:
		if CustomDuelOps.zone_idx(duel, p, z) == 0 or CustomDuelOps.zone_id(duel, p, z) != from_id:
			return
		for srcloc in [CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_HAND]:
			var si = CustomDuelOps.find_pile_index_by_id(duel, p, srcloc, to_id)
			if si >= 0:
				CustomDuelOps.send_zone_to_gy(duel, p, z)
				CustomDuelOps.special_summon_from_pile(duel, p, srcloc, si, p, true, false)
				return
	var from_name: String = CustomDuelOps.card_name(duel, from_id)
	var to_name: String = CustomDuelOps.card_name(duel, to_id)
	var text: String
	if Assets.lang == "a":
		text = "هل تريد تفعيل تأثير %s؟\nسيُرسل إلى المقبرة ويُستدعى %s استدعاءً خاصًا." % [from_name, to_name]
	elif Assets.lang == "s":
		text = "¿Activar el efecto de %s?\nSe enviará al Cementerio y se invocará por Invocación Especial a %s." % [from_name, to_name]
	else:
		text = "Activate the effect of %s?\nIt will be sent to the Graveyard and %s will be Special Summoned." % [from_name, to_name]
	# Con otro cuadro o una lista abiertos no se decide solo: la pregunta queda en cola y se
	# abre cuando se cierre lo que este en pantalla (duel_base._drain_optional_prompts).
	var human: bool = (p & 1) == 0 and int(duel.game_mode) == DuelBase.GAME_NORMAL \
			and int(duel.auto_answer) == -1 and DisplayServer.get_name() != "headless"
	if human and (not duel.dialog_open.is_empty() or not duel.list_open.is_empty()):
		var queue: Array = CustomDuelOps.state(duel).get_or_add("optional_prompts", [])
		queue.append({"text": text, "yes": do_evolve})
		return
	if not CustomDuelOps.ask_optional(duel, p, text, do_evolve):
		do_evolve.call()


static func on_standby_tick(duel, turn_p: int) -> void:
	turn_p &= 1
	var t = CustomDuelOps.turn_number(duel)
	for z in 5:
		if CustomDuelOps.zone_idx(duel, turn_p, z) == 0 or not CustomDuelOps.is_face_up(duel, turn_p, z):
			continue
		var cid = CustomDuelOps.zone_id(duel, turn_p, z)
		if CustomDuelOps.is_skill_drain_active(duel):
			continue
		match cid:
			2510: # Armed Dragon LV3 -> SS LV5
				var si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_DECK, 2511)
				var sl = CustomDuelOps.LOC_DECK
				if si < 0:
					si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_HAND, 2511)
					sl = CustomDuelOps.LOC_HAND
				if si >= 0:
					_evolve_optional(duel, turn_p, z, 2510, 2511)
			2573: # Exodia Necross +500 ATK
				CustomDuelOps.add_stat_mod(duel, turn_p, z, 500, 0, false)
			2636: # Silent Magician LV4 with 5 counters -> LV8
				if CustomDuelOps.get_counter(duel, turn_p, z, "spell") >= 5 and int(CustomDuelOps.zflags(duel, turn_p, z).get("lv4_ready_turn", t)) < t:
					var si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_DECK, 2637)
					var sl = CustomDuelOps.LOC_DECK
					if si < 0:
						si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_HAND, 2637)
						sl = CustomDuelOps.LOC_HAND
					if si >= 0:
						_evolve_optional(duel, turn_p, z, 2636, 2637)
			2639: # Silent Swordsman: +500 ATK
				CustomDuelOps.add_stat_mod(duel, turn_p, z, 500, 0, false)
			2640: # Silent Swordsman LV3 -> LV5 (not turn summoned)
				if int(CustomDuelOps.zflags(duel, turn_p, z).get("summoned_turn", -1)) < t:
					var si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_DECK, 2641)
					var sl = CustomDuelOps.LOC_DECK
					if si < 0:
						si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_HAND, 2641)
						sl = CustomDuelOps.LOC_HAND
					if si >= 0:
						_evolve_optional(duel, turn_p, z, 2640, 2641)
			2641: # Silent Swordsman LV5 -> LV7 after direct dmg
				if int(CustomDuelOps.zflags(duel, turn_p, z).get("lv5_direct_turn", 999999)) < t:
					var si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_DECK, 2642)
					var sl = CustomDuelOps.LOC_DECK
					if si < 0:
						si = CustomDuelOps.find_pile_index_by_id(duel, turn_p, CustomDuelOps.LOC_HAND, 2642)
						sl = CustomDuelOps.LOC_HAND
					if si >= 0:
						_evolve_optional(duel, turn_p, z, 2641, 2642)
			2643: # Silent Swordsman Zero: +1 Level
				var zf = CustomDuelOps.zflags(duel, turn_p, z)
				zf["lv_bonus"] = int(zf.get("lv_bonus", 0)) + 1
			2660: # Unstoppable Exodia Incarnate: Lose 1000 LP
				CustomDuelOps.damage(duel, turn_p, 1000, false)
			2790: # Lava Golem: controller takes 1000 dmg
				CustomDuelOps.damage(duel, turn_p, 1000, false)


static func on_end_phase(duel, turn_p: int) -> void:
	turn_p &= 1
	var t = CustomDuelOps.turn_number(duel)
	for pl in 2:
		for z in range(4, -1, -1):
			if CustomDuelOps.zone_idx(duel, pl, z) == 0:
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			var zf = CustomDuelOps.zflags(duel, pl, z)
			# Spirit monsters return to hand on EP if summoned/flipped this turn
			if cid in SPIRIT_MONSTERS_M1 and int(zf.get("spirit_return_turn", -1)) == t:
				CustomDuelOps.bounce_zone(duel, pl, z)
				continue
			# Obelisk / Slifer Special Summoned -> send to GY
			if cid in [2500, 2502] and t in zf.get("ss_turn_hist", []):
				CustomDuelOps.send_zone_to_gy(duel, pl, z)
				continue
			# Immortal Phoenix -> send to GY & SS Sphere Mode
			if cid == 2504:
				CustomDuelOps.send_zone_to_gy(duel, pl, z)
				for srcloc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
					var si = CustomDuelOps.find_pile_index_by_id(duel, pl, srcloc, 2503)
					if si >= 0:
						CustomDuelOps.special_summon_from_pile(duel, pl, srcloc, si, pl, true, false)
						break
				continue
			# Magical Scientist Fusion return
			if int(zf.get("return_extra_ep", -1)) == t:
				CustomDuelOps.spin_zone(duel, pl, z, false)
				continue
			# Armityle Phantom of Fury control change EP
			if cid == 2514 and int(zf.get("control_changed_turn", -1)) == t:
				var owner_p := int(zf.get("orig_owner", 1 - pl))
				for zz in 11:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						CustomDuelOps.banish_zone(duel, pl, zz)
				var ai = CustomDuelOps.find_pile_index_by_id(duel, owner_p, CustomDuelOps.LOC_FUSION, 2513)
				if ai >= 0:
					CustomDuelOps.special_summon_from_pile(duel, owner_p, CustomDuelOps.LOC_FUSION, ai, owner_p, true, false)
				continue
			if pl == turn_p:
				match cid:
					2511, 2591, 2592: # Armed Dragon LV5 -> LV7 / Horus LV4 -> LV6 / Horus LV6 -> LV8
						if int(zf.get("evolve_ready_turn", -1)) == t:
							var target_id = 2512 if cid == 2511 else (2592 if cid == 2591 else 2593)
							if cid == 2511:
								# Armed Dragon LV5: el efecto es opcional ("puedes"), se pregunta al jugador.
								_evolve_optional(duel, pl, z, 2511, target_id)
							else:
								# Horus LV4 / LV6: "puedes", se pregunta al jugador.
								_evolve_optional(duel, pl, z, cid, target_id)
					2544: # DM of Chaos: add 1 Spell from GY, only the turn it was Summoned
						if int(zf.get("summoned_turn", -1)) == t and CustomDuelOps.can_hopt(duel, pl, 2544) and not CustomDuelOps.is_necrovalley_active(duel):
							CustomDuelOps.mark_hopt(duel, pl, 2544)
							var dmoc_pick = func(idx: int) -> void:
								if idx >= 0:
									CustomDuelOps.add_from_pile_to_hand(duel, pl, CustomDuelOps.LOC_GRAVE, idx)
							if not CustomDuelOps.ask_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx), dmoc_pick):
								var si = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_spell(d, idx), true)
								if si >= 0:
									CustomDuelOps.add_from_pile_to_hand(duel, pl, CustomDuelOps.LOC_GRAVE, si)
					2581: # Gandora send to GY
						if int(zf.get("summoned_turn", -1)) == t:
							CustomDuelOps.send_zone_to_gy(duel, pl, z)
					2584: # Gandora-X halve LP
						CustomDuelOps.pay_half_lp(duel, pl)
					2657: # Legendary Exodia Incarnate: add Forbidden One from GY
						if not CustomDuelOps.is_necrovalley_active(duel):
							var fi = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.FORBIDDEN_ONE_IDS, false)
							if fi >= 0:
								CustomDuelOps.add_from_pile_to_hand(duel, pl, CustomDuelOps.LOC_GRAVE, fi)
					2660: # Unstoppable Exodia Incarnate: Set Exodd/Obliterate from Deck
						var si = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.raw_id(d, idx) in [2621, 2622, 2707], true)
						if si >= 0 and CustomDuelOps.free_st_zone(duel, pl) >= 0:
							CustomDuelOps.set_st_from_pile(duel, pl, CustomDuelOps.LOC_DECK, si, pl, false)


static func on_continuous_enforce(duel) -> void:
	var has_toon_w = CustomDuelOps.has_toon_world(duel, -1)
	var has_field = CustomDuelOps.zone_idx(duel, 0, 10) != 0 and CustomDuelOps.is_face_up(duel, 0, 10) \
		or CustomDuelOps.zone_idx(duel, 1, 10) != 0 and CustomDuelOps.is_face_up(duel, 1, 10)
	for pl in 2:
		for z in 5:
			if CustomDuelOps.zone_idx(duel, pl, z) == 0:
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			var zf = CustomDuelOps.zflags(duel, pl, z)
			if cid in [2667, 2669, 2670, 2671, 2672] and not has_toon_w:
				CustomDuelOps.destroy_zone(duel, pl, z)
				continue
			if cid == 2573: # Exodia Necross requires all 5 Forbidden One in GY
				var ok = true
				for fid in CustomDuelOps.FORBIDDEN_ONE_IDS:
					if CustomDuelOps.find_pile_index_by_id(duel, pl, CustomDuelOps.LOC_GRAVE, fid) < 0:
						ok = false
						break
				if not ok:
					CustomDuelOps.destroy_zone(duel, pl, z)
					continue
			if cid == 2602 and not has_field:
				CustomDuelOps.destroy_zone(duel, pl, z)
				continue
			if cid == 2706: # Gradius' Option
				var gz := int(zf.get("gradius_link", -1))
				if gz < 0 or CustomDuelOps.zone_id(duel, pl, gz) != CustomDuelOps.NATIVE_GRADIUS or not CustomDuelOps.is_face_up(duel, pl, gz):
					CustomDuelOps.destroy_zone(duel, pl, z)
					continue
			if cid == 2761: # Thunder Nyan Nyan
				var non_light = false
				for zz in 5:
					var idx = CustomDuelOps.zone_idx(duel, pl, zz)
					if idx != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.monster_attr(duel, idx) != 1:
						non_light = true
						break
				if non_light:
					CustomDuelOps.destroy_zone(duel, pl, z)
		var has_wiseman = CustomDuelOps.has_faceup_id(duel, pl, 2731) and not CustomDuelOps.is_skill_drain_active(duel)
		for zz in 5:
			var widx = CustomDuelOps.zone_idx(duel, pl, zz)
			if widx != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.monster_race(duel, widx) == 15: # Frontier Wiseman: protect Warriors from Spells
				CustomDuelOps.zflags(duel, pl, zz)["spell_immune"] = has_wiseman
		var pf = CustomDuelOps.pflags(duel, pl)
		var had_serp := bool(pf.get("serpentine_on_field", false))
		var now_serp = CustomDuelOps.find_zone_of_id(duel, pl, 2762, true) >= 0
		if had_serp and not now_serp and CustomDuelOps.find_pile_index_by_id(duel, pl, CustomDuelOps.LOC_DECK, 2762) >= 0: # Serpentine Princess: returned from field to Deck -> SS 1 Lv<=3 from Deck
			var si = CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_DECK, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_level(d, idx) <= 3, true)
			if si >= 0 and CustomDuelOps.free_monster_zone(duel, pl) >= 0:
				CustomDuelOps.special_summon_from_pile(duel, pl, CustomDuelOps.LOC_DECK, si, pl, true, false)
		pf["serpentine_on_field"] = now_serp


static func modify_continuous(duel, p: int, z: int, cid: int, out: Dictionary) -> void:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	if CustomDuelOps.is_skill_drain_active(duel) or bool(CustomDuelOps.zflags(duel, p, z).get("negated", false)):
		return
	var zf = CustomDuelOps.zflags(duel, p, z)
	# Global aura modifiers from Wicked Dreadroot, Cyber Dragon Vier, Hunter, etc.
	if cid != 2662 and (CustomDuelOps.has_faceup_id(duel, 0, 2662) or CustomDuelOps.has_faceup_id(duel, 1, 2662)):
		out["half"] = true
	if cid in CustomDuelOps.CYBER_DRAGON_IDS or int(zf.get("name_cyber_dragon_turn", -1)) == t:
		var vier_n = CustomDuelOps.count_faceup_id(duel, p, 2536)
		out["atk_delta"] = int(out.get("atk_delta", 0)) + vier_n * 500
		out["def_delta"] = int(out.get("def_delta", 0)) + vier_n * 500
	match cid:
		2502: # Slifer: +1000 per card in hand
			var bonus = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) * 1000
			out["atk_set"] = bonus
			out["def_set"] = bonus
		2513: # Armityle: +10,000 ATK during your turn
			if CustomDuelOps.turn_player(duel) == p:
				out["atk_delta"] = int(out.get("atk_delta", 0)) + 10000
		2518: # Blue-Eyes Shining Dragon: +300 per Dragon in GY
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_race_in_gy(duel, p, 1) * 300
		2524: # Breaker: +300 per Spell Counter
			out["atk_delta"] = int(out.get("atk_delta", 0)) + CustomDuelOps.get_counter(duel, p, z, "spell") * 300
		2543: # DMG Magician's Apprentice: +300 per Shining Sarc monster in GYs
			var c = 0
			for pl in 2:
				for i in CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE):
					if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, pl, CustomDuelOps.LOC_GRAVE, i)) in CustomDuelOps.SHINING_SARC_IDS:
						c += 1
			out["atk_delta"] = int(out.get("atk_delta", 0)) + c * 300
		2545: # Dark Paladin: +500 per Dragon on field & GYs
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_race_field_and_gys(duel, 1) * 500
		2546: # Dark Paladin Wave-Motion: +500 per other monster on field
			out["atk_delta"] = int(out.get("atk_delta", 0)) + maxi(0, CustomDuelOps.count_total_monsters_on_field(duel) - 1) * 500
		2552: # Dragon Master Knight: +500 per other Dragon you control
			var dn = 0
			for zz in 5:
				if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, p, zz)) == 1:
					dn += 1
			out["atk_delta"] = int(out.get("atk_delta", 0)) + dn * 500
		2564: # Neos Knight: +1250
			out["atk_delta"] = int(out.get("atk_delta", 0)) + 1250
		2565: # Shining Flare Wingman: +300 per E-HERO in GY
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_ids_in_gy(duel, p, CustomDuelOps.ELEMENTAL_HERO_IDS) * 300
		2575: # Exodius: +1000 per Normal Monster in GY
			var nm = 0
			for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
				if CustomDuelOps.is_normal_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)):
					nm += 1
			out["atk_set"] = nm * 1000
		2582, 2585: # Gandora-G / Gigarays: +300 per banished card
			var bn = CustomDuelOps.pile_count(duel, 0, CustomDuelOps.LOC_BANISH) + CustomDuelOps.pile_count(duel, 1, CustomDuelOps.LOC_BANISH)
			out["atk_delta"] = int(out.get("atk_delta", 0)) + bn * 300
		2594: # Inferno Uria: +1000 per Trap in GYs
			var tr = 0
			for pl in 2:
				for i in CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE):
					if CustomDuelOps.is_trap(duel, CustomDuelOps.pile_idx(duel, pl, CustomDuelOps.LOC_GRAVE, i)):
						tr += 1
			out["atk_set"] = tr * 1000
			out["def_set"] = tr * 1000
		2627: # Red-Eyes Darkness Dragon: +300 per Dragon in GY
			out["atk_delta"] = int(out.get("atk_delta", 0)) + _count_race_in_gy(duel, p, 1) * 300
		2635: # Silent Magician: +500 per card in hand
			out["atk_delta"] = int(out.get("atk_delta", 0)) + CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) * 500
		2636: # Silent Magician LV4: +500 per Spell Counter
			out["atk_delta"] = int(out.get("atk_delta", 0)) + CustomDuelOps.get_counter(duel, p, z, "spell") * 500
		2638, 2643: # Silent Magician Zero / Swordsman Zero
			out["atk_delta"] = int(out.get("atk_delta", 0)) + int(zf.get("lv_bonus", 0)) * 500
		2657: # Legendary Exodia Incarnate: +1000 per Forbidden One in GY
			out["atk_set"] = _count_ids_in_gy(duel, p, CustomDuelOps.FORBIDDEN_ONE_IDS) * 1000
		2661: # The Wicked Avatar: highest current ATK on the field + 100
			var hi = 0
			for pl in 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.zone_id(duel, pl, zz) != 2661:
						var ba = CustomDuelOps.eff_atk(duel, pl, zz)
						if ba > hi:
							hi = ba
			out["atk_set"] = hi + 100
			out["def_set"] = hi + 100
		2663: # The Wicked Eraser: opp field cards * 1000
			var c = CustomDuelOps.total_field_cards(duel, opp) * 1000
			out["atk_set"] = c
			out["def_set"] = c
		2669: # Toon DMG: +300 per DM / MoBC in GYs
			var dm = 0
			for pl in 2:
				for i in CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_GRAVE):
					var gid = CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, pl, CustomDuelOps.LOC_GRAVE, i))
					if gid in CustomDuelOps.NATIVE_DARK_MAGICIAN or gid == CustomDuelOps.NATIVE_MAGICIAN_BLACK_CHAOS:
						dm += 1
			out["atk_delta"] = int(out.get("atk_delta", 0)) + dm * 300
		2677: # Uria: +1000 per Continuous Trap in your GY
			var ctr = 0
			for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
				var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
				if CustomDuelOps.is_trap(duel, idx) and CustomDuelOps.csub(duel, idx) == 4:
					ctr += 1
			out["atk_set"] = ctr * 1000
		2684: # Winged Kuriboh LV9: opp GY Spells * 500
			var sp = 0
			for i in CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE):
				if CustomDuelOps.is_spell(duel, CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_GRAVE, i)):
					sp += 1
			out["atk_set"] = sp * 500
			out["def_set"] = sp * 500
		2706: # Gradius' Option: copy selected Gradius ATK/DEF
			var gz := int(zf.get("gradius_link", -1))
			if gz >= 0 and CustomDuelOps.zone_id(duel, p, gz) == CustomDuelOps.NATIVE_GRADIUS:
				out["atk_set"] = CustomDuelOps.eff_atk(duel, p, gz)
				out["def_set"] = CustomDuelOps.eff_def(duel, p, gz)


static func can_attack(duel, p: int, z: int, cid: int) -> bool:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	var zf = CustomDuelOps.zflags(duel, p, z)
	if int(zf.get("cannot_atk_turn", -1)) == t:
		return false
	if cid == 2503: # Sphere Mode
		return false
	if cid in TOON_MONSTERS_M1 and int(zf.get("summoned_turn", -1)) == t:
		return false
	if cid == 2782: # Cave Dragon requires another Dragon
		var has_other = false
		for zz in 5:
			if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.monster_race(duel, CustomDuelOps.zone_idx(duel, p, zz)) == 1:
				has_other = true
				break
		if not has_other:
			return false
	# Malefic on field stops other monsters from attacking
	for zz in 5:
		if zz != z and CustomDuelOps.zone_id(duel, p, zz) == 2602 and CustomDuelOps.is_face_up(duel, p, zz):
			return false
	if int(CustomDuelOps.pflags(duel, p).get("skip_bp_turn", -1)) == t:
		return false
	if CustomDuelOps.has_faceup_id(duel, opp, 2554) and cid != 2554:
		pass
	return true


static func can_direct_attack(duel, p: int, _z: int, cid: int) -> bool:
	if cid == 2768 or cid == 2795: # Inaba White Rabbit / Servant of Catabolism
		return true
	if cid in TOON_MONSTERS_M1 and CustomDuelOps.has_toon_world(duel, p):
		var opp = 1 - (p & 1)
		for zz in 5:
			if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.zone_id(duel, opp, zz) in CustomDuelOps.TOON_IDS:
				return false
		return true
	return false


static func has_pierce(duel, p: int, z: int, cid: int) -> bool:
	return cid in [2538, 2539, 2712, 2723] or bool(CustomDuelOps.zflags(duel, p, z).get("pierce", false))


static func max_attacks(duel, p: int, z: int, cid: int) -> int:
	var t = CustomDuelOps.turn_number(duel)
	if cid == 2519:
		return 3
	if cid == 2539 and CustomDuelOps.eff_atk(duel, p, z) > CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, p, z)):
		return 3
	if cid == 2540 or cid == 2564 or cid == 2785:
		return 2
	if cid in [2546, 2676, 2700]:
		return 5
	if bool(CustomDuelOps.zflags(duel, p, z).get("attack_all_turn", -1) == t):
		return 5
	if bool(CustomDuelOps.zflags(duel, p, z).get("extra_atk_grant", -1) == t) or int(CustomDuelOps.zflags(duel, p, z).get("multi_atk_2", -1)) == t:
		return 2
	return 1


static func check_win(duel) -> int:
	for pl in 2:
		for z in 5:
			if CustomDuelOps.zone_idx(duel, pl, z) == 0:
				continue
			var cid = CustomDuelOps.zone_id(duel, pl, z)
			if cid == 2505 and CustomDuelOps.is_face_up(duel, pl, z):
				return pl
			if cid == 2575 and CustomDuelOps.is_face_up(duel, pl, z):
				var sent_f: Array = CustomDuelOps.zflags(duel, pl, z).get("exodius_forbidden", [])
				if sent_f.size() >= 5:
					return pl
			if cid == 2674 and CustomDuelOps.is_face_up(duel, pl, z):
				var my_n = CustomDuelOps.count_monsters(duel, pl, false)
				var opp_n = CustomDuelOps.count_monsters(duel, 1 - pl, false)
				if my_n == 5 and opp_n == 0:
					var found: Array[int] = []
					for zz in 5:
						var zid = CustomDuelOps.zone_id(duel, pl, zz)
						if zid in CustomDuelOps.FORBIDDEN_ONE_IDS and zid not in found and CustomDuelOps.is_face_up(duel, pl, zz):
							found.append(zid)
					if found.size() == 4:
						return 1 - pl
	return -1


# --- Private Helpers -----------------------------------------------------------------------------

static func _collect_monster_zones(duel, p: int, pred: Callable) -> Array[int]:
	var out: Array[int] = []
	for zz in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, zz)
		if idx != 0 and pred.call(duel, p, zz, idx):
			out.append(zz)
	return out


static func _collect_faceup_st_sub(duel, p: int, cat: int, sub: int) -> Array[int]:
	var out: Array[int] = []
	for zz in range(5, 10):
		var idx = CustomDuelOps.zone_idx(duel, p, zz)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.ctype(duel, idx) == cat:
			if sub < 0 or CustomDuelOps.csub(duel, idx) == sub:
				out.append(zz)
	return out


static func _find_attr_in_gy(duel, p: int, attr: int) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _s): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_attr(d, idx) == attr, false)


static func _count_attr_in_gy(duel, p: int, attr: int) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
		if CustomDuelOps.is_monster(duel, idx) and CustomDuelOps.monster_attr(duel, idx) == attr:
			n += 1
	return n


static func _count_race_in_gy(duel, p: int, race: int) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
		if CustomDuelOps.is_monster(duel, idx) and CustomDuelOps.monster_race(duel, idx) == race:
			n += 1
	return n


static func _count_race_field_and_gys(duel, race: int) -> int:
	var n = 0
	for pl in 2:
		for z in 5:
			var idx = CustomDuelOps.zone_idx(duel, pl, z)
			if idx != 0 and CustomDuelOps.is_face_up(duel, pl, z) and CustomDuelOps.monster_race(duel, idx) == race:
				n += 1
		n += _count_race_in_gy(duel, pl, race)
	return n


static func _count_ids_in_gy(duel, p: int, id_list: Array) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)) in id_list:
			n += 1
	return n


static func _count_distinct_ids_in_gy(duel, p: int, id_list: Array) -> int:
	var seen: Array[int] = []
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var rid = CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i))
		if rid in id_list and rid not in seen:
			seen.append(rid)
	return seen.size()


static func _count_monsters_in_gy(duel, p: int) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)):
			n += 1
	return n


static func _count_other_monsters_hand_field(duel, p: int, skip_hand_slot: int) -> int:
	var n = CustomDuelOps.count_monsters(duel, p, false)
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
		if i != skip_hand_slot and CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)):
			n += 1
	return n


static func _find_armed_lv10_combo(duel, p: int) -> Array:
	# Armed Dragon monsters on the field and/or in the GY whose total Levels equal 10.
	var lv_of := {2510: 3, 2511: 5, 2512: 7, 2508: 10, 2509: 10}
	var cands: Array = []
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0:
			var rid = CustomDuelOps.raw_id(duel, idx)
			if lv_of.has(rid):
				cands.append({"where": "field", "idx": z, "lv": int(lv_of[rid])})
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var rid2 = CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i))
		if lv_of.has(rid2):
			cands.append({"where": "gy", "idx": i, "lv": int(lv_of[rid2])})
	var n := cands.size()
	var best: Array = []
	for mask in range(1, 1 << n):
		var total := 0
		var chosen: Array = []
		for k in n:
			if (mask >> k) & 1:
				total += int(cands[k]["lv"])
				chosen.append(cands[k])
		if total == 10 and (best.is_empty() or chosen.size() < best.size()):
			best = chosen
	# Banish GY cards from the highest index down so earlier indexes stay valid.
	best.sort_custom(func(a, b): return (str(a["where"]) == "field" and str(b["where"]) != "field") or (str(a["where"]) == str(b["where"]) and int(a["idx"]) > int(b["idx"])))
	return best


static func _find_god_slime_tribute(duel, p: int) -> int:
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.monster_race(duel, idx) == 14 and CustomDuelOps.monster_level(duel, idx) == 10 and CustomDuelOps.eff_atk(duel, p, z) == 0:
			return z
	return -1


static func _has_faceup_name(duel, p: int, substr: String) -> bool:
	for z in range(0, 11):
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.name_matches(duel, idx, substr):
			return true
	return false


static func _has_shining_sarc(duel, p: int) -> bool:
	return _has_faceup_name(duel, p, "shining sarcophagus")


static func _has_malefic_on_field(duel) -> bool:
	return CustomDuelOps.has_faceup_id(duel, 0, 2602) or CustomDuelOps.has_faceup_id(duel, 1, 2602)


static func _find_red_eyes_zone(duel, p: int) -> int:
	for rid in CustomDuelOps.NATIVE_RED_EYES:
		var z = CustomDuelOps.find_zone_of_id(duel, p, rid, true)
		if z >= 0:
			return z
	return -1


static func _has_all_zones(duel, p: int, reqs: Array) -> bool:
	for r in reqs:
		if CustomDuelOps.find_zone_of_id(duel, p, int(r), true) < 0:
			return false
	return true


static func _can_summon_wk6(duel, p: int, loc: int, slot: int) -> bool:
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		if loc == CustomDuelOps.LOC_GRAVE and i == slot:
			continue
		var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
		var rid = CustomDuelOps.raw_id(duel, idx)
		if rid == 2681 or (rid in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.is_extra_deck_monster(duel, idx)):
			return true
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z):
			var rid = CustomDuelOps.raw_id(duel, idx)
			if rid == 2681 or (rid in CustomDuelOps.ELEMENTAL_HERO_IDS and CustomDuelOps.is_extra_deck_monster(duel, idx)):
				return true
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
		if loc == CustomDuelOps.LOC_HAND and i == slot:
			continue
		if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)) == 2681:
			return true
	return false


static func _has_archetype_on_field(duel, p: int, id_list: Array) -> bool:
	for z in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, z)
		if idx != 0 and CustomDuelOps.is_face_up(duel, p, z) and CustomDuelOps.raw_id(duel, idx) in id_list:
			return true
	return false


static func _has_sacred_beast_st_in_deck(duel, p: int, is_sp: bool) -> bool:
	var list = [2548, 2577, 2629] if is_sp else [2553, 2707]
	for sid in list:
		if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, sid) >= 0:
			return true
	return false


static func _has_sacred_beast_monster_in_deck(duel, p: int, except_id: int) -> bool:
	for sid in CustomDuelOps.SACRED_BEAST_IDS:
		if sid != except_id and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, sid) >= 0:
			return true
	return false


static func _find_race_in_pile(duel, p: int, loc: int, race: int, except_id := -1) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, loc, func(d, idx, _s): return CustomDuelOps.monster_race(d, idx) == race and CustomDuelOps.raw_id(d, idx) != except_id, true)


static func _find_metal_reflect(duel, p: int) -> int:
	for loc in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK, CustomDuelOps.LOC_GRAVE]:
		var idx = CustomDuelOps.find_pile_index_by_id(duel, p, loc, 2606)
		if idx >= 0:
			return idx
	return -1


static func _find_fusion_spell_in_deck(duel, p: int) -> int:
	var fi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_POLYMERIZATION)
	if fi >= 0:
		return fi
	return CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2615)
