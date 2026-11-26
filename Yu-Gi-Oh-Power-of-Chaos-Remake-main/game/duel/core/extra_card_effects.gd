class_name ExtraCardEffects
extends RefCounted
## Efectos continuos, modificadores dinamicos de ATK/DEF, auras de campo, robo extra de
## Spirit of the Pot of Greed y soporte de invocacion ritual para las cartas de expansion
## (extra_cards.json >= 2500) tanto en el motor compartido Yugi/Kaiba (DuelMem) como en el
## motor nativo de Joey (JoeyMem).

const EXODIA_IDS := [0x10, 0x11, 0x12, 0x13, 0x14, 2573, 2574, 2575, 2657, 2660, 2674]
const AMAZONESS_IDS := [2907, 2940, 2945, 2968, 2981]
const GRAVEKEEPER_IDS := [2820, 2822, 2823, 2826, 2848, 2855, 2857, 2890, 2891]
const HERO_IDS := [2555, 2556, 2557, 2558, 2559, 2560, 2561, 2562, 2563, 2564, 2565, 2566, 2567, 2568, 2569, 2570]
const SACRED_BEAST_IDS := [2513, 2514, 2589, 2624, 2677]
const EXTRA_RITUAL_SPELLS := [2904, 3018, 3047, 3053, 3083]
const EXTRA_RITUAL_MONSTERS := [2526, 2966, 3046, 3071, 3084, 3129]
const EXTRA_FUSION_RECIPES := {
	2513: [2677, 2589, 2624], # Armityle the Chaos Phantasm (Uria + Hamon + Raviel)
	2514: [2677, 2589, 2624], # Armityle the Chaos Phantasm - Phantom of Fury
	2519: [0, 0, 0], # Blue-Eyes Ultimate Dragon, the God-Surpassing Servant
	2538: [2531, 2531, 2531], # Cyber End Dragon (3x Cyber Dragon)
	2540: [2531, 2531], # Cyber Twin Dragon (2x Cyber Dragon)
	2545: [34, 808], # Dark Paladin (Dark Magician + Buster Blader)
	2552: [3129, 379], # Dragon Master Knight (Black Luster Soldier + Blue-Eyes Ultimate Dragon)
	2559: [2555, 2557], # Elemental HERO Flame Wingman (Avian + Burstinatrix)
	2565: [2559, 2566], # Elemental HERO Shining Flare Wingman (Flame Wingman + Sparkman)
	2567: [2555, 2566, 2556], # Elemental HERO Tempest (Avian + Sparkman + Bubbleman)
	2568: [2566, 2558], # Elemental HERO Thunder Giant (Sparkman + Clayman)
	2620: [0, 0, 0], # Neo Blue-Eyes Ultimate Dragon (3x Blue-Eyes White Dragon)
	2687: [2686, 2690], # XY-Dragon Cannon (X-Head Cannon + Y-Dragon Head)
	2688: [2686, 2690, 2692], # XYZ-Dragon Cannon (X + Y + Z)
	2689: [2686, 2692], # XZ-Tank Cannon (X + Z)
	2691: [2690, 2692], # YZ-Tank Dragon (Y + Z)
	2694: [21, 81], # Black Skull Dragon (Summoned Skull + Red-Eyes B. Dragon)
	2741: [2764, 2758], # Ryu Senshi (Warrior Dai Grepher + Spirit Ryu)
	2757: [2782, 2710], # Fiend Skull Dragon (Cave Dragon + Lesser Fiend)
	2772: [2742, 2731], # Dark Balter the Terrible (Possessed Dark Soul + Frontier Wiseman)
	2881: [2651, 2854], # Reaper on the Nightmare (Spirit Reaper + Nightmare Horse)
	3000: [34, 14], # Dark Flare Knight (Dark Magician + Flame Swordsman)
}

static var _in_avatar_calc := false


static func fusion_materials(raw_id: int) -> Array[int]:
	var out: Array[int] = []
	if EXTRA_FUSION_RECIPES.has(raw_id):
		var raw_list: Variant = EXTRA_FUSION_RECIPES[raw_id]
		if raw_list is Array:
			for v: Variant in raw_list:
				out.append(int(v))
	return out


static func pot_of_greed_extra_draws_core(duel, activating_player: int) -> int:
	var m: DuelMem = duel.m
	if m.u8(DuelMem.pl(activating_player) + DuelMem.P_DECK_N) <= 2:
		return 0
	for pl in 2:
		for z in 5:
			var zone := DuelMem.zone(pl, z)
			var idx := m.u16(zone) & 0xfff
			if idx == 0:
				continue
			if (m.u16(zone + 6) & 3) == 2 and (m.u16(zone + 6) & 0x1000) == 0:
				if duel.cards.id_of(idx) == 3093:
					return 1
	return 0


static func pot_of_greed_extra_draws_joey(duel, activating_player: int) -> int:
	var m: JoeyMem = duel.m
	if m.u8(JoeyMem.pl(activating_player) + JoeyMem.P_DECK_N) <= 2:
		return 0
	for pl in 2:
		for z in 5:
			var zo := JoeyMem.zone(pl, z)
			var idx := m.u16(zo) & 0xfff
			if idx == 0:
				continue
			var fl := m.u16(zo + JoeyMem.Z_FLAGS)
			if (fl & 3) == 2 and (m.u8(zo + JoeyMem.Z_STATUS) & 0x20) == 0:
				var key := JoeyMem.ident(m.u32(zo))
				if (duel.f56b440(idx, key) & 0xffffffff) == 0 and duel.cards.id_of(idx) == 3093:
					return 1
	return 0


static func matches_ritual_monster_core(duel, card_index: int, ritual_id: int) -> bool:
	var idx := card_index & 0xfff
	if idx == 0 or ritual_id <= 0:
		return false
	return duel.cards.id_of(idx) == ritual_id or (duel.effect_card_id(idx) & 0xffff) == ritual_id


static func matches_ritual_monster_joey(duel, card_index: int, ritual_id: int) -> bool:
	var idx := card_index & 0xfff
	if idx == 0 or ritual_id <= 0:
		return false
	return duel.cards.id_of(idx) == ritual_id or (duel.effect_card_id(idx) & 0xffff) == ritual_id


static func _preferred_ritual_monsters(spell_raw_id: int) -> Array[int]:
	match spell_raw_id:
		2904:
			return [2966]
		3018:
			return [3046]
		3047:
			return [3071]
		3053:
			return [3084, 2526, 3129]
		3083:
			return [3084]
		_:
			return []


static func _is_ritual_monster_core(duel, idx: int) -> bool:
	if idx <= 0:
		return false
	var raw_id: int = duel.cards.id_of(idx)
	if raw_id in EXTRA_RITUAL_MONSTERS:
		return true
	var prop: int = duel.f401a20(idx)
	return ((prop >> 20) & 0x1f) < 0x15 and (duel.f541950(idx) & 0xffff) == 3


static func _is_ritual_monster_joey(duel, idx: int) -> bool:
	if idx <= 0:
		return false
	var raw_id: int = duel.cards.id_of(idx)
	if raw_id in EXTRA_RITUAL_MONSTERS:
		return true
	return (duel.f4025d0(idx) & 0xffff) < 0x15 and (duel.f402740(idx) & 0xffff) == 3


static func sync_ritual_table_core(duel, spell_index: int, player := -1) -> void:
	var idx := spell_index & 0xfff
	if idx == 0:
		return
	var raw_spell: int = duel.cards.id_of(idx)
	var m: DuelMem = duel.m
	var target_row := -1
	var r := 0
	while (m.u32(0x5aa9f0 + r * 4) & 0x3ffe000) != 0:
		if ((m.u32(0x5aa9f0 + r * 4) >> 13) & 0x1fff) == 0x2d0:
			target_row = r
			break
		r += 1
	if target_row < 0:
		return
	if raw_spell == 0x2d0:
		m.set_u32(0x5aa9f0 + target_row * 4, (6 << 26) | (0x2d0 << 13) | 0x2cf)
		return
	if raw_spell not in EXTRA_RITUAL_SPELLS:
		return
	var players: Array[int] = []
	if player >= 0:
		players.append(player & 1)
	else:
		var turn_p := m.u8(0xa1340f) & 1
		players.append(turn_p)
		players.append(1 - turn_p)
	var pref := _preferred_ritual_monsters(raw_spell)
	var chosen_id := 0
	var chosen_lv := 8
	for pl in players:
		var a := DuelMem.pl(pl)
		var hand_n := m.u8(a + DuelMem.P_HAND_N)
		for target_id in pref:
			for i in hand_n:
				var h_idx := m.u16(a + DuelMem.P_HAND + i * 4) & 0xfff
				if duel.cards.id_of(h_idx) == target_id:
					chosen_id = target_id
					chosen_lv = maxi(1, (duel.f401a20(h_idx) >> 25) & 0xf)
					break
			if chosen_id != 0:
				break
		if chosen_id == 0:
			for i in hand_n:
				var h_idx := m.u16(a + DuelMem.P_HAND + i * 4) & 0xfff
				if _is_ritual_monster_core(duel, h_idx):
					chosen_id = duel.cards.id_of(h_idx)
					chosen_lv = maxi(1, (duel.f401a20(h_idx) >> 25) & 0xf)
					break
		if chosen_id != 0:
			break
	if chosen_id == 0:
		chosen_id = pref[0] if not pref.is_empty() else 3129
		var c_idx: int = duel.cards.index_of(chosen_id)
		chosen_lv = maxi(1, (duel.f401a20(c_idx) >> 25) & 0xf) if c_idx > 0 else 8
	m.set_u32(0x5aa9f0 + target_row * 4, ((chosen_lv & 0x3f) << 26) | (0x2d0 << 13) | (chosen_id & 0x1fff))


static func sync_ritual_table_joey(duel, spell_index: int, player := -1) -> void:
	var idx := spell_index & 0xfff
	if idx == 0:
		return
	var raw_spell: int = duel.cards.id_of(idx)
	var m: JoeyMem = duel.m
	var target_row := -1
	var r := 0
	while (m.u32(0x5ed060 + r * 4) & 0x3ffe000) != 0:
		if ((m.u32(0x5ed060 + r * 4) >> 13) & 0x1fff) == 0x2d0:
			target_row = r
			break
		r += 1
	if target_row < 0:
		return
	if raw_spell == 0x2d0:
		m.set_u32(0x5ed060 + target_row * 4, (6 << 26) | (0x2d0 << 13) | 0x2cf)
		return
	if raw_spell not in EXTRA_RITUAL_SPELLS:
		return
	var players: Array[int] = []
	if player >= 0:
		players.append(player & 1)
	else:
		var turn_p := m.u8(JoeyMem.TURN) & 1
		players.append(turn_p)
		players.append(1 - turn_p)
	var pref := _preferred_ritual_monsters(raw_spell)
	var chosen_id := 0
	var chosen_lv := 8
	for pl in players:
		var a := JoeyMem.pl(pl)
		var hand_n := m.u8(a + JoeyMem.P_HAND_N)
		for target_id in pref:
			for i in hand_n:
				var h_idx := m.u16(a + JoeyMem.P_HAND + i * 4) & 0xfff
				if duel.cards.id_of(h_idx) == target_id:
					chosen_id = target_id
					chosen_lv = maxi(1, duel.f4026c0(h_idx) & 0xffff)
					break
			if chosen_id != 0:
				break
		if chosen_id == 0:
			for i in hand_n:
				var h_idx := m.u16(a + JoeyMem.P_HAND + i * 4) & 0xfff
				if _is_ritual_monster_joey(duel, h_idx):
					chosen_id = duel.cards.id_of(h_idx)
					chosen_lv = maxi(1, duel.f4026c0(h_idx) & 0xffff)
					break
		if chosen_id != 0:
			break
	if chosen_id == 0:
		chosen_id = pref[0] if not pref.is_empty() else 3129
		var c_idx: int = duel.cards.index_of(chosen_id)
		chosen_lv = maxi(1, duel.f4026c0(c_idx) & 0xffff) if c_idx > 0 else 8
	m.set_u32(0x5ed060 + target_row * 4, ((chosen_lv & 0x3f) << 26) | (0x2d0 << 13) | (chosen_id & 0x1fff))


# --- Core (Yugi / Kaiba) helpers -------------------------------------------------------------

static func _core_gy_monsters(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var n := 0
	for i in m.u8(pl + DuelMem.P_GRAVE_N):
		var idx := m.u16(pl + DuelMem.P_GRAVE + i * 4) & 0xfff
		if ((duel.f401a20(idx) >> 20) & 0x1f) < 0x15:
			n += 1
	return n


static func _core_gy_normal_monsters(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var n := 0
	for i in m.u8(pl + DuelMem.P_GRAVE_N):
		var idx := m.u16(pl + DuelMem.P_GRAVE + i * 4) & 0xfff
		if ((duel.f401a20(idx) >> 20) & 0x1f) < 0x15 and (duel.f541950(idx) & 0xffff) == 0:
			n += 1
	return n


static func _core_gy_type(duel, p: int, kind: int) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var n := 0
	for i in m.u8(pl + DuelMem.P_GRAVE_N):
		var idx := m.u16(pl + DuelMem.P_GRAVE + i * 4) & 0xfff
		if ((duel.f401a20(idx) >> 20) & 0x1f) == kind:
			n += 1
	return n


static func _core_hand_type(duel, p: int, kind: int) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var n := 0
	for i in m.u8(pl + DuelMem.P_HAND_N):
		var idx := m.u16(pl + DuelMem.P_HAND + i * 4) & 0xfff
		if ((duel.f401a20(idx) >> 20) & 0x1f) == kind:
			n += 1
	return n


static func _core_gy_exodia(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var n := 0
	for i in m.u8(pl + DuelMem.P_GRAVE_N):
		var idx := m.u16(pl + DuelMem.P_GRAVE + i * 4) & 0xfff
		if duel.cards.id_of(idx) in EXODIA_IDS or (duel.effect_card_id(idx) & 0xffff) in EXODIA_IDS:
			n += 1
	return n


static func _core_top_gy_stat_sum(duel, p: int, count: int, use_def := false) -> int:
	var m: DuelMem = duel.m
	var pl := DuelMem.pl(p)
	var vals: Array[int] = []
	for i in m.u8(pl + DuelMem.P_GRAVE_N):
		var idx := m.u16(pl + DuelMem.P_GRAVE + i * 4) & 0xfff
		if ((duel.f401a20(idx) >> 20) & 0x1f) < 0x15:
			vals.append(duel.f445850(idx) if use_def else duel.f445810(idx))
	vals.sort()
	vals.reverse()
	var total := 0
	for i in mini(count, vals.size()):
		total += vals[i]
	return total


static func _core_field_cards(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var n := 0
	for z in 11:
		if (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0:
			n += 1
	return n


static func _core_field_monsters(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var n := 0
	for z in 5:
		if (m.u32(DuelMem.zone(p, z)) & 0xfff) != 0:
			n += 1
	return n


static func _core_faceup_monsters(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var n := 0
	for z in 5:
		var zone := DuelMem.zone(p, z)
		var idx := m.u16(zone) & 0xfff
		if idx != 0 and (m.u8(zone + 6) & 2) != 0:
			n += 1
	return n


static func _core_amazoness_on_field(duel, p: int) -> int:
	var m: DuelMem = duel.m
	var n := 0
	for z in 5:
		var zone := DuelMem.zone(p, z)
		var idx := m.u16(zone) & 0xfff
		if idx != 0 and (m.u8(zone + 6) & 2) != 0 and duel.cards.id_of(idx) in AMAZONESS_IDS:
			n += 1
	return n


static func _core_other_type_on_field(duel, p: int, skip_z: int, kind: int) -> int:
	var m: DuelMem = duel.m
	var n := 0
	for z in 5:
		if z == skip_z:
			continue
		var zone := DuelMem.zone(p, z)
		var idx := m.u16(zone) & 0xfff
		if idx != 0 and (m.u8(zone + 6) & 2) != 0 and ((duel.f401a20(idx) >> 20) & 0x1f) == kind:
			n += 1
	return n


static func _core_has_active_raw_id(duel, pl: int, target_id: int, skip_p := -1, skip_z := -1) -> bool:
	var m: DuelMem = duel.m
	for z in 5:
		if pl == skip_p and z == skip_z:
			continue
		var zone := DuelMem.zone(pl, z)
		var idx := m.u16(zone) & 0xfff
		if idx != 0 and (m.u8(zone + 6) & 2) != 0 and (m.u16(zone + 6) & 0x1000) == 0:
			if duel.cards.id_of(idx) == target_id:
				return true
	return false


static func _core_count_active_st_raw_id(duel, pl: int, target_id: int) -> int:
	var m: DuelMem = duel.m
	if (m.u32(0xa133ec) & 0x100) != 0:
		return 0
	var n := 0
	for z in range(5, 11):
		var zone := DuelMem.zone(pl, z)
		var idx := m.u16(zone) & 0xfff
		if idx != 0 and (m.u8(zone + 6) & 2) != 0 and (m.u8(zone + 0x8f) & 4) == 0:
			if duel.cards.id_of(idx) == target_id:
				n += 1
	return n


static func _core_skill_drain_active(duel) -> bool:
	return _core_count_active_st_raw_id(duel, 0, 2644) > 0 or _core_count_active_st_raw_id(duel, 1, 2644) > 0


static func _core_highest_other_atk(duel, self_p: int, self_z: int, only_player := -1) -> int:
	var m: DuelMem = duel.m
	var best := 0
	if _in_avatar_calc:
		return best
	_in_avatar_calc = true
	for pl in 2:
		if only_player >= 0 and pl != (only_player & 1):
			continue
		for z in 5:
			if pl == (self_p & 1) and z == self_z:
				continue
			var zone := DuelMem.zone(pl, z)
			var idx := m.u16(zone) & 0xfff
			if idx == 0 or (m.u8(zone + 6) & 2) == 0:
				continue
			if duel.cards.id_of(idx) == 2661:
				continue
			var tmp := m.local(12)
			duel.f546470(pl, z, tmp)
			best = maxi(best, m.u32(tmp + 4))
	_in_avatar_calc = false
	return best


static func _core_dreadroot_active(duel) -> bool:
	return _core_has_active_raw_id(duel, 0, 2662) or _core_has_active_raw_id(duel, 1, 2662)


static func compute_stat_bonuses_core(duel, p: int, z: int, out: int, zone: int) -> Vector2i:
	var m: DuelMem = duel.m
	var raw_id: int = duel.cards.id_of(m.u16(out) & 0xfff)
	if raw_id < 2500:
		return Vector2i.ZERO
	if (m.u16(zone + 6) & 0x1000) != 0 or _core_skill_drain_active(duel):
		if raw_id in [2501, 2502, 2505, 2574, 2583, 2584, 2660, 2661, 2663, 2664, 2677, 2991, 3030, 3121]:
			m.set_u32(out + 4, 0)
			m.set_u32(out + 8, 0)
		return Vector2i.ZERO
	var pl := DuelMem.pl(p)
	var opp := 1 - (p & 1)
	var opp_pl := DuelMem.pl(opp)
	var atk_add := 0
	var def_add := 0
	match raw_id:
		2501:
			# The Winged Dragon of Ra: inherits power from 3 Tributes (top 3 GY monsters, min 3000)
			m.set_u32(out + 4, maxi(3000, _core_top_gy_stat_sum(duel, p, 3, false)))
			m.set_u32(out + 8, maxi(3000, _core_top_gy_stat_sum(duel, p, 3, true)))
		2502:
			var hc := m.u8(pl + DuelMem.P_HAND_N)
			m.set_u32(out + 4, hc * 1000)
			m.set_u32(out + 8, hc * 1000)
		2505:
			# Holactie the Creator of Light
			var lp_stat := maxi(5000, m.u16(pl + DuelMem.P_LP))
			m.set_u32(out + 4, lp_stat)
			m.set_u32(out + 8, lp_stat)
		2506:
			# Amulet Dragon: +100 ATK per Spell in both GYs
			atk_add = (_core_gy_type(duel, p, 22) + _core_gy_type(duel, opp, 22)) * 100
		2513, 2514:
			if (m.u8(0xa133f2) & 1) == (p & 1):
				atk_add = 10000
		2518, 2627:
			atk_add = _core_gy_type(duel, p, 1) * 300
		2524:
			atk_add = 300
		2536:
			# Cyber Dragon Vier: +500 ATK/DEF
			atk_add = 500
			def_add = 500
		2537:
			# Cyber Dragon Zwei: +300 ATK if Spell in GY
			if _core_gy_type(duel, p, 22) > 0:
				atk_add = 300
		2539:
			# Cyber End Dragon, the Final Strike Dragon: +500 ATK per Machine in GY
			atk_add = _core_gy_type(duel, p, 7) * 500
		2545:
			# Dark Paladin: +500 ATK per Dragon on field or in either GY
			var dragons := (
				_core_other_type_on_field(duel, p, z, 1)
				+ _core_other_type_on_field(duel, opp, -1, 1)
				+ _core_gy_type(duel, p, 1)
				+ _core_gy_type(duel, opp, 1)
			)
			atk_add = dragons * 500
		2546:
			# Dark Paladin - Wave-Motion: +500 ATK per other face-up monster on field
			var others := maxi(0, _core_faceup_monsters(duel, p) - 1) + _core_faceup_monsters(duel, opp)
			atk_add = others * 500
		2552:
			# Dragon Master Knight: +500 ATK per other Dragon you control
			atk_add = _core_other_type_on_field(duel, p, z, 1) * 500
		2564:
			# Elemental HERO Neos Knight: gains half ATK of strongest GY monster (up to +1500)
			atk_add = mini(1500, _core_top_gy_stat_sum(duel, p, 1, false) / 2)
		2565:
			# Elemental HERO Shining Flare Wingman: +300 ATK per Warrior in your GY
			atk_add = _core_gy_type(duel, p, 15) * 300
		2573:
			atk_add = _core_gy_exodia(duel, p) * 500
		2574:
			m.set_u32(out + 4, maxi(4000, _core_top_gy_stat_sum(duel, p, 5, false)))
			m.set_u32(out + 8, maxi(4000, _core_top_gy_stat_sum(duel, p, 5, true)))
		2575:
			atk_add = _core_gy_normal_monsters(duel, p) * 1000
		2581, 2582, 2585:
			var total_cards := (
				m.u8(DuelMem.pl(0) + DuelMem.P_BANISH_N)
				+ m.u8(DuelMem.pl(1) + DuelMem.P_BANISH_N)
				+ m.u8(DuelMem.pl(0) + DuelMem.P_GRAVE_N)
				+ m.u8(DuelMem.pl(1) + DuelMem.P_GRAVE_N)
			)
			atk_add = total_cards * 300
		2583, 2584:
			atk_add = maxi(2400, maxi(_core_top_gy_stat_sum(duel, p, 1, false), _core_highest_other_atk(duel, p, z)))
		2588:
			def_add = maxi(1000, _core_highest_other_atk(duel, p, z, opp))
		2611:
			# Millennium Scorpion: +500 ATK per monster in opponent's GY (capped +2500)
			atk_add = mini(2500, _core_gy_monsters(duel, opp) * 500)
		2635:
			atk_add = m.u8(pl + DuelMem.P_HAND_N) * 500
		2636:
			# Silent Magician LV4: +500 ATK per Spell in opponent's GY (max +2500)
			atk_add = mini(2500, _core_gy_type(duel, opp, 22) * 500)
		2638:
			# Silent Magician Zero: +500 ATK per card in opponent's hand
			atk_add = m.u8(opp_pl + DuelMem.P_HAND_N) * 500
		2639:
			# Silent Swordsman: +500 ATK per Warrior in your GY (max +2500)
			atk_add = mini(2500, _core_gy_type(duel, p, 15) * 500)
		2643:
			# Silent Swordsman Zero: +500 ATK per monster in your GY (max +2500)
			atk_add = mini(2500, _core_gy_monsters(duel, p) * 500)
		2657:
			atk_add = _core_gy_exodia(duel, p) * 1000
		2660:
			atk_add = m.u16(pl + DuelMem.P_LP)
		2661:
			var target_stat := _core_highest_other_atk(duel, p, z) + 100
			m.set_u32(out + 4, target_stat)
			m.set_u32(out + 8, target_stat)
		2663:
			var opp_cards := _core_field_cards(duel, opp) * 1000
			atk_add = opp_cards
			def_add = opp_cards
		2664:
			m.set_u32(out + 4, 4000)
			m.set_u32(out + 8, 4000)
		2669:
			# Toon Dark Magician Girl: +300 ATK per Spellcaster in either GY
			atk_add = (_core_gy_type(duel, p, 18) + _core_gy_type(duel, opp, 18)) * 300
		2677, 2594:
			var traps := _core_gy_type(duel, p, 21) * 1000
			atk_add = traps
			def_add = traps
		2684:
			var spells := _core_gy_type(duel, opp, 22) * 500
			atk_add = spells
			def_add = spells
		2699:
			# The Hunter with 7 Weapons: +1000 ATK when opponent controls a face-up monster
			if _core_faceup_monsters(duel, opp) > 0:
				atk_add = 1000
		2706:
			atk_add = maxi(1200, _core_highest_other_atk(duel, p, z, p & 1))
			def_add = 800
		2758:
			# Spirit Ryu: +500 ATK/DEF per Dragon in your hand
			var drg := _core_hand_type(duel, p, 1) * 500
			atk_add = drg
			def_add = drg
		2771:
			# Injection Fairy Lily: +2000 ATK when your LP > 2000
			if m.u16(pl + DuelMem.P_LP) > 2000:
				atk_add = 2000
		2814:
			# Royal Keeper: +300 ATK/DEF while face-up
			atk_add = 300
			def_add = 300
		2840:
			if _core_other_type_on_field(duel, p, z, 10) == 0:
				atk_add = -1000
				def_add = -1000
		2899:
			# Magical Marionette: +200 ATK per Spell in either GY
			atk_add = (_core_gy_type(duel, p, 22) + _core_gy_type(duel, opp, 22)) * 200
		2907:
			atk_add = _core_amazoness_on_field(duel, p) * 400
		2936, 2970:
			# Skilled White / Dark Magician: +200 ATK per Spell in your GY (max +600)
			atk_add = mini(600, _core_gy_type(duel, p, 22) * 200)
		2940:
			atk_add = _core_amazoness_on_field(duel, p) * 100
		2962:
			# Royal Magical Library: +300 DEF per Spell in your GY (max +1200)
			def_add = mini(1200, _core_gy_type(duel, p, 22) * 300)
		2991:
			atk_add = maxi(2400, _core_top_gy_stat_sum(duel, p, 2, false))
		2994:
			atk_add = _core_field_monsters(duel, opp) * 500
		3030:
			atk_add = maxi(2400, _core_top_gy_stat_sum(duel, p, 1, false) * 2)
		3034:
			# Mirage Knight: gains opponent's highest face-up monster ATK
			atk_add = _core_highest_other_atk(duel, p, z, opp)
		3066:
			atk_add = _core_gy_type(duel, p, 17) * 200
		3086:
			atk_add = _core_gy_monsters(duel, p) * 300
		3121:
			var ban := m.u8(pl + DuelMem.P_BANISH_N) * 400
			atk_add = ban
			def_add = ban
		3123:
			# Insect Princess: +500 ATK per Insect on opponent's field or GY
			atk_add = (_core_other_type_on_field(duel, opp, -1, 10) + _core_gy_type(duel, opp, 10)) * 500
	return Vector2i(atk_add, def_add)


static func apply_post_modifiers_core(duel, p: int, z: int, out: int, zone: int) -> void:
	var m: DuelMem = duel.m
	var idx := m.u16(out) & 0xfff
	var raw_id: int = duel.cards.id_of(idx)
	var skill_drain := _core_skill_drain_active(duel)
	if raw_id == 2661 and (m.u16(zone + 6) & 0x1000) == 0 and not skill_drain:
		var target_stat := _core_highest_other_atk(duel, p, z) + 100
		m.set_u32(out + 4, target_stat)
		m.set_u32(out + 8, target_stat)
		return
	var owner := p & 1
	var opp := 1 - owner
	var prop: int = int(duel.f401a20(idx))
	var m_type: int = m.u8(out + 2) & 0x1f
	var m_lv: int = (prop >> 25) & 0xf
	var atk_delta := 0
	var def_delta := 0
	if not skill_drain:
		# Ally field-wide / Union-support auras
		if m_type == 7:
			if _core_has_active_raw_id(duel, owner, 2536, owner, z):
				atk_delta += 500
				def_delta += 500
			if _core_has_active_raw_id(duel, owner, 2690, owner, z):
				atk_delta += 400
				def_delta += 400
			if _core_has_active_raw_id(duel, owner, 2692, owner, z):
				atk_delta += 600
				def_delta += 600
		if m_type == 13 and _core_has_active_raw_id(duel, owner, 2914, owner, z):
			atk_delta += 300
			def_delta += 300
		if m_type == 3:
			if _core_has_active_raw_id(duel, owner, 2915, owner, z):
				atk_delta += 500
				def_delta += 500
			if _core_has_active_raw_id(duel, owner, 2778, owner, z):
				atk_delta += 700
				def_delta += 700
		if (m_type == 1 or m_type == 15) and _core_has_active_raw_id(duel, owner, 2939, owner, z):
			atk_delta += 500
			def_delta += 500
		if m_type == 1 and _core_has_active_raw_id(duel, owner, 2974, owner, z):
			atk_delta += 1000
			def_delta += 1000
		if m_type == 2 and _core_has_active_raw_id(duel, owner, 2941, owner, z):
			atk_delta += 500
			def_delta += 500
		if (m_type == 4 or m_type == 14):
			if _core_has_active_raw_id(duel, owner, 2947, owner, z):
				atk_delta += 500
				def_delta += 500
			if _core_has_active_raw_id(duel, owner, 2975, owner, z):
				atk_delta += 500
				def_delta += 500
		if (m_type == 17 or m_type == 15) and _core_has_active_raw_id(duel, owner, 2959, owner, z):
			atk_delta += 1000
		if _core_has_active_raw_id(duel, owner, 2989, owner, z):
			atk_delta += 400
			def_delta += 400
		# Maiden of the Aqua (2816): Umi field aura
		if _core_has_active_raw_id(duel, 0, 2816) or _core_has_active_raw_id(duel, 1, 2816):
			if m_type in [5, 8, 14, 19]:
				atk_delta += 200
				def_delta += 200
			elif m_type in [4, 7]:
				atk_delta -= 200
				def_delta -= 200
		# Opponent debuff auras
		if _core_has_active_raw_id(duel, opp, 2886):
			atk_delta -= 800
		if _core_has_active_raw_id(duel, opp, 2968):
			atk_delta -= 500
		if _core_has_active_raw_id(duel, opp, 2983):
			atk_delta -= 500
	# Continuous Spells / Traps & Field Spells
	var a_forces := _core_count_active_st_raw_id(duel, owner, 2698)
	if a_forces > 0 and m_type == 15:
		var ws_count := (
			_core_other_type_on_field(duel, owner, -1, 15)
			+ _core_other_type_on_field(duel, owner, -1, 18)
		)
		atk_delta += a_forces * ws_count * 200
	var banner := _core_count_active_st_raw_id(duel, owner, 2807)
	if banner > 0 and (m.u8(0xa133f2) & 1) == owner:
		atk_delta += banner * 200
	var y_shield := _core_count_active_st_raw_id(duel, owner, 3091)
	if y_shield > 0:
		def_delta += y_shield * 300
	if (_core_count_active_st_raw_id(duel, 0, 2846) > 0 or _core_count_active_st_raw_id(duel, 1, 2846) > 0) and raw_id in GRAVEKEEPER_IDS:
		# Necrovalley (2846): direct +500 ATK/DEF to Gravekeeper's monsters.
		atk_delta += 500
		def_delta += 500
	if (_core_count_active_st_raw_id(duel, owner, 2645) > 0 or _core_count_active_st_raw_id(duel, owner, 2646) > 0) and raw_id in HERO_IDS:
		if (m.u8(0xa133f2) & 1) == owner and _core_highest_other_atk(duel, p, z, opp) > int(m.u32(out + 4)):
			atk_delta += 1000
	if (_core_count_active_st_raw_id(duel, 0, 2619) > 0 or _core_count_active_st_raw_id(duel, 1, 2619) > 0) and m_lv >= 10:
		atk_delta += 300
		def_delta += 300
	if (_core_count_active_st_raw_id(duel, owner, 2576) > 0 or _core_count_active_st_raw_id(duel, owner, 2577) > 0) and raw_id in SACRED_BEAST_IDS:
		atk_delta += 500
		def_delta += 500
	# Extra Equip Spells & Equip Traps (direct stat modifiers without native alias subtraction).
	if (m.u32(0xa133ec) & 0x100) == 0:
		for i in m.u16(zone + 0x88):
			if m.u8(zone + 0x48 + i * 2) != 1:
				continue
			var link := m.u16(zone + 8 + i * 2)
			var lzone := DuelMem.zone(link & 1, (link >> 8) & 0xff)
			var lix := m.u16(lzone) & 0xfff
			if lix == 0 or (m.u8(lzone + 0x8f) & 4) != 0:
				continue
			match duel.cards.id_of(lix):
				2729: # Fusion Sword Murasame Blade (+800 ATK)
					atk_delta += 800
				2787, 3011, 3016, 3052: # Blast with Chain / Cestus of Dagla / Gravity Axe - Grarl / Wicked-Breaking Flamberge - Baou (+500 ATK)
					atk_delta += 500
				2879: # Buster Rancher (+2500 vs >=2500 opponent monster)
					if _core_highest_other_atk(duel, p, z, opp) >= 2500:
						atk_delta += 2500
				2950: # Big Bang Shot (+400 ATK)
					atk_delta += 400
				3008: # Twin Swords of Flashing Light - Tryce (-500 ATK)
					atk_delta -= 500
				3054: # Butterfly Dagger - Elma (+300 ATK)
					atk_delta += 300
				3081: # Rod of Silence - Kay'est (+500 DEF)
					def_delta += 500
				3082: # Shooting Star Bow - Ceal (-1000 ATK)
					atk_delta -= 1000
				3096: # Fuhma Shuriken (+700 ATK)
					atk_delta += 700
	if atk_delta != 0:
		m.set_u32(out + 4, maxi(0, int(m.u32(out + 4)) + atk_delta))
	if def_delta != 0:
		m.set_u32(out + 8, maxi(0, int(m.u32(out + 8)) + def_delta))
	if not skill_drain and _core_has_active_raw_id(duel, opp, 2876) and int(m.u32(out + 4)) >= 1900:
		m.set_u32(out + 4, maxi(0, int(m.u32(out + 4)) - 400))
	if not skill_drain and raw_id != 2662 and _core_dreadroot_active(duel):
		m.set_u32(out + 4, duel.f53fbd0(m.u32(out + 4)))
		m.set_u32(out + 8, duel.f53fbd0(m.u32(out + 8)))
	var custom_stats: Dictionary = CustomCardEffects.modify_post_stats(duel, p, z, int(m.u32(out + 4)), int(m.u32(out + 8)))
	m.set_u32(out + 4, maxi(0, int(custom_stats.get("atk", m.u32(out + 4)))))
	m.set_u32(out + 8, maxi(0, int(custom_stats.get("def", m.u32(out + 8)))))


# --- Joey (JoeyMem) helpers ------------------------------------------------------------------

static func _joey_gy_monsters(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var n := 0
	for i in m.u8(pl + JoeyMem.P_GRAVE_N):
		var idx := m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff
		if (duel.f4025d0(idx) & 0xffff) < 0x15:
			n += 1
	return n


static func _joey_gy_normal_monsters(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var n := 0
	for i in m.u8(pl + JoeyMem.P_GRAVE_N):
		var idx := m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff
		if (duel.f4025d0(idx) & 0xffff) < 0x15 and (duel.f402740(idx) & 0xffff) == 0:
			n += 1
	return n


static func _joey_gy_type(duel, p: int, kind: int) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var n := 0
	for i in m.u8(pl + JoeyMem.P_GRAVE_N):
		var idx := m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff
		if (duel.f4025d0(idx) & 0xffff) == kind:
			n += 1
	return n


static func _joey_hand_type(duel, p: int, kind: int) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var n := 0
	for i in m.u8(pl + JoeyMem.P_HAND_N):
		var idx := m.u16(pl + JoeyMem.P_HAND + i * 4) & 0xfff
		if (duel.f4025d0(idx) & 0xffff) == kind:
			n += 1
	return n


static func _joey_gy_exodia(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var n := 0
	for i in m.u8(pl + JoeyMem.P_GRAVE_N):
		var idx := m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff
		if duel.cards.id_of(idx) in EXODIA_IDS or (duel.effect_card_id(idx) & 0xffff) in EXODIA_IDS:
			n += 1
	return n


static func _joey_top_gy_stat_sum(duel, p: int, count: int, use_def := false) -> int:
	var m: JoeyMem = duel.m
	var pl := JoeyMem.pl(p)
	var vals: Array[int] = []
	for i in m.u8(pl + JoeyMem.P_GRAVE_N):
		var idx := m.u16(pl + JoeyMem.P_GRAVE + i * 4) & 0xfff
		if (duel.f4025d0(idx) & 0xffff) < 0x15:
			vals.append((duel.f402800(idx) if use_def else duel.f4027b0(idx)) & 0xffff)
	vals.sort()
	vals.reverse()
	var total := 0
	for i in mini(count, vals.size()):
		total += vals[i]
	return total


static func _joey_field_cards(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var n := 0
	for z in 11:
		if (m.u32(JoeyMem.zone(p, z)) & 0xfff) != 0:
			n += 1
	return n


static func _joey_field_monsters(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var n := 0
	for z in 5:
		if (m.u32(JoeyMem.zone(p, z)) & 0xfff) != 0:
			n += 1
	return n


static func _joey_faceup_monsters(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var n := 0
	for z in 5:
		var zo := JoeyMem.zone(p, z)
		var idx := m.u16(zo) & 0xfff
		if idx != 0 and (m.u8(zo + JoeyMem.Z_FLAGS) & 2) != 0:
			n += 1
	return n


static func _joey_amazoness_on_field(duel, p: int) -> int:
	var m: JoeyMem = duel.m
	var n := 0
	for z in 5:
		var zo := JoeyMem.zone(p, z)
		var idx := m.u16(zo) & 0xfff
		if idx != 0 and (m.u8(zo + JoeyMem.Z_FLAGS) & 2) != 0 and duel.cards.id_of(idx) in AMAZONESS_IDS:
			n += 1
	return n


static func _joey_other_type_on_field(duel, p: int, skip_z: int, kind: int) -> int:
	var m: JoeyMem = duel.m
	var n := 0
	for z in 5:
		if z == skip_z:
			continue
		var zo := JoeyMem.zone(p, z)
		var idx := m.u16(zo) & 0xfff
		if idx != 0 and (m.u8(zo + JoeyMem.Z_FLAGS) & 2) != 0 and (duel.f56f6d0(p, z) & 0xffff) == kind:
			n += 1
	return n


static func _joey_has_active_raw_id(duel, pl: int, target_id: int, skip_p := -1, skip_z := -1) -> bool:
	var m: JoeyMem = duel.m
	for z in 5:
		if pl == skip_p and z == skip_z:
			continue
		var zo := JoeyMem.zone(pl, z)
		var idx := m.u16(zo) & 0xfff
		if idx != 0 and (m.u8(zo + JoeyMem.Z_FLAGS) & 2) != 0 and (m.u8(zo + JoeyMem.Z_STATUS) & 0x20) == 0:
			var key := JoeyMem.ident(m.u32(zo))
			if (duel.f56b440(idx, key) & 0xffffffff) == 0 and duel.cards.id_of(idx) == target_id:
				return true
	return false


static func _joey_count_active_st_raw_id(duel, pl: int, target_id: int) -> int:
	var m: JoeyMem = duel.m
	var rules := m.u32(JoeyMem.RULES)
	if (rules & 0x10000) != 0:
		return 0
	var n := 0
	for z in range(5, 11):
		var zo := JoeyMem.zone(pl, z)
		var idx := m.u16(zo) & 0xfff
		if idx != 0 and (m.u8(zo + JoeyMem.Z_FLAGS) & 2) != 0 and (m.u8(zo + JoeyMem.Z_STATUS) & 0x20) == 0:
			var key := JoeyMem.ident(m.u32(zo))
			if (duel.f56b440(idx, key) & 0xffffffff) == 0 and duel.cards.id_of(idx) == target_id:
				n += 1
	return n


static func _joey_skill_drain_active(duel) -> bool:
	return _joey_count_active_st_raw_id(duel, 0, 2644) > 0 or _joey_count_active_st_raw_id(duel, 1, 2644) > 0


static func _joey_highest_other_atk(duel, self_p: int, self_z: int, only_player := -1) -> int:
	var m: JoeyMem = duel.m
	var best := 0
	if _in_avatar_calc:
		return best
	_in_avatar_calc = true
	for pl in 2:
		if only_player >= 0 and pl != (only_player & 1):
			continue
		for z in 5:
			if pl == (self_p & 1) and z == self_z:
				continue
			var zo := JoeyMem.zone(pl, z)
			var idx := m.u16(zo) & 0xfff
			if idx == 0 or (m.u8(zo + JoeyMem.Z_FLAGS) & 2) == 0:
				continue
			if duel.cards.id_of(idx) == 2661:
				continue
			best = maxi(best, duel.f56f690(pl, z))
	_in_avatar_calc = false
	return best


static func _joey_dreadroot_active(duel) -> bool:
	return _joey_has_active_raw_id(duel, 0, 2662) or _joey_has_active_raw_id(duel, 1, 2662)


static func apply_own_effect_joey(duel, p: int, z: int, out: int, _zo: int, v: Array) -> void:
	var m: JoeyMem = duel.m
	var raw_id: int = duel.cards.id_of(m.u16(out) & 0xfff)
	if raw_id < 2500:
		return
	if _joey_skill_drain_active(duel):
		if raw_id in [2501, 2502, 2505, 2574, 2583, 2584, 2660, 2661, 2663, 2664, 2677, 2991, 3030, 3121]:
			m.set_u32(out + 4, 0)
			m.set_u32(out + 8, 0)
		return
	var pl := JoeyMem.pl(p)
	var opp := 1 - (p & 1)
	var opp_pl := JoeyMem.pl(opp)
	match raw_id:
		2501:
			m.set_u32(out + 4, maxi(3000, _joey_top_gy_stat_sum(duel, p, 3, false)))
			m.set_u32(out + 8, maxi(3000, _joey_top_gy_stat_sum(duel, p, 3, true)))
		2502:
			var hc := m.u8(pl + JoeyMem.P_HAND_N)
			m.set_u32(out + 4, hc * 1000)
			m.set_u32(out + 8, hc * 1000)
		2505:
			var lp_stat := maxi(5000, m.u16(pl + JoeyMem.P_LP))
			m.set_u32(out + 4, lp_stat)
			m.set_u32(out + 8, lp_stat)
		2506:
			v[0] += (_joey_gy_type(duel, p, 22) + _joey_gy_type(duel, opp, 22)) * 100
		2513, 2514:
			if (m.u8(JoeyMem.TURN) & 1) == (p & 1):
				v[0] += 10000
		2518, 2627:
			v[0] += _joey_gy_type(duel, p, 1) * 300
		2524:
			v[0] += 300
		2536:
			v[0] += 500
			v[1] += 500
		2537:
			if _joey_gy_type(duel, p, 22) > 0:
				v[0] += 300
		2539:
			v[0] += _joey_gy_type(duel, p, 7) * 500
		2545:
			var dragons := (
				_joey_other_type_on_field(duel, p, z, 1)
				+ _joey_other_type_on_field(duel, opp, -1, 1)
				+ _joey_gy_type(duel, p, 1)
				+ _joey_gy_type(duel, opp, 1)
			)
			v[0] += dragons * 500
		2546:
			var others := maxi(0, _joey_faceup_monsters(duel, p) - 1) + _joey_faceup_monsters(duel, opp)
			v[0] += others * 500
		2552:
			v[0] += _joey_other_type_on_field(duel, p, z, 1) * 500
		2564:
			v[0] += mini(1500, _joey_top_gy_stat_sum(duel, p, 1, false) / 2)
		2565:
			v[0] += _joey_gy_type(duel, p, 15) * 300
		2573:
			v[0] += _joey_gy_exodia(duel, p) * 500
		2574:
			m.set_u32(out + 4, maxi(4000, _joey_top_gy_stat_sum(duel, p, 5, false)))
			m.set_u32(out + 8, maxi(4000, _joey_top_gy_stat_sum(duel, p, 5, true)))
		2575:
			v[0] += _joey_gy_normal_monsters(duel, p) * 1000
		2581, 2582, 2585:
			var total_cards := (
				m.u8(JoeyMem.pl(0) + JoeyMem.P_BANISH_N)
				+ m.u8(JoeyMem.pl(1) + JoeyMem.P_BANISH_N)
				+ m.u8(JoeyMem.pl(0) + JoeyMem.P_GRAVE_N)
				+ m.u8(JoeyMem.pl(1) + JoeyMem.P_GRAVE_N)
			)
			v[0] += total_cards * 300
		2583, 2584:
			v[0] += maxi(2400, maxi(_joey_top_gy_stat_sum(duel, p, 1, false), _joey_highest_other_atk(duel, p, z)))
		2588:
			v[1] += maxi(1000, _joey_highest_other_atk(duel, p, z, opp))
		2611:
			v[0] += mini(2500, _joey_gy_monsters(duel, opp) * 500)
		2635:
			v[0] += m.u8(pl + JoeyMem.P_HAND_N) * 500
		2636:
			v[0] += mini(2500, _joey_gy_type(duel, opp, 22) * 500)
		2638:
			v[0] += m.u8(opp_pl + JoeyMem.P_HAND_N) * 500
		2639:
			v[0] += mini(2500, _joey_gy_type(duel, p, 15) * 500)
		2643:
			v[0] += mini(2500, _joey_gy_monsters(duel, p) * 500)
		2657:
			v[0] += _joey_gy_exodia(duel, p) * 1000
		2660:
			v[0] += m.u16(pl + JoeyMem.P_LP)
		2661:
			var target_stat := _joey_highest_other_atk(duel, p, z) + 100
			m.set_u32(out + 4, target_stat)
			m.set_u32(out + 8, target_stat)
		2663:
			var opp_cards := _joey_field_cards(duel, opp) * 1000
			v[0] += opp_cards
			v[1] += opp_cards
		2664:
			m.set_u32(out + 4, 4000)
			m.set_u32(out + 8, 4000)
		2669:
			v[0] += (_joey_gy_type(duel, p, 18) + _joey_gy_type(duel, opp, 18)) * 300
		2677, 2594:
			var traps := _joey_gy_type(duel, p, 21) * 1000
			v[0] += traps
			v[1] += traps
		2684:
			var spells := _joey_gy_type(duel, opp, 22) * 500
			v[0] += spells
			v[1] += spells
		2699:
			if _joey_faceup_monsters(duel, opp) > 0:
				v[0] += 1000
		2706:
			v[0] += maxi(1200, _joey_highest_other_atk(duel, p, z, p & 1))
			v[1] += 800
		2758:
			var drg := _joey_hand_type(duel, p, 1) * 500
			v[0] += drg
			v[1] += drg
		2771:
			if m.u16(pl + JoeyMem.P_LP) > 2000:
				v[0] += 2000
		2814:
			v[0] += 300
			v[1] += 300
		2840:
			if _joey_other_type_on_field(duel, p, z, 10) == 0:
				v[0] -= 1000
				v[1] -= 1000
		2899:
			v[0] += (_joey_gy_type(duel, p, 22) + _joey_gy_type(duel, opp, 22)) * 200
		2907:
			v[0] += _joey_amazoness_on_field(duel, p) * 400
		2936, 2970:
			v[0] += mini(600, _joey_gy_type(duel, p, 22) * 200)
		2940:
			v[0] += _joey_amazoness_on_field(duel, p) * 100
		2962:
			v[1] += mini(1200, _joey_gy_type(duel, p, 22) * 300)
		2991:
			v[0] += maxi(2400, _joey_top_gy_stat_sum(duel, p, 2, false))
		2994:
			v[0] += _joey_field_monsters(duel, opp) * 500
		3030:
			v[0] += maxi(2400, _joey_top_gy_stat_sum(duel, p, 1, false) * 2)
		3034:
			v[0] += _joey_highest_other_atk(duel, p, z, opp)
		3066:
			v[0] += _joey_gy_type(duel, p, 17) * 200
		3086:
			v[0] += _joey_gy_monsters(duel, p) * 300
		3121:
			var ban := m.u8(pl + JoeyMem.P_BANISH_N) * 400
			v[0] += ban
			v[1] += ban
		3123:
			v[0] += (_joey_other_type_on_field(duel, opp, -1, 10) + _joey_gy_type(duel, opp, 10)) * 500


static func apply_post_modifiers_joey(duel, p: int, z: int, out: int, zo: int) -> void:
	var m: JoeyMem = duel.m
	var idx := m.u16(out) & 0xfff
	var raw_id: int = duel.cards.id_of(idx)
	var key := JoeyMem.ident(m.u32(zo))
	var skill_drain := _joey_skill_drain_active(duel)
	if raw_id == 2661 and (duel.f56b440(idx, key) & 0xffffffff) == 0 and not skill_drain:
		var target_stat := _joey_highest_other_atk(duel, p, z) + 100
		m.set_u32(out + 4, target_stat)
		m.set_u32(out + 8, target_stat)
		return
	var owner := p & 1
	var opp := 1 - owner
	var m_type: int = m.u8(out + 2) & 0xff
	var m_lv: int = int(duel.f4026c0(idx)) & 0xffff
	var atk_delta := 0
	var def_delta := 0
	if not skill_drain:
		if m_type == 7:
			if _joey_has_active_raw_id(duel, owner, 2536, owner, z):
				atk_delta += 500
				def_delta += 500
			if _joey_has_active_raw_id(duel, owner, 2690, owner, z):
				atk_delta += 400
				def_delta += 400
			if _joey_has_active_raw_id(duel, owner, 2692, owner, z):
				atk_delta += 600
				def_delta += 600
		if m_type == 13 and _joey_has_active_raw_id(duel, owner, 2914, owner, z):
			atk_delta += 300
			def_delta += 300
		if m_type == 3:
			if _joey_has_active_raw_id(duel, owner, 2915, owner, z):
				atk_delta += 500
				def_delta += 500
			if _joey_has_active_raw_id(duel, owner, 2778, owner, z):
				atk_delta += 700
				def_delta += 700
		if (m_type == 1 or m_type == 15) and _joey_has_active_raw_id(duel, owner, 2939, owner, z):
			atk_delta += 500
			def_delta += 500
		if m_type == 1 and _joey_has_active_raw_id(duel, owner, 2974, owner, z):
			atk_delta += 1000
			def_delta += 1000
		if m_type == 2 and _joey_has_active_raw_id(duel, owner, 2941, owner, z):
			atk_delta += 500
			def_delta += 500
		if (m_type == 4 or m_type == 14):
			if _joey_has_active_raw_id(duel, owner, 2947, owner, z):
				atk_delta += 500
				def_delta += 500
			if _joey_has_active_raw_id(duel, owner, 2975, owner, z):
				atk_delta += 500
				def_delta += 500
		if (m_type == 17 or m_type == 15) and _joey_has_active_raw_id(duel, owner, 2959, owner, z):
			atk_delta += 1000
		if _joey_has_active_raw_id(duel, owner, 2989, owner, z):
			atk_delta += 400
			def_delta += 400
		if _joey_has_active_raw_id(duel, 0, 2816) or _joey_has_active_raw_id(duel, 1, 2816):
			if m_type in [5, 8, 14, 19]:
				atk_delta += 200
				def_delta += 200
			elif m_type in [4, 7]:
				atk_delta -= 200
				def_delta -= 200
		if _joey_has_active_raw_id(duel, opp, 2886):
			atk_delta -= 800
		if _joey_has_active_raw_id(duel, opp, 2968):
			atk_delta -= 500
		if _joey_has_active_raw_id(duel, opp, 2983):
			atk_delta -= 500
	# Continuous Spells / Traps & Field Spells
	var a_forces := _joey_count_active_st_raw_id(duel, owner, 2698)
	if a_forces > 0 and m_type == 15:
		var ws_count := (
			_joey_other_type_on_field(duel, owner, -1, 15)
			+ _joey_other_type_on_field(duel, owner, -1, 18)
		)
		atk_delta += a_forces * ws_count * 200
	var banner := _joey_count_active_st_raw_id(duel, owner, 2807)
	if banner > 0 and (m.u8(JoeyMem.TURN) & 1) == owner:
		atk_delta += banner * 200
	var y_shield := _joey_count_active_st_raw_id(duel, owner, 3091)
	if y_shield > 0:
		def_delta += y_shield * 300
	if (_joey_count_active_st_raw_id(duel, 0, 2846) > 0 or _joey_count_active_st_raw_id(duel, 1, 2846) > 0) and raw_id in GRAVEKEEPER_IDS:
		atk_delta += 500
		def_delta += 500
	if (_joey_count_active_st_raw_id(duel, owner, 2645) > 0 or _joey_count_active_st_raw_id(duel, owner, 2646) > 0) and raw_id in HERO_IDS:
		if (m.u8(JoeyMem.TURN) & 1) == owner and _joey_highest_other_atk(duel, p, z, opp) > int(m.u32(out + 4)):
			atk_delta += 1000
	if (_joey_count_active_st_raw_id(duel, 0, 2619) > 0 or _joey_count_active_st_raw_id(duel, 1, 2619) > 0) and m_lv >= 10:
		atk_delta += 300
		def_delta += 300
	if (_joey_count_active_st_raw_id(duel, owner, 2576) > 0 or _joey_count_active_st_raw_id(duel, owner, 2577) > 0) and raw_id in SACRED_BEAST_IDS:
		atk_delta += 500
		def_delta += 500
	# Extra Equip Spells & Equip Traps (direct stat modifiers without native alias subtraction).
	if (m.u32(JoeyMem.RULES) & 0x10000) == 0:
		for i in m.u16(zo + JoeyMem.Z_LINKS_N):
			if (m.u8(zo + JoeyMem.Z_LINK_KIND + i * 2) & 0xf) != 1:
				continue
			var ref := m.u16(zo + JoeyMem.Z_LINK_REF + i * 2)
			var tz := JoeyMem.zone(ref & 1, ref >> 8)
			var lix := m.u16(tz) & 0xfff
			if lix == 0 or (m.u8(tz + JoeyMem.Z_STATUS) & 0x20) != 0 or (m.u8(tz + JoeyMem.Z_FLAGS) & 2) == 0:
				continue
			match duel.cards.id_of(lix):
				2729:
					atk_delta += 800
				2787, 3011, 3016, 3052:
					atk_delta += 500
				2879:
					if _joey_highest_other_atk(duel, p, z, opp) >= 2500:
						atk_delta += 2500
				2950:
					atk_delta += 400
				3008:
					atk_delta -= 500
				3054:
					atk_delta += 300
				3081:
					def_delta += 500
				3082:
					atk_delta -= 1000
				3096:
					atk_delta += 700
	if atk_delta != 0:
		m.set_u32(out + 4, maxi(0, int(m.u32(out + 4)) + atk_delta))
	if def_delta != 0:
		m.set_u32(out + 8, maxi(0, int(m.u32(out + 8)) + def_delta))
	if not skill_drain and _joey_has_active_raw_id(duel, opp, 2876) and int(m.u32(out + 4)) >= 1900:
		m.set_u32(out + 4, maxi(0, int(m.u32(out + 4)) - 400))
	if not skill_drain and raw_id != 2662 and _joey_dreadroot_active(duel):
		m.set_u32(out + 4, duel.f5be050(m.u32(out + 4)))
		m.set_u32(out + 8, duel.f5be050(m.u32(out + 8)))
	var custom_stats: Dictionary = CustomCardEffects.modify_post_stats(duel, p, z, int(m.u32(out + 4)), int(m.u32(out + 8)))
	m.set_u32(out + 4, maxi(0, int(custom_stats.get("atk", m.u32(out + 4)))))
	m.set_u32(out + 8, maxi(0, int(custom_stats.get("def", m.u32(out + 8)))))

