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
		self.assertEqual(len(self.cards), 630)
		self.assertEqual(set(self.by_id.keys()), set(range(2500, 3130)))

		custom = [c for c in self.cards if c.get("custom_effect")]
		normal = [c for c in self.cards if not c.get("custom_effect")]
		self.assertEqual(len(custom), 589)
		self.assertEqual(len(normal), 41)

		traps = [c for c in custom if c["category"] == "trap"]
		spells = [c for c in custom if c["category"] == "spell"]
		m1 = [c for c in custom if c["category"] == "monster" and c["internal_id"] < 2800]
		m2 = [c for c in custom if c["category"] == "monster" and c["internal_id"] >= 2800]
		self.assertEqual(len(traps), 97)
		self.assertEqual(len(spells), 146)
		self.assertEqual(len(m1), 184)
		self.assertEqual(len(m2), 162)

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

	def test_all_589_custom_ids_registered_and_implemented(self) -> None:
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

		self.assertEqual(len(union_ids), 589)

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
		joey_normal_path = REPO_ROOT / "game" / "scenes" / "duel" / "joey_native_normal.gd"
		joey_adapter_path = REPO_ROOT / "game" / "scenes" / "duel" / "joey_presentation_adapter.gd"

		for path in (lan_path, normal_duel_path, joey_normal_path, joey_adapter_path):
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
		self.assertIn("_online_auto_elapsed >= 6.0", normal_text, "Auto-end must include a deadlock release watchdog")
		self.assertIn("_online_resp_auto_decline", normal_text, "Response auto-decline must not mutate engine during presenting")

		step_timer_match = re.search(r"func _step_online_timer\(.*?\n(?=func |\Z)", normal_text, flags=re.S)
		self.assertIsNotNone(step_timer_match)
		self.assertNotIn("_online_step_auto_end(", step_timer_match.group(0), "_step_online_timer must not call _online_step_auto_end directly")

		joey_normal_text = joey_normal_path.read_text(encoding="utf-8")
		self.assertIn("0xa57804", joey_normal_text, "Joey _native_phase_hover must yield while card action menu is open")
		self.assertIn("Lan._poll()", joey_normal_text, "Joey paused network loop must poll Lan before f5bd2d0")


if __name__ == "__main__":
	unittest.main()
