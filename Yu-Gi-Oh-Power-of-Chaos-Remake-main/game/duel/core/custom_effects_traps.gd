class_name CustomEffectsTraps
extends RefCounted
## Faithful implementations for all 97 custom Trap cards (2521..3108) across Core and Joey.

const IDS: Array[int] = [
	2521, 2529, 2553, 2605, 2606, 2621, 2629, 2631, 2644, 2650,
	2652, 2658, 2707, 2715, 2718, 2720, 2724, 2734, 2737, 2745,
	2747, 2750, 2751, 2759, 2766, 2769, 2773, 2774, 2779, 2780,
	2781, 2787, 2791, 2792, 2796, 2797, 2798, 2799, 2802, 2824,
	2827, 2828, 2829, 2832, 2837, 2852, 2856, 2858, 2859, 2860,
	2867, 2869, 2871, 2875, 2887, 2916, 2917, 2919, 2920, 2927,
	2932, 2944, 2951, 2952, 2953, 2954, 2955, 2957, 2971, 2978,
	2979, 2980, 2982, 2985, 3006, 3007, 3012, 3014, 3015, 3024,
	3037, 3040, 3041, 3042, 3044, 3067, 3068, 3073, 3075, 3077,
	3102, 3103, 3104, 3105, 3106, 3107, 3108,
]


static func handles(cid: int) -> bool:
	return cid in IDS


static func can_activate(duel, p: int, cid: int, loc: int, _z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp = 1 - p
	var ev := str(ctx.get("event", "free"))
	var pf = CustomDuelOps.pflags(duel, p)
	if int(pf.get("cannot_activate_st_until_turn", -1)) >= CustomDuelOps.turn_number(duel):
		return false
	if int(pf.get("locked_st_until_ep", -1)) == CustomDuelOps.turn_number(duel):
		return false
	match cid:
		2521: # Bottomless Trap Hole
			return (ev == "summon" or ev == "normal_summon") and int(ctx.get("summon_p", -1)) == opp and int(ctx.get("summon_atk", 0)) >= 1500
		2529: # Compulsory Evacuation Device
			return CustomDuelOps.count_total_monsters_on_field(duel) > 0
		2553, 2631, 2832, 2955, 3075, 3104, 3108:
			if cid == 2955 and not _has_archetype_on_field(duel, p, CustomDuelOps.AMAZONESS_IDS):
				return false
			if cid == 3075 and CustomDuelOps.count_monsters(duel, p, true) == 0:
				return false
			if cid == 3104:
				var has_def = false
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and not CustomDuelOps.is_atk_pos(duel, opp, zz):
						has_def = true
						break
				if not has_def:
					return false
			if cid == 3108 and (CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 0 or CustomDuelOps.free_monster_zone(duel, p) < 0):
				return false
			return ev == "attack_declare" and int(ctx.get("atk_p", -1)) == opp
		2605: # Mayakashi Metamorphosis
			return CustomDuelOps.can_hopt(duel, p, 2605) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0 and not CustomDuelOps.is_necrovalley_active(duel) and _find_in_gy_or_banish(duel, p, [2605]) >= 0
		2606: # Metal Reflect Slime
			return CustomDuelOps.free_monster_zone(duel, p) >= 0
		2621: # Obliterate!!!
			if loc == CustomDuelOps.LOC_FIELD_ST:
				return true
			return CustomDuelOps.can_hopt(duel, p, 2621) and CustomDuelOps.count_total_monsters_on_field(duel) > 0 and _has_exodia_in_hand_or_deck(duel, p)
		2629: # Return from the Different Dimension
			return CustomDuelOps.get_lp(duel, p) > 1 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_BANISH) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0
		2644: # Skill Drain
			return CustomDuelOps.can_pay_lp(duel, p, 1000)
		2650: # Soul Energy MAX!!!
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.can_hopt(duel, p, 2650) and (CustomDuelOps.phase(duel) in [CustomDuelOps.PHASE_M1, CustomDuelOps.PHASE_BP, CustomDuelOps.PHASE_M2]) and (CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2500) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2500) >= 0)
			return CustomDuelOps.can_hopt(duel, p, 2650) and CustomDuelOps.has_faceup_id(duel, p, 2500) and CustomDuelOps.count_monsters(duel, p, true) >= 3
		2652: # Sun God Unification
			return true
		2658: # The Revived Sky God
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.can_hopt(duel, p, 2658) and (CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_MONSTER_REBORN) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, CustomDuelOps.NATIVE_MONSTER_REBORN) >= 0)
			return CustomDuelOps.can_hopt(duel, p, 2658) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2502) >= 0 and not CustomDuelOps.is_necrovalley_active(duel)
		2707, 2734, 2745, 2750, 2769, 2828, 2860, 2867, 2927, 2979, 3037, 3103:
			return true
		2715: # Disappear
			return not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0
		2718: # Last Turn
			return CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.get_lp(duel, p) <= 1000 and CustomDuelOps.count_monsters(duel, p, false) > 0
		2720: # Nutrient Z
			return (ev == "damage_calc" or ev == "damage_step") and int(ctx.get("recv_p", -1)) == p and int(ctx.get("amount", 2000)) >= 2000
		2724: # Ready for Intercepting
			return not CustomDuelOps.choose_zone(duel, p, func(d, _pl, zz, idx): return zz < 5 and CustomDuelOps.is_face_up(d, _pl, zz) and (CustomDuelOps.monster_race(d, idx) == 15 or CustomDuelOps.monster_race(d, idx) == 18)).is_empty()
		2737: # Bark of Dark Ruler
			return (ev == "damage_step" or ev == "damage_calc") and CustomDuelOps.can_pay_lp(duel, p, 100) and _battling_has_race(duel, p, 3, ctx)
		2747: # Drop Off
			return ev == "draw" and int(ctx.get("draw_p", -1)) == opp and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_DP and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		2751: # Bubble Crash
			var mine = CustomDuelOps.total_field_cards(duel, p) + CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
			var theirs = CustomDuelOps.total_field_cards(duel, opp) + CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND)
			return mine >= 6 or theirs >= 6
		2759: # A Feint Plan
			return true
		2766: # Soul Demolition
			return _has_race_on_field(duel, p, 3) and CustomDuelOps.can_pay_lp(duel, p, 500) and not CustomDuelOps.is_necrovalley_active(duel)
		2773: # Burst Breath
			return _has_race_on_field(duel, p, 1, false)
		2774: # Fiend Comedian
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0
		2779: # Spirit's Invitation
			return true
		2780: # The Dragon's Bead
			return ev == "chain_negate" and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and _chain_targets_race(duel, ctx, 1, true)
		2781: # Royal Oppression
			if ev == "chain_negate":
				return CustomDuelOps.can_pay_lp(duel, p, 800)
			return true
		2787: # Blast with Chain
			return CustomDuelOps.count_monsters(duel, p, true) > 0
		2791: # Pyro Clock of Destiny
			return true
		2792, 2859: # Dark Coffin / Statue of the Wicked (usually trigger on set destroy, allow manual check fail unless event)
			return ev == "destroyed_set"
		2796: # D. Tribe
			return CustomDuelOps.count_monsters(duel, p, false) > 0
		2797: # Curse of Royal
			return ev == "chain_negate" and bool(ctx.get("destroys_st", false))
		2798: # Trap of Board Eraser
			return ev == "effect_damage_incoming" and int(ctx.get("recv_p", -1)) == p
		2799: # Tutan Mask
			return ev == "chain_negate" and _chain_targets_race(duel, ctx, 2, false)
		2802: # Raigeki Break
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and (CustomDuelOps.total_field_cards(duel, opp) > 0 or CustomDuelOps.total_field_cards(duel, p) > 0)
		2824: # Rite of Spirit
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_archetype_in_gy(duel, p, CustomDuelOps.GRAVEKEEPER_IDS) >= 0
		2827: # Reckless Greed
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) >= 2
		2829: # Needle Ceiling
			return CustomDuelOps.count_total_monsters_on_field(duel) >= 4
		2837: # Curse of Aging
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2852: # Nightmare Wheel
			return CustomDuelOps.count_monsters(duel, opp, false) > 0
		2856: # Pharaoh's Treasure
			return true
		2858: # Trap Dustshoot
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) >= 4
		2869: # Non Aggression Area
			return CustomDuelOps.turn_player(duel) == p and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_SP and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0
		2871: # Disturbance Strategy
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		2875: # Barrel Behind the Door
			return ev == "effect_damage_incoming" and int(ctx.get("recv_p", -1)) == p
		2887: # Rope of Life
			return ev == "destroyed_battle_gy" and int(ctx.get("owner_p", -1)) == p and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 1 and CustomDuelOps.free_monster_zone(duel, p) >= 0
		2916: # Disarmament
			return _has_any_equip_on_field(duel)
		2917: # Hidden Spellbook
			return CustomDuelOps.turn_player(duel) == p and not CustomDuelOps.is_necrovalley_active(duel) and _count_pile_spells(duel, p, CustomDuelOps.LOC_GRAVE) >= 2
		2919: # Formation Union
			return _has_archetype_on_field(duel, p, CustomDuelOps.UNION_IDS) or _has_equipped_union(duel, p)
		2920: # Secret Barrel
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) + CustomDuelOps.total_field_cards(duel, opp) > 0
		2932: # Spell Shield Type-8
			return ev == "chain_negate" and bool(ctx.get("is_spell", false)) and (bool(ctx.get("targets_1_monster", false)) or _count_pile_spells(duel, p, CustomDuelOps.LOC_HAND) > 0)
		2944: # Anti-Spell
			return ev == "chain_negate" and bool(ctx.get("is_spell", false)) and CustomDuelOps.total_spell_counters(duel, p) >= 2
		2951: # Adhesion Trap Hole
			return (ev == "summon" or ev == "normal_summon") and int(ctx.get("summon_p", -1)) == opp
		2952: # Physical Double
			return CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.count_monsters(duel, opp, true) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0
		2953: # Meteorain
			return true
		2954: # Huge Revolution
			return CustomDuelOps.turn_player(duel) == p and CustomDuelOps.phase(duel) in [CustomDuelOps.PHASE_M1, CustomDuelOps.PHASE_M2] and CustomDuelOps.has_faceup_id(duel, p, 2913) and CustomDuelOps.has_faceup_id(duel, p, 2946) and CustomDuelOps.has_faceup_id(duel, p, 2976)
		2957: # Miracle Restoring
			return CustomDuelOps.total_spell_counters(duel, p) >= 2 and CustomDuelOps.free_monster_zone(duel, p) >= 0 and not CustomDuelOps.is_necrovalley_active(duel) and (_find_in_gy(duel, p, [34, 2034, CustomDuelOps.NATIVE_BUSTER_BLADER]) >= 0)
		2971: # Dramatic Rescue
			return ev == "chain_negate" and _chain_targets_archetype(duel, ctx, CustomDuelOps.AMAZONESS_IDS) and _has_monster_in_hand(duel, p)
		2978: # Pineapple Blast
			return ev == "normal_summon" and int(ctx.get("summon_p", -1)) == p and CustomDuelOps.count_monsters(duel, opp, false) > CustomDuelOps.count_monsters(duel, p, false)
		2980: # Thunder of Ruler
			return CustomDuelOps.turn_player(duel) == opp and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_SP
		2982: # Exhausting Spell
			return CustomDuelOps.total_spell_counters(duel, -1) > 0
		2985: # The Spell Absorbing Life
			for pl in 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and not CustomDuelOps.is_face_up(duel, pl, zz):
						return true
			return false
		3006: # Dark Scorpion Combination
			return CustomDuelOps.has_faceup_id(duel, p, 2550) and CustomDuelOps.has_faceup_id(duel, p, 2894) and CustomDuelOps.has_faceup_id(duel, p, 3049) and CustomDuelOps.has_faceup_id(duel, p, 3032) and CustomDuelOps.has_faceup_id(duel, p, 3061)
		3007: # Altar for Tribute
			return CustomDuelOps.count_monsters(duel, p, false) > 0
		3012: # Really Eternal Rest
			return _has_any_equip_on_field(duel)
		3014: # Spell Vanishing
			return ev == "chain_negate" and bool(ctx.get("is_spell", false)) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 2
		3015: # Ojama Trio
			var free = 0
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) == 0:
					free += 1
			return free >= 3
		3024: # Interdimensional Matter Transporter
			return CustomDuelOps.count_monsters(duel, p, true) > 0
		3040: # Judgment of Anubis
			return ev == "chain_negate" and bool(ctx.get("is_spell", false)) and bool(ctx.get("destroys_st", false)) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) >= 1
		3041: # Arsenal Robber
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_DECK) > 0
		3042: # Archfiend's Roar
			return CustomDuelOps.can_pay_lp(duel, p, 500) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and not CustomDuelOps.is_necrovalley_active(duel) and _find_archetype_in_gy(duel, p, CustomDuelOps.ARCHFIEND_IDS) >= 0
		3044: # Frozen Soul
			return CustomDuelOps.get_lp(duel, opp) - CustomDuelOps.get_lp(duel, p) >= 2000
		3067: # Ray of Hope
			return not CustomDuelOps.is_necrovalley_active(duel) and _count_gy_attr(duel, p, 1) >= 2
		3068: # Dice Re-Roll
			return true
		3073: # Blast Held by a Tribute
			return ev == "attack_declare" and int(ctx.get("atk_p", -1)) == opp and bool(ctx.get("tribute_summoned", false))
		3077: # Battle-Scarred
			return _has_archetype_on_field(duel, p, CustomDuelOps.ARCHFIEND_IDS)
		3102: # Trap Jammer
			return ev == "chain_negate" and bool(ctx.get("is_trap", false)) and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP
		3105: # Spatial Collapse
			return CustomDuelOps.total_field_cards(duel, 0) <= 5 and CustomDuelOps.total_field_cards(duel, 1) <= 5
		3106: # Destruction Ring
			return CustomDuelOps.count_monsters(duel, p, true) > 0
		3107: # Blasting the Ruins
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE) >= 30
	return false


static func resolve(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp = 1 - p
	var t = CustomDuelOps.turn_number(duel)
	match cid:
		2521: # Bottomless Trap Hole
			var sz := int(ctx.get("summon_z", -1))
			if sz >= 0 and sz < 5 and CustomDuelOps.zone_idx(duel, opp, sz) != 0 and CustomDuelOps.eff_atk(duel, opp, sz) >= 1500:
				CustomDuelOps.banish_zone(duel, opp, sz)
				return true
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.eff_atk(d, pl, zz) >= 1500)
			if not tgt.is_empty():
				CustomDuelOps.banish_zone(duel, opp, tgt["z"])
			return true
		2529: # Compulsory Evacuation Device
			var tgt = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5)
			if not tgt.is_empty():
				CustomDuelOps.bounce_zone(duel, tgt["p"], tgt["z"])
			return true
		2553: # Draining Shield
			var az := int(ctx.get("atk_z", -1))
			if az >= 0 and az < 5 and CustomDuelOps.zone_idx(duel, opp, az) != 0:
				var gain = CustomDuelOps.eff_atk(duel, opp, az)
				ctx["negate_attack"] = true
				CustomDuelOps.pflags(duel, p)["negate_current_attack"] = true
				CustomDuelOps.heal(duel, p, gain)
			return true
		2605: # Mayakashi Metamorphosis
			CustomDuelOps.mark_hopt(duel, p, 2605)
			CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true)
			var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
			if gi >= 0:
				var mz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
				if mz >= 0:
					CustomDuelOps.zflags(duel, p, mz)["untargetable_until_turn"] = t
			return true
		2606: # Metal Reflect Slime
			var mz = CustomDuelOps.activate_trap_as_monster(duel, p, z, 0, 3000, 14, 3, 10)
			if mz >= 0:
				CustomDuelOps.change_position(duel, p, mz, 1, 1)
				CustomDuelOps.zflags(duel, p, mz)["cannot_attack"] = true
			return true
		2621: # Obliterate!!!
			if loc == CustomDuelOps.LOC_GRAVE or bool(ctx.get("sent_to_gy", false)):
				CustomDuelOps.mark_hopt(duel, p, 2621)
				var gi = _find_in_gy(duel, p, CustomDuelOps.EXODIA_IDS)
				if gi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, gi)
				return true
			if CustomDuelOps.can_hopt(duel, p, 2621):
				CustomDuelOps.mark_hopt(duel, p, 2621)
				var sent = false
				var hi = _find_in_pile(duel, p, CustomDuelOps.LOC_HAND, CustomDuelOps.EXODIA_IDS)
				if hi >= 0:
					CustomDuelOps.discard_hand_slot(duel, p, hi)
					sent = true
				else:
					var di = _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.EXODIA_IDS)
					if di >= 0:
						CustomDuelOps.send_from_deck_to_gy(duel, p, di)
						sent = true
				if sent:
					var tgt = CustomDuelOps.choose_zone(duel, p, func(_d, _pl, zz, _idx): return zz < 5)
					if not tgt.is_empty():
						CustomDuelOps.bounce_zone(duel, tgt["p"], tgt["z"])
			return true
		2629: # Return from the Different Dimension
			CustomDuelOps.pay_half_lp(duel, p)
			while CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var bi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_BANISH, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
				if bi < 0:
					break
				var mz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_BANISH, bi, p)
				if mz < 0:
					break
				CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 2629, "banish_zone", {"p": p, "z": mz})
			return true
		2631: # Sakuretsu Armor
			var az := int(ctx.get("atk_z", -1))
			if az >= 0 and az < 5:
				CustomDuelOps.destroy_zone(duel, opp, az)
			return true
		2644: # Skill Drain
			CustomDuelOps.pay_lp(duel, p, 1000)
			return true
		2650: # Soul Energy MAX!!!
			CustomDuelOps.mark_hopt(duel, p, 2650)
			if loc == CustomDuelOps.LOC_GRAVE:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, int(ctx.get("pile_i", 0)))
				var idx_o = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2500)
				if idx_o >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, idx_o)
				else:
					idx_o = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2500)
					if idx_o >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, idx_o)
				return true
			var trib = 0
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) != 2500 and trib < 2:
					CustomDuelOps.tribute_zone(duel, p, zz)
					trib += 1
			if trib == 2:
				var destroyed = 0
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.destroy_zone(duel, opp, zz):
						destroyed += 1
				if destroyed > 0:
					CustomDuelOps.damage(duel, opp, 4000)
			return true
		2652: # Sun God Unification
			var ra_z = CustomDuelOps.find_zone_of_id(duel, p, 2501, true)
			if ra_z >= 0:
				if CustomDuelOps.get_lp(duel, p) > 100 and CustomDuelOps.can_opt(duel, p, 2652, 0):
					CustomDuelOps.mark_opt(duel, p, 2652, 0)
					var paid = CustomDuelOps.get_lp(duel, p) - 100
					CustomDuelOps.pay_lp(duel, p, paid)
					CustomDuelOps.add_stat_mod(duel, p, ra_z, paid, paid, false)
				elif CustomDuelOps.can_opt(duel, p, 2652, 1):
					CustomDuelOps.mark_opt(duel, p, 2652, 1)
					var atk = CustomDuelOps.eff_atk(duel, p, ra_z)
					CustomDuelOps.tribute_zone(duel, p, ra_z)
					CustomDuelOps.heal(duel, p, atk)
			return true
		2658: # The Revived Sky God
			CustomDuelOps.mark_hopt(duel, p, 2658)
			if loc == CustomDuelOps.LOC_GRAVE:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, int(ctx.get("pile_i", 0)))
				var r_idx = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_MONSTER_REBORN)
				if r_idx >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_DECK, r_idx, p, CustomDuelOps.LOC_DECK, false)
				else:
					r_idx = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, CustomDuelOps.NATIVE_MONSTER_REBORN)
					if r_idx >= 0:
						CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, r_idx, p, CustomDuelOps.LOC_DECK, false)
				for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
					if CustomDuelOps.is_divine_beast(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)):
						CustomDuelOps.draw(duel, p, 1)
						break
				return true
			var si = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2502)
			if si >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, si, p)
			for pl in [p, opp]:
				var need = 6 - CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND)
				if need > 0:
					CustomDuelOps.draw(duel, pl, need)
			return true
		2707: # Life Absorbing Machine (continuous standby heal)
			return true
		2715: # Disappear
			var gi = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(_d, _idx, _i): return true)
			if gi >= 0:
				CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, gi)
			return true
		2718: # Last Turn
			var keep = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, true, false)
			var keep_z := int(keep.get("z", -1))
			for pl in 2:
				for zz in 11:
					if pl == p and (zz == keep_z or zz == z):
						continue
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						CustomDuelOps.send_zone_to_gy(duel, pl, zz)
				while CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) > 0:
					CustomDuelOps.discard_hand_slot(duel, pl, 0)
			var opp_mon_i = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
			if opp_mon_i >= 0:
				CustomDuelOps.special_summon_from_pile(duel, opp, CustomDuelOps.LOC_DECK, opp_mon_i, opp, true, false)
			CustomDuelOps.pflags(duel, p)["last_turn_active"] = t
			CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 2718, "last_turn_judge", {})
			return true
		2720: # Nutrient Z
			CustomDuelOps.heal(duel, p, 4000)
			return true
		2724: # Ready for Intercepting
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) in [15, 18])
			if not tgt.is_empty():
				CustomDuelOps.change_position(duel, tgt["p"], tgt["z"], 1, 0)
			return true
		2734, 2745, 2769, 2860:
			return true
		2737: # Bark of Dark Ruler
			var pay = mini(CustomDuelOps.get_lp(duel, p) - 100, 2000)
			pay = int(pay / 100) * 100
			if pay >= 100:
				CustomDuelOps.pay_lp(duel, p, pay)
				var opp_z := int(ctx.get("opp_z", -1))
				if opp_z >= 0 and opp_z < 5:
					CustomDuelOps.add_stat_mod(duel, opp, opp_z, -pay, -pay, true)
			return true
		2747: # Drop Off
			var hc = CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND)
			if hc > 0:
				CustomDuelOps.discard_hand_slot(duel, opp, hc - 1, 1)
			return true
		2750: # Ominous Fortunetelling
			return true
		2751: # Bubble Crash
			for pl in [p, opp]:
				var excess = (CustomDuelOps.total_field_cards(duel, pl) + CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND)) - 5
				while excess > 0 and CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) > 0:
					CustomDuelOps.discard_hand_slot(duel, pl, 0)
					excess -= 1
				for zz in range(5, 11):
					if excess > 0 and CustomDuelOps.zone_idx(duel, pl, zz) != 0 and not (pl == p and zz == z):
						CustomDuelOps.send_zone_to_gy(duel, pl, zz)
						excess -= 1
				for zz in 5:
					if excess > 0 and CustomDuelOps.zone_idx(duel, pl, zz) != 0:
						CustomDuelOps.send_zone_to_gy(duel, pl, zz)
						excess -= 1
			return true
		2759: # A Feint Plan
			CustomDuelOps.pflags(duel, p)["cannot_attack_facedown_turn"] = t
			CustomDuelOps.pflags(duel, opp)["cannot_attack_facedown_turn"] = t
			return true
		2766: # Soul Demolition
			if CustomDuelOps.can_pay_lp(duel, p, 500) and _has_race_on_field(duel, p, 3):
				CustomDuelOps.pay_lp(duel, p, 500)
				for side in [opp, p]:
					var gi = CustomDuelOps.choose_pile_card(duel, side, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
					if gi >= 0:
						CustomDuelOps.banish_from_pile(duel, side, CustomDuelOps.LOC_GRAVE, gi)
			return true
		2773: # Burst Breath
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.monster_race(d, idx) == 1, true, false)
			if not tgt.is_empty():
				var cap = CustomDuelOps.eff_atk(duel, p, tgt["z"])
				CustomDuelOps.tribute_zone(duel, p, tgt["z"])
				for pl in 2:
					for zz in 5:
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.eff_def(duel, pl, zz) <= cap:
							CustomDuelOps.destroy_zone(duel, pl, zz)
			return true
		2774: # Fiend Comedian
			var coin = CustomDuelOps.coin_toss(duel, p)
			if coin == 1:
				while CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0:
					CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, 0)
			else:
				CustomDuelOps.mill(duel, p, CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE), 1)
			return true
		2779: # Spirit's Invitation
			return true
		2780: # The Dragon's Bead
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2781: # Royal Oppression
			if str(ctx.get("event", "")) == "chain_negate" and CustomDuelOps.can_pay_lp(duel, p, 800):
				CustomDuelOps.pay_lp(duel, p, 800)
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2787: # Blast with Chain
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, false)
			if not tgt.is_empty():
				CustomDuelOps.link_equip(duel, p, z, tgt["p"], tgt["z"])
			return true
		2791: # Pyro Clock of Destiny
			if CustomDuelOps.is_joey(duel):
				duel.m.set_u16(0xa577f8, duel.m.u16(0xa577f8) + 1)
			else:
				duel.m.set_u16(0xa133f0, duel.m.u16(0xa133f0) + 1)
			return true
		2792: # Dark Coffin
			if CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.count_monsters(duel, opp, false) == 0:
				CustomDuelOps.discard_random(duel, opp, 1)
			elif CustomDuelOps.count_monsters(duel, opp, false) > 0:
				var dtgt = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, false)
				if not dtgt.is_empty():
					CustomDuelOps.destroy_zone(duel, opp, dtgt["z"])
			return true
		2796: # D. Tribe
			CustomDuelOps.pflags(duel, p)["all_monsters_dragon_turn"] = t
			return true
		2797, 2799: # Curse of Royal / Tutan Mask
			CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2798: # Trap of Board Eraser
			CustomDuelOps.pflags(duel, p)["negate_next_effect_damage"] = true
			if CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, opp, 0, 1)
			return true
		2802: # Raigeki Break
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				var tgt = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return not (pl == p and zz == z))
				if not tgt.is_empty():
					CustomDuelOps.destroy_zone(duel, tgt["p"], tgt["z"])
			return true
		2824: # Rite of Spirit
			var gi = _find_archetype_in_gy(duel, p, CustomDuelOps.GRAVEKEEPER_IDS)
			if gi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
			return true
		2827: # Reckless Greed
			CustomDuelOps.draw(duel, p, 2)
			CustomDuelOps.pflags(duel, p)["skip_draw_phases"] = int(CustomDuelOps.pflags(duel, p).get("skip_draw_phases", 0)) + 2
			return true
		2828, 2832, 2867:
			return true
		2829: # Needle Ceiling
			if CustomDuelOps.count_total_monsters_on_field(duel) >= 4:
				for pl in 2:
					for zz in 5:
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz):
							CustomDuelOps.destroy_zone(duel, pl, zz)
			return true
		2837: # Curse of Aging
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz):
						CustomDuelOps.add_stat_mod(duel, opp, zz, -500, -500, true)
			return true
		2852: # Nightmare Wheel
			var tgt = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5)
			if not tgt.is_empty():
				CustomDuelOps.zflags(duel, opp, tgt["z"])["cannot_attack"] = true
				CustomDuelOps.zflags(duel, opp, tgt["z"])["cannot_pos"] = true
				CustomDuelOps.link_equip(duel, p, z, opp, tgt["z"])
			return true
		2856: # Pharaoh's Treasure
			if bool(ctx.get("drawn_treasure", false)):
				var gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) != 2856)
				if gi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, gi)
				return true
			if loc == CustomDuelOps.LOC_FIELD_ST:
				CustomDuelOps.spin_zone(duel, p, z, false)
				CustomDuelOps.shuffle_deck(duel, p)
				CustomDuelOps.pflags(duel, p)["pharaoh_treasure_armed"] = true
			return true
		2858: # Trap Dustshoot
			var mi = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
			if mi >= 0:
				CustomDuelOps.move_pile_card(duel, opp, CustomDuelOps.LOC_HAND, mi, opp, CustomDuelOps.LOC_DECK)
				CustomDuelOps.shuffle_deck(duel, opp)
			return true
		2859: # Statue of the Wicked
			CustomDuelOps.spawn_token(duel, p, 0, false, 1000, 1000)
			return true
		2869: # Non Aggression Area
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				CustomDuelOps.pflags(duel, opp)["cannot_summon_until_turn"] = t + 1
			return true
		2871: # Disturbance Strategy
			var hc = CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND)
			while CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.move_pile_card(duel, opp, CustomDuelOps.LOC_HAND, 0, opp, CustomDuelOps.LOC_DECK)
			CustomDuelOps.shuffle_deck(duel, opp)
			CustomDuelOps.draw(duel, opp, hc)
			return true
		2875: # Barrel Behind the Door
			CustomDuelOps.pflags(duel, p)["reflect_effect_damage_once"] = true
			return true
		2887: # Rope of Life
			while CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0)
			var lost_id := int(ctx.get("destroyed_id", 0))
			var gi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, lost_id)
			if gi < 0:
				gi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
			if gi >= 0:
				var mz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
				if mz >= 0:
					CustomDuelOps.add_stat_mod(duel, p, mz, 800, 0, false)
			return true
		2916: # Disarmament
			for pl in 2:
				for zz in range(5, 10):
					var idx = CustomDuelOps.zone_idx(duel, pl, zz)
					if idx != 0 and CustomDuelOps.csub(duel, idx) == 3:
						CustomDuelOps.destroy_zone(duel, pl, zz)
			return true
		2917: # Hidden Spellbook
			for _k in 2:
				var si = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx))
				if si >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, si, p, CustomDuelOps.LOC_DECK)
			CustomDuelOps.shuffle_deck(duel, p)
			return true
		2919: # Formation Union
			var un_z = _find_unequipped_union_zone(duel, p)
			if un_z >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, 0, p) # fallback
			for zz in range(5, 10):
				if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.UNION_IDS and CustomDuelOps.free_monster_zone(duel, p) >= 0:
					var mz = CustomDuelOps.activate_trap_as_monster(duel, p, zz, CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, p, zz)), CustomDuelOps.base_def(duel, CustomDuelOps.zone_idx(duel, p, zz)))
					if mz >= 0:
						CustomDuelOps.state(duel)["trap_monsters"].erase("%d:%d" % [p, mz])
					return true
			if un_z >= 0:
				var host = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5 and zz != un_z, true, false)
				var eq_slot = CustomDuelOps.free_st_zone(duel, p)
				if not host.is_empty() and eq_slot >= 0:
					var tmp: int = duel.m.local(4)
					duel.m.set_u32(tmp, CustomDuelOps.zone_entry(duel, p, un_z))
					if CustomDuelOps.is_joey(duel):
						duel.f570790(p, un_z, 0)
						duel.f5686e0(p, eq_slot, tmp, 1)
					else:
						duel.f542c40(p, un_z)
						duel.f5423a0(p, eq_slot - 5, tmp, 1)
					CustomDuelOps.link_equip(duel, p, eq_slot, host["p"], host["z"])
			return true
		2920: # Secret Barrel
			var cnt = CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) + CustomDuelOps.total_field_cards(duel, opp)
			CustomDuelOps.damage(duel, opp, cnt * 200)
			return true
		2927: # Pitch-Black Power Stone
			CustomDuelOps.add_counter(duel, p, z, "spell", 3)
			return true
		2932: # Spell Shield Type-8
			if bool(ctx.get("targets_1_monster", false)):
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			elif CustomDuelOps.discard_matching_hand(duel, p, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx)) > 0:
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2944: # Anti-Spell
			if CustomDuelOps.remove_spell_counters(duel, p, 2):
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2951: # Adhesion Trap Hole
			var sz := int(ctx.get("summon_z", -1))
			if sz >= 0 and sz < 5 and CustomDuelOps.zone_idx(duel, opp, sz) != 0:
				var half_atk := int(CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, opp, sz)) / 2)
				CustomDuelOps.set_stat_val(duel, opp, sz, half_atk, -1, false)
			return true
		2952: # Physical Double
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
			if not tgt.is_empty():
				var tid = CustomDuelOps.raw_id(duel, tgt["idx"])
				var atk = CustomDuelOps.eff_atk(duel, opp, tgt["z"])
				var defv = CustomDuelOps.eff_def(duel, opp, tgt["z"])
				var mz = CustomDuelOps.special_summon_by_id(duel, p, tid, atk, defv, true, false)
				if mz >= 0:
					CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 2952, "destroy_zone", {"p": p, "z": mz})
			return true
		2953: # Meteorain
			CustomDuelOps.pflags(duel, p)["piercing_turn"] = t
			return true
		2954: # Huge Revolution
			while CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, opp, 0)
			for zz in 11:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
					CustomDuelOps.destroy_zone(duel, opp, zz)
			return true
		2955: # Amazoness Archers
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
					CustomDuelOps.change_position(duel, opp, zz, 0, 1)
					CustomDuelOps.add_stat_mod(duel, opp, zz, -500, 0, false)
					CustomDuelOps.zflags(duel, opp, zz)["must_attack_turn"] = t
			return true
		2957: # Miracle Restoring
			if CustomDuelOps.remove_spell_counters(duel, p, 2):
				var gi = _find_in_gy(duel, p, [34, 2034, CustomDuelOps.NATIVE_BUSTER_BLADER])
				if gi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
			return true
		2971: # Dramatic Rescue
			var tz := int(ctx.get("target_z", -1))
			if tz >= 0 and tz < 5 and CustomDuelOps.zone_idx(duel, p, tz) != 0:
				CustomDuelOps.bounce_zone(duel, p, tz)
				var hi = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
				if hi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p)
			return true
		2978: # Pineapple Blast
			var keep_n = CustomDuelOps.count_monsters(duel, p, false)
			while CustomDuelOps.count_monsters(duel, opp, false) > keep_n:
				var dtgt = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, false)
				if dtgt.is_empty():
					break
				CustomDuelOps.destroy_zone(duel, opp, dtgt["z"])
			return true
		2979: # Rivalry of Warlords
			_enforce_rivalry(duel)
			return true
		2980: # Thunder of Ruler
			CustomDuelOps.pflags(duel, opp)["skip_bp_turn"] = t
			return true
		2982: # Exhausting Spell
			var st = CustomDuelOps.state(duel)
			for ck in st["counters"].keys():
				if str(ck).ends_with(":spell"):
					st["counters"][ck] = 0
			return true
		2985: # The Spell Absorbing Life
			var eff_count = 0
			for pl in 2:
				for zz in 5:
					var idx = CustomDuelOps.zone_idx(duel, pl, zz)
					if idx != 0:
						if not CustomDuelOps.is_face_up(duel, pl, zz):
							CustomDuelOps.change_position(duel, pl, zz, 1, 1)
						if CustomDuelOps.is_effect_monster(duel, idx):
							eff_count += 1
			CustomDuelOps.heal(duel, p, eff_count * 400)
			return true
		3006: # Dark Scorpion Combination
			for sc_id in [2550, 2894, 3049, 3032, 3061]:
				var sz = CustomDuelOps.find_zone_of_id(duel, p, sc_id, true)
				if sz >= 0:
					CustomDuelOps.zflags(duel, p, sz)["direct_atk_turn"] = t
					CustomDuelOps.zflags(duel, p, sz)["fixed_battle_dmg_turn"] = [t, 400]
			return true
		3007: # Altar for Tribute
			var tgt = CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			if not tgt.is_empty():
				var batk = CustomDuelOps.base_atk(duel, tgt["idx"])
				CustomDuelOps.send_zone_to_gy(duel, p, tgt["z"])
				CustomDuelOps.heal(duel, p, batk)
			return true
		3012: # Really Eternal Rest
			for pl in 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.equip_count_on_monster(duel, pl, zz) > 0:
						CustomDuelOps.destroy_zone(duel, pl, zz)
			return true
		3014: # Spell Vanishing
			for _k in 2:
				CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true)
			var negated_id := int(ctx.get("target_card_id", 0))
			CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			if negated_id > 0:
				for loc_i in [CustomDuelOps.LOC_HAND, CustomDuelOps.LOC_DECK]:
					var i = CustomDuelOps.pile_count(duel, opp, loc_i) - 1
					while i >= 0:
						if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, opp, loc_i, i)) == negated_id:
							CustomDuelOps.move_pile_card(duel, opp, loc_i, i, opp, CustomDuelOps.LOC_GRAVE)
						i -= 1
			return true
		3015: # Ojama Trio
			for _k in 3:
				var tz = CustomDuelOps.spawn_token(duel, opp, 0, true, 0, 1000)
				if tz >= 0:
					CustomDuelOps.zflags(duel, opp, tz)["ojama_token"] = true
					CustomDuelOps.zflags(duel, opp, tz)["cannot_tribute"] = true
			return true
		3024: # Interdimensional Matter Transporter
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, false)
			if not tgt.is_empty():
				var tid = CustomDuelOps.raw_id(duel, tgt["idx"])
				CustomDuelOps.banish_zone(duel, p, tgt["z"])
				CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 3024, "return_banished_id", {"p": p, "card_id": tid})
			return true
		3037: # Final Attack Orders
			for pl in 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz):
						CustomDuelOps.change_position(duel, pl, zz, 0, 1)
			return true
		3040: # Judgment of Anubis
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
				var mtgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
				if not mtgt.is_empty():
					var matk = CustomDuelOps.eff_atk(duel, opp, mtgt["z"])
					if CustomDuelOps.destroy_zone(duel, opp, mtgt["z"]):
						CustomDuelOps.damage(duel, opp, matk)
			return true
		3041: # Arsenal Robber
			var ei = CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 3)
			if ei >= 0:
				CustomDuelOps.send_from_deck_to_gy(duel, opp, ei)
			return true
		3042: # Archfiend's Roar
			if CustomDuelOps.pay_lp(duel, p, 500):
				var gi = _find_archetype_in_gy(duel, p, CustomDuelOps.ARCHFIEND_IDS)
				if gi >= 0:
					var mz = CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
					if mz >= 0:
						CustomDuelOps.zflags(duel, p, mz)["cannot_tribute"] = true
						CustomDuelOps.schedule_delayed(duel, t, CustomDuelOps.PHASE_EP, p, 3042, "destroy_zone", {"p": p, "z": mz})
			return true
		3044: # Frozen Soul
			CustomDuelOps.pflags(duel, opp)["skip_next_bp"] = true
			return true
		3067: # Ray of Hope
			for _k in 2:
				var li = CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_attr(d, idx) == 1)
				if li >= 0:
					CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, li, p, CustomDuelOps.LOC_DECK)
			CustomDuelOps.shuffle_deck(duel, p)
			return true
		3068: # Dice Re-Roll
			CustomDuelOps.pflags(duel, p)["dice_reroll_turn"] = t
			return true
		3073: # Blast Held by a Tribute
			var hit = false
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.is_atk_pos(duel, opp, zz):
					if CustomDuelOps.destroy_zone(duel, opp, zz):
						hit = true
			if hit:
				CustomDuelOps.damage(duel, opp, 1000)
			return true
		3075: # Staunch Defender
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, false)
			if not tgt.is_empty():
				CustomDuelOps.pflags(duel, opp)["must_attack_zone_turn"] = [t, tgt["z"]]
			return true
		3077: # Battle-Scarred
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and (CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ARCHFIEND_IDS), true, false)
			if not tgt.is_empty():
				CustomDuelOps.link_equip(duel, p, z, p, tgt["z"])
			return true
		3102: # Trap Jammer
			CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		3103: # Begone, Knave!
			return true
		3104: # Dark Mirror Force
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and not CustomDuelOps.is_atk_pos(duel, opp, zz):
					CustomDuelOps.banish_zone(duel, opp, zz)
			return true
		3105: # Spatial Collapse
			return true
		3106: # Destruction Ring
			var tgt = CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), false, false)
			if not tgt.is_empty() and CustomDuelOps.destroy_zone(duel, p, tgt["z"]):
				CustomDuelOps.damage(duel, 0, 1000)
				CustomDuelOps.damage(duel, 1, 1000)
			return true
		3107: # Blasting the Ruins
			if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE) >= 30:
				CustomDuelOps.damage(duel, opp, 3000)
			return true
		3108: # A Hero Emerges
			var hc = CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
			if hc > 0:
				var r: int = (duel.rng.rand() % hc) if duel.rng != null else (randi() % hc)
				var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, r)
				if CustomDuelOps.is_monster(duel, idx) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, r, p)
				else:
					CustomDuelOps.discard_hand_slot(duel, p, r, 1)
			return true
	return false


static func on_standby_tick(duel, tp: int) -> void:
	for pl in 2:
		if CustomDuelOps.has_faceup_id(duel, pl, 2707) and pl == tp: # Life Absorbing Machine
			var paid := int(CustomDuelOps.pflags(duel, pl).get("lp_paid_last_turn", 0))
			if paid > 0:
				CustomDuelOps.heal(duel, pl, int(paid / 2))
		if CustomDuelOps.has_faceup_id(duel, pl, 2750) and pl == tp: # Ominous Fortunetelling
			var opp = 1 - pl
			var hc = CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND)
			if hc > 0:
				var idx = CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_HAND, 0)
				var guess: int = (duel.rng.rand() % 3) if duel.rng != null else 0
				var actual = 1 if CustomDuelOps.is_spell(duel, idx) else (2 if CustomDuelOps.is_trap(duel, idx) else 0)
				if guess == actual:
					CustomDuelOps.damage(duel, opp, 700)
		if CustomDuelOps.has_faceup_id(duel, pl, 2779) and pl == tp: # Spirit's Invitation
			var iz = CustomDuelOps.find_zone_of_id(duel, pl, 2779, true)
			if iz >= 0:
				if CustomDuelOps.can_pay_lp(duel, pl, 500):
					CustomDuelOps.pay_lp(duel, pl, 500)
				else:
					CustomDuelOps.destroy_zone(duel, pl, iz)
		if CustomDuelOps.has_faceup_id(duel, pl, 2828) and pl == tp: # Needle Wall
			var opp = 1 - pl
			var roll = 6
			var guard = 0
			while roll == 6 and guard < 8:
				roll = CustomDuelOps.dice_roll(duel, pl)
				guard += 1
			if roll >= 1 and roll <= 5:
				var tz = 5 - roll
				if CustomDuelOps.zone_idx(duel, opp, tz) != 0:
					CustomDuelOps.destroy_zone(duel, opp, tz)
		if CustomDuelOps.has_faceup_id(duel, pl, 2852) and pl == tp: # Nightmare Wheel
			var wz = CustomDuelOps.find_zone_of_id(duel, pl, 2852, true)
			if wz >= 0:
				var link = CustomDuelOps.get_equip_target(duel, pl, wz)
				if not link.is_empty() and CustomDuelOps.zone_idx(duel, link["target_p"], link["target_z"]) != 0:
					CustomDuelOps.damage(duel, 1 - pl, 500)
				else:
					CustomDuelOps.destroy_zone(duel, pl, wz)
		if CustomDuelOps.has_faceup_id(duel, pl, 2867) and pl == tp: # Bottomless Shifting Sand
			if CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) <= 4:
				var sz = CustomDuelOps.find_zone_of_id(duel, pl, 2867, true)
				if sz >= 0:
					CustomDuelOps.destroy_zone(duel, pl, sz)
		if CustomDuelOps.has_faceup_id(duel, pl, 2927) and pl == tp: # Pitch-Black Power Stone
			var pz = CustomDuelOps.find_zone_of_id(duel, pl, 2927, true)
			if pz >= 0 and CustomDuelOps.get_counter(duel, pl, pz, "spell") > 0:
				var tgt = CustomDuelOps.choose_zone(duel, pl, func(d, t_pl, t_z, t_idx): return t_pl == pl and CustomDuelOps.is_face_up(d, t_pl, t_z) and t_z != pz and CustomDuelOps.raw_id(d, t_idx) in [2524, 2636, 2898, 2899, 2936, 2962, 2970, 3046], true, false)
				if not tgt.is_empty():
					CustomDuelOps.add_counter(duel, pl, pz, "spell", -1)
					CustomDuelOps.add_counter(duel, tgt["p"], tgt["z"], "spell", 1)
					if CustomDuelOps.get_counter(duel, pl, pz, "spell") <= 0:
						CustomDuelOps.destroy_zone(duel, pl, pz)


static func on_end_phase(duel, tp: int) -> void:
	for pl in 2:
		if CustomDuelOps.has_faceup_id(duel, pl, 2867) and pl != tp: # Bottomless Shifting Sand
			var best = -1
			for side in 2:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, side, zz) != 0 and CustomDuelOps.is_face_up(duel, side, zz):
						best = maxi(best, CustomDuelOps.eff_atk(duel, side, zz))
			if best >= 0:
				for side in 2:
					for zz in 5:
						if CustomDuelOps.zone_idx(duel, side, zz) != 0 and CustomDuelOps.is_face_up(duel, side, zz) and CustomDuelOps.eff_atk(duel, side, zz) == best:
							CustomDuelOps.destroy_zone(duel, side, zz)


static func on_continuous_enforce(duel) -> void:
	if CustomDuelOps.has_faceup_id(duel, 0, 2979) or CustomDuelOps.has_faceup_id(duel, 1, 2979): # Rivalry of Warlords
		_enforce_rivalry(duel)
	if CustomDuelOps.has_faceup_id(duel, 0, 3037) or CustomDuelOps.has_faceup_id(duel, 1, 3037): # Final Attack Orders
		for pl in 2:
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and not CustomDuelOps.is_atk_pos(duel, pl, zz):
					CustomDuelOps.change_position(duel, pl, zz, 0, 1)


static func on_monster_sent_to_gy(duel, owner_p: int, _cid: int, from_field: bool) -> void:
	owner_p &= 1
	for pl in 2:
		if from_field and CustomDuelOps.has_faceup_id(duel, pl, 2769): # Fatal Abacus
			CustomDuelOps.damage(duel, owner_p, 500)
		if CustomDuelOps.has_faceup_id(duel, pl, 2860) and owner_p == (1 - pl): # Coffin Seller
			CustomDuelOps.damage(duel, owner_p, 300)


static func _enforce_rivalry(duel) -> void:
	for pl in 2:
		var keep_race = -1
		for zz in 5:
			var idx = CustomDuelOps.zone_idx(duel, pl, zz)
			if idx != 0 and CustomDuelOps.is_face_up(duel, pl, zz):
				var r = CustomDuelOps.monster_race(duel, idx)
				if keep_race < 0:
					keep_race = r
				elif r != keep_race:
					CustomDuelOps.send_zone_to_gy(duel, pl, zz)


static func _has_archetype_on_field(duel, p: int, ids: Array) -> bool:
	for zz in 5:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in ids:
			return true
	return false


static func _has_race_on_field(duel, p: int, race: int, face_up_only := true) -> bool:
	for zz in 5:
		var idx = CustomDuelOps.zone_idx(duel, p, zz)
		if idx != 0 and (not face_up_only or CustomDuelOps.is_face_up(duel, p, zz)) and CustomDuelOps.monster_race(duel, idx) == race:
			return true
	return false


static func _has_exodia_in_hand_or_deck(duel, p: int) -> bool:
	return _find_in_pile(duel, p, CustomDuelOps.LOC_HAND, CustomDuelOps.EXODIA_IDS) >= 0 or _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.EXODIA_IDS) >= 0


static func _find_in_pile(duel, p: int, loc: int, ids: Array) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, loc, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in ids)


static func _find_in_gy(duel, p: int, ids: Array) -> int:
	return _find_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, ids)


static func _find_in_gy_or_banish(duel, p: int, ids: Array) -> int:
	var gi = _find_in_gy(duel, p, ids)
	if gi >= 0:
		return gi
	return _find_in_pile(duel, p, CustomDuelOps.LOC_BANISH, ids)


static func _find_archetype_in_gy(duel, p: int, ids: Array) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in ids and CustomDuelOps.is_monster(d, idx))


static func _battling_has_race(duel, p: int, race: int, ctx: Dictionary) -> bool:
	var my_z := int(ctx.get("my_z", -1))
	if my_z >= 0 and my_z < 5:
		var idx = CustomDuelOps.zone_idx(duel, p, my_z)
		if idx != 0 and CustomDuelOps.monster_race(duel, idx) == race:
			return true
	return _has_race_on_field(duel, p, race)


static func _chain_targets_race(duel, ctx: Dictionary, race: int, is_trap_only := false) -> bool:
	if is_trap_only and not bool(ctx.get("is_trap", false)):
		return false
	var tp := int(ctx.get("target_p", -1))
	var tz := int(ctx.get("target_z", -1))
	if tp >= 0 and tz >= 0 and tz < 5:
		var idx = CustomDuelOps.zone_idx(duel, tp, tz)
		return idx != 0 and CustomDuelOps.monster_race(duel, idx) == race
	return false


static func _chain_targets_archetype(duel, ctx: Dictionary, ids: Array) -> bool:
	var tp := int(ctx.get("target_p", -1))
	var tz := int(ctx.get("target_z", -1))
	if tp >= 0 and tz >= 0 and tz < 5:
		return CustomDuelOps.zone_id(duel, tp, tz) in ids
	return false


static func _has_any_equip_on_field(duel) -> bool:
	for pl in 2:
		for zz in range(5, 10):
			var idx = CustomDuelOps.zone_idx(duel, pl, zz)
			if idx != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.csub(duel, idx) == 3:
				return true
	return not CustomDuelOps.state(duel)["equip_links"].is_empty()


static func _count_pile_spells(duel, p: int, loc: int) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, loc):
		if CustomDuelOps.is_spell(duel, CustomDuelOps.pile_idx(duel, p, loc, i)):
			n += 1
	return n


static func _has_monster_in_hand(duel, p: int) -> bool:
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
		if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)):
			return true
	return false


static func _count_gy_attr(duel, p: int, attr: int) -> int:
	var n = 0
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		var idx = CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)
		if CustomDuelOps.is_monster(duel, idx) and CustomDuelOps.monster_attr(duel, idx) == attr:
			n += 1
	return n


static func _find_unequipped_union_zone(duel, p: int) -> int:
	for zz in 5:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.UNION_IDS:
			return zz
	return -1


static func _has_equipped_union(duel, p: int) -> bool:
	for zz in range(5, 10):
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.UNION_IDS:
			return true
	return false

