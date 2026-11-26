class_name CustomEffectsSpells
extends RefCounted
## Faithful implementations for all 146 custom Spell cards (2507..3120) across Core and Joey.

const IDS: Array[int] = [
	2507, 2517, 2520, 2522, 2530, 2547, 2548, 2549, 2571, 2576,
	2577, 2579, 2597, 2598, 2599, 2604, 2607, 2608, 2610, 2615,
	2619, 2622, 2645, 2646, 2647, 2649, 2653, 2654, 2655, 2656,
	2659, 2666, 2673, 2679, 2680, 2695, 2697, 2698, 2704, 2716,
	2717, 2719, 2722, 2725, 2726, 2727, 2729, 2736, 2743, 2748,
	2752, 2753, 2755, 2756, 2760, 2775, 2784, 2786, 2788, 2789,
	2793, 2804, 2806, 2807, 2808, 2809, 2810, 2830, 2831, 2834,
	2838, 2845, 2846, 2853, 2862, 2863, 2868, 2872, 2873, 2879,
	2880, 2892, 2893, 2896, 2897, 2901, 2902, 2904, 2918, 2921,
	2924, 2926, 2928, 2929, 2930, 2934, 2948, 2949, 2950, 2956,
	2958, 2961, 2963, 2964, 2972, 2977, 2984, 2988, 3003, 3004,
	3005, 3008, 3009, 3010, 3011, 3013, 3016, 3017, 3018, 3043,
	3045, 3047, 3050, 3051, 3052, 3053, 3054, 3055, 3076, 3078,
	3079, 3080, 3081, 3082, 3083, 3091, 3095, 3096, 3110, 3111,
	3112, 3114, 3117, 3118, 3119, 3120,
]


static func handles(cid: int) -> bool:
	return cid in IDS


static func can_activate(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp := 1 - p
	var ev := str(ctx.get("event", "free"))
	var pf := CustomDuelOps.pflags(duel, p)
	var t := CustomDuelOps.turn_number(duel)
	if int(pf.get("cannot_activate_st_until_turn", -1)) >= t:
		return false
	if int(pf.get("locked_st_until_ep", -1)) == t:
		return false
	match cid:
		2507: # Ancient Chant
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.can_hopt(duel, p, 2507)
			return CustomDuelOps.can_hopt(duel, p, 2507) and (_find_in_pile(duel, p, CustomDuelOps.LOC_DECK, [2501]) >= 0 or (not CustomDuelOps.is_necrovalley_active(duel) and _find_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, [2501]) >= 0))
		2517: # Blaze Cannon
			return CustomDuelOps.has_faceup_id(duel, p, 2501)
		2520: # Book of Moon
			return _has_faceup_monster_any(duel)
		2522: # Brain Control
			return CustomDuelOps.can_pay_lp(duel, p, 800) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2530: # Contract with Exodia
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and _has_all_5_forbidden_in_gy(duel, p) and _find_in_pile(duel, p, CustomDuelOps.LOC_HAND, [2573]) >= 0
		2547: # Dimension Fusion
			return CustomDuelOps.can_pay_lp(duel, p, 2000) and ((CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_BANISH) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0) or (CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_BANISH) > 0 and CustomDuelOps.free_monster_zone(duel, opp) >= 0))
		2548: # Dimension Fusion Destruction
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and _can_summon_armityle_from_extra(duel, p)
		2549: # Divine Evolution
			for zz in 5:
				var idx := CustomDuelOps.zone_idx(duel, p, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz):
					var rid := CustomDuelOps.raw_id(duel, idx)
					if (CustomDuelOps.is_divine_beast(duel, idx) or rid in CustomDuelOps.WICKED_GOD_IDS) and not bool(CustomDuelOps.zflags(duel, p, zz).get("divine_evolved", false)):
						return true
			return false
		2571: # Enemy Controller
			return CustomDuelOps.count_monsters(duel, opp, true) > 0
		2576, 2577, 2597, 2604, 2610, 2619, 2645, 2646, 2679, 2680, 2697, 2698, 2726, 2753, 2760, 2784, 2788, 2804, 2807, 2810, 2838, 2845, 2846, 2880, 2929, 2930, 2934, 2948, 2949, 2956, 3004, 3009, 3051, 3076, 3078, 3091, 3119, 3120:
			if cid == 2679 and loc == CustomDuelOps.LOC_FIELD_ST:
				return int(CustomDuelOps.zflags(duel, p, z).get("wmc_counters", 0)) > 0
			if cid == 2680 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.can_hopt(duel, p, 2680) and CustomDuelOps.free_st_zone(duel, p) >= 0 and _has_monster_in_hand(duel, p)
			if cid == 2804 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.can_opt(duel, p, 2804, z) and CustomDuelOps.count_monsters(duel, p, false) == 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 2) >= 0
			if cid == 2810 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.turn_player(duel) == p and CustomDuelOps.can_opt(duel, p, 2810, z) and CustomDuelOps.can_pay_lp(duel, p, 300)
			if cid == 2929 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.count_monsters(duel, p, false) > 0
			if cid == 2934 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.can_opt(duel, p, 2934, z) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_union_in_hand_lv4(duel, p) >= 0
			if cid == 3009 and loc == CustomDuelOps.LOC_FIELD_ST:
				return CustomDuelOps.can_opt(duel, p, 3009, z) and CustomDuelOps.can_pay_lp(duel, p, 500) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0
			return true
		2579: # Fist of Fate
			return CustomDuelOps.can_hopt(duel, p, 2579) and CustomDuelOps.has_faceup_id(duel, p, 2500) and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2598: # Lightning Vortex
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2599, 3112: # Magical Mallet / Reload
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0
		2607: # Metamorphosis
			return CustomDuelOps.count_monsters(duel, p, false) > 0 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_FUSION) > 0
		2608: # Millennium Ankh
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_in_pile(duel, p, CustomDuelOps.LOC_FUSION, [2660]) >= 0 and _count_forbidden_available(duel, p) >= 5
		2615: # Miracle Fusion
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and _can_miracle_fusion(duel, p)
		2622: # Obliterate!!! Blaze
			for zz in 5:
				var idx := CustomDuelOps.zone_idx(duel, p, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.raw_id(duel, idx) in CustomDuelOps.EXODIA_IDS and CustomDuelOps.monster_level(duel, idx) >= 10:
					return true
			return false
		2647: # Smashing Ground
			return CustomDuelOps.count_monsters(duel, opp, true) > 0
		2649: # Soul Crossing
			return CustomDuelOps.can_hopt(duel, p, 2649) and CustomDuelOps.phase(duel) in [CustomDuelOps.PHASE_M1, CustomDuelOps.PHASE_M2] and _find_divine_in_hand(duel, p) >= 0 and (CustomDuelOps.count_monsters(duel, 0, false) + CustomDuelOps.count_monsters(duel, 1, false)) >= 3
		2653: # The Breaking Ruin God
			if loc == CustomDuelOps.LOC_GRAVE:
				return CustomDuelOps.can_hopt(duel, p, 2653) and CustomDuelOps.has_faceup_id(duel, p, 2500) and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0
			return CustomDuelOps.can_hopt(duel, p, 2653) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and not CustomDuelOps.is_necrovalley_active(duel) and (_find_in_pile(duel, p, CustomDuelOps.LOC_HAND, [2500]) >= 0 or _find_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, [2500]) >= 0)
		2654: # The Claw of Hermos
			return CustomDuelOps.can_hopt(duel, p, 2654) and CustomDuelOps.free_monster_zone(duel, p) >= 0
		2655: # The Eye of Timaeus
			return CustomDuelOps.can_hopt(duel, p, 2655) and _has_dm_on_field(duel, p) and (_find_in_pile(duel, p, CustomDuelOps.LOC_FUSION, [2506, 2542]) >= 0)
		2656: # The Fang of Critias
			return CustomDuelOps.can_hopt(duel, p, 2656) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _can_fang_of_critias(duel, p) >= 0
		2659: # The True Name
			return CustomDuelOps.can_hopt(duel, p, 2659) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0
		2666: # Thunderforce Attack
			return CustomDuelOps.can_hopt(duel, p, 2666) and CustomDuelOps.has_faceup_id(duel, p, 2502) and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2673: # Toon Table of Contents
			return _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.TOON_IDS) >= 0
		2695: # Ookazi
			return true
		2704: # Double Snare
			return CustomDuelOps.has_faceup_id(duel, opp, 2780) or CustomDuelOps.has_faceup_id(duel, opp, 2644) or CustomDuelOps.has_faceup_id(duel, p, 2780)
		2716: # After the Struggle
			return CustomDuelOps.turn_player(duel) == p and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_M1
		2717: # Super Rejuvenation
			return true
		2719: # A Wingbeat of Giant Dragon
			return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 1 and CustomDuelOps.monster_level(d, idx) >= 5, true, false).is_empty()
		2722: # Creature Swap
			return CustomDuelOps.count_monsters(duel, p, false) > 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		2725: # Reinforcement of the Army
			return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_race(d, idx) == 15 and CustomDuelOps.monster_level(d, idx) <= 4) >= 0
		2727: # Fengsheng Mirror
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		2729, 2755, 2756, 2879, 2897, 2924, 2950, 2964, 3008, 3011, 3016, 3052, 3054, 3079, 3081, 3082, 3096:
			if cid == 3008 or cid == 3052:
				if CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) == 0:
					return false
			return not _choose_equip_target(duel, p, cid).is_empty()
		2736: # The Puppet Magic of Dark Ruler
			return not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 3) >= 0
		2743: # Emergency Provisions
			return CustomDuelOps.count_st(duel, p, true) > 1
		2748: # Dragon's Gunfire
			return _has_race_on_field(duel, p, 1)
		2752: # Magic Reflector
			return CustomDuelOps.count_st(duel, p, true) > 1
		2775: # Stamping Destruction
			return _has_race_on_field(duel, p, 1) and (CustomDuelOps.count_st(duel, opp, true) > 0 or CustomDuelOps.count_st(duel, p, true) > 1)
		2786: # The Warrior Returning Alive
			return not CustomDuelOps.is_necrovalley_active(duel) and _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 15) >= 0
		2789: # The Secret of the Bandit
			return CustomDuelOps.turn_player(duel) == p and CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_M1 and CustomDuelOps.count_monsters(duel, p, true) > 0
		2793: # Book of Life
			return not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 2) >= 0 and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) > 0
		2806: # Reversal Quiz
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0 and (CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) + CustomDuelOps.total_field_cards(duel, p)) > 1
		2808: # Hieroglyph Lithograph
			return CustomDuelOps.can_pay_lp(duel, p, 1000)
		2809: # Different Dimension Capsule
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0
		2830: # Book of Taiyou
			return _has_facedown_monster_any(duel)
		2831: # Question
			return not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx)) >= 0
		2834: # Timidity
			return true
		2853: # Reasoning
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) > 0
		2862: # Royal Tribute
			return CustomDuelOps.is_necrovalley_active(duel)
		2863: # Terraforming
			return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 2) >= 0
		2868: # Pyramid Energy
			return CustomDuelOps.count_monsters(duel, p, true) > 0
		2872: # Secret Pass to the Treasures
			return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_atk(d, pl, zz) <= 1000, true, false).is_empty()
		2873: # Dark Designator
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_DECK) > 0
		2892: # Tribute Doll
			return CustomDuelOps.count_monsters(duel, p, false) > 0 and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_level(d, idx) == 7) >= 0
		2893: # Emblem of Dragon Destroyer
			return _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, [CustomDuelOps.NATIVE_BUSTER_BLADER]) >= 0 or (not CustomDuelOps.is_necrovalley_active(duel) and _find_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, [CustomDuelOps.NATIVE_BUSTER_BLADER]) >= 0)
		2896: # Gather Your Mind
			return CustomDuelOps.can_hopt(duel, p, 2896) and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2896) >= 0
		2901: # Poison of the Old Man
			return true
		2902: # Combination Attack
			return CustomDuelOps.phase(duel) == CustomDuelOps.PHASE_BP and not CustomDuelOps.state(duel)["equip_links"].is_empty()
		2904, 3018, 3047, 3053, 3083: # Ritual Spells
			return true
		2918: # Double Spell
			return _find_spell_in_pile(duel, p, CustomDuelOps.LOC_HAND) >= 0 and _find_spell_in_pile(duel, opp, CustomDuelOps.LOC_GRAVE) >= 0 and not CustomDuelOps.is_necrovalley_active(duel)
		2921: # Mega Ton Magical Cannon
			return CustomDuelOps.total_spell_counters(duel, p) >= 10
		2926: # Jar Robber
			return ev == "chain_negate" and int(ctx.get("target_card_id", 0)) == CustomDuelOps.NATIVE_POT_OF_GREED
		2928: # Ante
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		2958: # My Body as a Shield
			return ev == "chain_negate" and CustomDuelOps.can_pay_lp(duel, p, 1500) and bool(ctx.get("destroys_monster", false))
		2961: # Dark Core
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and _has_faceup_monster_any(duel)
		2963: # Autonomous Action Unit
			return CustomDuelOps.can_pay_lp(duel, p, 1500) and not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx)) >= 0
		2972: # Amazoness Spellcaster
			return not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.AMAZONESS_IDS, true, false).is_empty() and CustomDuelOps.count_monsters(duel, opp, true) > 0
		2977: # Diffusion Wave-Motion
			return CustomDuelOps.can_pay_lp(duel, p, 1000) and CustomDuelOps.count_monsters(duel, opp, false) > 0 and not CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 18 and CustomDuelOps.monster_level(d, idx) >= 7, true, false).is_empty()
		2984: # Spellbook Organization
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK) >= 1
		2988: # A Deal with Dark Ruler
			return CustomDuelOps.free_monster_zone(duel, p) >= 0 and (_find_in_pile(duel, p, CustomDuelOps.LOC_HAND, [3070]) >= 0 or _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, [3070]) >= 0)
		3003: # Dragged Down into the Grave
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0 and CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		3005: # Fairy of the Spring
			return not CustomDuelOps.is_necrovalley_active(duel) and CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 3) >= 0
		3010: # Cost Down
			return CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0
		3013: # Spell Reproduction
			return _count_spells_in_pile(duel, p, CustomDuelOps.LOC_HAND) >= 2 and not CustomDuelOps.is_necrovalley_active(duel) and _find_spell_in_pile(duel, p, CustomDuelOps.LOC_GRAVE) >= 0
		3017: # Falling Down
			return _has_archfiend_card(duel, p) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		3043: # Different Dimension Gate
			return CustomDuelOps.count_monsters(duel, p, false) > 0 and CustomDuelOps.count_monsters(duel, opp, false) > 0
		3045: # Token Thanksgiving
			return _count_tokens_on_field(duel) > 0
		3050: # Mustering of the Dark Scorpions
			return CustomDuelOps.has_faceup_id(duel, p, 2550) and CustomDuelOps.free_monster_zone(duel, p) >= 0
		3055: # Checkmate
			return CustomDuelOps.has_faceup_id(duel, p, 3023) and CustomDuelOps.count_monsters(duel, p, false) >= 2
		3080: # Final Countdown
			return CustomDuelOps.can_pay_lp(duel, p, 2000)
		3095: # Ojama Delta Hurricane!!
			return CustomDuelOps.has_faceup_id(duel, p, 2999) and CustomDuelOps.total_field_cards(duel, opp) > 0
		3110: # Ultra Evolution Pill
			return _has_race_on_field(duel, p, 20, false) and CustomDuelOps.free_monster_zone(duel, p) >= 0 and _find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 9) >= 0
		3111: # Multiplication of Ants
			return _has_race_on_field(duel, p, 10, false)
		3114: # Primal Seed
			return (CustomDuelOps.has_faceup_id(duel, 0, 2515) or CustomDuelOps.has_faceup_id(duel, 1, 2515) or CustomDuelOps.has_faceup_id(duel, 0, 2527) or CustomDuelOps.has_faceup_id(duel, 1, 2527)) and CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_BANISH) > 0
		3117: # D.D. Designator
			return CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) > 0
		3118: # Gryphon's Feather Duster
			return CustomDuelOps.count_st(duel, p, true) > 1
	return false


static func resolve(duel, p: int, cid: int, loc: int, z: int, ctx: Dictionary) -> bool:
	p &= 1
	var opp := 1 - p
	var t := CustomDuelOps.turn_number(duel)
	match cid:
		2507: # Ancient Chant
			CustomDuelOps.mark_hopt(duel, p, 2507)
			if loc == CustomDuelOps.LOC_GRAVE:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, int(ctx.get("pile_i", 0)))
				CustomDuelOps.pflags(duel, p)["ancient_chant_ra_buff_turn"] = t
				return true
			var ri := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2501)
			if ri >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, ri)
			else:
				ri = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2501)
				if ri >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, ri)
			CustomDuelOps.pflags(duel, p)["extra_tribute_summon_turn"] = t
			return true
		2517: # Blaze Cannon
			var rz := CustomDuelOps.find_zone_of_id(duel, p, 2501, true)
			if rz >= 0:
				CustomDuelOps.zflags(duel, p, rz)["unaffected_until_turn"] = t
				CustomDuelOps.zflags(duel, p, rz)["blaze_cannon_turn"] = t
			return true
		2520: # Book of Moon
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
			if not tgt.is_empty():
				CustomDuelOps.change_position(duel, tgt["p"], tgt["z"], 1, 0)
			return true
		2522: # Brain Control
			if CustomDuelOps.pay_lp(duel, p, 800):
				var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
				if not tgt.is_empty():
					CustomDuelOps.change_control(duel, opp, tgt["z"], p, true)
			return true
		2530: # Contract with Exodia
			var hi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2573)
			if hi >= 0 and _has_all_5_forbidden_in_gy(duel, p):
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p)
			return true
		2547: # Dimension Fusion
			if CustomDuelOps.pay_lp(duel, p, 2000):
				for pl in [p, opp]:
					while CustomDuelOps.free_monster_zone(duel, pl) >= 0:
						var bi := CustomDuelOps.choose_pile_card(duel, pl, CustomDuelOps.LOC_BANISH, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
						if bi < 0:
							break
						CustomDuelOps.special_summon_from_pile(duel, pl, CustomDuelOps.LOC_BANISH, bi, pl)
			return true
		2548: # Dimension Fusion Destruction
			var arm_i := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2513)
			if arm_i < 0:
				arm_i = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2514)
			if arm_i >= 0 and _consume_materials_anywhere(duel, p, [2677, 2589, 2624], true):
				var mz := CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, arm_i, p)
				if mz >= 0:
					CustomDuelOps.zflags(duel, p, mz)["no_battle_dmg_to_controller"] = true
			return true
		2549: # Divine Evolution
			for zz in 5:
				var idx := CustomDuelOps.zone_idx(duel, p, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz):
					var rid := CustomDuelOps.raw_id(duel, idx)
					if (CustomDuelOps.is_divine_beast(duel, idx) or rid in CustomDuelOps.WICKED_GOD_IDS) and not bool(CustomDuelOps.zflags(duel, p, zz).get("divine_evolved", false)):
						CustomDuelOps.zflags(duel, p, zz)["divine_evolved"] = true
						CustomDuelOps.add_stat_mod(duel, p, zz, 1000, 1000, false)
						break
			return true
		2571: # Enemy Controller
			var can_steal := CustomDuelOps.count_monsters(duel, p, false) > 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
			if not tgt.is_empty():
				if can_steal and CustomDuelOps.eff_atk(duel, opp, tgt["z"]) >= 1800:
					var sac := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
					if not sac.is_empty() and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
						CustomDuelOps.change_control(duel, opp, tgt["z"], p, true)
				else:
					var next_def := 1 if CustomDuelOps.is_atk_pos(duel, opp, tgt["z"]) else 0
					CustomDuelOps.change_position(duel, opp, tgt["z"], next_def, 1)
			return true
		2576: # Fallen Paradise
			if loc == CustomDuelOps.LOC_FIELD_SPELL or loc == CustomDuelOps.LOC_FIELD_ST:
				if CustomDuelOps.can_opt(duel, p, 2576, z) and _has_any_id_on_field(duel, p, [2677, 2589, 2624, 2513, 2514]):
					CustomDuelOps.mark_opt(duel, p, 2576, z)
					CustomDuelOps.draw(duel, p, 2)
			return true
		2577: # Fallen Paradise of the Sacred Beasts
			if loc == CustomDuelOps.LOC_FIELD_SPELL or loc == CustomDuelOps.LOC_FIELD_ST:
				if CustomDuelOps.can_opt(duel, p, 2577, z) and _has_any_id_on_field(duel, p, CustomDuelOps.SACRED_BEAST_IDS):
					CustomDuelOps.mark_opt(duel, p, 2577, z)
					CustomDuelOps.draw(duel, p, 2)
			return true
		2579: # Fist of Fate
			CustomDuelOps.mark_hopt(duel, p, 2579)
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
			if not tgt.is_empty():
				CustomDuelOps.zflags(duel, opp, tgt["z"])["negated"] = true
				CustomDuelOps.destroy_zone(duel, opp, tgt["z"])
				if CustomDuelOps.phase(duel) in [CustomDuelOps.PHASE_M1, CustomDuelOps.PHASE_M2]:
					for zz in range(5, 11):
						if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
							CustomDuelOps.destroy_zone(duel, opp, zz)
			return true
		2597: # Level Limit - Area B
			_apply_level_limit_b(duel)
			return true
		2598: # Lightning Vortex
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz):
						CustomDuelOps.destroy_zone(duel, opp, zz)
			return true
		2599: # Magical Mallet
			var n := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND)
			var shuf := 0
			for _k in mini(n, 2):
				CustomDuelOps.move_pile_card(duel, p, CustomDuelOps.LOC_HAND, 0, p, CustomDuelOps.LOC_DECK)
				shuf += 1
			CustomDuelOps.shuffle_deck(duel, p)
			CustomDuelOps.draw(duel, p, shuf)
			return true
		2604: # Marshmallon Glasses
			return true
		2607: # Metamorphosis
			var tgt := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			if not tgt.is_empty():
				var lv := CustomDuelOps.monster_level(duel, tgt["idx"])
				if CustomDuelOps.tribute_zone(duel, p, tgt["z"]):
					var fi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(d, idx, _i): return CustomDuelOps.monster_level(d, idx) == lv)
					if fi >= 0:
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
			return true
		2608: # Millennium Ankh
			var fi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2660)
			if fi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
				for zz in 5:
					var idx := CustomDuelOps.zone_idx(duel, p, zz)
					if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz):
						var rid := CustomDuelOps.raw_id(duel, idx)
						var is_ex := (rid in CustomDuelOps.EXODIA_IDS and CustomDuelOps.monster_level(duel, idx) >= 10)
						var is_mil := (rid in CustomDuelOps.MILLENNIUM_IDS)
						if not is_ex and not is_mil:
							CustomDuelOps.spin_zone(duel, p, zz, false)
				CustomDuelOps.pflags(duel, p)["cannot_summon_until_turn"] = t
				CustomDuelOps.shuffle_deck(duel, p)
			return true
		2610: # Millennium Revelation
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_opt(duel, p, 2610, 0):
				var di := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_divine_beast(d, idx))
				if di >= 0:
					CustomDuelOps.mark_opt(duel, p, 2610, 0)
					CustomDuelOps.discard_hand_slot(duel, p, di)
					var ri := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_MONSTER_REBORN)
					if ri >= 0:
						CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, ri)
					else:
						ri = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, CustomDuelOps.NATIVE_MONSTER_REBORN)
						if ri >= 0:
							CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, ri)
				elif CustomDuelOps.can_opt(duel, p, 2610, 1):
					CustomDuelOps.mark_opt(duel, p, 2610, 1)
					CustomDuelOps.send_zone_to_gy(duel, p, z)
					CustomDuelOps.pflags(duel, p)["reborn_ra_turn"] = t
			return true
		2615: # Miracle Fusion
			_resolve_miracle_fusion(duel, p)
			return true
		2619: # Mound of the Bound Creator
			if bool(ctx.get("sent_to_gy_destroyed", false)):
				var di := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_divine_beast(d, idx))
				if di >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, di)
			return true
		2622: # Obliterate!!! Blaze
			var ez := -1
			for zz in 5:
				var idx := CustomDuelOps.zone_idx(duel, p, zz)
				if idx != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.raw_id(duel, idx) in CustomDuelOps.EXODIA_IDS and CustomDuelOps.monster_level(duel, idx) >= 10:
					ez = zz
					break
			if ez >= 0:
				CustomDuelOps.zflags(duel, p, ez)["pierce"] = true
				CustomDuelOps.pay_half_lp(duel, p)
				for pl in 2:
					for sz in range(5, 10):
						if CustomDuelOps.zone_idx(duel, pl, sz) != 0 and not (pl == p and sz == z):
							CustomDuelOps.destroy_zone(duel, pl, sz)
				var eq_cnt := 0
				for _k in 5:
					var slot := CustomDuelOps.free_st_zone(duel, p)
					if slot < 0:
						break
					var fi := _find_in_pile(duel, p, CustomDuelOps.LOC_HAND, CustomDuelOps.FORBIDDEN_ONE_IDS)
					var floc := CustomDuelOps.LOC_HAND
					if fi < 0:
						fi = _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.FORBIDDEN_ONE_IDS)
						floc = CustomDuelOps.LOC_DECK
					if fi < 0:
						break
					var tz := CustomDuelOps.set_st_from_pile(duel, p, floc, fi, p, true)
					if tz >= 0:
						CustomDuelOps.link_equip(duel, p, tz, p, ez)
						eq_cnt += 1
				CustomDuelOps.add_stat_mod(duel, p, ez, eq_cnt * 2000, 0, false)
				CustomDuelOps.pflags(duel, p)["locked_st_until_ep"] = t
			return true
		2645, 2646: # Skyscraper / Skyscraper 2 - Hero City
			if cid == 2646 and CustomDuelOps.can_opt(duel, p, 2646, z) and CustomDuelOps.free_monster_zone(duel, p) >= 0:
				var gi := _find_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, CustomDuelOps.ELEMENTAL_HERO_IDS)
				if gi >= 0:
					CustomDuelOps.mark_opt(duel, p, 2646, z)
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
			return true
		2647: # Smashing Ground
			var best_z := -1
			var best_def := -1
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz):
					var dv := CustomDuelOps.eff_def(duel, opp, zz)
					if dv > best_def:
						best_def = dv
						best_z = zz
			if best_z >= 0:
				CustomDuelOps.destroy_zone(duel, opp, best_z)
			return true
		2649: # Soul Crossing
			CustomDuelOps.mark_hopt(duel, p, 2649)
			var gi := _find_divine_in_hand(duel, p)
			if gi >= 0:
				var tribs := 0
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and tribs < 3:
						CustomDuelOps.tribute_zone(duel, opp, zz)
						tribs += 1
				for zz in 5:
					if CustomDuelOps.zone_idx(duel, p, zz) != 0 and tribs < 3:
						CustomDuelOps.tribute_zone(duel, p, zz)
						tribs += 1
				if tribs >= 3:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, gi, p)
			return true
		2653: # The Breaking Ruin God
			CustomDuelOps.mark_hopt(duel, p, 2653)
			if loc == CustomDuelOps.LOC_GRAVE:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, int(ctx.get("pile_i", 0)))
				var cnt := 0
				var i := CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_GRAVE) - 1
				while i >= 0:
					if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_GRAVE, i)):
						CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, i)
						cnt += 1
					i -= 1
				if cnt > 0:
					CustomDuelOps.damage(duel, opp, cnt * 500)
				return true
			var oi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 2500)
			var oloc := CustomDuelOps.LOC_HAND
			if oi < 0:
				oi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, 2500)
				oloc = CustomDuelOps.LOC_GRAVE
			if oi >= 0:
				var mz := CustomDuelOps.special_summon_from_pile(duel, p, oloc, oi, p)
				if mz >= 0:
					CustomDuelOps.zflags(duel, p, mz)["unaffected_until_turn"] = t
			return true
		2654: # The Claw of Hermos
			CustomDuelOps.mark_hopt(duel, p, 2654)
			var fi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_FUSION, func(_d, _idx, _i): return true)
			if fi >= 0:
				if CustomDuelOps.discard_matching_hand(duel, p, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx)) > 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
			return true
		2655: # The Eye of Timaeus
			CustomDuelOps.mark_hopt(duel, p, 2655)
			var dmz := -1
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in [34, 2034, 759]:
					dmz = zz
					break
			if dmz >= 0:
				var fi := _find_in_pile(duel, p, CustomDuelOps.LOC_FUSION, [2542, 2506])
				if fi >= 0:
					CustomDuelOps.send_zone_to_gy(duel, p, dmz)
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
			return true
		2656: # The Fang of Critias
			CustomDuelOps.mark_hopt(duel, p, 2656)
			var fid := _can_fang_of_critias(duel, p)
			if fid > 0:
				var fi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, fid)
				if fi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
			return true
		2659: # The True Name
			CustomDuelOps.mark_hopt(duel, p, 2659)
			var dn := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK)
			if dn > 0:
				var top_i := dn - 1
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, top_i)
				var god_i := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_divine_beast(d, idx))
				if god_i >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, god_i)
			return true
		2666: # Thunderforce Attack
			CustomDuelOps.mark_hopt(duel, p, 2666)
			var killed := 0
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0 and CustomDuelOps.is_face_up(duel, opp, zz) and CustomDuelOps.destroy_zone(duel, opp, zz):
					killed += 1
			if killed > 0 and CustomDuelOps.phase(duel) in [CustomDuelOps.PHASE_M1, CustomDuelOps.PHASE_M2]:
				CustomDuelOps.draw(duel, p, killed)
				CustomDuelOps.pflags(duel, p)["max_attackers_turn"] = t
			return true
		2673: # Toon Table of Contents
			var ti := _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.TOON_IDS)
			if ti >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, ti)
			return true
		2679: # Wave-Motion Cannon
			if loc == CustomDuelOps.LOC_FIELD_ST:
				var c := int(CustomDuelOps.zflags(duel, p, z).get("wmc_counters", 0))
				if c > 0:
					CustomDuelOps.send_zone_to_gy(duel, p, z)
					CustomDuelOps.damage(duel, opp, c * 1000)
			else:
				CustomDuelOps.zflags(duel, p, z)["wmc_counters"] = 0
			return true
		2680: # Wedju Temple
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_hopt(duel, p, 2680):
				var hi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
				if hi >= 0 and CustomDuelOps.set_st_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p, true) >= 0:
					CustomDuelOps.mark_hopt(duel, p, 2680)
					var mi := _find_in_pile(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.MILLENNIUM_IDS)
					if mi >= 0:
						CustomDuelOps.set_st_from_pile(duel, p, CustomDuelOps.LOC_DECK, mi, p, true)
			return true
		2695: # Ookazi
			CustomDuelOps.damage(duel, opp, 800)
			return true
		2697, 2698, 2726, 2753, 2784, 2807, 2834, 2846, 2880, 2930, 2949, 2956, 3004, 3051, 3076, 3078, 3091, 3119, 3120:
			return true
		2704: # Double Snare
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return zz >= 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.raw_id(d, idx) in [2644, 2780])
			if not tgt.is_empty():
				CustomDuelOps.destroy_zone(duel, tgt["p"], tgt["z"])
			return true
		2716: # After the Struggle
			CustomDuelOps.pflags(duel, 0)["destroy_battled_ep"] = t
			CustomDuelOps.pflags(duel, 1)["destroy_battled_ep"] = t
			return true
		2717: # Super Rejuvenation
			CustomDuelOps.pflags(duel, p)["super_rejuv_turn"] = t
			return true
		2719: # A Wingbeat of Giant Dragon
			var drg := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 1 and CustomDuelOps.monster_level(d, idx) >= 5, false, false)
			if not drg.is_empty():
				CustomDuelOps.bounce_zone(duel, p, drg["z"])
				for pl in 2:
					for zz in range(5, 11):
						if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and not (pl == p and zz == z):
							CustomDuelOps.destroy_zone(duel, pl, zz)
			return true
		2722: # Creature Swap
			var my_t := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			var op_t := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
			if not my_t.is_empty() and not op_t.is_empty():
				CustomDuelOps.swap_control(duel, my_t["z"] if p == 0 else op_t["z"], op_t["z"] if p == 0 else my_t["z"])
				CustomDuelOps.zflags(duel, p, my_t["z"])["cannot_pos_turn"] = t
				CustomDuelOps.zflags(duel, opp, op_t["z"])["cannot_pos_turn"] = t
			return true
		2725: # Reinforcement of the Army
			var wi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_race(d, idx) == 15 and CustomDuelOps.monster_level(d, idx) <= 4)
			if wi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, wi)
			return true
		2727: # Fengsheng Mirror
			var si := _find_in_pile(duel, opp, CustomDuelOps.LOC_HAND, CustomDuelOps.SPIRIT_IDS)
			if si >= 0:
				CustomDuelOps.discard_hand_slot(duel, opp, si, 1)
			return true
		2729, 2755, 2756, 2879, 2897, 2924, 2950, 2964, 3008, 3011, 3016, 3052, 3054, 3079, 3081, 3082, 3096:
			if cid == 3008 or cid == 3052:
				if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) == 0:
					return false
			var tgt := _choose_equip_target(duel, p, cid)
			if not tgt.is_empty():
				CustomDuelOps.link_equip(duel, p, z, tgt["p"], tgt["z"])
				if cid == 2950:
					CustomDuelOps.zflags(duel, tgt["p"], tgt["z"])["pierce"] = true
				elif cid == 3008:
					CustomDuelOps.zflags(duel, tgt["p"], tgt["z"])["max_attacks"] = 2
				elif cid == 3082:
					CustomDuelOps.zflags(duel, tgt["p"], tgt["z"])["direct_atk"] = true
			return true
		2736: # The Puppet Magic of Dark Ruler
			var gi := _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 3)
			if gi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi, p)
			return true
		2743: # Emergency Provisions
			var sent := 0
			for zz in range(5, 11):
				if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.send_zone_to_gy(duel, p, zz):
					sent += 1
			if sent > 0:
				CustomDuelOps.heal(duel, p, sent * 1000)
			return true
		2748: # Dragon's Gunfire
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_def(d, pl, zz) <= 800)
			if not tgt.is_empty():
				CustomDuelOps.destroy_zone(duel, opp, tgt["z"])
			else:
				CustomDuelOps.damage(duel, opp, 800)
			return true
		2752: # Magic Reflector
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz >= 5 and zz != z and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.is_spell(d, idx), true, false)
			if not tgt.is_empty():
				CustomDuelOps.add_counter(duel, p, tgt["z"], "reflector", 1)
			return true
		2760: # Array of Revealing Light
			CustomDuelOps.zflags(duel, p, z)["declared_race"] = 18
			return true
		2775: # Stamping Destruction
			var tgt := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz >= 5)
			if not tgt.is_empty() and CustomDuelOps.destroy_zone(duel, opp, tgt["z"]):
				CustomDuelOps.damage(duel, opp, 500)
			return true
		2786: # The Warrior Returning Alive
			var wi := _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 15)
			if wi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, wi)
			return true
		2788: # Spiritual Energy Settle Machine
			return true
		2789: # The Secret of the Bandit
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, false)
			if not tgt.is_empty():
				CustomDuelOps.zflags(duel, p, tgt["z"])["bandit_discard_turn"] = t
			return true
		2793: # Book of Life
			var zi := _find_race_in_pile(duel, p, CustomDuelOps.LOC_GRAVE, 2)
			if zi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, zi, p)
			var bi := CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
			if bi >= 0:
				CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, bi)
			return true
		2804: # Call of the Mummy
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_opt(duel, p, 2804, z) and CustomDuelOps.count_monsters(duel, p, false) == 0:
				var zi := _find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 2)
				if zi >= 0:
					CustomDuelOps.mark_opt(duel, p, 2804, z)
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, zi, p)
			return true
		2806: # Reversal Quiz
			while CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) > 0:
				CustomDuelOps.discard_hand_slot(duel, p, 0)
			for zz in 11:
				if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0:
					CustomDuelOps.send_zone_to_gy(duel, p, zz)
			var dn := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK)
			if dn > 0:
				var idx := CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_DECK, dn - 1)
				if CustomDuelOps.is_monster(duel, idx): # majority of decks: call monster
					var lp0 := CustomDuelOps.get_lp(duel, p)
					var lp1 := CustomDuelOps.get_lp(duel, opp)
					CustomDuelOps.set_lp(duel, p, lp1)
					CustomDuelOps.set_lp(duel, opp, lp0)
			return true
		2808: # Hieroglyph Lithograph
			if CustomDuelOps.pay_lp(duel, p, 1000):
				CustomDuelOps.pflags(duel, p)["hand_limit_7"] = true
			return true
		2809: # Different Dimension Capsule
			var di := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(_d, _idx, _i): return true)
			if di >= 0:
				var bidx := CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_DECK, di)
				CustomDuelOps.zflags(duel, p, z)["capsule_card_id"] = CustomDuelOps.raw_id(duel, bidx)
				CustomDuelOps.schedule_delayed(duel, t + 4, CustomDuelOps.PHASE_SP, p, 2809, "capsule_resolve", {"p": p, "z": z, "card_id": CustomDuelOps.raw_id(duel, bidx)})
			return true
		2810: # Card Shuffle
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_opt(duel, p, 2810, z) and CustomDuelOps.pay_lp(duel, p, 300):
				CustomDuelOps.mark_opt(duel, p, 2810, z)
				CustomDuelOps.shuffle_deck(duel, p)
			return true
		2830: # Book of Taiyou
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and not CustomDuelOps.is_face_up(d, pl, zz), true, false)
			if not tgt.is_empty():
				CustomDuelOps.change_position(duel, tgt["p"], tgt["z"], 0, 1)
			return true
		2831: # Question
			var bottom_idx := CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, 0)
			if bottom_idx != 0 and CustomDuelOps.is_monster(duel, bottom_idx):
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, 0, p)
			return true
		2838: # Mirage of Nightmare
			return true
		2845: # Dark Snake Syndrome
			CustomDuelOps.zflags(duel, p, z)["snake_dmg"] = 200
			return true
		2853: # Reasoning
			var opp_guess := 4
			var dn := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK)
			while dn > 0:
				dn -= 1
				var idx := CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_DECK, dn)
				if CustomDuelOps.is_monster(duel, idx):
					if CustomDuelOps.monster_level(duel, idx) == opp_guess:
						CustomDuelOps.send_from_deck_to_gy(duel, p, dn)
					else:
						CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_DECK, dn, p)
					break
				else:
					CustomDuelOps.send_from_deck_to_gy(duel, p, dn)
			return true
		2862: # Royal Tribute
			for pl in [p, opp]:
				var i := CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND) - 1
				while i >= 0:
					if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, pl, CustomDuelOps.LOC_HAND, i)):
						CustomDuelOps.discard_hand_slot(duel, pl, i)
					i -= 1
			return true
		2863: # Terraforming
			var fi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 2)
			if fi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, fi)
			return true
		2868: # Pyramid Energy
			for zz in 5:
				if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz):
					CustomDuelOps.add_stat_mod(duel, p, zz, 200, 0, true)
			return true
		2872: # Secret Pass to the Treasures
			var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.eff_atk(d, pl, zz) <= 1000, true, false)
			if not tgt.is_empty():
				CustomDuelOps.zflags(duel, p, tgt["z"])["direct_atk_turn"] = t
			return true
		2873: # Dark Designator
			var mi := CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_DECK, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx), false)
			if mi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, opp, CustomDuelOps.LOC_DECK, mi)
			return true
		2892: # Tribute Doll
			var sac := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			if not sac.is_empty() and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
				var hi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_level(d, idx) == 7)
				if hi >= 0:
					var mz := CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p)
					if mz >= 0:
						CustomDuelOps.zflags(duel, p, mz)["cannot_attack_turn"] = t
			return true
		2893: # Emblem of Dragon Destroyer
			var bi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, CustomDuelOps.NATIVE_BUSTER_BLADER)
			if bi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, bi)
			elif not CustomDuelOps.is_necrovalley_active(duel):
				bi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, CustomDuelOps.NATIVE_BUSTER_BLADER)
				if bi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, bi)
			return true
		2896: # Gather Your Mind
			CustomDuelOps.mark_hopt(duel, p, 2896)
			var gi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 2896)
			if gi >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_DECK, gi)
			return true
		2901: # Poison of the Old Man
			if CustomDuelOps.get_lp(duel, p) <= 2000:
				CustomDuelOps.heal(duel, p, 1200)
			else:
				CustomDuelOps.damage(duel, opp, 800)
			return true
		2902: # Combination Attack
			for k in CustomDuelOps.state(duel)["equip_links"].keys():
				var parts := str(k).split(":")
				if parts.size() >= 2 and int(parts[0]) == p:
					var eq_z := int(parts[1])
					var link: Dictionary = CustomDuelOps.state(duel)["equip_links"][k]
					if CustomDuelOps.zone_id(duel, p, eq_z) in CustomDuelOps.UNION_IDS and CustomDuelOps.free_monster_zone(duel, p) >= 0:
						var mz := CustomDuelOps.activate_trap_as_monster(duel, p, eq_z, CustomDuelOps.base_atk(duel, CustomDuelOps.zone_idx(duel, p, eq_z)), CustomDuelOps.base_def(duel, CustomDuelOps.zone_idx(duel, p, eq_z)))
						if mz >= 0:
							CustomDuelOps.state(duel)["trap_monsters"].erase("%d:%d" % [p, mz])
						CustomDuelOps.zflags(duel, link["target_p"], link["target_z"])["max_attacks"] = 2
						break
			return true
		2904, 3018, 3047, 3053, 3083: # Ritual Spells (also synced natively via sync_ritual_table)
			_resolve_ritual_spell(duel, p, cid)
			return true
		2918: # Double Spell
			var hs := _find_spell_in_pile(duel, p, CustomDuelOps.LOC_HAND)
			var gs := _find_spell_in_pile(duel, opp, CustomDuelOps.LOC_GRAVE)
			if hs >= 0 and gs >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, hs)
				var g_cid := CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_GRAVE, gs))
				if handles(g_cid):
					resolve(duel, p, g_cid, loc, z, ctx)
			return true
		2921: # Mega Ton Magical Cannon
			if CustomDuelOps.remove_spell_counters(duel, p, 10):
				for zz in 11:
					if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
						CustomDuelOps.destroy_zone(duel, opp, zz)
			return true
		2926: # Jar Robber
			CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			CustomDuelOps.draw(duel, p, 1)
			return true
		2928: # Ante
			var i0 := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND) - 1
			var i1 := CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND) - 1
			if i0 >= 0 and i1 >= 0:
				var lv0 := CustomDuelOps.monster_level(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i0))
				var lv1 := CustomDuelOps.monster_level(duel, CustomDuelOps.pile_idx(duel, opp, CustomDuelOps.LOC_HAND, i1))
				if lv0 < lv1:
					CustomDuelOps.discard_hand_slot(duel, p, i0)
					CustomDuelOps.damage(duel, p, 1000)
				elif lv1 < lv0:
					CustomDuelOps.discard_hand_slot(duel, opp, i1)
					CustomDuelOps.damage(duel, opp, 1000)
			return true
		2929: # Mass Driver
			if loc == CustomDuelOps.LOC_FIELD_ST:
				var sac := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
				if not sac.is_empty() and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
					CustomDuelOps.damage(duel, opp, 400)
			return true
		2934: # Frontline Base
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_opt(duel, p, 2934, z):
				var ui := _find_union_in_hand_lv4(duel, p)
				if ui >= 0:
					CustomDuelOps.mark_opt(duel, p, 2934, z)
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, ui, p)
			return true
		2948: # Senri Eye
			return true
		2958: # My Body as a Shield
			if CustomDuelOps.pay_lp(duel, p, 1500):
				CustomDuelOps.negate_chain_entry(duel, int(ctx.get("target_link", 0)), true)
			return true
		2961: # Dark Core
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return zz < 5 and CustomDuelOps.is_face_up(d, pl, zz))
				if not tgt.is_empty():
					CustomDuelOps.banish_zone(duel, tgt["p"], tgt["z"])
			return true
		2963: # Autonomous Action Unit
			if CustomDuelOps.pay_lp(duel, p, 1500):
				var gi := CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx))
				if gi >= 0:
					var mz := CustomDuelOps.special_summon_from_pile(duel, opp, CustomDuelOps.LOC_GRAVE, gi, p, true, false)
					if mz >= 0:
						CustomDuelOps.link_equip(duel, p, z, p, mz)
			return true
		2972: # Amazoness Spellcaster
			var my_t := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.AMAZONESS_IDS, false, false)
			var op_t := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, _idx): return pl == opp and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz), true, true)
			if not my_t.is_empty() and not op_t.is_empty():
				var a0 := CustomDuelOps.eff_atk(duel, p, my_t["z"])
				var a1 := CustomDuelOps.eff_atk(duel, opp, op_t["z"])
				CustomDuelOps.set_stat_val(duel, p, my_t["z"], a1, -1, true)
				CustomDuelOps.set_stat_val(duel, opp, op_t["z"], a0, -1, true)
			return true
		2977: # Diffusion Wave-Motion
			if CustomDuelOps.pay_lp(duel, p, 1000):
				var tgt := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.is_face_up(d, pl, zz) and CustomDuelOps.monster_race(d, idx) == 18 and CustomDuelOps.monster_level(d, idx) >= 7, true, false)
				if not tgt.is_empty():
					CustomDuelOps.zflags(duel, p, tgt["z"])["attack_all_turn"] = t
					CustomDuelOps.pflags(duel, p)["only_attacker_zone_turn"] = [t, tgt["z"]]
			return true
		2984: # Spellbook Organization
			return true
		2988: # A Deal with Dark Ruler
			var bi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, 3070)
			var bloc := CustomDuelOps.LOC_HAND
			if bi < 0:
				bi = CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, 3070)
				bloc = CustomDuelOps.LOC_DECK
			if bi >= 0:
				CustomDuelOps.special_summon_from_pile(duel, p, bloc, bi, p)
			return true
		3003: # Dragged Down into the Grave
			var r0 := CustomDuelOps.choose_pile_card(duel, opp, CustomDuelOps.LOC_HAND, func(_d, _idx, _i): return true)
			var r1 := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(_d, _idx, _i): return true, false)
			if r0 >= 0:
				CustomDuelOps.discard_hand_slot(duel, opp, r0)
			if r1 >= 0:
				CustomDuelOps.discard_hand_slot(duel, p, r1)
			CustomDuelOps.draw(duel, p, 1)
			CustomDuelOps.draw(duel, opp, 1)
			return true
		3005: # Fairy of the Spring
			var ei := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_GRAVE, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx) and CustomDuelOps.csub(d, idx) == 3)
			if ei >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, ei)
			return true
		3009: # Archfiend's Oath
			if loc == CustomDuelOps.LOC_FIELD_ST and CustomDuelOps.can_opt(duel, p, 3009, z) and CustomDuelOps.pay_lp(duel, p, 500):
				CustomDuelOps.mark_opt(duel, p, 3009, z)
				var dn := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_DECK)
				if dn > 0:
					CustomDuelOps.send_from_deck_to_gy(duel, p, dn - 1)
			return true
		3010: # Cost Down
			if CustomDuelOps.discard_matching_hand(duel, p, func(_d, _idx, _i): return true) > 0:
				CustomDuelOps.pflags(duel, p)["cost_down_turn"] = t
			return true
		3013: # Spell Reproduction
			for _k in 2:
				CustomDuelOps.discard_matching_hand(duel, p, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx))
			var si := _find_spell_in_pile(duel, p, CustomDuelOps.LOC_GRAVE)
			if si >= 0:
				CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_GRAVE, si)
			return true
		3017: # Falling Down
			var tgt := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5)
			if not tgt.is_empty():
				var tz := CustomDuelOps.change_control(duel, opp, tgt["z"], p, false)
				if tz >= 0:
					CustomDuelOps.link_equip(duel, p, z, p, tz)
			return true
		3043: # Different Dimension Gate
			var t0 := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == p and zz < 5, false, false)
			var t1 := CustomDuelOps.choose_zone(duel, p, func(_d, pl, zz, _idx): return pl == opp and zz < 5, true, true)
			if not t0.is_empty() and not t1.is_empty():
				CustomDuelOps.zflags(duel, p, z)["ddg_ids"] = [[p, CustomDuelOps.raw_id(duel, t0["idx"])], [opp, CustomDuelOps.raw_id(duel, t1["idx"])]]
				CustomDuelOps.banish_zone(duel, p, t0["z"])
				CustomDuelOps.banish_zone(duel, opp, t1["z"])
			return true
		3045: # Token Thanksgiving
			var destroyed := 0
			for pl in 2:
				for zz in 5:
					var rid := CustomDuelOps.zone_id(duel, pl, zz)
					if rid >= 0x780 and rid < 2000 and CustomDuelOps.destroy_zone(duel, pl, zz):
						destroyed += 1
			if destroyed > 0:
				CustomDuelOps.heal(duel, p, destroyed * 800)
			return true
		3050: # Mustering of the Dark Scorpions
			for sc_id in [2894, 3032, 3049, 3061]:
				if CustomDuelOps.free_monster_zone(duel, p) < 0:
					break
				var hi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, sc_id)
				if hi >= 0:
					CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi, p)
			return true
		3055: # Checkmate
			var sac := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.raw_id(d, idx) in CustomDuelOps.ARCHFIEND_IDS and CustomDuelOps.raw_id(d, idx) != 3023, false, false)
			var tk := CustomDuelOps.find_zone_of_id(duel, p, 3023, true)
			if not sac.is_empty() and tk >= 0 and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
				CustomDuelOps.zflags(duel, p, tk)["direct_atk_turn"] = t
			return true
		3080: # Final Countdown
			if CustomDuelOps.pay_lp(duel, p, 2000):
				CustomDuelOps.schedule_delayed(duel, t + 20, CustomDuelOps.PHASE_EP, p, 3080, "final_countdown_win", {"winner": p})
			return true
		3095: # Ojama Delta Hurricane!!
			for zz in 11:
				if CustomDuelOps.zone_idx(duel, opp, zz) != 0:
					CustomDuelOps.destroy_zone(duel, opp, zz)
			return true
		3110: # Ultra Evolution Pill
			var sac := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.monster_race(d, idx) == 20, false, false)
			var di := _find_race_in_pile(duel, p, CustomDuelOps.LOC_HAND, 9)
			if not sac.is_empty() and di >= 0 and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, di, p)
			return true
		3111: # Multiplication of Ants
			var sac := CustomDuelOps.choose_zone(duel, p, func(d, pl, zz, idx): return pl == p and zz < 5 and CustomDuelOps.monster_race(d, idx) == 10, false, false)
			if not sac.is_empty() and CustomDuelOps.tribute_zone(duel, p, sac["z"]):
				for _k in 2:
					var tz := CustomDuelOps.spawn_token(duel, p, 0, false, 500, 1200)
					if tz >= 0:
						CustomDuelOps.zflags(duel, p, tz)["cannot_tribute"] = true
			return true
		3114: # Primal Seed
			for _k in 2:
				var bi := CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_BANISH, func(_d, _idx, _i): return true)
				if bi >= 0:
					CustomDuelOps.add_from_pile_to_hand(duel, p, CustomDuelOps.LOC_BANISH, bi)
			return true
		3117: # D.D. Designator
			var hc := CustomDuelOps.pile_count(duel, opp, CustomDuelOps.LOC_HAND)
			if hc > 0:
				CustomDuelOps.banish_from_pile(duel, opp, CustomDuelOps.LOC_HAND, 0)
			return true
		3118: # Gryphon's Feather Duster
			var destroyed := 0
			for zz in range(5, 11):
				if zz != z and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.destroy_zone(duel, p, zz):
					destroyed += 1
			if destroyed > 0:
				CustomDuelOps.heal(duel, p, destroyed * 500)
			return true
	return false


static func on_standby_tick(duel, tp: int) -> void:
	for pl in 2:
		if CustomDuelOps.has_faceup_id(duel, pl, 2679) and pl == tp: # Wave-Motion Cannon
			var wz := CustomDuelOps.find_zone_of_id(duel, pl, 2679, true)
			if wz >= 0:
				var c := int(CustomDuelOps.zflags(duel, pl, wz).get("wmc_counters", 0)) + 1
				CustomDuelOps.zflags(duel, pl, wz)["wmc_counters"] = c
		if CustomDuelOps.has_faceup_id(duel, pl, 2838) and pl != tp: # Mirage of Nightmare
			var need := 4 - CustomDuelOps.pile_count(duel, pl, CustomDuelOps.LOC_HAND)
			if need > 0:
				var drawn := CustomDuelOps.draw(duel, pl, need)
				CustomDuelOps.pflags(duel, pl)["mirage_discard"] = drawn
		if CustomDuelOps.has_faceup_id(duel, pl, 2838) and pl == tp:
			var md := int(CustomDuelOps.pflags(duel, pl).get("mirage_discard", 0))
			if md > 0:
				CustomDuelOps.pflags(duel, pl)["mirage_discard"] = 0
				CustomDuelOps.discard_random(duel, pl, md)
		if CustomDuelOps.has_faceup_id(duel, pl, 2845) and pl == tp: # Dark Snake Syndrome
			var sz := CustomDuelOps.find_zone_of_id(duel, pl, 2845, true)
			if sz >= 0:
				var dmg := int(CustomDuelOps.zflags(duel, pl, sz).get("snake_dmg", 200))
				CustomDuelOps.damage(duel, 0, dmg)
				CustomDuelOps.damage(duel, 1, dmg)
				CustomDuelOps.zflags(duel, pl, sz)["snake_dmg"] = mini(16000, dmg * 2)
		if CustomDuelOps.has_faceup_id(duel, pl, 2948) and pl == tp: # Senri Eye
			if CustomDuelOps.can_pay_lp(duel, pl, 100):
				CustomDuelOps.pay_lp(duel, pl, 100)
		if CustomDuelOps.has_faceup_id(duel, pl, 3017) and pl != tp: # Falling Down
			CustomDuelOps.damage(duel, pl, 800)


static func on_end_phase(duel, tp: int) -> void:
	var t := CustomDuelOps.turn_number(duel)
	for pl in 2:
		if int(CustomDuelOps.pflags(duel, pl).get("super_rejuv_turn", -1)) == t:
			var d_cnt := int(CustomDuelOps.pflags(duel, pl).get("dragons_discarded_turn", 0))
			if d_cnt > 0:
				CustomDuelOps.draw(duel, pl, d_cnt)
		if CustomDuelOps.has_faceup_id(duel, pl, 2788) and pl == tp: # Spiritual Energy Settle Machine
			var sz := CustomDuelOps.find_zone_of_id(duel, pl, 2788, true)
			if sz >= 0 and CustomDuelOps.discard_matching_hand(duel, pl, func(_d, _idx, _i): return true) == 0:
				CustomDuelOps.destroy_zone(duel, pl, sz)


static func on_continuous_enforce(duel) -> void:
	if CustomDuelOps.has_faceup_id(duel, 0, 2597) or CustomDuelOps.has_faceup_id(duel, 1, 2597):
		_apply_level_limit_b(duel)


static func _apply_level_limit_b(duel) -> void:
	for pl in 2:
		for zz in 5:
			var idx := CustomDuelOps.zone_idx(duel, pl, zz)
			if idx != 0 and CustomDuelOps.is_face_up(duel, pl, zz) and CustomDuelOps.monster_level(duel, idx) >= 4 and CustomDuelOps.is_atk_pos(duel, pl, zz):
				CustomDuelOps.change_position(duel, pl, zz, 1, 1)


static func _has_faceup_monster_any(duel) -> bool:
	return CustomDuelOps.count_monsters(duel, 0, true) > 0 or CustomDuelOps.count_monsters(duel, 1, true) > 0


static func _has_facedown_monster_any(duel) -> bool:
	for pl in 2:
		for zz in 5:
			if CustomDuelOps.zone_idx(duel, pl, zz) != 0 and not CustomDuelOps.is_face_up(duel, pl, zz):
				return true
	return false


static func _has_all_5_forbidden_in_gy(duel, p: int) -> bool:
	for fid in CustomDuelOps.FORBIDDEN_ONE_IDS:
		if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, fid) < 0:
			return false
	return true


static func _count_forbidden_available(duel, p: int) -> int:
	var found := 0
	for fid in CustomDuelOps.FORBIDDEN_ONE_IDS:
		if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, fid) >= 0 or CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_DECK, fid) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, fid, true) >= 0:
			found += 1
	return found


static func _has_any_id_on_field(duel, p: int, ids: Array) -> bool:
	for zz in 5:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in ids:
			return true
	return false


static func _has_race_on_field(duel, p: int, race: int, face_up_only := true) -> bool:
	for zz in 5:
		var idx := CustomDuelOps.zone_idx(duel, p, zz)
		if idx != 0 and (not face_up_only or CustomDuelOps.is_face_up(duel, p, zz)) and CustomDuelOps.monster_race(duel, idx) == race:
			return true
	return false


static func _find_in_pile(duel, p: int, loc: int, ids: Array) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, loc, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in ids)


static func _find_race_in_pile(duel, p: int, loc: int, race: int) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, loc, func(d, idx, _i): return CustomDuelOps.is_monster(d, idx) and CustomDuelOps.monster_race(d, idx) == race)


static func _find_spell_in_pile(duel, p: int, loc: int) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, loc, func(d, idx, _i): return CustomDuelOps.is_spell(d, idx))


static func _count_spells_in_pile(duel, p: int, loc: int) -> int:
	var n := 0
	for i in CustomDuelOps.pile_count(duel, p, loc):
		if CustomDuelOps.is_spell(duel, CustomDuelOps.pile_idx(duel, p, loc, i)):
			n += 1
	return n


static func _has_monster_in_hand(duel, p: int) -> bool:
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_HAND):
		if CustomDuelOps.is_monster(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, i)):
			return true
	return false


static func _find_divine_in_hand(duel, p: int) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.is_divine_beast(d, idx))


static func _find_union_in_hand_lv4(duel, p: int) -> int:
	return CustomDuelOps.choose_pile_card(duel, p, CustomDuelOps.LOC_HAND, func(d, idx, _i): return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.UNION_IDS and CustomDuelOps.monster_level(d, idx) <= 4)


static func _has_dm_on_field(duel, p: int) -> bool:
	for zz in 5:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in [34, 2034, 759]:
			return true
	return false


static func _has_archfiend_card(duel, p: int) -> bool:
	for zz in 11:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.is_face_up(duel, p, zz) and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.ARCHFIEND_IDS:
			return true
	return false


static func _count_tokens_on_field(duel) -> int:
	var n := 0
	for pl in 2:
		for zz in 5:
			var rid := CustomDuelOps.zone_id(duel, pl, zz)
			if rid >= 0x780 and rid < 2000:
				n += 1
	return n


static func _can_summon_armityle_from_extra(duel, p: int) -> bool:
	if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2513) < 0 and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2514) < 0:
		return false
	for mid in [2677, 2589, 2624]:
		if CustomDuelOps.find_zone_of_id(duel, p, mid, false) < 0 and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, mid) < 0 and CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, mid) < 0:
			return false
	return true


static func _consume_materials_anywhere(duel, p: int, ids: Array, banish_them: bool) -> bool:
	for mid in ids:
		var zz := CustomDuelOps.find_zone_of_id(duel, p, mid, false)
		if zz >= 0:
			if banish_them:
				CustomDuelOps.banish_zone(duel, p, zz)
			else:
				CustomDuelOps.send_zone_to_gy(duel, p, zz)
			continue
		var hi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_HAND, mid)
		if hi >= 0:
			if banish_them:
				CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_HAND, hi)
			else:
				CustomDuelOps.discard_hand_slot(duel, p, hi)
			continue
		var gi := CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_GRAVE, mid)
		if gi >= 0 and banish_them:
			CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
			continue
		return false
	return true


static func _can_miracle_fusion(duel, p: int) -> bool:
	for fi in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_FUSION):
		var fid := CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_FUSION, fi))
		if fid in CustomDuelOps.HERO_IDS:
			if _count_hero_materials(duel, p) >= 2:
				return true
	return false


static func _resolve_miracle_fusion(duel, p: int) -> void:
	for fi in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_FUSION):
		var fid := CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_FUSION, fi))
		if fid in CustomDuelOps.HERO_IDS:
			var used := 0
			for zz in 5:
				if used < 2 and CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.ELEMENTAL_HERO_IDS:
					CustomDuelOps.banish_zone(duel, p, zz)
					used += 1
			var gi := CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE) - 1
			while used < 2 and gi >= 0:
				if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, gi)) in CustomDuelOps.ELEMENTAL_HERO_IDS:
					CustomDuelOps.banish_from_pile(duel, p, CustomDuelOps.LOC_GRAVE, gi)
					used += 1
				gi -= 1
			if used >= 2:
				CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_FUSION, fi, p)
			return


static func _count_hero_materials(duel, p: int) -> int:
	var n := 0
	for zz in 5:
		if CustomDuelOps.zone_idx(duel, p, zz) != 0 and CustomDuelOps.zone_id(duel, p, zz) in CustomDuelOps.ELEMENTAL_HERO_IDS:
			n += 1
	for i in CustomDuelOps.pile_count(duel, p, CustomDuelOps.LOC_GRAVE):
		if CustomDuelOps.raw_id(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_GRAVE, i)) in CustomDuelOps.ELEMENTAL_HERO_IDS:
			n += 1
	return n


static func _can_fang_of_critias(duel, p: int) -> int:
	if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2551) >= 0 and (_find_in_pile(duel, p, CustomDuelOps.LOC_HAND, [CustomDuelOps.NATIVE_CRUSH_CARD]) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_CRUSH_CARD, false) >= 0):
		return 2551
	if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2616) >= 0 and (_find_in_pile(duel, p, CustomDuelOps.LOC_HAND, [CustomDuelOps.NATIVE_MIRROR_FORCE]) >= 0 or CustomDuelOps.find_zone_of_id(duel, p, CustomDuelOps.NATIVE_MIRROR_FORCE, false) >= 0):
		return 2616
	if CustomDuelOps.find_pile_index_by_id(duel, p, CustomDuelOps.LOC_FUSION, 2676) >= 0:
		return 2676
	return -1


static func _choose_equip_target(duel, p: int, cid: int) -> Dictionary:
	var pred := func(d, pl, zz, idx):
		if pl != p or zz >= 5 or not CustomDuelOps.is_face_up(d, pl, zz):
			return false
		match cid:
			2729: return CustomDuelOps.monster_race(d, idx) == 15
			2879: return CustomDuelOps.eff_atk(d, pl, zz) <= 1000
			3011: return CustomDuelOps.monster_race(d, idx) == 17
			3096: return CustomDuelOps.raw_id(d, idx) in CustomDuelOps.NINJA_IDS
		return true
	return CustomDuelOps.choose_zone(duel, p, pred, true, false)


static func _resolve_ritual_spell(duel, p: int, cid: int) -> void:
	var target_ids: Array = []
	match cid:
		2904: target_ids = [2966]
		3018: target_ids = [3046]
		3047: target_ids = [3071]
		3053: target_ids = [2526, 2966, 3046, 3071, 3084, 3129]
		3083: target_ids = [3084]
	var ri := _find_in_pile(duel, p, CustomDuelOps.LOC_HAND, target_ids)
	if ri >= 0 and CustomDuelOps.free_monster_zone(duel, p) >= 0:
		var need_lv := CustomDuelOps.monster_level(duel, CustomDuelOps.pile_idx(duel, p, CustomDuelOps.LOC_HAND, ri))
		var tributed := 0
		for zz in 5:
			if tributed >= need_lv:
				break
			var idx := CustomDuelOps.zone_idx(duel, p, zz)
			if idx != 0:
				tributed += CustomDuelOps.monster_level(duel, idx)
				CustomDuelOps.tribute_zone(duel, p, zz)
		if tributed >= need_lv:
			CustomDuelOps.special_summon_from_pile(duel, p, CustomDuelOps.LOC_HAND, ri, p)
