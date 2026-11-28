from __future__ import annotations

import json
import pathlib
import re
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
EXTRA_CARDS_JSON = REPO_ROOT / "game/assets/cards/extra_cards.json"
CORE_DIR = REPO_ROOT / "game/duel/core"
JOEY_DIR = REPO_ROOT / "game/duel/joey"

DUEL_FILES = [
	CORE_DIR / "custom_duel_ops.gd",
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

REMOVED_CUSTOM_LAYER = [
	CORE_DIR / "custom_card_effects.gd",
	CORE_DIR / "custom_effects_traps.gd",
	CORE_DIR / "custom_effects_spells.gd",
	CORE_DIR / "custom_effects_monsters_1.gd",
	CORE_DIR / "custom_effects_monsters_2.gd",
	CORE_DIR / "extra_card_effects.gd",
]

CUSTOM_LAYER_SYMBOLS = (
	r"\b(CustomCardEffects|CustomEffectsTraps|CustomEffectsSpells"
	r"|CustomEffectsMonsters1|CustomEffectsMonsters2|ExtraCardEffects)\b"
)


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


def _extract_symbols(path: pathlib.Path) -> tuple[set[str], set[str]]:
	text = path.read_text(encoding="utf-8")
	funcs = set(re.findall(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M))
	consts = set(re.findall(r"^const\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, re.M))
	vars_ = set(re.findall(r"^(?:static\s+)?var\s+([A-Za-z_][A-Za-z0-9_]*)\b", text, re.M))
	return funcs, consts | vars_


class TestEngineAndCardData(unittest.TestCase):
	@classmethod
	def setUpClass(cls) -> None:
		cls.payload = json.loads(EXTRA_CARDS_JSON.read_text(encoding="utf-8"))

	def test_extra_pack_carries_no_custom_cards(self) -> None:
		# This branch keeps only the original game cards: the extra pack is empty and the file
		# survives solely for the original-card artwork map it also carries.
		self.assertEqual(self.payload["cards"], [])
		self.assertGreater(len(self.payload.get("original_art", {})), 0)

	def test_custom_card_layer_is_gone(self) -> None:
		for path in REMOVED_CUSTOM_LAYER:
			self.assertFalse(path.exists(), f"Custom card layer file still present: {path.name}")
		for path in sorted(REPO_ROOT.joinpath("game").rglob("*.gd")) + sorted(
			REPO_ROOT.joinpath("tools").rglob("*.py")
		):
			if path == pathlib.Path(__file__):
				continue
			stripped = _strip_comments_and_strings(path.read_text(encoding="utf-8"))
			match = re.search(CUSTOM_LAYER_SYMBOLS, stripped)
			self.assertIsNone(
				match,
				f"Reference to the removed custom card layer in {path.relative_to(REPO_ROOT)}",
			)

	def test_gdscript_static_syntax_and_style(self) -> None:
		for path in DUEL_FILES:
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
		funcs, consts = _extract_symbols(CORE_DIR / "custom_duel_ops.gd")
		symbols = funcs | consts
		pattern = re.compile(r"\bCustomDuelOps\.([A-Za-z_][A-Za-z0-9_]*)")
		for path in sorted(REPO_ROOT.joinpath("game").rglob("*.gd")):
			if path.name == "custom_duel_ops.gd":
				continue
			stripped = _strip_comments_and_strings(path.read_text(encoding="utf-8"))
			for sym in pattern.findall(stripped):
				self.assertIn(
					sym,
					symbols,
					f"Unresolved reference CustomDuelOps.{sym} in {path.relative_to(REPO_ROOT)}",
				)

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

	def test_card_back_import_android_safe(self) -> None:
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

	def test_field_visual_fallback(self) -> None:
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

	def test_joey_startup_and_effect_animations(self) -> None:
		joey_normal_text = (REPO_ROOT / "game/scenes/duel/joey_native_normal.gd").read_text(encoding="utf-8")
		self.assertIn('Duel.create(Paths.data_dir, "kaiba")', joey_normal_text)
		self.assertIn('fallback.rules_game = "joey"', joey_normal_text)

		ops_text = (CORE_DIR / "custom_duel_ops.gd").read_text(encoding="utf-8")
		self.assertIn("static func _present(", ops_text)
		self.assertIn('_present(duel, "move", {', ops_text)
		self.assertIn('_present(duel, "special", {', ops_text)
		self.assertIn('_present(duel, "flip", {', ops_text)


if __name__ == "__main__":
	unittest.main()
