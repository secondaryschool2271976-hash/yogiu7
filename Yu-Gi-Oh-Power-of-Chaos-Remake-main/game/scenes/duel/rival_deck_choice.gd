class_name RivalDeckChoice
extends RefCounted
## Tablas y ramas nativas: Kaiba 438210; Joey 44bbe0.
## `draw` es el MT de interfaz; separado para comprobar cada rama y sus tiradas.

const KAIBA := [
	["kaiba_j", "kaiba_jj", "kaiba_gensaku", "kaiba_equip", "kaiba_hand", "kaiba_fusion", "kaiba_deck", "kaiba_blueeyes", "kaiba_inifu", "kaiba_dragon", "kaiba_k", "kaiba_kk", "kaiba_kkk"],
	["kaiba_deck", "kaiba_inifu", "yk_bokori", "yk_kongo", "yk_counter", "kaiba_fusion", "kaiba_blueeyes", "kaiba_equip", "kaiba_kkk", "kaiba_kk", "yk_k", "yk_kk", "yk_kkk"],
]
const JOEY_CPU := [[0, 1, 2, 3, 4], [3, 4, 10, 11, 12], [10, 11, 12, 13, 14], [13, 14, 15, 20, 21], [20, 21, 22, 23, 24], [23, 24, 25, 26, 27], [25, 26, 27, 28, 29]]
const JOEY_FULL := [
	["0ge1", "0umi", "0val"],
	["1dec", "1red", "1too", "1ins", "1uij", "1umi", "1val"],
	["1fus", "1gam", "1ge1", "1ge2", "1hik", "1mix"],
	["2dec", "2val", "2too", "2ge1", "2hik", "2ins", "2uij"],
	["2fus", "2gam", "2ge2", "2mix", "2red", "2umi"],
	["3all", "3dec", "3yam", "3fus", "3too", "3hnd"],
	["3all", "3dec", "3exo", "3fus", "3grv", "3hnd"],
]


static func kaiba(pct: int, last: int, run: int, mixed: bool, draw: Callable) -> String:
	var pool: Array = KAIBA[int(mixed)]
	var index := -1
	if pct < 40:
		if last == 2 and run >= 2 and (int(draw.call()) & 1) == 0:
			index = 1
		if last == 1:
			if run > 5 and int(draw.call()) % 3 == 0:
				index = 10
			elif run > 3 and (int(draw.call()) & 3) == 0:
				index = 10
	elif pct < 65:
		if last == 2 and run >= 3 and int(draw.call()) % 3 == 0:
			index = int(draw.call()) & 1
		if last == 1:
			if run > 5 and (int(draw.call()) & 1) == 0:
				index = 11 + (int(draw.call()) & 1)
			elif run > 3 and int(draw.call()) % 3 == 0:
				index = 10 + (int(draw.call()) & 1)
	elif pct < 85:
		if last == 2 and run >= 3 and int(draw.call()) % 3 == 0:
			index = 1
		if last == 1:
			if run > 4 and (int(draw.call()) & 1) == 0:
				index = 11 + (int(draw.call()) & 1)
			elif run > 2 and int(draw.call()) % 3 == 0:
				index = 11 + (int(draw.call()) & 1)
	else:
		index = 2 + int(draw.call()) % (10 + int(mixed))
	if index < 0:
		index = 2 + (int(draw.call()) & 7)
	return "kaiba/file/%s.json" % pool[index]


static func joey(level: int, mixed: bool, draw: Callable) -> String:
	if not mixed:
		return "joey/file/cpu_%03d.json" % JOEY_CPU[clampi(level, 1, 7) - 1][int(draw.call()) % 5]
	var pool: Array = JOEY_FULL[clampi(level + 2, 3, 9) - 3]
	return "joey/file/ful_%s.json" % pool[int(draw.call()) % pool.size()]


## 446df0; tablas DWORD 5daf40 y 5daf64. El match solo cambia nivel al decidirse.
## FF inicial: 446f43 lee sin signo; tablas solapadas PE5db360/5db368.
const JOEY_INITIAL_LOSS_THRESHOLDS := {255: 4530096, 257: 4206720}

static func joey_after_result(level: int, mixed: bool, last: int, run: int, decided: bool) -> Vector2i:
	if not decided:
		return Vector2i(level, run)
	var offset := int(mixed) * 2
	var effective := maxi(1, (level & 255) + offset)
	if last == 1:
		if effective < (9 if mixed else 7) and run >= [0, 3, 4, 5, 5, 5, 6, 6, 7][effective]:
			return Vector2i(effective - offset + 1, 0)
	elif effective > offset + 1:
		var thresholds := [0, 0, 3, 4, 4, 4, 4, 3, 2, 2]
		var threshold: int = thresholds[effective] if effective < thresholds.size() else JOEY_INITIAL_LOSS_THRESHOLDS[effective]
		if run >= threshold: return Vector2i((effective - offset - 1) & 255, 0)
	return Vector2i(level, run)


## Ready-made preset decks per character (using each edition's official PCK decks).
const PRESET_DECKS := {
	"yugi": [
		{"path": "yugi/file/starter_deck.json", "tier": "easy", "rival": false, "ar": "مجموعة البداية (يوغي)", "es": "Mazo Inicial (Yugi)", "en": "Yugi Starter Deck"},
		{"path": "yugi/file/cpujj.json", "tier": "easy", "rival": true, "ar": "يوغي المبتدئ 1 (سهل)", "es": "Yugi Principiante 1 (Fácil)", "en": "Beginner Yugi 1 (Easy)"},
		{"path": "yugi/file/cpuj.json", "tier": "easy", "rival": true, "ar": "يوغي المبتدئ 2 (سهل)", "es": "Yugi Principiante 2 (Fácil)", "en": "Beginner Yugi 2 (Easy)"},
		{"path": "yugi/file/cpu01.json", "tier": "normal", "rival": true, "ar": "يوغي الكلاسيكي 1 (متوسط)", "es": "Yugi Clásico 1 (Normal)", "en": "Classic Yugi 1 (Normal)"},
		{"path": "yugi/file/cpu02.json", "tier": "normal", "rival": true, "ar": "يوغي الكلاسيكي 2 (متوسط)", "es": "Yugi Clásico 2 (Normal)", "en": "Classic Yugi 2 (Normal)"},
		{"path": "yugi/file/cpu03.json", "tier": "normal", "rival": true, "ar": "يوغي الكلاسيكي 3 (متوسط)", "es": "Yugi Clásico 3 (Normal)", "en": "Classic Yugi 3 (Normal)"},
		{"path": "yugi/file/cpu04.json", "tier": "normal", "rival": true, "ar": "يوغي الكلاسيكي 4 (متوسط)", "es": "Yugi Clásico 4 (Normal)", "en": "Classic Yugi 4 (Normal)"},
		{"path": "yugi/file/cpuk.json", "tier": "hard", "rival": true, "ar": "يوغي المحترف · ساحر الظلام (صعب)", "es": "Yugi Pro · Mago Oscuro (Difícil)", "en": "Pro Yugi · Dark Magician (Hard)"},
		{"path": "yugi/file/cpukk.json", "tier": "expert", "rival": true, "ar": "يوغي الأسطوري · أقصى قوة (أسطوري)", "es": "Yugi Maestro · Poder Máximo (Experto)", "en": "Master Yugi · Max Power (Expert)"},
	],
	"kaiba": [
		{"path": "kaiba/file/starter_deck.json", "tier": "easy", "rival": false, "ar": "مجموعة البداية (كايبا)", "es": "Mazo Inicial (Kaiba)", "en": "Kaiba Starter Deck"},
		{"path": "kaiba/file/kaiba_j.json", "tier": "easy", "rival": true, "ar": "كايبا المبتدئ 1 (سهل)", "es": "Kaiba Principiante 1 (Fácil)", "en": "Beginner Kaiba 1 (Easy)"},
		{"path": "kaiba/file/kaiba_jj.json", "tier": "easy", "rival": true, "ar": "كايبا المبتدئ 2 (سهل)", "es": "Kaiba Principiante 2 (Fácil)", "en": "Beginner Kaiba 2 (Easy)"},
		{"path": "kaiba/file/kaiba_gensaku.json", "tier": "normal", "rival": true, "ar": "كايبا الأنمي الأصلي (متوسط)", "es": "Kaiba Anime Original (Normal)", "en": "Anime Kaiba Deck (Normal)"},
		{"path": "kaiba/file/kaiba_blueeyes.json", "tier": "normal", "rival": true, "ar": "التنين الأبيض أزرق العينين (متوسط)", "es": "Dragón Blanco de Ojos Azules (Normal)", "en": "Blue-Eyes White Dragon (Normal)"},
		{"path": "kaiba/file/kaiba_dragon.json", "tier": "normal", "rival": true, "ar": "مجموعة التنانين (متوسط)", "es": "Mazo de Dragones (Normal)", "en": "Dragon Power Deck (Normal)"},
		{"path": "kaiba/file/kaiba_fusion.json", "tier": "normal", "rival": true, "ar": "مجموعة الانصهار (متوسط)", "es": "Mazo de Fusión (Normal)", "en": "Kaiba Fusion Deck (Normal)"},
		{"path": "kaiba/file/kaiba_equip.json", "tier": "normal", "rival": true, "ar": "مجموعة التجهيز والهجوم (متوسط)", "es": "Mazo de Equipo (Normal)", "en": "Equip Beatdown Deck (Normal)"},
		{"path": "kaiba/file/kaiba_hand.json", "tier": "hard", "rival": true, "ar": "تدمير اليد (صعب)", "es": "Destrucción de Mano (Difícil)", "en": "Hand Destruction (Hard)"},
		{"path": "kaiba/file/kaiba_k.json", "tier": "hard", "rival": true, "ar": "كايبا المحترف 1 (صعب)", "es": "Kaiba Pro 1 (Difícil)", "en": "Pro Kaiba 1 (Hard)"},
		{"path": "kaiba/file/kaiba_kk.json", "tier": "hard", "rival": true, "ar": "كايبا المحترف 2 (صعب)", "es": "Kaiba Pro 2 (Difícil)", "en": "Pro Kaiba 2 (Hard)"},
		{"path": "kaiba/file/kaiba_kkk.json", "tier": "expert", "rival": true, "ar": "كايبا الأسطوري (أسطوري)", "es": "Kaiba Maestro (Experto)", "en": "Master Kaiba (Expert)"},
		{"path": "kaiba/file/yk_kkk.json", "tier": "expert", "rival": true, "ar": "كايبا النهائي · يوغي+كايبا (أسطوري)", "es": "Kaiba Definitivo · Y+K (Experto)", "en": "Ultimate Kaiba · Y+K (Expert)"},
	],
	"joey": [
		{"path": "joey/file/starter_deck.json", "tier": "easy", "rival": false, "ar": "مجموعة البداية (جوي)", "es": "Mazo Inicial (Joey)", "en": "Joey Starter Deck"},
		{"path": "joey/file/cpu_000.json", "tier": "easy", "rival": true, "ar": "جوي المبتدئ · مستوى 1 (سهل)", "es": "Joey Principiante · Nv.1 (Fácil)", "en": "Beginner Joey · Lv.1 (Easy)"},
		{"path": "joey/file/ful_0ge1.json", "tier": "easy", "rival": true, "ar": "جوي الأساسي (سهل)", "es": "Joey Básico (Fácil)", "en": "Basic Joey Deck (Easy)"},
		{"path": "joey/file/ful_1red.json", "tier": "normal", "rival": true, "ar": "التنين الأحمر أسود العينين 1 (متوسط)", "es": "Ojos Rojos 1 (Normal)", "en": "Red-Eyes Deck 1 (Normal)"},
		{"path": "joey/file/ful_2red.json", "tier": "normal", "rival": true, "ar": "التنين الأحمر المتطور (متوسط)", "es": "Ojos Rojos Avanzado (Normal)", "en": "Red-Eyes Advanced (Normal)"},
		{"path": "joey/file/ful_2too.json", "tier": "normal", "rival": true, "ar": "عالم الكرتون · Toon World (متوسط)", "es": "Mundo Toon (Normal)", "en": "Toon World Deck (Normal)"},
		{"path": "joey/file/ful_2fus.json", "tier": "normal", "rival": true, "ar": "مجموعة الانصهار (متوسط)", "es": "Mazo de Fusión (Normal)", "en": "Fusion Deck (Normal)"},
		{"path": "joey/file/ful_2gam.json", "tier": "normal", "rival": true, "ar": "الحظ والنرد (متوسط)", "es": "Suerte y Dados (Normal)", "en": "Gamble & Luck Deck (Normal)"},
		{"path": "joey/file/ful_3fus.json", "tier": "hard", "rival": true, "ar": "انصهار المحترفين (صعب)", "es": "Fusión Maestra (Difícil)", "en": "Master Fusion (Hard)"},
		{"path": "joey/file/ful_3yam.json", "tier": "hard", "rival": true, "ar": "الظلام والشياطين (صعب)", "es": "Oscuridad y Demonios (Difícil)", "en": "Dark & Fiend (Hard)"},
		{"path": "joey/file/ful_3dec.json", "tier": "hard", "rival": true, "ar": "تدمير المجموعة (صعب)", "es": "Destrucción de Mazo (Difícil)", "en": "Deck Destruction (Hard)"},
		{"path": "joey/file/ful_3hnd.json", "tier": "expert", "rival": true, "ar": "السيطرة على اليد (أسطوري)", "es": "Control de Mano (Experto)", "en": "Hand Control (Expert)"},
		{"path": "joey/file/ful_3grv.json", "tier": "expert", "rival": true, "ar": "استدعاء المقبرة (أسطوري)", "es": "Resurrección del Cementerio (Experto)", "en": "Graveyard Revival (Expert)"},
		{"path": "joey/file/ful_3exo.json", "tier": "expert", "rival": true, "ar": "إكسوديا المحظور (أسطوري)", "es": "Exodia el Prohibido (Experto)", "en": "Exodia the Forbidden (Expert)"},
		{"path": "joey/file/ful_3all.json", "tier": "expert", "rival": true, "ar": "جوي الأسطوري · أقصى قوة (أسطوري)", "es": "Joey Maestro · Todas las Cartas (Experto)", "en": "All-Star Master Joey (Expert)"},
	],
}


static func available_presets(game: String, rival_only := false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var list: Array = PRESET_DECKS.get(game, [])
	for raw_entry: Variant in list:
		if not (raw_entry is Dictionary):
			continue
		var entry: Dictionary = raw_entry
		if rival_only and not bool(entry.get("rival", true)):
			continue
		var path := str(entry.get("path", ""))
		if path != "" and Assets.exists(path):
			out.append(entry)
	return out


static func pick_by_difficulty(game: String, difficulty: String, draw: Callable) -> String:
	var pool: Array[String] = []
	for entry: Dictionary in available_presets(game, true):
		if str(entry.get("tier", "")) == difficulty:
			pool.append(str(entry["path"]))
	if pool.is_empty():
		for entry: Dictionary in available_presets(game, true):
			pool.append(str(entry["path"]))
	if pool.is_empty():
		return ""
	return pool[posmod(int(draw.call()), pool.size())]
