from __future__ import annotations

import json
import pathlib
import re
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
EXTRA_CARDS_JSON = REPO_ROOT / "game/assets/cards/extra_cards.json"
CORE_DIR = REPO_ROOT / "game/duel/core"
JOEY_DIR = REPO_ROOT / "game/duel/joey"

CUSTOM_FILES = [
	CORE_DIR / "custom_duel_ops.gd",
	CORE_DIR / "custom_effects_traps.gd",
	CORE_DIR / "custom_effects_spells.gd",
	CORE_DIR / "custom_effects_monsters_1.gd",
	CORE_DIR / "custom_effects_monsters_2.gd",
	CORE_DIR / "custom_card_effects.gd",
]

MODIFIED_ENGINE_FILES = [
	CORE_DIR / "extra_card_effects.gd",
	CORE_DIR / "duel.gd",
	CORE_DIR / "duel_port_e.gd",
	CORE_DIR / "duel_port_f.gd",
	CORE_DIR / "duel_port_g.gd",
	CORE_DIR / "duel_port_h.gd",
	CORE_DIR / "duel_port_l.gd",
	CORE_DIR / "duel_port_m.gd",
	CORE_DIR / "duel_port_n.gd",
	JOEY_DIR / "joey_base.gd",
	JOEY_DIR / "joey_port_c.gd",
	JOEY_DIR / "joey_port_o.gd",
	JOEY_DIR / "joey_port_p.gd",
	JOEY_DIR / "joey_port_s.gd",
	JOEY_DIR / "joey_port_t.gd",
	JOEY_DIR / "joey_port_u.gd",
	JOEY_DIR / "joey_port_w.gd",
	JOEY_DIR / "joey_port_y.gd",
	JOEY_DIR / "joey_port_zb.gd",
	JOEY_DIR / "joey_port_zi.gd",
]


def _strip_comments_and_strings(text: str) -> str:
	out: list[str] = []
	i = 0
	n = len(text)
	while i < n:
		ch = text[i]
		if ch == "#":
			while i < n and text[i] != "\n":
				i += 1
			continue
		if ch in ('"', "'"):
			quote = ch
			if text[i : i + 3] == quote * 3:
				i += 3
				while i < n and text[i : i + 3] != quote * 3:
					if text[i] == "\n":
						out.append("\n")
					i += 1
				i += 3
				continue
			i += 1
			while i < n and text[i] != quote:
				if text[i] == "\\":
					i += 2
					continue
				if text[i] == "\n":
					out.append("\n")
				i += 1
			i += 1
			continue
		out.append(ch)
		i += 1
	return "".join(out)


def _extract_ids(path: pathlib.Path) -> list[int]:
	text = path.read_text(encoding="utf-8")
	match = re.search(r"const\s+IDS[^=]*=\s*\[(.*?)\]", text, re.S)
	assert match is not None, f"Missing const IDS in {path.name}"
	return [int(tok) for tok in re.findall(r"\d+", match.group(1))]


def _extract_symbols(path: pathlib.Path) -> tuple[set[str], set[str]]:
	text = path.read_text(encoding="utf-8")
	funcs = set(re.findall(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M))
	consts = set(re.findall(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, re.M))
	return funcs, consts


class TestYgojsonAndCustomEffects(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.payload = json.loads(EXTRA_CARDS_JSON.read_text(encoding="utf-8"))
		cls.cards = cls.payload["cards"]
		cls.by_id = {int(c["internal_id"]): c for c in cls.cards}

	def test_extra_cards_counts_and_schema(self) -> None:
		self.assertEqual(len(self.cards), 649)
		self.assertEqual(set(self.by_id.keys()), set(range(2500, 3149)))

		custom = [c for c in self.cards if c.get("custom_effect")]
		normal = [c for c in self.cards if not c.get("custom_effect")]
		self.assertEqual(len(custom), 608)
		self.assertEqual(len(normal), 41)

		traps = [c for c in custom if c["category"] == "trap"]
		spells = [c for c in custom if c["category"] == "spell"]
		m1 = [c for c in custom if c["category"] == "monster" and c["internal_id"] < 2800]
		m2 = [c for c in custom if c["category"] == "monster" and c["internal_id"] >= 2800]
		self.assertEqual(len(traps), 98)
		self.assertEqual(len(spells), 153)
		self.assertEqual(len(m1), 184)
		self.assertEqual(len(m2), 173)

		for card in self.cards:
			self.assertTrue(card.get("names", {}).get("eng"), f"Missing eng name for {card['internal_id']}")
			self.assertTrue(card.get("card_shape"), f"Missing card_shape for {card['internal_id']}")
			self.assertTrue(card.get("frame_type"), f"Missing frame_type for {card['internal_id']}")
			if card.get("custom_effect"):
				# The 5 custom Ritual Spells intentionally use native Ritual Spell UI hook 720.
				# All other 584 custom cards must have effect_alias == 0 (no stolen native aliases).
				expected_alias = 720 if card["internal_id"] in {2904, 3018, 3047, 3053, 3083} else 0
				self.assertEqual(
					int(card.get("effect_alias", 0)),
					expected_alias,
					f"Custom card {card['internal_id']} has unexpected effect_alias={card.get('effect_alias')} (expected {expected_alias})",
				)

	def test_all_604_custom_ids_registered_and_implemented(self) -> None:
		expected = {
			CORE_DIR / "custom_effects_traps.gd": {
				c["internal_id"] for c in self.cards if c.get("custom_effect") and c["category"] == "trap"
			},
			CORE_DIR / "custom_effects_spells.gd": {
				c["internal_id"] for c in self.cards if c.get("custom_effect") and c["category"] == "spell"
			},
			CORE_DIR / "custom_effects_monsters_1.gd": {
				c["internal_id"]
				for c in self.cards
				if c.get("custom_effect") and c["category"] == "monster" and c["internal_id"] < 2800
			},
			CORE_DIR / "custom_effects_monsters_2.gd": {
				c["internal_id"]
				for c in self.cards
				if c.get("custom_effect") and c["category"] == "monster" and c["internal_id"] >= 2800
			},
		}

		union_ids: set[int] = set()
		for path, exp_ids in expected.items():
			ids = _extract_ids(path)
			self.assertEqual(len(ids), len(set(ids)), f"Duplicate IDs in {path.name}")
			self.assertEqual(set(ids), exp_ids, f"ID set mismatch in {path.name}")
			self.assertTrue(union_ids.isdisjoint(exp_ids), f"Overlap across modules for {path.name}")
			union_ids.update(exp_ids)

			# Verify every registered ID also appears in implementation logic outside const IDS.
			text = path.read_text(encoding="utf-8")
			body = re.sub(r"const\s+IDS[^=]*=\s*\[.*?\]", "", text, count=1, flags=re.S)
			body_nums = {int(tok) for tok in re.findall(r"\b\d{4}\b", body)}
			missing_in_body = exp_ids - body_nums
			# Some cards are handled via archetype arrays in CustomDuelOps; verify none are silently dropped
			# unless present in a CustomDuelOps archetype list.
			if missing_in_body:
				ops_text = (CORE_DIR / "custom_duel_ops.gd").read_text(encoding="utf-8")
				ops_nums = {int(tok) for tok in re.findall(r"\b\d{4}\b", ops_text)}
				truly_missing = missing_in_body - ops_nums
				self.assertEqual(
					truly_missing,
					set(),
					f"IDs registered in {path.name} but unreferenced in logic: {sorted(truly_missing)}",
				)

		self.assertEqual(len(union_ids), 608)

	def test_gdscript_static_syntax_and_style(self) -> None:
		for path in CUSTOM_FILES + MODIFIED_ENGINE_FILES:
			self.assertTrue(path.exists(), f"Missing file: {path}")
			text = path.read_text(encoding="utf-8")
			lines = text.splitlines()

			# 1. Tabs-only leading indentation (allow spaces only inside multi-line doc/continuation or empty lines)
			for lineno, line in enumerate(lines, start=1):
				if not line.strip():
					continue
				leading = line[: len(line) - len(line.lstrip(" \t"))]
				if leading and " " in leading and "\t" in leading:
					self.fail(f"Mixed tabs and spaces at {path.name}:{lineno}")

			# 2. Balanced brackets outside strings and comments
			stripped = _strip_comments_and_strings(text)
			stack: list[tuple[str, int]] = []
			pairs = {")": "(", "]": "[", "}": "{"}
			cur_line = 1
			for ch in stripped:
				if ch == "\n":
					cur_line += 1
				elif ch in "([{":
					stack.append((ch, cur_line))
				elif ch in ")]}":
					if not stack or stack[-1][0] != pairs[ch]:
						self.fail(f"Unbalanced '{ch}' at {path.name}:{cur_line}")
					stack.pop()
			if stack:
				self.fail(f"Unclosed '{stack[-1][0]}' at {path.name}:{stack[-1][1]}")

			# 3. No duplicate top-level func or const definitions
			seen_funcs: set[str] = set()
			seen_consts: set[str] = set()
			for lineno, line in enumerate(lines, start=1):
				m_func = re.match(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", line)
				if m_func:
					name = m_func.group(1)
					self.assertNotIn(name, seen_funcs, f"Duplicate func {name} in {path.name}:{lineno}")
					seen_funcs.add(name)
				m_const = re.match(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\b", line)
				if m_const:
					name = m_const.group(1)
					self.assertNotIn(name, seen_consts, f"Duplicate const {name} in {path.name}:{lineno}")
					seen_consts.add(name)

			# 4. No hard CardDB autoload references inside game/duel/
			self.assertNotRegex(
				stripped,
				r"\bCardDB\.",
				f"Forbidden direct CardDB autoload reference in {path.name}",
			)

	def test_cross_module_symbol_resolution(self) -> None:
		class_symbols: dict[str, set[str]] = {}
		class_files = {
			"CustomDuelOps": CORE_DIR / "custom_duel_ops.gd",
			"CustomEffectsTraps": CORE_DIR / "custom_effects_traps.gd",
			"CustomEffectsSpells": CORE_DIR / "custom_effects_spells.gd",
			"CustomEffectsMonsters1": CORE_DIR / "custom_effects_monsters_1.gd",
			"CustomEffectsMonsters2": CORE_DIR / "custom_effects_monsters_2.gd",
			"CustomCardEffects": CORE_DIR / "custom_card_effects.gd",
		}
		for cls_name, path in class_files.items():
			funcs, consts = _extract_symbols(path)
			class_symbols[cls_name] = funcs | consts

		pattern = re.compile(
			r"\b(CustomDuelOps|CustomEffectsTraps|CustomEffectsSpells|CustomEffectsMonsters1|CustomEffectsMonsters2|CustomCardEffects)\.([A-Za-z_][A-Za-z0-9_]*)"
		)
		for path in CUSTOM_FILES + MODIFIED_ENGINE_FILES:
			stripped = _strip_comments_and_strings(path.read_text(encoding="utf-8"))
			for cls_name, sym in pattern.findall(stripped):
				self.assertIn(
					sym,
					class_symbols[cls_name],
					f"Unresolved reference {cls_name}.{sym} in {path.name}",
				)

	def test_core_and_joey_engine_hooks_present(self) -> None:
		core_blob = "\n".join(
			(CORE_DIR / f).read_text(encoding="utf-8")
			for f in [
				"extra_card_effects.gd",
				"duel.gd",
				"duel_port_e.gd",
				"duel_port_f.gd",
				"duel_port_g.gd",
				"duel_port_h.gd",
				"duel_port_l.gd",
				"duel_port_m.gd",
				"duel_port_n.gd",
			]
		)
		joey_blob = "\n".join(
			[
				(CORE_DIR / "extra_card_effects.gd").read_text(encoding="utf-8"),
			]
			+ [
				(JOEY_DIR / f).read_text(encoding="utf-8")
				for f in [
					"joey_base.gd",
					"joey_port_c.gd",
					"joey_port_o.gd",
					"joey_port_p.gd",
					"joey_port_s.gd",
					"joey_port_t.gd",
					"joey_port_u.gd",
					"joey_port_w.gd",
					"joey_port_y.gd",
				]
			]
		)
		required_hooks = [
			"CustomCardEffects.on_duel_reset",
			"CustomCardEffects.on_phase_tick",
			"CustomCardEffects.check_win",
			"CustomCardEffects.can_activate",
			"CustomCardEffects.resolve_chain_link",
			"CustomCardEffects.can_normal_summon",
			"CustomCardEffects.can_special_summon",
			"CustomCardEffects.special_summon",
			"CustomCardEffects.on_summon_or_flip",
			"CustomCardEffects.on_attack_declare",
			"CustomCardEffects.on_damage_calc",
			"CustomCardEffects.on_battle_damage",
			"CustomCardEffects.on_battle_end",
			"CustomCardEffects.on_destroyed",
			"CustomCardEffects.on_sent_to_gy",
			"CustomCardEffects.on_draw",
			"CustomCardEffects.can_attack",
			"CustomCardEffects.can_direct_attack",
			"CustomCardEffects.has_pierce",
			"CustomCardEffects.modify_post_stats",
		]
		for hook in required_hooks:
			self.assertIn(hook, core_blob, f"Missing Core hook: {hook}")
			self.assertIn(hook, joey_blob, f"Missing Joey hook: {hook}")

		# CustomCardEffects.check_win returns -1 (undecided), 0/1 (player), 2 (draw).
		joey_s = (JOEY_DIR / "joey_port_s.gd").read_text(encoding="utf-8")
		self.assertIn("if cw < 0:", joey_s, "Joey f5bc050 must treat check_win() < 0 as undecided")
		core_duel = (CORE_DIR / "duel.gd").read_text(encoding="utf-8")
		self.assertIn("if cw >= 0:", core_duel, "Core winner() must treat check_win() < 0 as undecided")
		self.assertIn("return cw + 1", core_duel, "Core winner() must map 0/1/2 -> 1/2/3")

	def test_lan_and_online_timer_stability(self) -> None:
		lan_path = REPO_ROOT / "game" / "autoload" / "lan.gd"
		normal_duel_path = REPO_ROOT / "game" / "scenes" / "duel" / "normal_duel.gd"
		timer_path = REPO_ROOT / "game" / "core" / "online_turn_timer.gd"
		joey_normal_path = REPO_ROOT / "game" / "scenes" / "duel" / "joey_native_normal.gd"
		joey_adapter_path = REPO_ROOT / "game" / "scenes" / "duel" / "joey_presentation_adapter.gd"

		for path in (lan_path, normal_duel_path, timer_path, joey_normal_path, joey_adapter_path):
			text = path.read_text(encoding="utf-8")
			lines = text.splitlines()
			for lineno, line in enumerate(lines, start=1):
				if not line.strip():
					continue
				leading = line[: len(line) - len(line.lstrip(" \t"))]
				if leading and " " in leading and "\t" in leading:
					self.fail(f"Mixed tabs and spaces at {path.name}:{lineno}")
			stripped = _strip_comments_and_strings(text)
			stack: list[tuple[str, int]] = []
			pairs = {")": "(", "]": "[", "}": "{"}
			cur_line = 1
			for ch in stripped:
				if ch == "\n":
					cur_line += 1
				elif ch in "([{":
					stack.append((ch, cur_line))
				elif ch in ")]}":
					if not stack or stack[-1][0] != pairs[ch]:
						self.fail(f"Unbalanced '{ch}' at {path.name}:{cur_line}")
					stack.pop()
			if stack:
				self.fail(f"Unclosed '{stack[-1][0]}' at {path.name}:{stack[-1][1]}")

		lan_text = lan_path.read_text(encoding="utf-8")
		self.assertIn("0xf043", lan_text, "Lan.COUNTED must include Core ack opcode 0xf043")

		adapter_text = joey_adapter_path.read_text(encoding="utf-8")
		self.assertIn("func f53eda0() -> int:", adapter_text, "JoeyPresentationAdapter must block inherited Core f53eda0")

		normal_text = normal_duel_path.read_text(encoding="utf-8")
		self.assertIn("not (_duel is JoeyPresentationAdapter)", normal_text, "normal_duel must not call Core f53eda0 on Joey")
		self.assertNotIn("Lan.in_flight > 0", normal_text, "Timer must rely on _duel.net_waiting(), not Lan.in_flight")
		self.assertIn("if _dialog_box != null and is_instance_valid(_dialog_box):", normal_text)
		self.assertIn("msg in [0xe5, 0xdc, 0xdd]", normal_text, "Auto-end must pick End Turn (1) on phase menu dialogs")
		self.assertIn("msg == 0xe6", normal_text, "Auto-end must answer Yes (1) on End Turn confirmation 0xe6")
		self.assertIn("_is_action_menu_open()", normal_text, "Auto-end must dismiss open card action menus before ending phase")
		timer_text = timer_path.read_text(encoding="utf-8")
		self.assertIn("OnlineTurnTimer.new()", normal_text, "normal_duel must drive the shared online clock")
		self.assertIn("auto_elapsed >= AUTO_RETRY_SEC", timer_text, "Auto-end must include a deadlock release watchdog")
		self.assertIn("wait_stuck >= STALL_SEC", timer_text, "A paused wait for the opponent must have a cap")
		self.assertIn("opponent_turn_left = maxf(0.0, opponent_turn_left - delta)", timer_text, "The opponent turn clock must be counted locally")
		self.assertIn("_online_resp_auto_decline", normal_text, "Response auto-decline must not mutate engine during presenting")

		step_timer_match = re.search(r"func _step_online_timer\(.*?\n(?=func |\Z)", normal_text, flags=re.S)
		self.assertIsNotNone(step_timer_match)
		self.assertNotIn("_online_step_auto_end(", step_timer_match.group(0), "_step_online_timer must not call _online_step_auto_end directly")

		joey_normal_text = joey_normal_path.read_text(encoding="utf-8")
		self.assertIn("0xa57804", joey_normal_text, "Joey _native_phase_hover must yield while card action menu is open")
		self.assertIn("Lan._poll()", joey_normal_text, "Joey paused network loop must poll Lan before f5bd2d0")

	def test_custom_card_back_import_android_safe(self) -> None:
		settings_path = REPO_ROOT / "game" / "autoload" / "launcher_settings.gd"
		art_path = REPO_ROOT / "game" / "core" / "card_back_art.gd"
		modal_path = REPO_ROOT / "game" / "scenes" / "launcher" / "card_back_modal.gd"

		for path in (settings_path, art_path, modal_path):
			text = path.read_text(encoding="utf-8")
			for lineno, line in enumerate(text.splitlines(), start=1):
				if not line.strip():
					continue
				leading = line[: len(line) - len(line.lstrip(" \t"))]
				if leading and " " in leading and "\t" in leading:
					self.fail(f"Mixed tabs and spaces at {path.name}:{lineno}")
			stripped = _strip_comments_and_strings(text)
			stack: list[tuple[str, int]] = []
			pairs = {")": "(", "]": "[", "}": "{"}
			cur_line = 1
			for ch in stripped:
				if ch == "\n":
					cur_line += 1
				elif ch in "([{":
					stack.append((ch, cur_line))
				elif ch in ")]}":
					if not stack or stack[-1][0] != pairs[ch]:
						self.fail(f"Unbalanced '{ch}' at {path.name}:{cur_line}")
					stack.pop()
			if stack:
				self.fail(f"Unclosed '{stack[-1][0]}' at {path.name}:{stack[-1][1]}")

		settings_text = settings_path.read_text(encoding="utf-8")
		for required in (
			"static func _read_file_bytes(",
			"static func decode_image_bytes(",
			"static func load_image_from_any_path(",
			"load_png_from_buffer",
			"load_jpg_from_buffer",
			"load_webp_from_buffer",
			"load_bmp_from_buffer",
			"save_png_to_buffer",
			"user://custom_card_back.png",
		):
			self.assertIn(required, settings_text, f"Missing {required} in launcher_settings.gd")

		art_text = art_path.read_text(encoding="utf-8")
		self.assertIn("LauncherSettings.load_image_from_any_path", art_text)

		modal_text = modal_path.read_text(encoding="utf-8")
		self.assertIn("image/*", modal_text, "FileDialog must use image/* MIME type for Android SAF gallery compatibility")
		self.assertIn("*/*", modal_text, "FileDialog should include All Files fallback filter")

	def test_custom_effects_visual_sync_prompts_and_race_attr_ids(self) -> None:
		cce_text = (CORE_DIR / "custom_card_effects.gd").read_text(encoding="utf-8")
		ops_text = (CORE_DIR / "custom_duel_ops.gd").read_text(encoding="utf-8")
		m1_text = (CORE_DIR / "custom_effects_monsters_1.gd").read_text(encoding="utf-8")
		m2_text = (CORE_DIR / "custom_effects_monsters_2.gd").read_text(encoding="utf-8")
		traps_text = (CORE_DIR / "custom_effects_traps.gd").read_text(encoding="utf-8")

		# Event builders and flip kind normalization
		for sym in ("func map_core_event(", "func map_joey_event(", "func build_core_ctx(", "func build_joey_ctx("):
			self.assertIn(sym, cce_text)
		self.assertIn('"flip_summon" if kind == "flip"', cce_text)

		# Visual sync pipeline
		self.assertIn("static func sync_visuals(", ops_text)
		self.assertIn('"table_sync"', ops_text)
		table_path = REPO_ROOT / "game/scenes/duel/duel_card_table.gd"
		pres_path = REPO_ROOT / "game/scenes/duel/duel_presentation.gd"
		adapter_path = REPO_ROOT / "game/scenes/duel/joey_presentation_adapter.gd"
		self.assertIn("func sync_from_memory(", table_path.read_text(encoding="utf-8"))
		self.assertIn('"table_sync"', pres_path.read_text(encoding="utf-8"))
		self.assertIn('"table_sync"', adapter_path.read_text(encoding="utf-8"))

		# Core resolution, prompts, summon & battle-destruction hooks
		port_f = (CORE_DIR / "duel_port_f.gd").read_text(encoding="utf-8")
		self.assertIn("f541cb0(0xa15fdc, f5419b0(cp, cz, clast))", port_f)
		self.assertIn("issue((cflags << 15) | 0x78, cz, 0, 0)", port_f)
		self.assertIn("CustomCardEffects.build_core_ctx(", port_f)

		port_h = (CORE_DIR / "duel_port_h.gd").read_text(encoding="utf-8")
		self.assertLess(
			port_h.index("if row < 0 and CustomCardEffects.handles(raw_id):"),
			port_h.index("if (m.u16(e + 2) & 0xfc00) == 0x4400:"),
			"Core f551a40 must evaluate custom cards before native Damage Step allowlist",
		)
		self.assertIn("CustomCardEffects.build_core_ctx(", port_h)

		port_l = (CORE_DIR / "duel_port_l.gd").read_text(encoding="utf-8")
		self.assertIn("if CustomCardEffects.handles(cards.id_of(index) & 0xffff):\n\t\treturn 1", port_l)
		self.assertIn("and not CustomCardEffects.handles(cards.id_of(index) & 0xffff) and (flags & 2) != 0:", port_l)

		port_n = (CORE_DIR / "duel_port_n.gd").read_text(encoding="utf-8")
		self.assertIn('sum_kind = "tribute" if (desc & ((1 << 25) | (1 << 26))) != 0 else "normal"', port_n)
		self.assertIn("CustomCardEffects.on_summon_or_flip(self, p, z, cards.id_of(entry & 0xfff) & 0xffff, sum_kind)", port_n)

		port_m = (CORE_DIR / "duel_port_m.gd").read_text(encoding="utf-8")
		self.assertIn("CustomCardEffects.on_destroyed(self, p, atk_raw, true, false)", port_m)
		self.assertIn("CustomCardEffects.on_destroyed(self, defender, def_raw, true, false)", port_m)
		self.assertIn("CustomDuelOps.LOC_FIELD_SPELL if z + 5 == 10 else CustomDuelOps.LOC_FIELD_ST", port_m)

		# Joey menu, prompts, Damage Step & battle-destruction hooks
		j_zi = (JOEY_DIR / "joey_port_zi.gd").read_text(encoding="utf-8")
		self.assertGreaterEqual(j_zi.count("CustomCardEffects.handles(cards.id_of(card & 0xffff) & 0xffff)"), 4)
		j_zb = (JOEY_DIR / "joey_port_zb.gd").read_text(encoding="utf-8")
		self.assertIn("if CustomCardEffects.handles(cards.id_of(index) & 0xffff):\n\t\treturn 1", j_zb)
		j_y = (JOEY_DIR / "joey_port_y.gd").read_text(encoding="utf-8")
		self.assertIn("CustomCardEffects.build_joey_ctx(", j_y)
		self.assertIn("and not CustomCardEffects.handles(cards.id_of(m.u16(effect)) & 0xffff) and f5683f0(", j_y)
		j_w = (JOEY_DIR / "joey_port_w.gd").read_text(encoding="utf-8")
		self.assertIn("CustomCardEffects.build_joey_ctx(", j_w)
		j_t = (JOEY_DIR / "joey_port_t.gd").read_text(encoding="utf-8")
		self.assertIn("CustomCardEffects.on_destroyed(self, p, atk_raw, true, false)", j_t)
		self.assertIn("CustomCardEffects.on_destroyed(self, other, def_raw, true, false)", j_t)

		# Verify PoC race/attribute ID fixes (Machine=7, Spellcaster=18, Aqua=14, Zombie=2, Insect=10, Plant=13, Fairy=17, LIGHT=1, DARK=2, WATER=3)
		self.assertIn("CustomDuelOps.monster_race(duel, idx_tmp) != 7", m1_text)
		self.assertIn("CustomDuelOps.monster_race(d, idx) == 7 and (CustomDuelOps.base_atk(d, idx) == 2100", m1_text)
		self.assertIn("18 if cid == 2635 else 15", m1_text)
		self.assertIn("CustomDuelOps.monster_attr(duel, def_idx) == 2 and CustomDuelOps.monster_race(duel, def_idx) == 3", m1_text)
		self.assertIn("CustomDuelOps.monster_attr(duel, idx) != 1", m1_text)
		self.assertIn("CustomDuelOps.monster_race(duel, idx) == 14 and CustomDuelOps.monster_level(duel, idx) == 10", m1_text)

		self.assertIn("_collect_attr_indices_in_gy(duel, p, 3)", m2_text)
		self.assertIn("_collect_attr_indices_in_gy(duel, p, 1)", m2_text)
		self.assertNotIn("CustomDuelOps.monster_race(d, idx) == 4", m2_text)
		self.assertNotIn("CustomDuelOps.monster_race(d, idx) == 9", m2_text)
		self.assertNotIn("CustomDuelOps.monster_race(d, idx) == 7", m2_text)
		self.assertIn('if kind == "normal" or kind == "tribute" or kind == "normal_summon":', m2_text)

		# Trap event matching accepts normal_summon and damage_step
		self.assertIn('(ev == "summon" or ev == "normal_summon")', traps_text)
		self.assertIn('(ev == "damage_calc" or ev == "damage_step")', traps_text)

	def test_original_cards_protected_and_field_visual_fallback(self) -> None:
		cce_text = (CORE_DIR / "custom_card_effects.gd").read_text(encoding="utf-8")
		self.assertIn("if cid < 2500:\n\t\treturn overrides(cid)", cce_text)
		self.assertIn("const NATIVE_OVERRIDES: Array[int] = [1532]", cce_text)

		fv_path = REPO_ROOT / "game/scenes/duel/duel_field_visual.gd"
		fv_text = fv_path.read_text(encoding="utf-8")
		self.assertIn("static func banner_texture_for(", fv_text)
		self.assertIn('"fie_normal"', fv_text)
		self.assertIn("banner_texture_for(game, id)", fv_text)
		self.assertIn('for fallback_game: String in ["joey", "kaiba", "yugi"]:', fv_text)

	def test_deck_persistence_cross_pack_and_unicode_names(self) -> None:
		save_path = REPO_ROOT / "game/autoload/save_data.gd"
		dlg_path = REPO_ROOT / "game/scenes/deck_editor/deck_file_dialog.gd"
		ed_path = REPO_ROOT / "game/scenes/deck_editor/deck_editor.gd"
		fv_path = REPO_ROOT / "game/scenes/duel/duel_field_visual.gd"
		table_path = REPO_ROOT / "game/scenes/duel/duel_card_table.gd"
		pres_path = REPO_ROOT / "game/scenes/duel/duel_presentation.gd"

		for path in (save_path, dlg_path, ed_path, fv_path, table_path, pres_path):
			text = path.read_text(encoding="utf-8")
			for lineno, line in enumerate(text.splitlines(), start=1):
				if not line.strip():
					continue
				leading = line[: len(line) - len(line.lstrip(" \t"))]
				if leading and " " in leading and "\t" in leading:
					self.fail(f"Mixed tabs and spaces at {path.name}:{lineno}")
			stripped = _strip_comments_and_strings(text)
			stack: list[tuple[str, int]] = []
			pairs = {")": "(", "]": "[", "}": "{"}
			cur_line = 1
			for ch in stripped:
				if ch == "\n":
					cur_line += 1
				elif ch in "([{":
					stack.append((ch, cur_line))
				elif ch in ")]}":
					if not stack or stack[-1][0] != pairs[ch]:
						self.fail(f"Unbalanced '{ch}' at {path.name}:{cur_line}")
					stack.pop()
			if stack:
				self.fail(f"Unclosed '{stack[-1][0]}' at {path.name}:{stack[-1][1]}")

		save_text = save_path.read_text(encoding="utf-8")
		self.assertIn('preload("res://core/native_deck_import.gd").filter(', save_text)
		self.assertIn("_startup_checked[game] = true", save_text)

		dlg_text = dlg_path.read_text(encoding="utf-8")
		self.assertIn("const FORBIDDEN :=", dlg_text)
		self.assertNotIn('(c >= "a" and c <= "z")', dlg_text)

		ed_text = ed_path.read_text(encoding="utf-8")
		self.assertIn("SaveData.set_deck(game, _deck.duplicate(true))", ed_text)
		self.assertGreaterEqual(ed_text.count("_autosave_deck()"), 4)

	def test_joey_startup_and_custom_effect_animations(self) -> None:
		joey_normal_text = (REPO_ROOT / "game/scenes/duel/joey_native_normal.gd").read_text(encoding="utf-8")
		self.assertIn('Duel.create(Paths.data_dir, "kaiba")', joey_normal_text)
		self.assertIn('fallback.rules_game = "joey"', joey_normal_text)

		ops_text = (CORE_DIR / "custom_duel_ops.gd").read_text(encoding="utf-8")
		self.assertIn("static func _present(", ops_text)
		self.assertIn('_present(duel, "move", {', ops_text)
		self.assertIn('_present(duel, "special", {', ops_text)
		self.assertIn('_present(duel, "flip", {', ops_text)

		cce_text = (CORE_DIR / "custom_card_effects.gd").read_text(encoding="utf-8")
		self.assertIn('CustomDuelOps._present(duel, "card_effect"', cce_text)
		self.assertIn('ctx["target_link"]', cce_text)
		self.assertIn('ctx["target_card_id"]', cce_text)


if __name__ == "__main__":
	unittest.main()
