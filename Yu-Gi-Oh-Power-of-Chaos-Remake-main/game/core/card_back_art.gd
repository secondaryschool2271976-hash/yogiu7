class_name CardBackArt
extends RefCounted
## Generates crisp preset card-back textures (200x290 full, 50x72 mini) and loads user custom card backs.

const FULL_SIZE := Vector2i(200, 290)
const MINI_SIZE := Vector2i(50, 72)

const IMAGE_PRESETS := {
	"anime_classic": "res://assets/card_backs/anime_classic.jpg",
	"ember_burst": "res://assets/card_backs/ember_burst.jpg",
	"ocg_crimson_portal": "res://assets/card_backs/ocg_crimson_portal.jpg",
	"shadow_obsidian": "res://assets/card_backs/shadow_obsidian.jpg",
	"crimson_abyss": "res://assets/card_backs/crimson_abyss.jpg",
	"crimson_dragon": "res://assets/card_backs/crimson_dragon.jpg",
	"arcane_gold_violet": "res://assets/card_backs/arcane_gold_violet.jpg",
}

const PRESETS := {
	"yugi_edition": {
		"border": Color(0.08, 0.04, 0.12),
		"rim": Color(0.95, 0.78, 0.28),
		"frame_a": Color(0.38, 0.16, 0.56),
		"frame_b": Color(0.18, 0.07, 0.30),
		"inner_rim": Color(0.98, 0.85, 0.38),
		"vortex_outer": Color(0.54, 0.18, 0.68),
		"vortex_mid": Color(0.24, 0.07, 0.36),
		"vortex_core": Color(0.06, 0.02, 0.10),
		"glow": Color(1.0, 0.84, 0.34),
		"emblem": "yugi",
	},
	"kaiba_edition": {
		"border": Color(0.04, 0.07, 0.13),
		"rim": Color(0.76, 0.90, 1.0),
		"frame_a": Color(0.14, 0.34, 0.62),
		"frame_b": Color(0.06, 0.15, 0.34),
		"inner_rim": Color(0.42, 0.88, 1.0),
		"vortex_outer": Color(0.18, 0.54, 0.88),
		"vortex_mid": Color(0.07, 0.22, 0.46),
		"vortex_core": Color(0.02, 0.05, 0.14),
		"glow": Color(0.62, 0.94, 1.0),
		"emblem": "kaiba",
	},
	"joey_edition": {
		"border": Color(0.12, 0.04, 0.03),
		"rim": Color(0.96, 0.66, 0.24),
		"frame_a": Color(0.56, 0.15, 0.10),
		"frame_b": Color(0.28, 0.06, 0.04),
		"inner_rim": Color(1.0, 0.78, 0.34),
		"vortex_outer": Color(0.74, 0.20, 0.12),
		"vortex_mid": Color(0.36, 0.07, 0.04),
		"vortex_core": Color(0.09, 0.02, 0.01),
		"glow": Color(1.0, 0.54, 0.20),
		"emblem": "joey",
	},
	"gold_millennium": {
		"border": Color(0.11, 0.08, 0.04),
		"rim": Color(0.92, 0.74, 0.28),
		"frame_a": Color(0.42, 0.27, 0.09),
		"frame_b": Color(0.24, 0.14, 0.04),
		"inner_rim": Color(0.96, 0.84, 0.44),
		"vortex_outer": Color(0.56, 0.34, 0.08),
		"vortex_mid": Color(0.28, 0.14, 0.03),
		"vortex_core": Color(0.07, 0.04, 0.02),
		"glow": Color(1.0, 0.86, 0.38),
	},
	"dark_violet": {
		"border": Color(0.07, 0.05, 0.12),
		"rim": Color(0.76, 0.56, 0.96),
		"frame_a": Color(0.26, 0.12, 0.44),
		"frame_b": Color(0.12, 0.06, 0.22),
		"inner_rim": Color(0.90, 0.76, 0.42),
		"vortex_outer": Color(0.38, 0.16, 0.62),
		"vortex_mid": Color(0.16, 0.06, 0.30),
		"vortex_core": Color(0.04, 0.02, 0.08),
		"glow": Color(0.78, 0.52, 1.0),
	},
	"blue_eyes": {
		"border": Color(0.04, 0.08, 0.16),
		"rim": Color(0.45, 0.84, 1.0),
		"frame_a": Color(0.10, 0.28, 0.56),
		"frame_b": Color(0.05, 0.13, 0.30),
		"inner_rim": Color(0.84, 0.94, 1.0),
		"vortex_outer": Color(0.16, 0.48, 0.82),
		"vortex_mid": Color(0.06, 0.20, 0.42),
		"vortex_core": Color(0.02, 0.05, 0.12),
		"glow": Color(0.48, 0.90, 1.0),
	},
	"crimson_egyptian": {
		"border": Color(0.12, 0.03, 0.04),
		"rim": Color(0.92, 0.72, 0.30),
		"frame_a": Color(0.50, 0.09, 0.11),
		"frame_b": Color(0.24, 0.04, 0.05),
		"inner_rim": Color(0.98, 0.82, 0.40),
		"vortex_outer": Color(0.66, 0.12, 0.14),
		"vortex_mid": Color(0.30, 0.04, 0.06),
		"vortex_core": Color(0.06, 0.01, 0.02),
		"glow": Color(1.0, 0.46, 0.28),
	},
	"obsidian_cyan": {
		"border": Color(0.03, 0.04, 0.07),
		"rim": Color(0.24, 0.84, 0.96),
		"frame_a": Color(0.08, 0.12, 0.20),
		"frame_b": Color(0.04, 0.06, 0.11),
		"inner_rim": Color(0.92, 0.76, 0.34),
		"vortex_outer": Color(0.10, 0.34, 0.46),
		"vortex_mid": Color(0.05, 0.14, 0.22),
		"vortex_core": Color(0.02, 0.03, 0.06),
		"glow": Color(0.30, 0.92, 1.0),
	},
}

static var _cache := {}


static func invalidate_cache() -> void:
	_cache.clear()


static func label_for(style: String, lang: String) -> String:
	var ar := lang == "a"
	var es := lang == "s"
	match style:
		"classic":
			return "الأصلية (كلاسيك)" if ar else ("Clásico (Original)" if es else "Classic (Original)")
		"anime_classic":
			return "كلاسيك الأنمي" if ar else ("Clásico Anime" if es else "Anime Classic")
		"ember_burst":
			return "انفجار اللهب" if ar else ("Explosión Ígnea" if es else "Ember Burst")
		"ocg_crimson_portal":
			return "بوابة الظل اليابانية (OCG)" if ar else ("Portal Carmesí OCG" if es else "OCG Crimson Portal")
		"shadow_obsidian":
			return "دوامة الظل القوطي" if ar else ("Vórtice Sombra Gótica" if es else "Gothic Shadow Vortex")
		"crimson_abyss":
			return "هاوية القرمزي" if ar else ("Abismo Carmesí" if es else "Crimson Abyss")
		"crimson_dragon":
			return "التنين القرمزي" if ar else ("Dragón Carmesí" if es else "Crimson Dragon")
		"arcane_gold_violet":
			return "الدوامة الذهبية السحرية" if ar else ("Vórtice Arcano Dorado" if es else "Arcane Gold Vortex")
		"yugi_edition":
			return "خلفية يوغي" if ar else ("Edición Yugi" if es else "Yugi Edition")
		"kaiba_edition":
			return "خلفية كايبا" if ar else ("Edición Kaiba" if es else "Kaiba Edition")
		"joey_edition":
			return "خلفية جوي" if ar else ("Edición Joey" if es else "Joey Edition")
		"gold_millennium":
			return "الألفية الذهبية" if ar else ("Milenio Dorado" if es else "Millennium Gold")
		"dark_violet":
			return "الساحر الداكن" if ar else ("Violeta Oscuro" if es else "Dark Violet")
		"blue_eyes":
			return "التنين الأزرق" if ar else ("Azul Real" if es else "Royal Azure")
		"crimson_egyptian":
			return "الأحمر الفرعوني" if ar else ("Carmesí Egipcio" if es else "Egyptian Crimson")
		"obsidian_cyan":
			return "الظلام الملكي" if ar else ("Obsidiana Cian" if es else "Obsidian Cyan")
		"custom":
			return "صورة مخصصة" if ar else ("Imagen personalizada" if es else "Custom Image")
	return style


static func get_texture(style: String, mini := false) -> Texture2D:
	if style == "classic" or style == "":
		return null
	var key := "%s:%s" % [style, "mini" if mini else "full"]
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	if style == "custom":
		tex = _load_custom_texture(mini)
	elif IMAGE_PRESETS.has(style):
		tex = _load_image_preset_texture(style, mini)
	elif PRESETS.has(style):
		tex = _build_preset_texture(style, mini)
	if tex != null:
		_cache[key] = tex
	return tex


static func _load_image_preset_texture(style: String, mini: bool) -> Texture2D:
	var full_key := "%s:full" % style
	var full_img: Image = null
	if _cache.has(full_key) and _cache[full_key] is Texture2D:
		full_img = (_cache[full_key] as Texture2D).get_image()
	if full_img == null:
		var res_path := str(IMAGE_PRESETS.get(style, ""))
		if res_path == "":
			return null
		if ResourceLoader.exists(res_path):
			var loaded: Resource = load(res_path)
			if loaded is Texture2D:
				full_img = (loaded as Texture2D).get_image()
		if (full_img == null or full_img.is_empty()) and FileAccess.file_exists(res_path):
			var bytes := FileAccess.get_file_as_bytes(res_path)
			if not bytes.is_empty():
				var decoded := Image.new()
				if decoded.load_jpg_from_buffer(bytes) == OK or decoded.load_png_from_buffer(bytes) == OK:
					full_img = decoded
		if full_img == null or full_img.is_empty():
			return null
		full_img = full_img.duplicate() as Image
		if full_img.is_compressed():
			full_img.decompress()
		if full_img.get_width() != FULL_SIZE.x or full_img.get_height() != FULL_SIZE.y:
			full_img.resize(FULL_SIZE.x, FULL_SIZE.y, Image.INTERPOLATE_LANCZOS)
		_cache[full_key] = ImageTexture.create_from_image(full_img)
	if not mini:
		return _cache[full_key]
	var mini_img := full_img.duplicate() as Image
	if mini_img.is_compressed():
		mini_img.decompress()
	mini_img.resize(MINI_SIZE.x, MINI_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(mini_img)


static func _load_custom_texture(mini: bool) -> Texture2D:
	if not is_instance_valid(LauncherSettings):
		return null
	var path: String = LauncherSettings.custom_card_back_path()
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	var target := MINI_SIZE if mini else FULL_SIZE
	if img.get_width() != target.x or img.get_height() != target.y:
		img.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS if not mini else Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


static func _build_preset_texture(style: String, mini: bool) -> Texture2D:
	var p: Dictionary = PRESETS[style]
	var full_key := "%s:full" % style
	var full_img: Image = null
	if _cache.has(full_key) and _cache[full_key] is Texture2D:
		full_img = (_cache[full_key] as Texture2D).get_image()
	if full_img == null:
		full_img = _render_full_image(p)
		_cache[full_key] = ImageTexture.create_from_image(full_img)
	if not mini:
		return _cache[full_key]
	var mini_img := full_img.duplicate() as Image
	mini_img.resize(MINI_SIZE.x, MINI_SIZE.y, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(mini_img)


static func _render_full_image(p: Dictionary) -> Image:
	var w := FULL_SIZE.x
	var h := FULL_SIZE.y
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c_border: Color = p["border"]
	var c_rim: Color = p["rim"]
	var c_frame_a: Color = p["frame_a"]
	var c_frame_b: Color = p["frame_b"]
	var c_inner_rim: Color = p["inner_rim"]
	var c_v_outer: Color = p["vortex_outer"]
	var c_v_mid: Color = p["vortex_mid"]
	var c_v_core: Color = p["vortex_core"]
	var c_glow: Color = p["glow"]
	var emblem := str(p.get("emblem", ""))

	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	var rx := 64.0
	var ry := 96.0

	for y in h:
		var fy := float(y) / float(h - 1)
		for x in w:
			var fx := float(x) / float(w - 1)
			var dx := mini(x, w - 1 - x)
			var dy := mini(y, h - 1 - y)
			var edge := mini(dx, dy)

			# Outer black/dark card border
			if edge < 7:
				img.set_pixel(x, y, c_border)
				continue
			# Outer metallic trim
			if edge < 9:
				img.set_pixel(x, y, c_rim)
				continue
			# Subtle card bevel shadow
			if edge == 9:
				img.set_pixel(x, y, c_border.lerp(c_frame_b, 0.5))
				continue

			# Textured outer frame with diagonal shimmer
			var diag := 0.5 + 0.5 * sin((fx * 5.0 + fy * 3.0) * PI)
			var grain := 0.06 * sin(float(x * 13 + y * 29) * 0.17)
			var col := c_frame_b.lerp(c_frame_a, clampf(0.35 + 0.45 * diag + grain, 0.0, 1.0))

			# Inner card window border (x: 19..180, y: 22..267)
			var in_x := x >= 19 and x <= w - 20
			var in_y := y >= 22 and y <= h - 23
			if in_x and in_y:
				var idx := mini(x - 19, w - 20 - x)
				var idy := mini(y - 22, h - 23 - y)
				var iedge := mini(idx, idy)
				if iedge < 2:
					col = c_inner_rim
				elif iedge < 4:
					col = c_border
				else:
					# Swirling vortex ellipse inside inner frame
					var nx := (float(x) - cx) / rx
					var ny := (float(y) - cy) / ry
					var r := sqrt(nx * nx + ny * ny)
					var ang := atan2(ny, nx)
					if r <= 1.08:
						var swirl := 0.5 + 0.5 * sin(ang * 3.0 + r * 9.5)
						var ring := 0.5 + 0.5 * cos(r * 16.0 - ang * 2.0)
						var blend := clampf(r / 1.08, 0.0, 1.0)
						var vcol := c_v_core.lerp(c_v_mid, pow(blend, 0.7)).lerp(c_v_outer, pow(blend, 1.4))
						var highlight := pow(swirl * 0.65 + ring * 0.35, 2.2) * (1.0 - absf(blend - 0.52) * 1.4)
						col = vcol.lerp(c_glow, clampf(highlight * 0.72, 0.0, 0.85))
						if r > 0.98 and r <= 1.06:
							col = col.lerp(c_inner_rim, 0.65)
						if emblem != "":
							col = _apply_emblem(col, float(x) - cx, float(y) - cy, emblem, c_inner_rim, c_glow, c_border)
					else:
						# Dark patterned background behind oval
						var corner_grad := clampf((r - 1.08) * 1.6, 0.0, 1.0)
						col = c_v_mid.lerp(c_v_core, corner_grad * 0.75)

			# Small Millennium diamond accents in the 4 outer corners
			for corner: Vector2 in [Vector2(13.5, 15.0), Vector2(w - 14.5, 15.0), Vector2(13.5, h - 16.0), Vector2(w - 14.5, h - 16.0)]:
				var md := absf(float(x) - corner.x) + absf(float(y) - corner.y)
				if md <= 3.2:
					col = c_inner_rim if md <= 1.8 else c_border

			img.set_pixel(x, y, col)
	return img


static func _apply_emblem(col: Color, ox: float, oy: float, emblem: String, c_rim: Color, c_glow: Color, c_border: Color) -> Color:
	if emblem == "yugi":
		# Inverted Millennium Puzzle triangle + glowing Eye core
		var top_y := -24.0
		var bot_y := 26.0
		if oy >= top_y and oy <= bot_y:
			var t := (bot_y - oy) / (bot_y - top_y)
			var half_w := 28.0 * t
			var ax := absf(ox)
			if ax <= half_w:
				var rim_d := minf(half_w - ax, minf(oy - top_y, bot_y - oy))
				if rim_d < 2.6:
					return c_rim.lerp(c_glow, 0.4)
				elif rim_d < 4.2:
					return col.lerp(c_border, 0.55)
				var er := sqrt(ox * ox + (oy + 4.0) * (oy + 4.0))
				if er <= 9.0:
					return c_glow.lerp(Color.WHITE, clampf(1.0 - er / 9.0, 0.0, 0.85))
				return col.lerp(c_rim, 0.18)
	elif emblem == "kaiba":
		# Sleek KaibaCorp twin-diamond / Blue-Eyes star crest
		var d_outer := absf(ox) / 28.0 + absf(oy) / 42.0
		var d_inner := absf(ox) / 14.0 + absf(oy) / 22.0
		if d_outer <= 1.0 and d_outer >= 0.86:
			return c_rim.lerp(Color.WHITE, 0.35)
		if d_inner <= 1.0:
			var core_glow := clampf(1.0 - d_inner, 0.0, 1.0)
			return col.lerp(c_glow.lerp(Color.WHITE, 0.4), 0.30 + 0.55 * core_glow)
		if absf(ox) <= 2.0 and absf(oy) <= 34.0:
			return col.lerp(c_rim, 0.45)
	elif emblem == "joey":
		# Bold Flame / Red-Eyes Shield Star crest
		var r := sqrt(ox * ox + oy * oy)
		var ang := atan2(oy, ox)
		var star_r := 26.0 + 9.0 * cos(ang * 4.0)
		if r <= star_r:
			if r >= star_r - 2.6:
				return c_rim
			var inner := clampf(1.0 - r / star_r, 0.0, 1.0)
			return col.lerp(c_glow, 0.25 + 0.65 * pow(inner, 1.4))
	return col

