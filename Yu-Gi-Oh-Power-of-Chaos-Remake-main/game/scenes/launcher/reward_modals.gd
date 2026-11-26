extends CanvasLayer
## Modales propios del selector:
## 1) Canjear código de carta (أدخل كود البطاقة -> حفظ مباشر في مستودع البطاقات)
## 2) Ruleta de la suerte cada 4 horas (عجلة الحظ -> دوران متحرك وحفظ تلقائي للبطاقة المختارة)
## 3) Ruleta especial de mazos completos cada 2 horas (عجلة المجموعات الكاملة · كل ساعتين)

signal closed
signal card_unlocked(internal_id: int)

const DialogTheme := preload("res://scenes/launcher/dialog_theme.gd")
const _RivalDeckChoice := preload("res://scenes/duel/rival_deck_choice.gd")
const WHEEL_COOLDOWN_SEC := 4 * 3600 # 4 hours
const SETS_WHEEL_COOLDOWN_SEC := 2 * 3600 # 2 hours
const SPIN_DURATION := 4.2

const SPECIAL_SETS := [
	{
		"id": "toon",
		"ar": "عالم الكرتون (Toon World)",
		"es": "Mundo Toon (Toon World)",
		"en": "Toon World Set",
		"accent": Color(0.92, 0.34, 0.72),
		"cover_id": 766,
		"cards": [954, 766, 728, 727, 726, 725],
	},
	{
		"id": "relinquished",
		"ar": "أوهام بيغاسوس (المستسلم)",
		"es": "Ilusiones de Pegasus (Relinquished)",
		"en": "Pegasus Relinquished Set",
		"accent": Color(0.58, 0.32, 0.96),
		"cover_id": 730,
		"cards": [730, 958, 1334, 1333, 729, 41, 731, 382, 384],
	},
	{
		"id": "exodia",
		"ar": "إكسوديا المحظور",
		"es": "Exodia el Prohibido",
		"en": "Exodia the Forbidden Set",
		"accent": Color(0.96, 0.74, 0.22),
		"cover_id": 20,
		"cards": [20, 16, 17, 18, 19, 47, 573, 1010],
	},
	{
		"id": "dark_magician",
		"ar": "ساحر الظلام والفوضى",
		"es": "Mago Oscuro y Caos",
		"en": "Dark Magician Set",
		"accent": Color(0.45, 0.26, 0.88),
		"cover_id": 34,
		"cards": [34, 759, 721, 720, 1212, 1211, 1213, 945, 1248],
	},
	{
		"id": "blue_eyes",
		"ar": "التنين الأبيض أزرق العينين",
		"es": "Dragón Blanco de Ojos Azules",
		"en": "Blue-Eyes Dragon Set",
		"accent": Color(0.18, 0.78, 1.0),
		"cover_id": 0,
		"cards": [0, 379, 740, 966, 1003, 1546, 837],
	},
	{
		"id": "gate_guardian",
		"ar": "حارس البوابة والمتاهة",
		"es": "Guardián de la Puerta",
		"en": "Gate Guardian Set",
		"accent": Color(0.22, 0.68, 0.56),
		"cover_id": 373,
		"cards": [373, 370, 371, 372, 365, 368, 367, 369, 651],
	},
	{
		"id": "harpie",
		"ar": "سيدات الهاربي",
		"es": "Damas Arpía",
		"en": "Harpie Ladies Set",
		"accent": Color(0.86, 0.36, 0.42),
		"cover_id": 62,
		"cards": [61, 62, 385, 671, 317, 1174, 1128],
	},
	{
		"id": "magnet",
		"ar": "المحاربون المغناطيسيون",
		"es": "Guerreros Magnéticos",
		"en": "Magnet Warriors Set",
		"accent": Color(0.82, 0.52, 0.24),
		"cover_id": 845,
		"cards": [845, 737, 756, 800, 73, 1125],
	},
	{
		"id": "bls",
		"ar": "الجندي الأسود اللامع (Black Luster Soldier)",
		"es": "Soldado del Brillo Negro (BLS)",
		"en": "Black Luster Soldier Deck",
		"accent": Color(0.24, 0.52, 0.94),
		"cover_id": 3129,
		"cards": [3129, 3109, 34, 73, 15, 1109, 1096, 1008, 331],
	},
]


class WheelCanvas:
	extends Control
	var angle := 0.0
	var spinning := false
	var glow_phase := 0.0
	var won_flash := 0.0
	var special_mode := false
	var segment_count := 10
	var segment_colors: Array[Color] = []
	var slice_labels: Array[String] = []
	var slice_textures: Array[Texture2D] = []
	var active_index := 0

	func current_pointer_index() -> int:
		var segs := maxi(4, segment_count)
		var step := TAU / float(segs)
		var rel := fposmod(-angle, TAU)
		return clampi(int(floor(rel / step)), 0, segs - 1)

	static func _short_label(txt: String, max_chars := 16) -> String:
		var clean := txt.strip_edges()
		if clean.length() <= max_chars:
			return clean
		return clean.substr(0, max_chars - 1) + "…"

	func _draw() -> void:
		var center := size * 0.5
		var radius := minf(size.x, size.y) * 0.455
		if radius <= 16.0:
			return
		var ring_col := DialogTheme.GOLD if special_mode else DialogTheme.CYAN
		for ring in 3:
			var rr := radius + 13.0 - ring * 3.0
			var alpha := (0.18 + 0.10 * sin(glow_phase * 2.8)) if spinning or won_flash > 0.0 else 0.11
			draw_circle(center, rr, Color(ring_col, alpha))
		draw_circle(center, radius + 6.0, DialogTheme.GOLD_DARK)
		draw_circle(center, radius + 2.5, DialogTheme.GOLD)
		var default_palette := [
			Color(0.68, 0.14, 0.28),
			Color(0.11, 0.32, 0.64),
			Color(0.12, 0.48, 0.42),
			Color(0.46, 0.18, 0.58),
			Color(0.76, 0.42, 0.10),
			Color(0.16, 0.42, 0.56),
			Color(0.54, 0.16, 0.42),
			Color(0.18, 0.38, 0.28),
			Color(0.62, 0.26, 0.16),
			Color(0.24, 0.22, 0.58),
		]
		var segs := maxi(4, segment_count)
		var step := TAU / float(segs)
		var pointer_idx := current_pointer_index()
		active_index = pointer_idx
		var font: Font = Assets.ui_font(700)

		for i in segs:
			var a0 := angle + float(i) * step - PI * 0.5
			var a1 := a0 + step
			var pts := PackedVector2Array([center])
			var arc_steps := 12
			for s in arc_steps + 1:
				var a := lerpf(a0, a1, float(s) / float(arc_steps))
				pts.append(center + Vector2(cos(a), sin(a)) * (radius - 2.0))
			var col: Color
			if special_mode and i < segment_colors.size():
				col = segment_colors[i].darkened(0.38)
			else:
				col = default_palette[i % default_palette.size()]
			if i == pointer_idx:
				var highlight_boost := 0.26 if (spinning or won_flash > 0.0) else 0.16
				col = col.lightened(highlight_boost)
			draw_colored_polygon(pts, col)
			if i == pointer_idx:
				var rim_pts := PackedVector2Array()
				for s in arc_steps + 1:
					var a := lerpf(a0, a1, float(s) / float(arc_steps))
					rim_pts.append(center + Vector2(cos(a), sin(a)) * (radius - 3.5))
				draw_polyline(rim_pts, DialogTheme.GOLD_LIGHT, 3.0, true)
			draw_line(center, center + Vector2(cos(a0), sin(a0)) * (radius - 2.0), Color(DialogTheme.GOLD, 0.88), 2.0, true)

			var amid := (a0 + a1) * 0.5
			var dir := Vector2(cos(amid), sin(amid))

			# Mini card thumbnail or gem near the outer edge of each slice
			var icon_pos := center + dir * (radius * 0.82)
			var tex: Texture2D = slice_textures[i] if i < slice_textures.size() else null
			if tex != null:
				draw_set_transform(icon_pos, amid + PI * 0.5, Vector2.ONE)
				var thumb_rect := Rect2(Vector2(-11.0, -15.0), Vector2(22.0, 30.0))
				draw_rect(thumb_rect.grow(1.5), DialogTheme.GOLD_LIGHT if i == pointer_idx else DialogTheme.GOLD_DARK, true)
				draw_texture_rect(tex, thumb_rect, false)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var gem_col := (segment_colors[i] if i < segment_colors.size() else DialogTheme.GOLD_LIGHT) if special_mode else DialogTheme.GOLD_LIGHT
				draw_circle(icon_pos, 5.5, gem_col)
				draw_circle(icon_pos, 2.5, DialogTheme.BG_VOID)

			# Radial card name label drawn directly inside each slice
			var raw_lbl: String = slice_labels[i] if i < slice_labels.size() else ("#%d" % (i + 1))
			var lbl := _short_label(raw_lbl, 15)
			if font != null and lbl != "":
				var text_r := radius * 0.49
				var text_pos := center + dir * text_r
				var norm_a := fposmod(amid, TAU)
				var flip := norm_a > PI * 0.5 and norm_a < PI * 1.5
				var text_rot := amid + PI if flip else amid
				var fsize := 10 if segs >= 10 else 11
				var tsize := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
				draw_set_transform(text_pos, text_rot, Vector2.ONE)
				var draw_pt := Vector2(-tsize.x * 0.5, tsize.y * 0.32)
				draw_string_outline(font, draw_pt, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 3, Color(0.02, 0.02, 0.06, 0.92))
				var txt_col := Color(1.0, 0.96, 0.72) if i == pointer_idx else Color.WHITE
				draw_string(font, draw_pt, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, txt_col)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# Outer casino / My Orange style LED lights around the wheel bezel
		for i in 20:
			var a := angle * 0.35 + float(i) * (TAU / 20.0)
			var p := center + Vector2(cos(a), sin(a)) * (radius + 4.0)
			var lit := (i + int(floorf(glow_phase * 8.0))) % 2 == 0
			var c := (DialogTheme.GOLD_LIGHT if i % 2 == 0 else DialogTheme.VIOLET.lightened(0.35)) if special_mode else (DialogTheme.GOLD_LIGHT if i % 2 == 0 else DialogTheme.CYAN)
			draw_circle(p, 3.0 if lit else 2.0, c if lit else Color(c, 0.38))

		# Center hub medallion
		draw_circle(center, radius * 0.20, DialogTheme.GOLD_DARK)
		draw_circle(center, radius * 0.17, DialogTheme.BG_VOID)
		draw_arc(center, radius * 0.155, 0.0, TAU, 28, DialogTheme.GOLD if special_mode else DialogTheme.CYAN, 2.2, true)
		var d := radius * 0.085
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -d), center + Vector2(d, 0),
			center + Vector2(0, d), center + Vector2(-d, 0)
		]), DialogTheme.GOLD_LIGHT)

		# Top pointer / stopper arrow
		var needle_wobble := sin(angle * float(segs)) * 0.16 if spinning else 0.0
		var tip := center + Vector2(sin(needle_wobble) * 9.0, -radius + 17.0)
		var top_l := center + Vector2(-14.0, -radius - 12.0)
		var top_r := center + Vector2(14.0, -radius - 12.0)
		draw_colored_polygon(PackedVector2Array([top_l, top_r, tip]), Color(0.96, 0.18, 0.22))
		draw_polyline(PackedVector2Array([top_l, top_r, tip, top_l]), DialogTheme.GOLD_LIGHT, 2.2, true)
		draw_circle(center + Vector2(0.0, -radius - 6.0), 4.0, DialogTheme.GOLD_LIGHT)


var _backdrop := ColorRect.new()
var _code_panel := PanelContainer.new()
var _wheel_panel := PanelContainer.new()
var _admin_panel := PanelContainer.new()
var _ready_decks_panel := PanelContainer.new()

# Ready-made decks modal controls
var _ready_decks_title: Label
var _ready_decks_hint: Label
var _ready_decks_search: LineEdit
var _ready_decks_cat := "all"
var _ready_decks_cat_btns: Dictionary = {}
var _ready_decks_unlock_all_btn: Button
var _ready_decks_wheel_btn: Button
var _ready_decks_list_vbox: VBoxContainer
var _ready_decks_status: Label
var _ready_decks_open_editor_btn: Button
var _ready_decks_close_btn: Button
var _ready_decks_entries: Array[Dictionary] = []

# Card code controls
var _code_title: Label
var _code_hint: Label
var _code_input: LineEdit
var _code_redeem_btn: Button
var _code_close_btn: Button
var _code_status: Label
var _code_preview_box: HBoxContainer
var _code_card_tex: TextureRect
var _code_card_title: Label
var _code_card_sub: Label
var _code_card_desc: RichTextLabel

# Lucky wheel controls (shared window with 2 modes: "single" and "sets_beta")
var _wheel_mode := "single"
var _tab_single_btn: Button
var _tab_special_btn: Button
var _wheel_title: Label
var _wheel_badge: Label
var _wheel_hint: Label
var _wheel_canvas: WheelCanvas
var _wheel_card_tex: TextureRect
var _wheel_card_name: Label
var _wheel_card_meta: Label
var _wheel_card_desc: RichTextLabel
var _wheel_cards_list: RichTextLabel
var _wheel_status: Label
var _wheel_spin_btn: Button
var _wheel_close_btn: Button

# Admin gift code manager controls (protected by server ADMIN_PASSCODE)
var _admin_title: Label
var _admin_login_box: VBoxContainer
var _admin_login_hint: Label
var _admin_pass_input: LineEdit
var _admin_login_btn: Button
var _admin_login_status: Label
var _admin_login_close_btn: Button
var _admin_work_box: VBoxContainer
var _admin_mode := "card"
var _admin_mode_card_btn: Button
var _admin_mode_deck_btn: Button
var _admin_mode_unlock_btn: Button
var _admin_gift_code_input: LineEdit
var _admin_random_btn: Button
var _admin_max_uses_input: LineEdit
var _admin_copies_btn: Button
var _admin_copies_val := 1
var _admin_card_row: HBoxContainer
var _admin_card_input: LineEdit
var _admin_deck_box: VBoxContainer
var _admin_deck_pick_btn: Button
var _admin_deck_load_btn: Button
var _admin_deck_name_input: LineEdit
var _admin_deck_cards_input: TextEdit
var _admin_deck_sources: Array[Dictionary] = []
var _admin_deck_selected_idx := -1
var _admin_unlock_box: PanelContainer
var _admin_unlock_info_lbl: Label
var _deck_picker_layer: CanvasLayer
var _deck_picker_backdrop: ColorRect
var _deck_picker_panel: PanelContainer
var _deck_picker_title: Label
var _deck_picker_search: LineEdit
var _deck_picker_list: VBoxContainer
var _admin_create_btn: Button
var _admin_preview_tex: TextureRect
var _admin_preview_lbl: Label
var _admin_status_lbl: Label
var _admin_list_scroll: ScrollContainer
var _admin_list_vbox: VBoxContainer
var _admin_refresh_btn: Button
var _admin_logout_btn: Button
var _admin_close_btn: Button
var _admin_busy := false
var _admin_resolved_code := ""
var _admin_resolved_label := ""
var _admin_resolved_deck: Array[Dictionary] = []

var _eligible_pool: Array[Dictionary] = []
var _wheel_slices: Array[Dictionary] = []
var _spinning := false
var _spin_elapsed := 0.0
var _spin_start_angle := 0.0
var _spin_target_angle := 0.0
var _spin_tick_clock := 0.0
var _spin_tick_step := 0.05
var _won_card: Dictionary = {}
var _won_slice_index := 0
var _active_slice_index := -1
var _won_set_index := 0
var _active_set_index := 0
var _wheel_rotation_bucket := -1
var _ui_tick_accum := 0.0
var _pending_slice_ids: Array[int] = []
var _pending_slice_cursor := 0
var _rng := RandomNumberGenerator.new()
static var _cached_last_spin_unix := -1
static var _cached_sets_last_spin_unix := -1


func _ready() -> void:
	layer = 92
	_rng.randomize()
	_backdrop.color = Color(0.012, 0.015, 0.045, 0.82)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	_backdrop.hide()
	add_child(_backdrop)
	_build_code_panel()
	_build_wheel_panel()
	_build_admin_panel()
	_build_ready_decks_panel()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	close_all()


func _on_backdrop_input(event: InputEvent) -> void:
	if _spinning or not is_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_all()
		get_viewport().set_input_as_handled()


func _on_viewport_resized() -> void:
	if _code_panel.visible:
		_center_panel.call_deferred(_code_panel)
	elif _wheel_panel.visible:
		_center_panel.call_deferred(_wheel_panel)
	elif _admin_panel.visible:
		_center_panel.call_deferred(_admin_panel)
	elif _ready_decks_panel.visible:
		_center_panel.call_deferred(_ready_decks_panel)
	if is_instance_valid(_deck_picker_panel) and _deck_picker_panel.visible:
		_center_panel.call_deferred(_deck_picker_panel)


func is_open() -> bool:
	return _code_panel.visible or _wheel_panel.visible or _admin_panel.visible or _ready_decks_panel.visible


func close_all() -> void:
	if _spinning:
		return
	_close_admin_deck_picker()
	_backdrop.hide()
	_code_panel.hide()
	_wheel_panel.hide()
	_admin_panel.hide()
	_ready_decks_panel.hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") and not _spinning:
		if is_instance_valid(_deck_picker_layer) and _deck_picker_layer.visible:
			_close_admin_deck_picker()
		else:
			close_all()
		get_viewport().set_input_as_handled()


func _tr(ar: String, es: String, en: String) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		return ar
	return es if lang == "s" else en


static func normalize_digits(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var code := raw.unicode_at(i)
		if code >= 0x0660 and code <= 0x0669:
			out += str(code - 0x0660)
		elif code >= 0x06F0 and code <= 0x06F9:
			out += str(code - 0x06F0)
		else:
			out += raw.substr(i, 1)
	return out


static func _last_spin_unix() -> int:
	var save_ts := 0
	if is_instance_valid(SaveData) and SaveData.data is Dictionary:
		var wheel_data: Variant = SaveData.data.get("wheel", {})
		if wheel_data is Dictionary:
			save_ts = int((wheel_data as Dictionary).get("last_spin", 0))
	if _cached_last_spin_unix < 0:
		var cfg_ts := 0
		if is_instance_valid(Paths):
			var cfg := ConfigFile.new()
			if cfg.load(Paths.settings_path()) == OK:
				cfg_ts = int(cfg.get_value("launcher", "wheel_last_spin", 0))
		_cached_last_spin_unix = cfg_ts
	return maxi(save_ts, _cached_last_spin_unix)


static func remaining_cooldown_sec() -> int:
	var last_spin := _last_spin_unix()
	if last_spin <= 0:
		return 0
	var now := int(Time.get_unix_time_from_system())
	if now < last_spin:
		return mini(WHEEL_COOLDOWN_SEC, last_spin - now)
	var elapsed := now - last_spin
	return maxi(0, WHEEL_COOLDOWN_SEC - elapsed)


static func _last_sets_spin_unix() -> int:
	var save_ts := 0
	if is_instance_valid(SaveData) and SaveData.data is Dictionary:
		var sets_data: Variant = SaveData.data.get("sets_wheel", {})
		if sets_data is Dictionary:
			save_ts = int((sets_data as Dictionary).get("last_spin", 0))
	if _cached_sets_last_spin_unix < 0:
		var cfg_ts := 0
		if is_instance_valid(Paths):
			var cfg := ConfigFile.new()
			if cfg.load(Paths.settings_path()) == OK:
				cfg_ts = int(cfg.get_value("launcher", "sets_wheel_last_spin", 0))
		_cached_sets_last_spin_unix = cfg_ts
	return maxi(save_ts, _cached_sets_last_spin_unix)


static func sets_remaining_cooldown_sec() -> int:
	var last_spin := _last_sets_spin_unix()
	if last_spin <= 0:
		return 0
	var now := int(Time.get_unix_time_from_system())
	if now < last_spin:
		return mini(SETS_WHEEL_COOLDOWN_SEC, last_spin - now)
	var elapsed := now - last_spin
	return maxi(0, SETS_WHEEL_COOLDOWN_SEC - elapsed)


static func format_duration(sec: int) -> String:
	var clamped := maxi(0, sec)
	var h := clamped / 3600
	var m := (clamped % 3600) / 60
	var s := clamped % 60
	return "%02d:%02d:%02d" % [h, m, s]


static func card_code_string(card: Dictionary) -> String:
	var pwd := str(card.get("password", "")).strip_edges()
	if pwd != "" and pwd.to_lower() != "ffffffff":
		return pwd.lpad(8, "0")
	return "%08d" % int(card.get("internal_id", 0))


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.048, 0.058, 0.128, 0.98)
	box.border_color = DialogTheme.CYAN.lerp(DialogTheme.GOLD, 0.55)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.shadow_color = Color(0, 0, 0, 0.72)
	box.shadow_size = 24
	box.set_content_margin_all(20)
	return box


func _subbox_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.072, 0.088, 0.185, 0.94)
	box.border_color = Color(DialogTheme.CYAN, 0.35)
	box.set_border_width_all(1)
	box.set_corner_radius_all(10)
	box.set_content_margin_all(12)
	return box


func _style_btn(btn: Button, primary := false, accent_gold := false) -> void:
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_override("font", Assets.ui_font(700))
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color.WHITE if primary else DialogTheme.GOLD_LIGHT)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.75, 0.85, 0.45))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		if primary:
			if accent_gold:
				box.bg_color = Color(0.32, 0.14, 0.44, 0.98) if state == "normal" else (Color(0.42, 0.20, 0.56, 1.0) if state in ["hover", "pressed"] else Color(0.14, 0.10, 0.22, 0.7))
			else:
				box.bg_color = Color(0.11, 0.38, 0.54, 0.98) if state == "normal" else (Color(0.16, 0.50, 0.70, 1.0) if state in ["hover", "pressed"] else Color(0.10, 0.14, 0.24, 0.7))
			box.border_color = DialogTheme.GOLD if state != "disabled" else Color(DialogTheme.GOLD, 0.25)
		else:
			box.bg_color = DialogTheme.SURFACE_HOVER if state in ["hover", "pressed"] else DialogTheme.SURFACE
			box.border_color = Color(DialogTheme.CYAN, 0.48) if state == "normal" else (DialogTheme.GOLD if state != "disabled" else Color(DialogTheme.CYAN, 0.2))
		box.set_border_width_all(2 if primary else 1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		btn.add_theme_stylebox_override(state, box)


func _style_input(le: LineEdit) -> void:
	le.add_theme_font_override("font", Assets.ui_font(700))
	le.add_theme_font_size_override("font_size", 16)
	le.add_theme_color_override("font_color", Color.WHITE)
	le.add_theme_color_override("font_placeholder_color", Color(0.65, 0.75, 0.90, 0.55))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.036, 0.085, 0.98)
	box.border_color = DialogTheme.CYAN
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	le.add_theme_stylebox_override("normal", box)
	le.add_theme_stylebox_override("focus", box)


# --- Card Code Dialog -------------------------------------------------------

func _build_code_panel() -> void:
	_code_panel.add_theme_stylebox_override("panel", _panel_style())
	_code_panel.custom_minimum_size = Vector2(540, 380)
	_code_panel.hide()
	add_child(_code_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(500, 0)
	root.add_theme_constant_override("separation", 12)
	_code_panel.add_child(root)

	_code_title = Label.new()
	_code_title.add_theme_font_override("font", Assets.ui_font(700))
	_code_title.add_theme_font_size_override("font_size", 22)
	_code_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	_code_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_code_title)

	_code_hint = Label.new()
	_code_hint.custom_minimum_size = Vector2(460, 0)
	_code_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_hint.add_theme_font_override("font", Assets.ui_font())
	_code_hint.add_theme_font_size_override("font_size", 14)
	_code_hint.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_code_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_code_hint)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	_code_input = LineEdit.new()
	_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_input.max_length = 64
	_code_input.text_submitted.connect(func(_t: String) -> void: _on_redeem_pressed())
	_style_input(_code_input)
	row.add_child(_code_input)

	_code_redeem_btn = Button.new()
	_code_redeem_btn.pressed.connect(_on_redeem_pressed)
	_style_btn(_code_redeem_btn, true)
	row.add_child(_code_redeem_btn)

	_code_status = Label.new()
	_code_status.custom_minimum_size = Vector2(460, 22)
	_code_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_status.add_theme_font_override("font", Assets.ui_font(700))
	_code_status.add_theme_font_size_override("font_size", 14)
	_code_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_code_status)

	var preview_frame := PanelContainer.new()
	preview_frame.add_theme_stylebox_override("panel", _subbox_style())
	root.add_child(preview_frame)

	_code_preview_box = HBoxContainer.new()
	_code_preview_box.add_theme_constant_override("separation", 14)
	preview_frame.add_child(_code_preview_box)

	_code_card_tex = TextureRect.new()
	_code_card_tex.custom_minimum_size = Vector2(92, 134)
	_code_card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_code_card_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_code_preview_box.add_child(_code_card_tex)

	var meta := VBoxContainer.new()
	meta.custom_minimum_size = Vector2(320, 0)
	meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meta.add_theme_constant_override("separation", 6)
	_code_preview_box.add_child(meta)

	_code_card_title = Label.new()
	_code_card_title.custom_minimum_size = Vector2(310, 0)
	_code_card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_card_title.add_theme_font_override("font", Assets.ui_font(700))
	_code_card_title.add_theme_font_size_override("font_size", 17)
	_code_card_title.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_code_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_child(_code_card_title)

	_code_card_sub = Label.new()
	_code_card_sub.custom_minimum_size = Vector2(310, 0)
	_code_card_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_card_sub.add_theme_font_override("font", Assets.ui_font())
	_code_card_sub.add_theme_font_size_override("font_size", 13)
	_code_card_sub.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_code_card_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta.add_child(_code_card_sub)

	_code_card_desc = RichTextLabel.new()
	_code_card_desc.custom_minimum_size = Vector2(310, 66)
	_code_card_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_card_desc.bbcode_enabled = true
	_code_card_desc.scroll_active = true
	_code_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_card_desc.add_theme_font_override("normal_font", Assets.ui_font())
	_code_card_desc.add_theme_font_override("bold_font", Assets.ui_font(700))
	_code_card_desc.add_theme_font_size_override("normal_font_size", 12)
	_code_card_desc.add_theme_font_size_override("bold_font_size", 12)
	_code_card_desc.add_theme_constant_override("line_separation", 3)
	_code_card_desc.add_theme_color_override("default_color", Color(0.92, 0.95, 1.0))
	meta.add_child(_code_card_desc)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(footer)

	_code_close_btn = Button.new()
	_code_close_btn.pressed.connect(close_all)
	_style_btn(_code_close_btn, false)
	footer.add_child(_code_close_btn)


func _card_translation_bbcode(cid: int) -> String:
	var card := CardDB.by_id(cid)
	if card.is_empty():
		return ""
	var type_str := CardDB.type_text(card).replace("[", "[lb]")
	var header := "[color=#ffd978]%s[/color]" % type_str
	if str(card.get("category", "")) == "monster":
		header += "  [color=#9fe4ff]ATK/%d  DEF/%d[/color]" % [int(card.get("atk", 0)), int(card.get("defense", 0))]
	var desc := CardDB.text(card, "descriptions").strip_edges().replace("[", "[lb]")
	if desc == "":
		return header
	return "%s\n[color=#eef4ff]%s[/color]" % [header, desc]


func _apply_card_desc_label(lbl: RichTextLabel, cid: int) -> void:
	if lbl == null:
		return
	var is_ar := is_instance_valid(Assets) and Assets.lang == "a"
	lbl.text_direction = Control.TEXT_DIRECTION_RTL if is_ar else Control.TEXT_DIRECTION_AUTO
	var content := _card_translation_bbcode(cid)
	lbl.text = content
	lbl.visible = content != ""


func open_card_code() -> void:
	if _spinning:
		return
	_wheel_panel.hide()
	_admin_panel.hide()
	_code_title.text = _tr("🔑 كود البطاقة أو كود الهدية", "🔑 Canjear código de carta o regalo", "🔑 Redeem Card or Gift Code")
	_code_hint.text = _tr(
		"أدخل كود البطاقة الأساسي (8 أرقام) أو اسمها أو كود هدية محدود ليتم تسجيل البطاقة في مستودعك فوراً.",
		"Introduce un código de carta (8 dígitos), su nombre o un código de regalo limitado.",
		"Enter an 8-digit card code, card name, or limited gift code to unlock it in your trunk."
	)
	_code_input.placeholder_text = _tr("مثال: 24094653 أو الانصهار أو FUSION10", "Ej: 24094653 o FUSION10", "e.g. 24094653, Polymerization, or FUSION10")
	_code_input.text = ""
	_code_redeem_btn.disabled = false
	_code_redeem_btn.text = _tr("تسجيل البطاقة", "Canjear", "Unlock Card")
	_code_close_btn.text = _tr("إغلاق", "Cerrar", "Close")
	_code_status.text = ""
	_code_card_tex.texture = null
	_code_card_title.text = _tr("في انتظار إدخال الكود…", "Esperando código…", "Waiting for code…")
	_code_card_sub.text = _tr("سيتم حفظ البطاقة مباشرة في مستودع البطاقات.", "La carta se guardará directamente en tu baúl.", "The card will be saved directly to your card trunk.")
	_code_card_desc.text = ""
	_code_card_desc.hide()
	_backdrop.show()
	_code_panel.show()
	_center_panel(_code_panel)
	_center_panel.call_deferred(_code_panel)
	_code_input.grab_focus()


static func _normalize_card_name(raw: String) -> String:
	var s := normalize_digits(raw).strip_edges().to_lower()
	var out := ""
	var prev_space := false
	for i in s.length():
		var c := s.unicode_at(i)
		# Skip Arabic diacritics & tatweel
		if (c >= 0x064B and c <= 0x065F) or c == 0x0670 or c == 0x0640:
			continue
		if c == 0x0623 or c == 0x0625 or c == 0x0622 or c == 0x0671:
			out += "ا"
			prev_space = false
		elif c == 0x0629:
			out += "ه"
			prev_space = false
		elif c == 0x0649:
			out += "ي"
			prev_space = false
		elif c == 0x0624:
			out += "و"
			prev_space = false
		elif c == 0x0626:
			out += "ي"
			prev_space = false
		elif c == 0x0020 or c == 0x0009 or c == 0x000A or c == 0x002D or c == 0x005F or c == 0x0028 or c == 0x0029 or c == 0x002F or c == 0x002E or c == 0x002C or c == 0x060C:
			if not prev_space and not out.is_empty():
				out += " "
				prev_space = true
		else:
			out += s.substr(i, 1)
			prev_space = false
	out = out.strip_edges()
	for pref: String in ["بطاقه ", "ورقه ", "كارت ", "كرت "]:
		if out.begins_with(pref) and out.length() > pref.length() + 1:
			out = out.substr(pref.length()).strip_edges()
			break
	return out


func _resolve_card_id(raw_entry: String) -> int:
	if CardDB.cards.is_empty():
		CardDB.load_db()
	var cleaned := normalize_digits(raw_entry).strip_edges()
	if cleaned.is_empty():
		return -1
	var upper := cleaned.to_upper()
	if upper.begins_with("CARD-"):
		cleaned = cleaned.substr(5).strip_edges()
	elif upper.begins_with("POC-"):
		cleaned = cleaned.substr(4).strip_edges()
	elif cleaned.begins_with("#"):
		cleaned = cleaned.substr(1).strip_edges()
	var is_num := cleaned.is_valid_int()
	var padded := cleaned.lpad(8, "0") if is_num else ""
	if is_num:
		for card: Dictionary in CardDB.cards:
			var cid := int(card.get("internal_id", -1))
			if cid < 0 or card.get("image") == null or int(card.get("pack", 0)) == 0:
				continue
			var pwd := str(card.get("password", "")).strip_edges()
			if pwd != "" and pwd.to_lower() != "ffffffff":
				if pwd == cleaned or pwd.lpad(8, "0") == padded:
					return cid
		var parsed_id := cleaned.to_int()
		var direct := CardDB.by_id(parsed_id)
		if not direct.is_empty() and direct.get("image") != null and int(direct.get("pack", 0)) != 0:
			return parsed_id
	var needle := _normalize_card_name(cleaned)
	if needle.is_empty():
		return -1
	var best_prefix_cid := -1
	var best_prefix_len := 9999
	var best_sub_cid := -1
	var best_sub_len := 9999
	for card: Dictionary in CardDB.cards:
		var cid := int(card.get("internal_id", -1))
		if cid < 0 or card.get("image") == null or int(card.get("pack", 0)) == 0:
			continue
		for lang_code: String in ["ara", "eng", "spa"]:
			var nm := _normalize_card_name(CardDB.name_of(cid, lang_code))
			if nm.is_empty():
				continue
			if nm == needle:
				return cid
			if nm.begins_with(needle) and nm.length() < best_prefix_len:
				best_prefix_cid = cid
				best_prefix_len = nm.length()
			elif nm.find(needle) != -1 and nm.length() < best_sub_len:
				best_sub_cid = cid
				best_sub_len = nm.length()
	if best_prefix_cid >= 0:
		return best_prefix_cid
	return best_sub_cid


var _redeem_busy: bool = false


func _on_redeem_pressed() -> void:
	if _redeem_busy:
		return
	if not Paths.has_data():
		_code_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		_code_status.text = _tr(
			"يرجى استيراد موارد اللعبة أولاً قبل تسجيل البطاقات.",
			"Importa primero los recursos del juego antes de canjear cartas.",
			"Please import game resources first before unlocking cards."
		)
		return
	var raw_entry := normalize_digits(_code_input.text).strip_edges()
	if raw_entry.is_empty():
		_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		_code_status.text = _tr(
			"يرجى إدخال كود البطاقة أو كود الهدية أولاً.",
			"Introduce primero un código de carta o regalo.",
			"Please enter a card code or gift code first."
		)
		return

	var cid: int = -1
	var copies_to_add: int = 1
	var gift_meta: Dictionary = {}

	# Check server-managed limited gift codes first when signed into Online
	if is_instance_valid(Online) and Online.is_logged_in():
		_redeem_busy = true
		_code_redeem_btn.disabled = true
		_code_status.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
		_code_status.text = _tr("جاري التحقق من الكود…", "Verificando código…", "Checking code…")
		var gift_res: Dictionary = await Online.redeem_gift_code(raw_entry)
		_redeem_busy = false
		_code_redeem_btn.disabled = false
		if bool(gift_res.get("ok", false)):
			var reward_type := str(gift_res.get("rewardType", "card")).to_lower()
			if reward_type == "unlock_all":
				_redeem_unlock_all_gift(raw_entry, gift_res)
				return
			var deck_cards_raw: Variant = gift_res.get("cards", [])
			if reward_type == "deck" and deck_cards_raw is Array and not (deck_cards_raw as Array).is_empty():
				_redeem_deck_gift(raw_entry, gift_res)
				return
			var mapped_code := str(gift_res.get("cardCode", "")).strip_edges()
			cid = _resolve_card_id(mapped_code)
			copies_to_add = clampi(int(gift_res.get("copies", 1)), 1, 3)
			gift_meta = gift_res
			if cid < 0:
				_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
				_code_status.text = _tr(
					"كود الهدية مرتبط ببطاقة غير متوفرة في هذا الإصدار.",
					"El código de regalo apunta a una carta no disponible en esta versión.",
					"This gift code maps to a card unavailable in this build."
				)
				return
		else:
			var err := str(gift_res.get("error", ""))
			if err == "code_exhausted":
				_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
				_code_status.text = _tr(
					"عذراً، انتهى الحد الأقصى لهذا الكود وتم إيقافه تلقائياً.",
					"Lo sentimos, este código de regalo ya alcanzó su límite máximo de usos.",
					"Sorry, this gift code has reached its maximum user limit."
				)
				return
			elif err == "already_redeemed":
				_code_status.add_theme_color_override("font_color", DialogTheme.GOLD)
				_code_status.text = _tr(
					"لقد قمت باستخدام كود الهدية هذا من قبل على حسابك.",
					"Ya has canjeado este código de regalo en tu cuenta.",
					"You have already redeemed this gift code on your account."
				)
				return
			elif err == "code_inactive":
				_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
				_code_status.text = _tr(
					"كود الهدية هذا موقوف حالياً.",
					"Este código de regalo está desactivado actualmente.",
					"This gift code is currently disabled."
				)
				return
			elif err == "code_expired":
				_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
				_code_status.text = _tr(
					"انتهت صلاحية كود الهدية هذا.",
					"Este código de regalo ha caducado.",
					"This gift code has expired."
				)
				return
			elif err == "rate_limited":
				_code_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
				_code_status.text = _tr(
					"محاولات كثيرة جداً، انتظر قليلاً ثم حاول مرة أخرى.",
					"Demasiados intentos, espera un momento e inténtalo de nuevo.",
					"Too many attempts. Please wait a moment and try again."
				)
				return
			# Otherwise ("code_not_found" or offline/network error), fall back to local card code lookup.

	if cid < 0:
		cid = _resolve_card_id(raw_entry)
	if cid < 0:
		_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if is_instance_valid(Online) and not Online.is_logged_in():
			_code_status.text = _tr(
				"الكود غير موجود. إذا كان هذا كود هدية محدود، يرجى تسجيل الدخول في الأونلاين أولاً.",
				"Código no encontrado. Si es un código de regalo limitado, inicia sesión online primero.",
				"Code not found. If this is a limited gift code, please sign in online first."
			)
		else:
			_code_status.text = _tr(
				"الكود غير صحيح أو غير موجود. تأكد من كتابته بشكل صحيح.",
				"Código no válido o no encontrado.",
				"Invalid or unknown card code."
			)
		return
	if SaveData.data.is_empty():
		SaveData.load_or_create()
	var current_count := SaveData.card_count(cid)
	var card := CardDB.by_id(cid)
	var ar_name := CardDB.name_of(cid, "ara")
	var en_name := CardDB.name_of(cid, "eng")
	var code_str := card_code_string(card)
	_code_card_tex.texture = CardDB.card_texture(cid, false)
	_code_card_title.text = ("%s\n%s" % [ar_name, en_name]) if ar_name != en_name else en_name
	_apply_card_desc_label(_code_card_desc, cid)
	if current_count >= 99:
		_code_status.add_theme_color_override("font_color", DialogTheme.GOLD)
		_code_status.text = _tr("وصلت للحد الأقصى (99 نسخة) لهذه البطاقة.", "Ya tienes el máximo (99 copias).", "Already at max (99 copies) for this card.")
		_code_card_sub.text = _tr("الكود: %s · النسخ في المستودع: %d", "Código: %s · En baúl: %d", "Code: %s · In trunk: %d") % [code_str, current_count]
		return
	SaveData.add_card(cid, copies_to_add)
	SaveData.save()
	var after_count := SaveData.card_count(cid)
	_code_status.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
	if not gift_meta.is_empty():
		var used_n := int(gift_meta.get("usedCount", 1))
		var max_n := int(gift_meta.get("maxUses", 1))
		var rem_n := int(gift_meta.get("remaining", 0))
		_code_status.text = _tr(
			"🎁 تم استلام بطاقة الهدية بنجاح! (%d / %d · المتبقي: %d)",
			"🎁 ¡Carta de regalo canjeada con éxito! (%d / %d · Restantes: %d)",
			"🎁 Gift card claimed successfully! (%d / %d · Remaining: %d)"
		) % [used_n, max_n, rem_n]
		_code_card_sub.text = _tr(
			"كود الهدية: %s → البطاقة: %s · لديك الآن %d نسخة",
			"Regalo: %s → Carta: %s · Ahora tienes %d",
			"Gift: %s → Card: %s · Owned: %d"
		) % [str(gift_meta.get("code", raw_entry)), code_str, after_count]
		if is_instance_valid(Online) and Online.is_logged_in():
			Online.sync_collection_now()
	else:
		_code_status.text = _tr(
			"✓ تم تسجيل البطاقة وحفظها في مستودع البطاقات بنجاح!",
			"✓ ¡Carta registrada y guardada en tu baúl!",
			"✓ Card unlocked and saved to your card trunk!"
		)
		_code_card_sub.text = _tr("الكود: %s · لديك الآن %d نسخة", "Código: %s · Ahora tienes %d", "Code: %s · Owned: %d") % [code_str, after_count]
	_code_input.text = ""
	card_unlocked.emit(cid)


static func _safe_deck_filename(raw_title: String, fallback_code: String) -> String:
	var base := raw_title.strip_edges()
	var out := ""
	for i in base.length():
		var ch := base.substr(i, 1)
		var code := base.unicode_at(i)
		var is_ascii_alnum := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		if is_ascii_alnum or ch == "_" or ch == "-":
			out += ch
		elif ch == " ":
			out += "_"
	while out.find("__") != -1:
		out = out.replace("__", "_")
	out = out.strip_edges().trim_prefix("_").trim_suffix("_").trim_prefix("-").trim_suffix("-")
	if out.length() < 2:
		var fb := fallback_code.strip_edges().to_upper()
		var clean_fb := ""
		for i in fb.length():
			var c := fb.unicode_at(i)
			if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or fb.substr(i, 1) == "-":
				clean_fb += fb.substr(i, 1)
		out = "GiftDeck_" + (clean_fb if clean_fb != "" else str(Time.get_unix_time_from_system()))
	return out.substr(0, 28)


func _redeem_deck_gift(raw_entry: String, gift_res: Dictionary) -> void:
	if SaveData.data.is_empty():
		SaveData.load_or_create()
	var cards_raw: Array = gift_res.get("cards", [])
	var deck_dict := {"main": [], "fusion": [], "side": []}
	var total_added := 0
	var unique_resolved := 0
	var cover_cid = _resolve_card_id(str(gift_res.get("cardCode", "")))

	for entry_v: Variant in cards_raw:
		if not (entry_v is Dictionary):
			continue
		var entry: Dictionary = entry_v
		var c_code := str(entry.get("cardCode", "")).strip_edges()
		var cid := _resolve_card_id(c_code)
		if cid < 0:
			var c_lbl := str(entry.get("cardLabel", "")).strip_edges()
			if c_lbl != "":
				cid = _resolve_card_id(c_lbl)
		if cid < 0:
			continue
		if cover_cid < 0:
			cover_cid = cid
		var copies = clampi(int(entry.get("copies", 1)), 1, 3)
		var zone := str(entry.get("zone", "main")).strip_edges().to_lower()
		if zone not in ["main", "fusion", "side"]:
			zone = "main"
		var cur := SaveData.card_count(cid)
		var add_n := mini(copies, maxi(0, 99 - cur))
		if add_n > 0:
			SaveData.add_card(cid, add_n)
			total_added += add_n
		unique_resolved += 1
		var zone_cap := 80 if zone == "main" else 15
		var zone_arr: Array = deck_dict[zone]
		for _i in copies:
			if zone_arr.size() < zone_cap:
				zone_arr.append(cid)

	if unique_resolved == 0:
		_code_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		_code_status.text = _tr(
			"كود المجموعة لا يحتوي على بطاقات متوفرة في هذا الإصدار.",
			"Este código de mazo no contiene cartas disponibles en esta versión.",
			"This deck gift code contains no cards available in this build."
		)
		return

	SaveData.save()
	var gcode := str(gift_res.get("code", raw_entry))
	var deck_label := str(gift_res.get("cardLabel", "")).strip_edges()
	if deck_label.is_empty():
		deck_label = _tr("مجموعة هدية", "Mazo de regalo", "Gift Deck")

	var saved_ydc_name := ""
	if (deck_dict["main"] as Array).size() >= 40:
		var safe_name := _safe_deck_filename(deck_label, gcode)
		var deck_path := Paths.save_dir.path_join("decks").path_join(safe_name + ".ydc")
		if Ydc.save(deck_path, deck_dict, SaveData.deck_file_header(true)):
			saved_ydc_name = safe_name

	if is_instance_valid(Online) and Online.is_logged_in():
		Online.sync_collection_now()

	if cover_cid >= 0:
		_code_card_tex.texture = CardDB.card_texture(cover_cid, false)
	_code_card_title.text = "📦 %s" % deck_label

	var used_n := int(gift_res.get("usedCount", 1))
	var max_n := int(gift_res.get("maxUses", 1))
	var rem_n := int(gift_res.get("remaining", 0))
	_code_status.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
	_code_status.text = _tr(
		"🎁 تم استلام مجموعة الهدية بنجاح! (+%d بطاقة · %d / %d · المتبقي: %d)",
		"🎁 ¡Mazo de regalo canjeado! (+%d cartas · %d / %d · Restantes: %d)",
		"🎁 Gift deck claimed! (+%d cards · %d / %d · Remaining: %d)"
	) % [total_added, used_n, max_n, rem_n]

	var sub_txt := _tr(
		"كود الهدية: %s · أضيفت %d بطاقة إلى المستودع",
		"Regalo: %s · %d cartas añadidas al baúl",
		"Gift: %s · %d cards added to trunk"
	) % [gcode, total_added]
	if saved_ydc_name != "":
		sub_txt += _tr(
			"\nتم حفظ المجموعة الجاهزة للاستيراد: %s.ydc",
			"\nMazo guardado listo para importar: %s.ydc",
			"\nSaved deck ready to import: %s.ydc"
		) % saved_ydc_name
	_code_card_sub.text = sub_txt
	_apply_card_desc_label(_code_card_desc, cover_cid)
	_code_input.text = ""
	if cover_cid >= 0:
		card_unlocked.emit(cover_cid)


func _redeem_unlock_all_gift(raw_entry: String, gift_res: Dictionary) -> void:
	if SaveData.data.is_empty():
		SaveData.load_or_create()
	SaveData.unlock_all()
	SaveData.data["all_cards_unlocked"] = true
	SaveData.save()
	if is_instance_valid(Online):
		Online.mark_all_cards_unlocked()
		if Online.is_logged_in():
			Online.sync_collection_now()

	var cover_cid := 0
	if CardDB.cards.is_empty():
		CardDB.load_db()
	if not CardDB.by_id(0).is_empty():
		_code_card_tex.texture = CardDB.card_texture(0, false)
	elif not CardDB.by_id(34).is_empty():
		cover_cid = 34
		_code_card_tex.texture = CardDB.card_texture(34, false)
	else:
		_code_card_tex.texture = null

	var gcode := str(gift_res.get("code", raw_entry))
	var used_n := int(gift_res.get("usedCount", 1))
	var max_n := int(gift_res.get("maxUses", 1))
	var rem_n := int(gift_res.get("remaining", 0))
	_code_card_title.text = _tr("🔓 تم فتح جميع البطاقات!", "🔓 ¡Todas las cartas desbloqueadas!", "🔓 All Cards Unlocked!")
	_code_status.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
	_code_status.text = _tr(
		"🎁 تم تفعيل كود فتح كل البطاقات بنجاح! (3 نسخ لكل بطاقة · %d / %d · المتبقي: %d)",
		"🎁 ¡Código de todas las cartas canjeado! (3 copias · %d / %d · Restantes: %d)",
		"🎁 Unlock All Cards code redeemed! (3 copies each · %d / %d · Remaining: %d)"
	) % [used_n, max_n, rem_n]
	_code_card_sub.text = _tr(
		"الكود: %s\nلضمان العدل في الأونلاين، تم نقل حسابك إلى «🧪 وضع اختبار المجموعات» بدلاً من وضع المنافسة.",
		"Código: %s\nPara mantener el juego justo, tu cuenta pasó al servidor «🧪 Prueba de Mazos» en Online.",
		"Code: %s\nTo keep Online fair, your account is now placed in the «🧪 Deck Testing» server pool."
	) % gcode
	_code_card_desc.text = ""
	_code_card_desc.hide()
	_code_input.text = ""
	card_unlocked.emit(cover_cid)


# --- Lucky Wheels (4-Hour Single Card + 2-Hour Complete Sets) -----------------

func _build_wheel_panel() -> void:
	var panel_box := _panel_style()
	panel_box.set_content_margin_all(12)
	_wheel_panel.add_theme_stylebox_override("panel", panel_box)
	_wheel_panel.custom_minimum_size = Vector2(660, 444)
	_wheel_panel.hide()
	add_child(_wheel_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(632, 0)
	root.add_theme_constant_override("separation", 6)
	_wheel_panel.add_child(root)

	# Top mode tabs
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	root.add_child(tabs)

	_tab_single_btn = Button.new()
	_tab_single_btn.pressed.connect(func() -> void: _switch_wheel_mode("single"))
	tabs.add_child(_tab_single_btn)

	_tab_special_btn = Button.new()
	_tab_special_btn.pressed.connect(func() -> void: _switch_wheel_mode("sets"))
	tabs.add_child(_tab_special_btn)

	_wheel_title = Label.new()
	_wheel_title.add_theme_font_override("font", Assets.ui_font(700))
	_wheel_title.add_theme_font_size_override("font_size", 18)
	_wheel_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	_wheel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_wheel_title)

	_wheel_badge = Label.new()
	_wheel_badge.add_theme_font_override("font", Assets.ui_font(700))
	_wheel_badge.add_theme_font_size_override("font_size", 11)
	_wheel_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.36))
	_wheel_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_badge.hide()
	root.add_child(_wheel_badge)

	_wheel_hint = Label.new()
	_wheel_hint.custom_minimum_size = Vector2(610, 0)
	_wheel_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_hint.add_theme_font_override("font", Assets.ui_font())
	_wheel_hint.add_theme_font_size_override("font_size", 12)
	_wheel_hint.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_wheel_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_wheel_hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(body)

	_wheel_canvas = WheelCanvas.new()
	_wheel_canvas.custom_minimum_size = Vector2(236, 236)
	_wheel_canvas.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wheel_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(_wheel_canvas)

	var card_box := PanelContainer.new()
	card_box.add_theme_stylebox_override("panel", _subbox_style())
	card_box.custom_minimum_size = Vector2(304, 248)
	card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(card_box)

	var c_col := VBoxContainer.new()
	c_col.custom_minimum_size = Vector2(280, 0)
	c_col.add_theme_constant_override("separation", 4)
	c_col.alignment = BoxContainer.ALIGNMENT_CENTER
	card_box.add_child(c_col)

	_wheel_card_tex = TextureRect.new()
	_wheel_card_tex.custom_minimum_size = Vector2(82, 120)
	_wheel_card_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wheel_card_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_wheel_card_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c_col.add_child(_wheel_card_tex)

	_wheel_card_name = Label.new()
	_wheel_card_name.custom_minimum_size = Vector2(272, 20)
	_wheel_card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_card_name.add_theme_font_override("font", Assets.ui_font(700))
	_wheel_card_name.add_theme_font_size_override("font_size", 14)
	_wheel_card_name.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_wheel_card_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_col.add_child(_wheel_card_name)

	_wheel_card_meta = Label.new()
	_wheel_card_meta.custom_minimum_size = Vector2(272, 18)
	_wheel_card_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_card_meta.add_theme_font_override("font", Assets.ui_font())
	_wheel_card_meta.add_theme_font_size_override("font_size", 11)
	_wheel_card_meta.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_wheel_card_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_card_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c_col.add_child(_wheel_card_meta)

	_wheel_card_desc = RichTextLabel.new()
	_wheel_card_desc.custom_minimum_size = Vector2(272, 62)
	_wheel_card_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_card_desc.bbcode_enabled = true
	_wheel_card_desc.scroll_active = true
	_wheel_card_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wheel_card_desc.add_theme_font_override("normal_font", Assets.ui_font())
	_wheel_card_desc.add_theme_font_override("bold_font", Assets.ui_font(700))
	_wheel_card_desc.add_theme_font_size_override("normal_font_size", 11)
	_wheel_card_desc.add_theme_font_size_override("bold_font_size", 11)
	_wheel_card_desc.add_theme_constant_override("line_separation", 2)
	_wheel_card_desc.add_theme_color_override("default_color", Color(0.92, 0.95, 1.0))
	c_col.add_child(_wheel_card_desc)

	_wheel_cards_list = RichTextLabel.new()
	_wheel_cards_list.custom_minimum_size = Vector2(272, 62)
	_wheel_cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_cards_list.add_theme_font_override("normal_font", Assets.ui_font())
	_wheel_cards_list.add_theme_font_size_override("normal_font_size", 11)
	_wheel_cards_list.add_theme_color_override("default_color", Color(0.86, 0.92, 1.0))
	_wheel_cards_list.hide()
	c_col.add_child(_wheel_cards_list)

	_wheel_status = Label.new()
	_wheel_status.custom_minimum_size = Vector2(610, 20)
	_wheel_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel_status.add_theme_font_override("font", Assets.ui_font(700))
	_wheel_status.add_theme_font_size_override("font_size", 12)
	_wheel_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wheel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_wheel_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	root.add_child(actions)

	_wheel_spin_btn = Button.new()
	_wheel_spin_btn.custom_minimum_size = Vector2(204, 36)
	_wheel_spin_btn.pressed.connect(_on_spin_pressed)
	_style_btn(_wheel_spin_btn, true)
	actions.add_child(_wheel_spin_btn)

	_wheel_close_btn = Button.new()
	_wheel_close_btn.custom_minimum_size = Vector2(102, 36)
	_wheel_close_btn.pressed.connect(close_all)
	_style_btn(_wheel_close_btn, false)
	actions.add_child(_wheel_close_btn)


func _ensure_pool() -> void:
	if not _eligible_pool.is_empty():
		return
	if CardDB.cards.is_empty():
		CardDB.load_db()
	for card: Dictionary in CardDB.cards:
		if card.get("image") != null and int(card.get("pack", 0)) != 0:
			_eligible_pool.append(card)
	_eligible_pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("internal_id", 0)) < int(b.get("internal_id", 0)))


static func _current_wheel_bucket() -> int:
	return int(Time.get_unix_time_from_system()) / WHEEL_COOLDOWN_SEC


static func _seconds_until_next_wheel_rotation() -> int:
	var now := int(Time.get_unix_time_from_system())
	var rem := WHEEL_COOLDOWN_SEC - (now % WHEEL_COOLDOWN_SEC)
	return maxi(1, rem)


func open_lucky_wheel() -> void:
	if _spinning:
		return
	_code_panel.hide()
	_admin_panel.hide()
	_ready_decks_panel.hide()
	_ensure_pool()
	_switch_wheel_mode("single")
	_backdrop.show()
	_wheel_panel.show()
	_center_panel(_wheel_panel)
	_center_panel.call_deferred(_wheel_panel)


func open_special_wheel() -> void:
	open_ready_decks()


func open_special_wheel_spin() -> void:
	if _spinning:
		return
	_code_panel.hide()
	_admin_panel.hide()
	_ready_decks_panel.hide()
	_ensure_pool()
	_switch_wheel_mode("sets")
	_backdrop.show()
	_wheel_panel.show()
	_center_panel(_wheel_panel)
	_center_panel.call_deferred(_wheel_panel)


func _populate_wheel_slices() -> void:
	_ensure_pool()
	_wheel_slices.clear()
	var bucket := _current_wheel_bucket()
	_wheel_rotation_bucket = bucket
	var labels: Array[String] = []
	var textures: Array[Texture2D] = []
	if _eligible_pool.is_empty():
		for i in 10:
			labels.append(_tr("بطاقة #%d", "Carta #%d", "Card #%d") % (i + 1))
			textures.append(null)
		_wheel_canvas.slice_labels = labels
		_wheel_canvas.slice_textures = textures
		return
	var bucket_rng := RandomNumberGenerator.new()
	bucket_rng.seed = int(bucket) * 2654435761 + 1400
	var used_ids: Dictionary = {}
	var count := mini(10, _eligible_pool.size())
	var guard := 0
	while _wheel_slices.size() < count and guard < 2000:
		guard += 1
		var cand: Dictionary = _eligible_pool[bucket_rng.randi_range(0, _eligible_pool.size() - 1)]
		var cid := int(cand.get("internal_id", -1))
		if cid < 0 or used_ids.has(cid):
			continue
		used_ids[cid] = true
		_wheel_slices.append(cand)
	while _wheel_slices.size() < 10:
		_wheel_slices.append(_eligible_pool[bucket_rng.randi_range(0, _eligible_pool.size() - 1)])
	_pending_slice_ids.clear()
	_pending_slice_cursor = 0
	for card: Dictionary in _wheel_slices:
		var cid := int(card.get("internal_id", -1))
		labels.append(CardDB.name_of(cid))
		textures.append(null)
		_pending_slice_ids.append(cid)
	_wheel_canvas.slice_labels = labels
	_wheel_canvas.slice_textures = textures


func _step_pending_slice_textures(max_per_frame := 2) -> void:
	if _pending_slice_cursor >= _pending_slice_ids.size() or not Paths.has_data():
		return
	if is_instance_valid(Assets) and Assets._card_pack_mirroring:
		return
	var loaded := 0
	while _pending_slice_cursor < _pending_slice_ids.size() and loaded < max_per_frame:
		var idx := _pending_slice_cursor
		_pending_slice_cursor += 1
		var cid := _pending_slice_ids[idx]
		if cid >= 0 and idx < _wheel_canvas.slice_textures.size() and not CardDB.by_id(cid).is_empty():
			_wheel_canvas.slice_textures[idx] = CardDB.card_texture(cid, true)
			loaded += 1


func _show_wheel_slice(index: int) -> void:
	if _wheel_slices.is_empty():
		return
	var idx := posmod(index, _wheel_slices.size())
	_active_slice_index = idx
	var card: Dictionary = _wheel_slices[idx]
	var cid := int(card.get("internal_id", -1))
	if Paths.has_data() and cid >= 0:
		_wheel_card_tex.texture = CardDB.card_texture(cid, false)
	else:
		_wheel_card_tex.texture = null
	_wheel_card_name.text = CardDB.name_of(cid)
	var owned := SaveData.card_count(cid) if is_instance_valid(SaveData) and not SaveData.data.is_empty() else 0
	_wheel_card_meta.text = _tr(
		"البطاقة %d / 10 على العجلة · في مستودعك: %d",
		"Carta %d / 10 en la ruleta · En tu baúl: %d",
		"Card %d / 10 on wheel · Owned: %d"
	) % [idx + 1, owned]
	_apply_card_desc_label(_wheel_card_desc, cid)


func _switch_wheel_mode(mode: String) -> void:
	if _spinning:
		return
	if mode == "sets_beta":
		mode = "sets"
	_wheel_mode = mode
	_ui_tick_accum = 0.0
	_tab_single_btn.text = _tr("🎡 عجلة البطاقة (10 بطاقات)", "🎡 Ruleta Carta (10 cartas)", "🎡 10-Card Lucky Wheel")
	_tab_special_btn.text = _tr("👑 عجلة المجموعات (كل ساعتين)", "👑 Ruleta de Mazos (2h)", "👑 Complete Sets Wheel (2h)")
	_style_btn(_tab_single_btn, mode == "single", false)
	_style_btn(_tab_special_btn, mode == "sets", true)
	_wheel_close_btn.text = _tr("إغلاق", "Cerrar", "Close")

	if mode == "sets":
		_wheel_canvas.special_mode = true
		_wheel_canvas.segment_count = SPECIAL_SETS.size()
		var cols: Array[Color] = []
		var set_labels: Array[String] = []
		var set_textures: Array[Texture2D] = []
		_pending_slice_ids.clear()
		_pending_slice_cursor = 0
		for s: Dictionary in SPECIAL_SETS:
			cols.append(s["accent"])
			set_labels.append(_set_title(s))
			var cov := int(s["cover_id"])
			set_textures.append(null)
			_pending_slice_ids.append(cov)
		_wheel_canvas.segment_colors = cols
		_wheel_canvas.slice_labels = set_labels
		_wheel_canvas.slice_textures = set_textures
		_wheel_canvas.won_flash = 0.0
		_wheel_title.text = _tr("👑 عجلة المجموعات الكاملة", "👑 Ruleta de Mazos Completos", "👑 Complete-Sets Wheel")
		_wheel_badge.text = _tr("✨ لفة مجانية كل ساعتين · تُفتح البطاقات وتُحفظ المجموعة فوراً ✨", "✨ Giro gratis cada 2 horas · Se desbloquea y guarda al instante ✨", "✨ Free spin every 2 hours · Unlocks & saves deck instantly ✨")
		_wheel_badge.show()
		_wheel_hint.text = _tr(
			"لف العجلة للفوز بمجموعة كاملة دفعة واحدة (مثل: عالم الكرتون، إكسوديا، ساحر الظلام، التنين الأبيض...) وتصديرها إلى واجهة الدكات!",
			"Gira la ruleta para ganar un mazo completo de una sola vez (Mundo Toon, Exodia, Mago Oscuro...) y exportarlo al editor.",
			"Spin to win an entire themed set at once (Toon World, Exodia, Dark Magician, Blue-Eyes...) and export it straight to Deck Editor!"
		)
		_wheel_card_desc.hide()
		_wheel_cards_list.show()
		_style_btn(_wheel_spin_btn, true, true)
		_show_special_set(_active_set_index)
	else:
		_wheel_canvas.special_mode = false
		_wheel_canvas.segment_count = 10
		_wheel_canvas.segment_colors = []
		_wheel_canvas.won_flash = 0.0
		_populate_wheel_slices()
		_wheel_title.text = _tr("🎡 عجلة الحظ (10 بطاقات)", "🎡 Ruleta de la Suerte (10 Cartas)", "🎡 10-Card Lucky Wheel")
		_wheel_badge.hide()
		_update_single_wheel_hint()
		_wheel_cards_list.hide()
		_style_btn(_wheel_spin_btn, true, false)
		if not _wheel_slices.is_empty():
			_show_wheel_slice(_wheel_canvas.current_pointer_index())
		else:
			_wheel_card_tex.texture = Assets.texture("common/card/card_ura.png") if Paths.has_data() else null
			_wheel_card_name.text = _tr("اضغط لبدء اللف!", "¡Pulsa para girar!", "Press Spin to Roll!")
			_wheel_card_meta.text = _tr("تتبدل الـ 10 بطاقات تلقائياً كل 4 ساعات", "Las 10 cartas cambian automáticamente cada 4 horas", "The 10 cards rotate automatically every 4 hours")
			_wheel_card_desc.text = ""
			_wheel_card_desc.hide()
	_refresh_wheel_cooldown_ui()
	_wheel_canvas.queue_redraw()
	if _wheel_panel.visible:
		_center_panel.call_deferred(_wheel_panel)


func _set_title(entry: Dictionary) -> String:
	var lang: String = Assets.lang if is_instance_valid(Assets) else "e"
	if lang == "a":
		return str(entry["ar"])
	return str(entry["es"]) if lang == "s" else str(entry["en"])


func _show_special_set(index: int) -> void:
	var idx := posmod(index, SPECIAL_SETS.size())
	var entry: Dictionary = SPECIAL_SETS[idx]
	var cover_id := int(entry["cover_id"])
	var card_ids: Array = entry["cards"]
	if Paths.has_data() and not CardDB.by_id(cover_id).is_empty():
		_wheel_card_tex.texture = CardDB.card_texture(cover_id, false)
	else:
		_wheel_card_tex.texture = Assets.texture("common/card/card_ura.png") if Paths.has_data() else null
	_wheel_card_name.text = _set_title(entry)
	_wheel_card_meta.text = _tr(
		"تحتوي على %d بطاقات أساسية + إكمال المجموعة إلى 40 بطاقة",
		"Contiene %d cartas clave + mazo completo de 40 cartas",
		"Contains %d core cards + full 40-card deck"
	) % card_ids.size()
	var lines: Array[String] = []
	for raw_id: Variant in card_ids:
		var cid := int(raw_id)
		var cname := CardDB.name_of(cid) if Paths.has_data() and not CardDB.by_id(cid).is_empty() else ("Card #%d" % cid)
		lines.append("• " + cname)
	_wheel_cards_list.text = "\n".join(lines)


func _update_single_wheel_hint() -> void:
	if _wheel_mode != "single":
		return
	var next_rot := format_duration(_seconds_until_next_wheel_rotation())
	var wanted := _tr(
		"البطاقة التي يتوقف عليها السهم تُضاف فوراً إلى مستودعك · تتبدل بطاقات العجلة تلقائياً كل 4 ساعات (التبديل القادم بعد: %s)",
		"La carta donde se detenga la flecha se añade directo a tu baúl · Cambian solas cada 4 h (próximo cambio: %s)",
		"The card under the arrow is added straight to your trunk · Wheel cards rotate automatically every 4h (next refresh: %s)"
	) % next_rot
	if _wheel_hint.text != wanted:
		_wheel_hint.text = wanted


func _refresh_wheel_cooldown_ui() -> void:
	if _spinning:
		_tab_single_btn.disabled = true
		_tab_special_btn.disabled = true
		_wheel_spin_btn.disabled = true
		_wheel_close_btn.disabled = true
		var spin_txt := _tr("جارٍ اللف…", "Girando…", "Spinning…")
		if _wheel_spin_btn.text != spin_txt:
			_wheel_spin_btn.text = spin_txt
		return
	_tab_single_btn.disabled = false
	_tab_special_btn.disabled = false
	_wheel_close_btn.disabled = false

	if _wheel_mode == "sets":
		if not Paths.has_data():
			_wheel_spin_btn.disabled = true
			var no_data_btn := _tr("غير متاح الآن", "No disponible", "Unavailable")
			if _wheel_spin_btn.text != no_data_btn:
				_wheel_spin_btn.text = no_data_btn
			_wheel_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
			_wheel_status.text = _tr("قم باستيراد موارد اللعبة أولاً لتفعيل عجلة المجموعات.", "Importa los recursos del juego primero.", "Import game resources first to enable the Sets Wheel.")
			return
		var rem_sets := sets_remaining_cooldown_sec()
		if rem_sets <= 0:
			_wheel_spin_btn.disabled = false
			var ready_sets_btn := _tr("👑 لف عجلة المجموعات الآن!", "👑 ¡Girar Ruleta de Mazos!", "👑 Spin Sets Wheel!")
			if _wheel_spin_btn.text != ready_sets_btn:
				_wheel_spin_btn.text = ready_sets_btn
			_wheel_status.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
			var ready_sets_status := _tr(
				"عجلة المجموعات جاهزة! اربح مجموعة كاملة مجاناً كل ساعتين.",
				"¡Ruleta de mazos lista! Gana un mazo completo gratis cada 2 horas.",
				"Sets Wheel is ready! Win a full complete set free every 2 hours."
			)
			if _wheel_status.text != ready_sets_status:
				_wheel_status.text = ready_sets_status
		else:
			_wheel_spin_btn.disabled = true
			var fmt_sets := format_duration(rem_sets)
			var wait_sets_btn := _tr("⏳ متبقي %s", "⏳ Faltan %s", "⏳ %s left") % fmt_sets
			if _wheel_spin_btn.text != wait_sets_btn:
				_wheel_spin_btn.text = wait_sets_btn
			_wheel_status.add_theme_color_override("font_color", DialogTheme.GOLD)
			var wait_sets_status := _tr(
				"اللفة القادمة لعجلة المجموعات متاحة بعد: %s (مرة كل ساعتين)",
				"Próximo giro de mazos disponible en: %s (cada 2 horas)",
				"Next Sets Wheel spin ready in: %s (every 2 hours)"
			) % fmt_sets
			if _wheel_status.text != wait_sets_status:
				_wheel_status.text = wait_sets_status
		return

	if not Paths.has_data() or _eligible_pool.is_empty():
		_wheel_spin_btn.disabled = true
		var unavail_btn := _tr("غير متاح الآن", "No disponible", "Unavailable")
		if _wheel_spin_btn.text != unavail_btn:
			_wheel_spin_btn.text = unavail_btn
		_wheel_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.45))
		var unavail_status := _tr("قم باستيراد موارد اللعبة أولاً لتفعيل عجلة الحظ.", "Importa los recursos del juego primero.", "Import game resources first to enable the Lucky Wheel.")
		if _wheel_status.text != unavail_status:
			_wheel_status.text = unavail_status
		return
	var rem := remaining_cooldown_sec()
	if rem <= 0:
		_wheel_spin_btn.disabled = false
		var ready_btn := _tr("✨ لف العجلة الآن!", "✨ ¡Girar Ruleta!", "✨ Spin the Wheel!")
		if _wheel_spin_btn.text != ready_btn:
			_wheel_spin_btn.text = ready_btn
		_wheel_status.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
		var ready_status := _tr("العجلة جاهزة! احصل على بطاقتك العشوائية المجانية.", "¡Ruleta lista! Consigue tu carta aleatoria.", "Wheel is ready! Spin for a free random card.")
		if _wheel_status.text != ready_status:
			_wheel_status.text = ready_status
	else:
		_wheel_spin_btn.disabled = true
		var formatted := format_duration(rem)
		var wait_btn := _tr("⏳ متبقي %s", "⏳ Faltan %s", "⏳ %s left") % formatted
		if _wheel_spin_btn.text != wait_btn:
			_wheel_spin_btn.text = wait_btn
		_wheel_status.add_theme_color_override("font_color", DialogTheme.GOLD)
		var wait_status := _tr(
			"اللفة القادمة متاحة بعد: %s (مرة كل 4 ساعات)",
			"Próximo giro disponible en: %s (cada 4 horas)",
			"Next spin ready in: %s (every 4 hours)"
		) % formatted
		if _wheel_status.text != wait_status:
			_wheel_status.text = wait_status


func _on_spin_pressed() -> void:
	if _spinning:
		return
	if _wheel_mode == "sets":
		if sets_remaining_cooldown_sec() > 0 or not Paths.has_data():
			_refresh_wheel_cooldown_ui()
			return
		if SaveData.data.is_empty():
			SaveData.load_or_create()
		_won_set_index = _rng.randi_range(0, SPECIAL_SETS.size() - 1)
		var now_sets := int(Time.get_unix_time_from_system())
		var sets_data: Dictionary = SaveData.data.get_or_add("sets_wheel", {})
		sets_data["last_spin"] = now_sets
		sets_data["last_set_id"] = str(SPECIAL_SETS[_won_set_index].get("id", ""))
		sets_data["total_spins"] = int(sets_data.get("total_spins", 0)) + 1
		SaveData.save()
		var sets_cfg := ConfigFile.new()
		sets_cfg.load(Paths.settings_path())
		sets_cfg.set_value("launcher", "sets_wheel_last_spin", now_sets)
		sets_cfg.save(Paths.settings_path())
		_cached_sets_last_spin_unix = now_sets
		_spinning = true
		_spin_elapsed = 0.0
		_spin_tick_clock = 0.0
		_spin_tick_step = 0.055
		_spin_start_angle = fmod(_wheel_canvas.angle, TAU)
		var step := TAU / float(SPECIAL_SETS.size())
		# Land cleanly so segment `_won_set_index` stops under the top pointer
		var target_offset := -((float(_won_set_index) + 0.5) * step)
		var extra_turns := TAU * float(_rng.randi_range(6, 8))
		_spin_target_angle = _spin_start_angle + extra_turns + fposmod(target_offset - _spin_start_angle, TAU)
		_wheel_canvas.spinning = true
		_wheel_canvas.won_flash = 0.0
		_wheel_status.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
		_wheel_status.text = _tr("جارٍ لف عجلة المجموعات الكاملة…", "Girando la ruleta de mazos completos…", "Spinning the Complete Sets Wheel…")
		_refresh_wheel_cooldown_ui()
		return

	if remaining_cooldown_sec() > 0:
		return
	_ensure_pool()
	if _eligible_pool.is_empty() or not Paths.has_data():
		return
	if _wheel_slices.size() != 10 or _current_wheel_bucket() != _wheel_rotation_bucket:
		_populate_wheel_slices()
	if SaveData.data.is_empty():
		SaveData.load_or_create()
	_won_slice_index = _rng.randi_range(0, _wheel_slices.size() - 1)
	var pick: Dictionary = _wheel_slices[_won_slice_index]
	var won_id := int(pick.get("internal_id", -1))
	if won_id < 0:
		return
	var now := int(Time.get_unix_time_from_system())
	SaveData.add_card(won_id, 1)
	var wheel_data: Dictionary = SaveData.data.get_or_add("wheel", {})
	wheel_data["last_spin"] = now
	wheel_data["last_card_id"] = won_id
	wheel_data["total_spins"] = int(wheel_data.get("total_spins", 0)) + 1
	SaveData.save()
	var cfg := ConfigFile.new()
	cfg.load(Paths.settings_path())
	cfg.set_value("launcher", "wheel_last_spin", now)
	cfg.save(Paths.settings_path())
	_cached_last_spin_unix = now

	_won_card = pick
	_spinning = true
	_spin_elapsed = 0.0
	_spin_tick_clock = 0.0
	_spin_tick_step = 0.045
	_spin_start_angle = fmod(_wheel_canvas.angle, TAU)
	var step := TAU / float(_wheel_slices.size())
	var jitter := _rng.randf_range(-0.28, 0.28) * step
	var target_offset := -((float(_won_slice_index) + 0.5) * step) + jitter
	var extra_turns := TAU * float(_rng.randi_range(7, 9))
	_spin_target_angle = _spin_start_angle + extra_turns + fposmod(target_offset - _spin_start_angle, TAU)
	_wheel_canvas.spinning = true
	_wheel_canvas.won_flash = 0.0
	_wheel_status.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_wheel_status.text = _tr("العجلة تدور الآن بين الـ 10 بطاقات…", "La ruleta gira entre las 10 cartas…", "Spinning across the 10 cards on the wheel…")
	_refresh_wheel_cooldown_ui()


func _process(delta: float) -> void:
	if not _wheel_panel.visible:
		return
	_step_pending_slice_textures(2)
	_wheel_canvas.glow_phase += delta
	if _wheel_canvas.won_flash > 0.0:
		_wheel_canvas.won_flash = maxf(0.0, _wheel_canvas.won_flash - delta)
	if _spinning:
		_spin_elapsed += delta
		var t := clampf(_spin_elapsed / SPIN_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - t, 3.3)
		_wheel_canvas.angle = lerpf(_spin_start_angle, _spin_target_angle, eased)
		var ptr_idx := _wheel_canvas.current_pointer_index()
		if _wheel_mode == "sets":
			if ptr_idx != _active_set_index:
				_active_set_index = ptr_idx
				_show_special_set(_active_set_index)
		elif not _wheel_slices.is_empty():
			if ptr_idx != _active_slice_index:
				_show_wheel_slice(ptr_idx)
		if t >= 1.0:
			_finish_spin()
	elif _wheel_mode == "single":
		_ui_tick_accum += delta
		if _ui_tick_accum >= 0.5:
			_ui_tick_accum = 0.0
			if _current_wheel_bucket() != _wheel_rotation_bucket:
				_populate_wheel_slices()
				_show_wheel_slice(_wheel_canvas.current_pointer_index())
			_update_single_wheel_hint()
			_refresh_wheel_cooldown_ui()
	elif _wheel_mode == "sets":
		_ui_tick_accum += delta
		if _ui_tick_accum >= 0.5:
			_ui_tick_accum = 0.0
			_refresh_wheel_cooldown_ui()
	_wheel_canvas.queue_redraw()


func _finish_spin() -> void:
	_spinning = false
	_wheel_canvas.spinning = false
	_wheel_canvas.won_flash = 2.0
	if _wheel_mode == "sets":
		_active_set_index = _won_set_index
		_show_special_set(_won_set_index)
		var entry: Dictionary = SPECIAL_SETS[_won_set_index]
		var full_deck := _build_special_set_full_deck(entry)
		var export_name = "Set_" + str(entry.get("id", "ready"))
		var res := SaveData.apply_ready_made_deck(full_deck, export_name, true)
		_refresh_wheel_cooldown_ui()
		_wheel_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.68))
		_wheel_status.text = _tr(
			"🎉 مبروك! تم فتح جميع البطاقات وحفظ «%s.ydc» (%d بطاقة) وتصديرها لواجهة الدكات وتفعيلها!",
			"🎉 ¡Mazo «%s.ydc» (%d cartas) guardado, exportado y activado con todas las cartas!",
			"🎉 Unlocked all cards, saved \"%s.ydc\" (%d cards), and exported to Deck Editor!"
		) % [str(res.get("name", export_name)), int(res.get("main_count", 40))]
		if is_instance_valid(Online) and Online.is_logged_in():
			Online.sync_collection_now()
		card_unlocked.emit(int(entry.get("cover_id", 0)))
		return

	var cid := int(_won_card.get("internal_id", -1))
	var ar_name := CardDB.name_of(cid, "ara")
	var en_name := CardDB.name_of(cid, "eng")
	var owned := SaveData.card_count(cid)
	_wheel_card_tex.texture = CardDB.card_texture(cid, false)
	_wheel_card_name.text = ("%s\n%s" % [ar_name, en_name]) if ar_name != en_name else en_name
	_wheel_card_meta.text = _tr("✓ تمت إضافتها مباشرةً إلى مستودعك · لديك الآن: %d نسخة", "✓ Añadida directo a tu baúl · Tienes: %d", "✓ Added directly to your trunk · Owned: %d") % owned
	_apply_card_desc_label(_wheel_card_desc, cid)
	_refresh_wheel_cooldown_ui()
	_wheel_status.add_theme_color_override("font_color", Color(0.45, 1.0, 0.68))
	_wheel_status.text = _tr(
		"🎉 مبروك! تمت إضافة البطاقة مباشرة إلى مستودع البطاقات!",
		"🎉 ¡Felicidades! Carta añadida directamente a tu baúl.",
		"🎉 Won! Card added directly to your card trunk!"
	)
	if is_instance_valid(Online) and Online.is_logged_in():
		Online.sync_collection_now()
	card_unlocked.emit(cid)


# --- Admin Gift Code Creator Modal (Protected by ADMIN_PASSCODE) -------------

func _build_admin_panel() -> void:
	var panel_box := _panel_style()
	panel_box.set_content_margin_all(12)
	panel_box.border_color = DialogTheme.GOLD
	_admin_panel.add_theme_stylebox_override("panel", panel_box)
	_admin_panel.custom_minimum_size = Vector2(660, 444)
	_admin_panel.hide()
	add_child(_admin_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(632, 0)
	root.add_theme_constant_override("separation", 6)
	_admin_panel.add_child(root)

	_admin_title = Label.new()
	_admin_title.add_theme_font_override("font", Assets.ui_font(700))
	_admin_title.add_theme_font_size_override("font_size", 19)
	_admin_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	_admin_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_admin_title)

	# --- Login Box (when not authenticated as admin) ---
	_admin_login_box = VBoxContainer.new()
	_admin_login_box.custom_minimum_size = Vector2(560, 0)
	_admin_login_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_admin_login_box.add_theme_constant_override("separation", 12)
	root.add_child(_admin_login_box)

	_admin_login_hint = Label.new()
	_admin_login_hint.custom_minimum_size = Vector2(520, 0)
	_admin_login_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_login_hint.add_theme_font_override("font", Assets.ui_font())
	_admin_login_hint.add_theme_font_size_override("font_size", 14)
	_admin_login_hint.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_admin_login_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_admin_login_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_login_box.add_child(_admin_login_hint)

	var login_row := HBoxContainer.new()
	login_row.add_theme_constant_override("separation", 10)
	_admin_login_box.add_child(login_row)

	_admin_pass_input = LineEdit.new()
	_admin_pass_input.secret = true
	_admin_pass_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_pass_input.max_length = 80
	_admin_pass_input.text_submitted.connect(func(_t: String) -> void: _on_admin_login_pressed())
	_style_input(_admin_pass_input)
	login_row.add_child(_admin_pass_input)

	_admin_login_btn = Button.new()
	_admin_login_btn.custom_minimum_size = Vector2(150, 40)
	_admin_login_btn.pressed.connect(_on_admin_login_pressed)
	_style_btn(_admin_login_btn, true, true)
	login_row.add_child(_admin_login_btn)

	_admin_login_status = Label.new()
	_admin_login_status.custom_minimum_size = Vector2(520, 22)
	_admin_login_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_login_status.add_theme_font_override("font", Assets.ui_font(700))
	_admin_login_status.add_theme_font_size_override("font_size", 13)
	_admin_login_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_admin_login_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_login_box.add_child(_admin_login_status)

	var login_footer := HBoxContainer.new()
	login_footer.alignment = BoxContainer.ALIGNMENT_END
	_admin_login_box.add_child(login_footer)

	_admin_login_close_btn = Button.new()
	_admin_login_close_btn.pressed.connect(close_all)
	_style_btn(_admin_login_close_btn, false)
	login_footer.add_child(_admin_login_close_btn)

	# --- Workspace Box (authenticated admin) ---
	_admin_work_box = VBoxContainer.new()
	_admin_work_box.custom_minimum_size = Vector2(648, 0)
	_admin_work_box.add_theme_constant_override("separation", 8)
	_admin_work_box.hide()
	root.add_child(_admin_work_box)

	var form_frame := PanelContainer.new()
	form_frame.add_theme_stylebox_override("panel", _subbox_style())
	_admin_work_box.add_child(form_frame)

	var form_v := VBoxContainer.new()
	form_v.custom_minimum_size = Vector2(616, 0)
	form_v.add_theme_constant_override("separation", 8)
	form_frame.add_child(form_v)

	# Row 0: Reward Type Mode Tabs (Single Card vs Full Deck/Pack vs Unlock All Cards)
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	form_v.add_child(mode_row)

	_admin_mode_card_btn = Button.new()
	_admin_mode_card_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_mode_card_btn.custom_minimum_size = Vector2(0, 34)
	_admin_mode_card_btn.pressed.connect(func() -> void: _set_admin_mode("card"))
	_style_btn(_admin_mode_card_btn, true)
	mode_row.add_child(_admin_mode_card_btn)

	_admin_mode_deck_btn = Button.new()
	_admin_mode_deck_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_mode_deck_btn.custom_minimum_size = Vector2(0, 34)
	_admin_mode_deck_btn.pressed.connect(func() -> void: _set_admin_mode("deck"))
	_style_btn(_admin_mode_deck_btn, false)
	mode_row.add_child(_admin_mode_deck_btn)

	_admin_mode_unlock_btn = Button.new()
	_admin_mode_unlock_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_mode_unlock_btn.custom_minimum_size = Vector2(0, 34)
	_admin_mode_unlock_btn.pressed.connect(func() -> void: _set_admin_mode("unlock_all"))
	_style_btn(_admin_mode_unlock_btn, false)
	mode_row.add_child(_admin_mode_unlock_btn)

	# Row 1: Gift code + Random + Max Uses + Copies (touch-safe cycle button)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	form_v.add_child(row1)

	_admin_gift_code_input = LineEdit.new()
	_admin_gift_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_gift_code_input.max_length = 32
	_style_input(_admin_gift_code_input)
	row1.add_child(_admin_gift_code_input)

	_admin_random_btn = Button.new()
	_admin_random_btn.custom_minimum_size = Vector2(96, 38)
	_admin_random_btn.pressed.connect(_on_admin_random_code)
	_style_btn(_admin_random_btn, false)
	row1.add_child(_admin_random_btn)

	_admin_max_uses_input = LineEdit.new()
	_admin_max_uses_input.custom_minimum_size = Vector2(96, 38)
	_admin_max_uses_input.max_length = 6
	_admin_max_uses_input.text = "10"
	_style_input(_admin_max_uses_input)
	row1.add_child(_admin_max_uses_input)

	_admin_copies_btn = Button.new()
	_admin_copies_btn.custom_minimum_size = Vector2(92, 38)
	_admin_copies_btn.pressed.connect(_on_admin_cycle_copies)
	_style_btn(_admin_copies_btn, false)
	_update_admin_copies_btn()
	row1.add_child(_admin_copies_btn)

	# Row 2A: Single Card Code OR Card Name
	_admin_card_row = HBoxContainer.new()
	_admin_card_row.add_theme_constant_override("separation", 8)
	form_v.add_child(_admin_card_row)

	_admin_card_input = LineEdit.new()
	_admin_card_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_card_input.max_length = 72
	_admin_card_input.text_changed.connect(_on_admin_card_input_changed)
	_admin_card_input.text_submitted.connect(func(_t: String) -> void: _on_admin_create_pressed())
	_style_input(_admin_card_input)
	_admin_card_row.add_child(_admin_card_input)

	# Row 2B: Deck / Pack Builder (touch-safe scrollable picker modal showing ALL decks)
	_admin_deck_box = VBoxContainer.new()
	_admin_deck_box.add_theme_constant_override("separation", 6)
	_admin_deck_box.hide()
	form_v.add_child(_admin_deck_box)

	var deck_src_row := HBoxContainer.new()
	deck_src_row.add_theme_constant_override("separation", 8)
	_admin_deck_box.add_child(deck_src_row)

	_admin_deck_pick_btn = Button.new()
	_admin_deck_pick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_deck_pick_btn.custom_minimum_size = Vector2(260, 38)
	_admin_deck_pick_btn.clip_text = true
	_admin_deck_pick_btn.pressed.connect(_open_admin_deck_picker)
	_style_btn(_admin_deck_pick_btn, false)
	deck_src_row.add_child(_admin_deck_pick_btn)

	_admin_deck_load_btn = Button.new()
	_admin_deck_load_btn.custom_minimum_size = Vector2(118, 38)
	_admin_deck_load_btn.pressed.connect(_on_admin_load_deck_source)
	_style_btn(_admin_deck_load_btn, false)
	deck_src_row.add_child(_admin_deck_load_btn)

	_admin_deck_name_input = LineEdit.new()
	_admin_deck_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_deck_name_input.max_length = 64
	_style_input(_admin_deck_name_input)
	_admin_deck_box.add_child(_admin_deck_name_input)

	_admin_deck_cards_input = TextEdit.new()
	_admin_deck_cards_input.custom_minimum_size = Vector2(0, 64)
	_admin_deck_cards_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_deck_cards_input.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_admin_deck_cards_input.add_theme_font_override("font", Assets.ui_font(500))
	_admin_deck_cards_input.add_theme_font_size_override("font_size", 12)
	_admin_deck_cards_input.add_theme_color_override("font_color", Color(0.95, 0.96, 1.0))
	_admin_deck_cards_input.add_theme_color_override("font_placeholder_color", Color(0.62, 0.70, 0.82))
	var te_style := StyleBoxFlat.new()
	te_style.bg_color = Color(0.06, 0.09, 0.16, 0.95)
	te_style.border_color = Color(0.32, 0.48, 0.72, 0.85)
	te_style.set_border_width_all(1)
	te_style.set_corner_radius_all(6)
	te_style.set_content_margin_all(6)
	_admin_deck_cards_input.add_theme_stylebox_override("normal", te_style)
	_admin_deck_cards_input.add_theme_stylebox_override("focus", te_style)
	_admin_deck_cards_input.text_changed.connect(_on_admin_deck_cards_changed)
	_admin_deck_box.add_child(_admin_deck_cards_input)

	# Row 2C: Unlock All Cards info banner
	_admin_unlock_box = PanelContainer.new()
	var ub := StyleBoxFlat.new()
	ub.bg_color = Color(0.18, 0.09, 0.28, 0.92)
	ub.border_color = Color(0.96, 0.76, 0.28, 0.85)
	ub.set_border_width_all(1)
	ub.set_corner_radius_all(8)
	ub.set_content_margin_all(10)
	_admin_unlock_box.add_theme_stylebox_override("panel", ub)
	_admin_unlock_box.hide()
	form_v.add_child(_admin_unlock_box)

	_admin_unlock_info_lbl = Label.new()
	_admin_unlock_info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_unlock_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_unlock_info_lbl.add_theme_font_override("font", Assets.ui_font(600))
	_admin_unlock_info_lbl.add_theme_font_size_override("font_size", 13)
	_admin_unlock_info_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.68))
	_admin_unlock_box.add_child(_admin_unlock_info_lbl)

	_build_admin_deck_picker()

	# Live card/deck preview strip + Create Button
	var prev_row := HBoxContainer.new()
	prev_row.add_theme_constant_override("separation", 10)
	form_v.add_child(prev_row)

	_admin_preview_tex = TextureRect.new()
	_admin_preview_tex.custom_minimum_size = Vector2(40, 58)
	_admin_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_admin_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prev_row.add_child(_admin_preview_tex)

	_admin_preview_lbl = Label.new()
	_admin_preview_lbl.custom_minimum_size = Vector2(360, 36)
	_admin_preview_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_preview_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_admin_preview_lbl.add_theme_font_override("font", Assets.ui_font(600))
	_admin_preview_lbl.add_theme_font_size_override("font_size", 13)
	_admin_preview_lbl.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_admin_preview_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prev_row.add_child(_admin_preview_lbl)

	_admin_create_btn = Button.new()
	_admin_create_btn.custom_minimum_size = Vector2(150, 42)
	_admin_create_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_admin_create_btn.pressed.connect(_on_admin_create_pressed)
	_style_btn(_admin_create_btn, true, true)
	prev_row.add_child(_admin_create_btn)

	_admin_status_lbl = Label.new()
	_admin_status_lbl.custom_minimum_size = Vector2(620, 22)
	_admin_status_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_status_lbl.add_theme_font_override("font", Assets.ui_font(700))
	_admin_status_lbl.add_theme_font_size_override("font_size", 13)
	_admin_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_admin_status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_admin_work_box.add_child(_admin_status_lbl)

	# Existing codes list
	var list_frame := PanelContainer.new()
	list_frame.add_theme_stylebox_override("panel", _subbox_style())
	_admin_work_box.add_child(list_frame)

	_admin_list_scroll = ScrollContainer.new()
	_admin_list_scroll.custom_minimum_size = Vector2(604, 132)
	_admin_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_frame.add_child(_admin_list_scroll)

	_admin_list_vbox = VBoxContainer.new()
	_admin_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_admin_list_vbox.add_theme_constant_override("separation", 6)
	_admin_list_scroll.add_child(_admin_list_vbox)

	# Footer
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	_admin_work_box.add_child(footer)

	_admin_refresh_btn = Button.new()
	_admin_refresh_btn.pressed.connect(_refresh_admin_codes)
	_style_btn(_admin_refresh_btn, false)
	footer.add_child(_admin_refresh_btn)

	_admin_logout_btn = Button.new()
	_admin_logout_btn.pressed.connect(_on_admin_logout_pressed)
	_style_btn(_admin_logout_btn, false)
	footer.add_child(_admin_logout_btn)

	_admin_close_btn = Button.new()
	_admin_close_btn.pressed.connect(close_all)
	_style_btn(_admin_close_btn, false)
	footer.add_child(_admin_close_btn)


func open_gift_admin() -> void:
	if _spinning:
		return
	_code_panel.hide()
	_wheel_panel.hide()
	_admin_title.text = _tr("🎁 إنشاء أكواد الهدايا (لوحة الإدارة)", "🎁 Crear Códigos de Regalo (Admin)", "🎁 Create Gift Codes (Admin)")
	_admin_login_hint.text = _tr(
		"هذه اللوحة محمية بكلمة مرور الإدارة (ADMIN_PASSCODE) ولا يمكن الدخول إليها إلا لصاحب كلمة المرور.",
		"Este panel está protegido por la contraseña de administrador (ADMIN_PASSCODE).",
		"This panel is protected by your server ADMIN_PASSCODE. Only authorized admins can access it."
	)
	_admin_pass_input.placeholder_text = _tr("أدخل كلمة مرور الإدارة…", "Contraseña de administrador…", "Enter ADMIN_PASSCODE…")
	_admin_pass_input.text = ""
	_admin_login_btn.text = _tr("دخول الإدارة", "Entrar", "Admin Login")
	_admin_login_btn.disabled = false
	_admin_login_status.text = ""
	_admin_login_close_btn.text = _tr("إغلاق", "Cerrar", "Close")

	_admin_mode_card_btn.text = _tr("🃏 بطاقة واحدة", "🃏 Carta única", "🃏 Single Card")
	_admin_mode_deck_btn.text = _tr("📦 مجموعة كاملة", "📦 Mazo completo", "📦 Full Deck")
	_admin_mode_unlock_btn.text = _tr("🔓 فتح كل البطاقات", "🔓 Todas las cartas", "🔓 Unlock All")
	_admin_unlock_info_lbl.text = _tr(
		"🔓 هذا الكود يفتح 3 نسخ من كل بطاقات اللعبة للاعب.\n⚖️ حفاظاً على العدل، أي حساب يستخدم هذا الكود ينتقل تلقائياً في الأونلاين إلى «🧪 وضع اختبار المجموعات» ولا يستطيع الدخول إلى «🏆 وضع المنافسة».",
		"🔓 Este código desbloquea 3 copias de todas las cartas.\n⚖️ Para mantener el juego justo, quien lo canjee pasará al servidor «🧪 Prueba de Mazos» y no podrá entrar al «🏆 Modo Competitivo».",
		"🔓 Unlocks 3 copies of every card in the game.\n⚖️ For fairness, accounts redeeming this code are moved to the «🧪 Deck Testing» server pool and cannot enter «🏆 Competitive Mode»."
	)
	_admin_gift_code_input.placeholder_text = _tr("كود الهدية (مثال: FUSION10)", "Código regalo (ej: FUSION10)", "Gift code (e.g. FUSION10)")
	_admin_random_btn.text = _tr("🎲 عشوائي", "🎲 Azar", "🎲 Random")
	_admin_max_uses_input.placeholder_text = _tr("الحد (10)", "Límite (10)", "Max (10)")
	_update_admin_copies_btn()
	_admin_card_input.placeholder_text = _tr("كود البطاقة أو اسمها (مثال: 24094653 أو بطاقة الانصهار)", "Código o nombre de carta (ej: 24094653 o Polymerization)", "Card code or name (e.g. 24094653 or Polymerization)")
	_admin_deck_load_btn.text = _tr("📥 تحميل", "📥 Cargar", "📥 Load")
	_admin_deck_name_input.placeholder_text = _tr("اسم المجموعة (مثال: مجموعة التنين الأزرق)", "Nombre del mazo (ej: Mazo Dragón Azul)", "Deck / pack name (e.g. Blue-Eyes Deck)")
	_admin_deck_cards_input.placeholder_text = _tr("أكواد أو أسماء البطاقات (بطاقة في كل سطر، مثال: 89631139 x3)", "Códigos o nombres de cartas (una por línea, ej: 89631139 x3)", "Card codes or names (one per line, e.g. 89631139 x3)")
	_admin_create_btn.text = _tr("➕ إنشاء الكود", "➕ Crear código", "➕ Create Code")
	_admin_refresh_btn.text = _tr("🔄 تحديث", "🔄 Actualizar", "🔄 Refresh")
	_admin_logout_btn.text = _tr("تسجيل خروج", "Cerrar sesión", "Admin Logout")
	_admin_close_btn.text = _tr("إغلاق", "Cerrar", "Close")
	_admin_status_lbl.text = ""

	_populate_admin_deck_sources()
	var authed := is_instance_valid(Online) and Online.is_admin_logged_in()
	_admin_login_box.visible = not authed
	_admin_work_box.visible = authed
	_set_admin_mode(_admin_mode)

	_backdrop.show()
	_admin_panel.show()
	_center_panel(_admin_panel)
	_center_panel.call_deferred(_admin_panel)
	if authed:
		_refresh_admin_codes()
		_admin_gift_code_input.grab_focus()
	else:
		_admin_pass_input.grab_focus()


func _on_admin_login_pressed() -> void:
	if _admin_busy or not is_instance_valid(Online):
		return
	var pw := _admin_pass_input.text.strip_edges()
	if pw.is_empty():
		_admin_login_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		_admin_login_status.text = _tr("يرجى إدخال كلمة مرور الإدارة أولاً.", "Introduce la contraseña primero.", "Please enter the admin passcode first.")
		return
	_admin_busy = true
	_admin_login_btn.disabled = true
	_admin_login_status.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_admin_login_status.text = _tr("جاري التحقق من كلمة المرور…", "Verificando contraseña…", "Verifying passcode…")
	var res: Dictionary = await Online.admin_login(pw)
	_admin_busy = false
	_admin_login_btn.disabled = false
	if bool(res.get("ok", false)):
		_admin_pass_input.text = ""
		_admin_login_status.text = ""
		_admin_login_box.hide()
		_admin_work_box.show()
		_populate_admin_deck_sources()
		_set_admin_mode(_admin_mode)
		_refresh_admin_codes()
		_admin_gift_code_input.grab_focus()
	else:
		var err := str(res.get("error", ""))
		_admin_login_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if err == "admin_not_configured":
			_admin_login_status.text = _tr("متغير ADMIN_PASSCODE غير مضبوط على السيرفر بعد.", "ADMIN_PASSCODE no está configurado en el servidor.", "ADMIN_PASSCODE is not configured on the server yet.")
		elif err == "unauthorized":
			_admin_login_status.text = _tr("السيرفر على Render ما زال بالنسخة القديمة — ارفع تحديث مجلد relay-server وأعد النشر (Deploy) على Render.", "El servidor Render aún usa la versión antigua; despliega el relay-server actualizado.", "Render server is still on an older version — deploy the updated relay-server first.")
		elif err == "rate_limited":
			_admin_login_status.text = _tr("محاولات كثيرة، انتظر بضع دقائق ثم أعد المحاولة.", "Demasiados intentos, espera unos minutos.", "Too many attempts. Please wait a few minutes.")
		elif err == "invalid_passcode" or int(res.get("http_status", 0)) == 401:
			_admin_login_status.text = _tr("كلمة مرور الإدارة غير صحيحة.", "Contraseña de administrador incorrecta.", "Invalid admin passcode.")
		else:
			_admin_login_status.text = _tr("تعذر الاتصال بالسيرفر، تأكد من الإنترنت وحاول مجدداً.", "Error de conexión con el servidor.", "Could not reach server. Please check connection.")


func _on_admin_logout_pressed() -> void:
	if is_instance_valid(Online):
		Online.admin_logout()
	_admin_work_box.hide()
	_admin_login_box.show()
	_admin_panel.custom_minimum_size = Vector2(560, 248)
	_admin_pass_input.text = ""
	_admin_login_status.text = ""
	_center_panel(_admin_panel)
	_center_panel.call_deferred(_admin_panel)
	_admin_pass_input.grab_focus()


func _on_admin_cycle_copies() -> void:
	_admin_copies_val = (_admin_copies_val % 3) + 1
	_update_admin_copies_btn()


func _update_admin_copies_btn() -> void:
	if is_instance_valid(_admin_copies_btn):
		_admin_copies_btn.text = _tr("النسخ: x%d", "Copias: x%d", "Copies: x%d") % _admin_copies_val


func _build_admin_deck_picker() -> void:
	_deck_picker_layer = CanvasLayer.new()
	_deck_picker_layer.layer = 98
	_deck_picker_layer.visible = false
	add_child(_deck_picker_layer)

	_deck_picker_backdrop = ColorRect.new()
	_deck_picker_backdrop.color = Color(0.01, 0.014, 0.04, 0.80)
	_deck_picker_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_picker_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_picker_backdrop.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_admin_deck_picker()
			get_viewport().set_input_as_handled())
	_deck_picker_layer.add_child(_deck_picker_backdrop)

	_deck_picker_panel = PanelContainer.new()
	_deck_picker_panel.add_theme_stylebox_override("panel", _panel_style())
	_deck_picker_panel.custom_minimum_size = Vector2(560, 420)
	_deck_picker_layer.add_child(_deck_picker_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	_deck_picker_panel.add_child(pv)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 8)
	pv.add_child(hdr)

	_deck_picker_title = Label.new()
	_deck_picker_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_title.add_theme_font_override("font", Assets.ui_font(700))
	_deck_picker_title.add_theme_font_size_override("font_size", 17)
	_deck_picker_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	hdr.add_child(_deck_picker_title)

	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(40, 36)
	_style_btn(x_btn, false)
	x_btn.pressed.connect(_close_admin_deck_picker)
	hdr.add_child(x_btn)

	_deck_picker_search = LineEdit.new()
	_deck_picker_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_search.text_changed.connect(func(q: String) -> void: _render_admin_deck_picker_list(q))
	_style_input(_deck_picker_search)
	pv.add_child(_deck_picker_search)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(520, 290)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(sc)

	_deck_picker_list = VBoxContainer.new()
	_deck_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_picker_list.add_theme_constant_override("separation", 6)
	sc.add_child(_deck_picker_list)


func _open_admin_deck_picker() -> void:
	_populate_admin_deck_sources()
	if not is_instance_valid(_deck_picker_layer):
		return
	_deck_picker_title.text = _tr("📦 اختر مجموعة من جميع المجموعات المتوفرة (%d)", "📦 Elegir mazo (%d disponibles)", "📦 Pick from All Available Decks (%d)") % _admin_deck_sources.size()
	_deck_picker_search.placeholder_text = _tr("ابحث في المجموعات (يوغي، كايبا، جوي، إكسوديا...)", "Buscar mazo...", "Search decks (Yugi, Kaiba, Joey, Exodia...)")
	_deck_picker_search.text = ""
	_render_admin_deck_picker_list("")
	_deck_picker_layer.show()
	_center_panel(_deck_picker_panel)
	_center_panel.call_deferred(_deck_picker_panel)


func _close_admin_deck_picker() -> void:
	if is_instance_valid(_deck_picker_layer):
		_deck_picker_layer.hide()


func _render_admin_deck_picker_list(query: String) -> void:
	if not is_instance_valid(_deck_picker_list):
		return
	for ch in _deck_picker_list.get_children():
		ch.queue_free()
	var needle := query.strip_edges().to_lower()
	var shown := 0
	for i in _admin_deck_sources.size():
		var src: Dictionary = _admin_deck_sources[i]
		var disp := str(src.get("display", src.get("label", "")))
		if needle != "" and disp.to_lower().find(needle) == -1:
			continue
		shown += 1
		var btn := Button.new()
		btn.text = disp
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 42)
		btn.clip_text = true
		_style_btn(btn, i == _admin_deck_selected_idx)
		var picked_idx := i
		btn.pressed.connect(func() -> void:
			_admin_deck_selected_idx = picked_idx
			_update_admin_deck_pick_label()
			_close_admin_deck_picker()
			_load_admin_deck_at(picked_idx))
		_deck_picker_list.add_child(btn)
	if shown == 0:
		var emp := Label.new()
		emp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emp.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
		emp.text = _tr("لا توجد مجموعات مطابقة للبحث.", "No hay mazos que coincidan.", "No matching decks found.")
		_deck_picker_list.add_child(emp)


func _update_admin_deck_pick_label() -> void:
	if not is_instance_valid(_admin_deck_pick_btn):
		return
	if _admin_deck_selected_idx >= 0 and _admin_deck_selected_idx < _admin_deck_sources.size():
		var src: Dictionary = _admin_deck_sources[_admin_deck_selected_idx]
		_admin_deck_pick_btn.text = "▾ %s" % str(src.get("display", src.get("label", "")))
	else:
		_admin_deck_pick_btn.text = _tr("▾ اختر من جميع المجموعات (%d)…", "▾ Elegir mazo (%d)…", "▾ Choose from All Decks (%d)…") % _admin_deck_sources.size()


func _on_admin_random_code() -> void:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := "ALLCARDS-" if _admin_mode == "unlock_all" else ("DECK-" if _admin_mode == "deck" else "GIFT-")
	for _i in 6:
		out += CHARS.substr(_rng.randi_range(0, CHARS.length() - 1), 1)
	_admin_gift_code_input.text = out


func _set_admin_mode(mode: String) -> void:
	if mode == "deck" or mode == "unlock_all":
		_admin_mode = mode
	else:
		_admin_mode = "card"
	var is_card := _admin_mode == "card"
	var is_deck := _admin_mode == "deck"
	var is_unlock := _admin_mode == "unlock_all"
	_style_btn(_admin_mode_card_btn, is_card)
	_style_btn(_admin_mode_deck_btn, is_deck)
	_style_btn(_admin_mode_unlock_btn, is_unlock, is_unlock)
	_admin_card_row.visible = is_card
	_admin_copies_btn.visible = is_card
	_admin_deck_box.visible = is_deck
	_admin_unlock_box.visible = is_unlock
	if _admin_work_box.visible:
		_admin_panel.custom_minimum_size = Vector2(660, 548) if is_deck else Vector2(660, 476)
		_center_panel(_admin_panel)
		_center_panel.call_deferred(_admin_panel)
	else:
		_admin_panel.custom_minimum_size = Vector2(560, 248)
	if is_deck:
		_on_admin_deck_cards_changed()
	elif is_unlock:
		_admin_preview_tex.texture = null
		_admin_preview_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		_admin_preview_lbl.text = _tr(
			"🔓 جاهز: كود فتح جميع البطاقات (3 نسخ لكل بطاقة + نقل تلقائي لوضع اختبار المجموعات).",
			"🔓 Listo: desbloquea todas las cartas (3 copias + traslado automático a Prueba de Mazos).",
			"🔓 Ready: unlocks all cards (3 copies each + auto-moves redeemer to Deck Testing pool)."
		)
	else:
		_on_admin_card_input_changed(_admin_card_input.text)


func _populate_admin_deck_sources() -> void:
	_admin_deck_sources.clear()
	if SaveData.data.is_empty() and Paths.has_data():
		SaveData.load_or_create()
	var game_labels := {
		"yugi": _tr("مجموعتي النشطة (يوغي)", "Mi mazo activo (Yugi)", "My Active Deck (Yugi)"),
		"kaiba": _tr("مجموعتي النشطة (كايبا)", "Mi mazo activo (Kaiba)", "My Active Deck (Kaiba)"),
		"joey": _tr("مجموعتي النشطة (جوي)", "Mi mazo activo (Joey)", "My Active Deck (Joey)"),
	}
	for g in ["yugi", "kaiba", "joey"]:
		var d: Dictionary = SaveData.deck(g) if not SaveData.data.is_empty() else {}
		var main_arr: Array = d.get("main", [])
		if not main_arr.is_empty():
			var disp := "⭐ %s (%d)" % [game_labels[g], main_arr.size()]
			_admin_deck_sources.append({"kind": "active", "game": g, "label": game_labels[g], "display": disp})

	var decks_dir := Paths.save_dir.path_join("decks")
	if DirAccess.dir_exists_absolute(decks_dir):
		var files := DirAccess.get_files_at(decks_dir)
		files.sort()
		for fname in files:
			if fname.get_extension().to_lower() != "ydc":
				continue
			var base := fname.get_basename()
			_admin_deck_sources.append({
				"kind": "ydc",
				"path": decks_dir.path_join(fname),
				"label": base,
				"display": "📁 %s.ydc" % base,
			})

	# Include ALL official preset decks across Yugi, Kaiba, and Joey
	var ed_tags := {
		"yugi": _tr("يوغي", "Yugi", "Yugi"),
		"kaiba": _tr("كايبا", "Kaiba", "Kaiba"),
		"joey": _tr("جوي", "Joey", "Joey"),
	}
	for g in ["yugi", "kaiba", "joey"]:
		var presets: Array = _RivalDeckChoice.PRESET_DECKS.get(g, [])
		for raw_entry: Variant in presets:
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = raw_entry
			var p := str(entry.get("path", ""))
			if p == "" or (Paths.has_data() and not Assets.exists(p)):
				continue
			var p_name = _tr(str(entry.get("ar", "")), str(entry.get("es", "")), str(entry.get("en", "")))
			var disp := "🃏 [%s] %s" % [ed_tags[g], p_name]
			_admin_deck_sources.append({
				"kind": "preset_json",
				"path": p,
				"label": p_name,
				"display": disp,
			})

	for s: Dictionary in SPECIAL_SETS:
		var s_name = _tr(str(s["ar"]), str(s["es"]), str(s["en"]))
		var disp = "★ %s (%d)" % [s_name, (s["cards"] as Array).size()]
		_admin_deck_sources.append({"kind": "special_set", "set": s, "label": s_name, "display": disp})

	if _admin_deck_sources.is_empty():
		_admin_deck_selected_idx = -1
	elif _admin_deck_selected_idx < 0 or _admin_deck_selected_idx >= _admin_deck_sources.size():
		_admin_deck_selected_idx = 0
	_update_admin_deck_pick_label()


func _deck_dict_to_lines(deck_dict: Dictionary) -> String:
	var lines: Array[String] = []
	for zone in ["main", "fusion", "side"]:
		var arr: Array = deck_dict.get(zone, [])
		if arr.is_empty():
			continue
		var counts := {}
		var order: Array[int] = []
		for raw_id: Variant in arr:
			var cid := int(raw_id)
			if not counts.has(cid):
				counts[cid] = 1
				order.append(cid)
			else:
				counts[cid] = mini(3, int(counts[cid]) + 1)
		for cid in order:
			var card := CardDB.by_id(cid)
			if card.is_empty():
				continue
			var code := card_code_string(card)
			var cp := int(counts[cid])
			var line := code
			if cp > 1:
				line += " x%d" % cp
			if zone != "main":
				line += " " + zone
			lines.append(line)
	return "\n".join(lines)


func _on_admin_load_deck_source() -> void:
	if _admin_deck_sources.is_empty():
		_populate_admin_deck_sources()
	if _admin_deck_selected_idx < 0 or _admin_deck_selected_idx >= _admin_deck_sources.size():
		_open_admin_deck_picker()
		return
	_load_admin_deck_at(_admin_deck_selected_idx)


func _load_admin_deck_at(sel: int) -> void:
	if sel < 0 or sel >= _admin_deck_sources.size():
		return
	var src: Dictionary = _admin_deck_sources[sel]
	var kind := str(src.get("kind", ""))
	if kind == "active":
		var g := str(src.get("game", "joey"))
		var d: Dictionary = SaveData.deck(g)
		_admin_deck_cards_input.text = _deck_dict_to_lines(d)
		_admin_deck_name_input.text = str(src.get("label", ""))
	elif kind == "ydc":
		var d: Dictionary = Ydc.load(str(src.get("path", "")))
		if d.is_empty():
			_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_status_lbl.text = _tr("تعذر قراءة ملف المجموعة.", "No se pudo leer el archivo del mazo.", "Failed to read .ydc deck file.")
			return
		_admin_deck_cards_input.text = _deck_dict_to_lines(d)
		_admin_deck_name_input.text = str(src.get("label", ""))
	elif kind == "preset_json":
		var raw_json: Variant = Assets.read_json(str(src.get("path", "")))
		var deck_dict: Dictionary = {}
		if raw_json is Dictionary:
			deck_dict = raw_json as Dictionary
		elif raw_json is Array:
			deck_dict = {"main": raw_json}
		if deck_dict.is_empty():
			_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_status_lbl.text = _tr("تعذر تحميل هذه المجموعة (تأكد من تثبيت ملفات اللعبة).", "No se pudo cargar este mazo.", "Could not load this preset deck.")
			return
		_admin_deck_cards_input.text = _deck_dict_to_lines(deck_dict)
		_admin_deck_name_input.text = str(src.get("label", ""))
	elif kind == "special_set":
		var s: Dictionary = src.get("set", {})
		var ids: Array = s.get("cards", [])
		_admin_deck_cards_input.text = _deck_dict_to_lines({"main": ids})
		_admin_deck_name_input.text = str(src.get("label", ""))
	_on_admin_deck_cards_changed()


func _parse_admin_deck_text(raw_text: String) -> Dictionary:
	var out: Array[Dictionary] = []
	var merged := {}
	var total_copies := 0
	var cover_cid := -1
	var normalized := raw_text.replace(",", "\n").replace(";", "\n")
	for raw_line in normalized.split("\n"):
		var line := normalize_digits(raw_line).strip_edges()
		if line.is_empty():
			continue
		var zone := "main"
		var lower := line.to_lower()
		for z in ["fusion", "side", "main"]:
			if lower.ends_with(" " + z) or lower.ends_with(":" + z):
				zone = z
				line = line.substr(0, line.length() - z.length() - 1).strip_edges()
				break
		var copies := 1
		var parts := line.split(" ", false)
		if parts.size() >= 2:
			var last_tok := parts[parts.size() - 1].to_lower()
			var cp_str := ""
			if (last_tok.begins_with("x") or last_tok.begins_with("*")) and last_tok.length() >= 2:
				cp_str = last_tok.substr(1)
			elif (last_tok.ends_with("x") or last_tok.ends_with("*")) and last_tok.length() >= 2:
				cp_str = last_tok.substr(0, last_tok.length() - 1)
			if cp_str.is_valid_int():
				copies = clampi(cp_str.to_int(), 1, 3)
				parts.remove_at(parts.size() - 1)
				line = " ".join(parts).strip_edges()
		if line.is_empty():
			continue
		var info := _lookup_card_preview_info(line)
		var card_code := str(info.get("code", line))
		var card_label := str(info.get("label", ""))
		var cid := int(info.get("cid", -1))
		if cover_cid < 0 and cid >= 0:
			cover_cid = cid
		var mkey := "%s|%s" % [card_code, zone]
		if merged.has(mkey):
			var idx: int = int(merged[mkey])
			var prev_c := int(out[idx]["copies"])
			var next_c := mini(3, prev_c + copies)
			total_copies += next_c - prev_c
			out[idx]["copies"] = next_c
		else:
			merged[mkey] = out.size()
			out.append({
				"cardCode": card_code,
				"cardLabel": card_label,
				"copies": copies,
				"zone": zone,
			})
			total_copies += copies
	return {"cards": out, "total": total_copies, "cover_cid": cover_cid}


func _on_admin_deck_cards_changed() -> void:
	var parsed := _parse_admin_deck_text(_admin_deck_cards_input.text)
	_admin_resolved_deck = parsed["cards"]
	var total := int(parsed["total"])
	var cover_cid := int(parsed["cover_cid"])
	if cover_cid >= 0 and Paths.has_data():
		_admin_preview_tex.texture = CardDB.card_texture(cover_cid, true)
	else:
		_admin_preview_tex.texture = null
	if _admin_resolved_deck.is_empty():
		_admin_preview_lbl.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
		_admin_preview_lbl.text = _tr(
			"اختر مجموعة جاهزة من الأعلى واضغط «تحميل»، أو اكتب أكواد البطاقات (بطاقة في كل سطر، مثال: 89631139 x3).",
			"Elige un mazo arriba y pulsa «Cargar», o escribe códigos de carta (una por línea).",
			"Pick a deck above and press Load, or type card codes (one per line, e.g. 89631139 x3)."
		)
	else:
		var col := Color(0.45, 0.96, 0.65) if total <= 150 else Color(1.0, 0.45, 0.45)
		_admin_preview_lbl.add_theme_color_override("font_color", col)
		_admin_preview_lbl.text = _tr(
			"📦 جاهز للإرسال: %d بطاقة إجمالاً (%d بطاقة مختلفة) · المجموعات من 40+ بطاقة تُحفظ تلقائياً عند اللاعب.",
			"📦 Listo: %d cartas en total (%d distintas) · Los mazos de 40+ cartas se guardan automáticamente.",
			"📦 Ready: %d total cards (%d unique) · 40+ card decks auto-save as .ydc for players."
		) % [total, _admin_resolved_deck.size()]


func _lookup_card_preview_info(raw_text: String) -> Dictionary:
	var cleaned := normalize_digits(raw_text).strip_edges()
	if cleaned.is_empty():
		return {}
	# 1) Try full CardDB first (gives card texture + exact internal_id)
	var cid := _resolve_card_id(cleaned)
	if cid >= 0:
		var card := CardDB.by_id(cid)
		var ar_n := CardDB.name_of(cid, "ara")
		var en_n := CardDB.name_of(cid, "eng")
		return {
			"cid": cid,
			"code": card_code_string(card),
			"ar": ar_n,
			"en": en_n,
			"label": ar_n if ar_n != "" else en_n
		}
	# 2) Fallback: search bundled CardTranslations._arabic_cards (works even before PCK import!)
	if is_instance_valid(CardTranslations) and CardTranslations._arabic_cards is Dictionary:
		var dict: Dictionary = CardTranslations._arabic_cards
		var is_num := cleaned.is_valid_int()
		if is_num:
			var padded := cleaned.lpad(8, "0")
			if dict.has(padded):
				var e: Dictionary = dict[padded]
				return {"cid": -1, "code": padded, "ar": str(e.get("name", "")), "en": "", "label": str(e.get("name", ""))}
			if dict.has(cleaned):
				var e2: Dictionary = dict[cleaned]
				return {"cid": -1, "code": cleaned.lpad(8, "0"), "ar": str(e2.get("name", "")), "en": "", "label": str(e2.get("name", ""))}
		var needle := _normalize_card_name(cleaned)
		if not needle.is_empty():
			var best_key := ""
			var best_name := ""
			var best_rank := 99999
			for k: Variant in dict.keys():
				var entry: Variant = dict[k]
				if not (entry is Dictionary):
					continue
				var nm_raw := str((entry as Dictionary).get("name", ""))
				var nm := _normalize_card_name(nm_raw)
				if nm == needle:
					return {"cid": -1, "code": str(k).lpad(8, "0"), "ar": nm_raw, "en": "", "label": nm_raw}
				var rank := 99999
				if nm.begins_with(needle):
					rank = nm.length()
				elif nm.find(needle) != -1:
					rank = 1000 + nm.length()
				if rank < best_rank:
					best_rank = rank
					best_key = str(k)
					best_name = nm_raw
			if best_key != "":
				return {"cid": -1, "code": best_key.lpad(8, "0"), "ar": best_name, "en": "", "label": best_name}
	return {}


func _on_admin_card_input_changed(new_text: String) -> void:
	_admin_resolved_code = ""
	_admin_resolved_label = ""
	var raw := new_text.strip_edges()
	if raw.is_empty():
		_admin_preview_tex.texture = null
		_admin_preview_lbl.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
		_admin_preview_lbl.text = _tr(
			"اكتب كود البطاقة (8 أرقام) أو اسم البطاقة بالعربية/الإنجليزية وسيتم التعرف عليها تلقائياً.",
			"Escribe el código (8 dígitos) o el nombre de la carta para identificarla automáticamente.",
			"Type an 8-digit card code or card name (Arabic/English) to match automatically."
		)
		return
	var info := _lookup_card_preview_info(raw)
	if not info.is_empty():
		_admin_resolved_code = str(info.get("code", ""))
		_admin_resolved_label = str(info.get("label", ""))
		var cid := int(info.get("cid", -1))
		if cid >= 0 and Paths.has_data():
			_admin_preview_tex.texture = CardDB.card_texture(cid, true)
		else:
			_admin_preview_tex.texture = null
		var ar_n := str(info.get("ar", ""))
		var en_n := str(info.get("en", ""))
		var disp := ("%s · %s" % [ar_n, en_n]) if (ar_n != "" and en_n != "" and ar_n != en_n) else (ar_n if ar_n != "" else en_n)
		_admin_preview_lbl.add_theme_color_override("font_color", Color(0.45, 0.96, 0.65))
		_admin_preview_lbl.text = _tr("✓ تم التعرف على البطاقة: %s  (الكود: %s)", "✓ Carta encontrada: %s  (Código: %s)", "✓ Matched card: %s  (Code: %s)") % [disp, _admin_resolved_code]
	else:
		_admin_preview_tex.texture = null
		_admin_preview_lbl.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
		_admin_preview_lbl.text = _tr(
			"سيتم مطابقة «%s» تلقائياً عبر السيرفر عند الإنشاء.",
			"Se buscará «%s» en el servidor al crear el código.",
			"Will resolve \"%s\" on the server when creating."
		) % raw


func _on_admin_create_pressed() -> void:
	if _admin_busy or not is_instance_valid(Online) or not Online.is_admin_logged_in():
		return
	var gift_code := _admin_gift_code_input.text.strip_edges().to_upper()
	if gift_code.is_empty():
		_on_admin_random_code()
		gift_code = _admin_gift_code_input.text.strip_edges().to_upper()
	var max_uses_str := normalize_digits(_admin_max_uses_input.text).strip_edges()
	var max_uses := max_uses_str.to_int() if max_uses_str.is_valid_int() else 10
	max_uses = clampi(max_uses, 1, 100000)

	var send_card := ""
	var send_label := ""
	var copies := 1
	var reward_type := _admin_mode
	var deck_cards: Array = []
	var deck_total := 0

	if reward_type == "unlock_all":
		send_card = "ALL"
		send_label = _tr("فتح كل البطاقات", "Desbloquear todas las cartas", "Unlock All Cards")
		copies = 3
	elif reward_type == "deck":
		var parsed := _parse_admin_deck_text(_admin_deck_cards_input.text)
		deck_cards = parsed["cards"]
		deck_total = int(parsed["total"])
		if deck_cards.is_empty() or deck_cards.size() > 120:
			_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_status_lbl.text = _tr("يرجى إضافة بين 1 و 120 بطاقة في المجموعة أولاً.", "Añade entre 1 y 120 cartas al mazo.", "Please add between 1 and 120 cards to the deck first.")
			return
		if deck_total > 150:
			_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_status_lbl.text = _tr("إجمالي البطاقات يتجاوز الحد المسموح (150).", "El total de cartas supera el límite (150).", "Total cards exceed the 150-card limit.")
			return
		send_card = str((deck_cards[0] as Dictionary).get("cardCode", ""))
		send_label = _admin_deck_name_input.text.strip_edges()
		if send_label.is_empty():
			send_label = _tr("مجموعة هدية", "Mazo de regalo", "Gift Deck")
	else:
		var card_raw := _admin_card_input.text.strip_edges()
		if card_raw.is_empty():
			_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_status_lbl.text = _tr("يرجى إدخال كود البطاقة أو اسمها أولاً.", "Introduce el código o nombre de la carta.", "Please enter a card code or card name first.")
			return
		copies = clampi(_admin_copies_val, 1, 3)
		send_card = _admin_resolved_code if _admin_resolved_code != "" else card_raw
		send_label = _admin_resolved_label

	_admin_busy = true
	_admin_create_btn.disabled = true
	_admin_status_lbl.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_admin_status_lbl.text = _tr("جاري إنشاء كود الهدية…", "Creando código de regalo…", "Creating gift code…")
	var res: Dictionary = await Online.admin_create_gift_code(gift_code, send_card, send_label, max_uses, copies, reward_type, deck_cards)
	_admin_busy = false
	_admin_create_btn.disabled = false
	if bool(res.get("ok", false)):
		var item: Dictionary = res.get("giftCode", {})
		var created_code := str(item.get("code", gift_code))
		var created_card := str(item.get("cardCode", send_card))
		var created_lbl := str(item.get("cardLabel", send_label))
		DisplayServer.clipboard_set(created_code)
		_admin_status_lbl.add_theme_color_override("font_color", Color(0.42, 0.96, 0.65))
		if reward_type == "unlock_all":
			_admin_status_lbl.text = _tr(
				"✓ تم إنشاء كود فتح كل البطاقات %s (الحد: %d أشخاص) · تم نسخه للحافظة!",
				"✓ Código de todas las cartas %s creado (límite: %d) · ¡Copiado!",
				"✓ Created Unlock All Cards code %s (max: %d users) · Copied!"
			) % [created_code, max_uses]
		elif reward_type == "deck":
			_admin_status_lbl.text = _tr(
				"✓ تم إنشاء كود المجموعة %s (الحد: %d أشخاص) → 📦 %s (%d بطاقة) · تم نسخه للحافظة!",
				"✓ Mazo %s creado (límite: %d) → 📦 %s (%d cartas) · ¡Copiado!",
				"✓ Created deck code %s (max: %d) → 📦 %s (%d cards) · Copied!"
			) % [created_code, max_uses, created_lbl, deck_total]
		else:
			_admin_status_lbl.text = _tr(
				"✓ تم إنشاء الكود %s (الحد: %d أشخاص) → %s (%s) · تم نسخه للحافظة!",
				"✓ Código %s creado (límite: %d) → %s (%s) · ¡Copiado!",
				"✓ Created %s (max: %d users) → %s (%s) · Copied!"
			) % [created_code, max_uses, created_lbl if created_lbl != "" else created_card, created_card]
		_admin_gift_code_input.text = ""
		_refresh_admin_codes()
	else:
		var err := str(res.get("error", ""))
		_admin_status_lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		if int(res.get("http_status", 0)) == 401:
			_on_admin_logout_pressed()
			_admin_login_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			_admin_login_status.text = _tr("انتهت جلسة الإدارة، سجل الدخول مجدداً.", "Sesión expirada, inicia sesión de nuevo.", "Admin session expired. Please sign in again.")
		elif err in ["code_exists", "code_already_exists"]:
			_admin_status_lbl.text = _tr("كود الهدية هذا موجود بالفعل، اختر اسماً آخر.", "Este código ya existe.", "That gift code already exists.")
		elif err == "invalid_card_code":
			_admin_status_lbl.text = _tr("لم يتم التعرف على إحدى البطاقات. تأكد من الأكواد أو الأسماء.", "No se encontró una de las cartas.", "Card not recognized. Check the code or card name.")
		elif err in ["invalid_deck_cards", "deck_too_large"]:
			_admin_status_lbl.text = _tr("عدد البطاقات في المجموعة غير صالح (المسموح 1 إلى 150 بطاقة).", "Cantidad de cartas de mazo inválida (1 a 150).", "Invalid deck card count (allowed: 1 to 150 cards).")
		elif err in ["invalid_code", "invalid_code_format"]:
			_admin_status_lbl.text = _tr("كود الهدية يجب أن يكون 3 إلى 32 حرف/رقم إنجليزي.", "El código debe tener entre 3 y 32 caracteres.", "Gift code must be 3-32 letters/numbers/dashes.")
		else:
			_admin_status_lbl.text = _tr("تعذر إنشاء الكود (%s).", "No se pudo crear el código (%s).", "Failed to create code (%s).") % err


func _refresh_admin_codes() -> void:
	if not is_instance_valid(Online) or not Online.is_admin_logged_in():
		return
	for ch in _admin_list_vbox.get_children():
		ch.queue_free()
	var loading := Label.new()
	loading.add_theme_font_override("font", Assets.ui_font())
	loading.add_theme_font_size_override("font_size", 13)
	loading.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading.text = _tr("جاري تحميل الأكواد…", "Cargando códigos…", "Loading gift codes…")
	_admin_list_vbox.add_child(loading)

	var res: Dictionary = await Online.admin_list_gift_codes()
	for ch in _admin_list_vbox.get_children():
		ch.queue_free()
	if not bool(res.get("ok", false)):
		if int(res.get("http_status", 0)) == 401:
			_on_admin_logout_pressed()
			return
		var err_lbl := Label.new()
		err_lbl.add_theme_font_override("font", Assets.ui_font())
		err_lbl.add_theme_font_size_override("font_size", 13)
		err_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		err_lbl.text = _tr("تعذر تحميل قائمة الأكواد.", "No se pudo cargar la lista.", "Failed to load gift codes.")
		_admin_list_vbox.add_child(err_lbl)
		return

	var items: Variant = res.get("giftCodes", [])
	if not (items is Array) or (items as Array).is_empty():
		var empty_lbl := Label.new()
		empty_lbl.add_theme_font_override("font", Assets.ui_font())
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.82, 0.92))
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.text = _tr("لا توجد أكواد هدايا بعد. أنشئ أول كود من الأعلى!", "Aún no hay códigos de regalo.", "No gift codes yet. Create your first one above!")
		_admin_list_vbox.add_child(empty_lbl)
		return

	for raw_item: Variant in (items as Array):
		if not (raw_item is Dictionary):
			continue
		var item: Dictionary = raw_item
		var gcode := str(item.get("code", ""))
		var ccode := str(item.get("cardCode", ""))
		var clbl := str(item.get("cardLabel", ""))
		var used := int(item.get("usedCount", 0))
		var max_u := int(item.get("maxUses", 1))
		var active := bool(item.get("active", true))
		var exhausted := used >= max_u

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_admin_list_vbox.add_child(row)

		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.clip_text = true
		info.add_theme_font_override("font", Assets.ui_font(600))
		info.add_theme_font_size_override("font_size", 13)
		var state_txt := _tr("مكتمل", "Agotado", "Full") if exhausted else (_tr("نشط", "Activo", "Active") if active else _tr("موقوف", "Pausado", "Paused"))
		info.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82) if (exhausted or not active) else Color(0.95, 0.96, 1.0))
		var rtype := str(item.get("rewardType", "card")).to_lower()
		var card_disp := ""
		if rtype == "unlock_all":
			card_disp = _tr("🔓 فتح كل البطاقات (اختبار المجموعات)", "🔓 Todas las cartas (Prueba de Mazos)", "🔓 Unlock All Cards (Deck Testing)")
		elif rtype == "deck" and item.get("cards", []) is Array:
			var total_c := 0
			for dc: Variant in (item.get("cards", []) as Array):
				if dc is Dictionary:
					total_c += int((dc as Dictionary).get("copies", 1))
			var dtitle := clbl if clbl != "" else _tr("مجموعة هدية", "Mazo de regalo", "Gift Deck")
			card_disp = _tr("📦 %s (%d بطاقة)", "📦 %s (%d cartas)", "📦 %s (%d cards)") % [dtitle, total_c]
		else:
			card_disp = ("%s (%s)" % [clbl, ccode]) if clbl != "" else ccode
		info.text = "%s  →  %s  ·  %d/%d  [%s]" % [gcode, card_disp, used, max_u, state_txt]
		row.add_child(info)

		var copy_btn := Button.new()
		copy_btn.text = _tr("نسخ", "Copiar", "Copy")
		copy_btn.custom_minimum_size = Vector2(56, 28)
		_style_btn(copy_btn, false)
		copy_btn.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(gcode)
			_admin_status_lbl.add_theme_color_override("font_color", Color(0.45, 0.95, 0.65))
			_admin_status_lbl.text = _tr("تم نسخ الكود: %s", "Copiado: %s", "Copied: %s") % gcode)
		row.add_child(copy_btn)

		var toggle_btn := Button.new()
		toggle_btn.text = _tr("إيقاف", "Pausar", "Pause") if active else _tr("تفعيل", "Activar", "Resume")
		toggle_btn.custom_minimum_size = Vector2(64, 28)
		_style_btn(toggle_btn, false)
		toggle_btn.pressed.connect(func() -> void:
			await Online.admin_toggle_gift_code(gcode, not active)
			_refresh_admin_codes())
		row.add_child(toggle_btn)

		var del_btn := Button.new()
		del_btn.text = "🗑"
		del_btn.custom_minimum_size = Vector2(36, 28)
		_style_btn(del_btn, false)
		del_btn.pressed.connect(func() -> void:
			await Online.admin_delete_gift_code(gcode)
			_refresh_admin_codes())
		row.add_child(del_btn)


func _center_panel(panel: PanelContainer) -> void:
	var vp := get_viewport().get_visible_rect().size
	if vp.x <= 0.0 or vp.y <= 0.0:
		return
	panel.reset_size()
	var sz := panel.get_combined_minimum_size()
	sz.x = clampf(sz.x, 300.0, vp.x - 24.0)
	sz.y = clampf(sz.y, 180.0, vp.y - 24.0)
	panel.size = sz
	panel.position = Vector2(
		maxf(12.0, (vp.x - sz.x) * 0.5),
		maxf(12.0, (vp.y - sz.y) * 0.5)
	).floor()


# --- Ready-Made Decks Selector & Auto-.YDC Exporter (📦 المجموعات الجاهزة) ---

func _build_special_set_full_deck(entry: Dictionary) -> Dictionary:
	if CardDB.cards.is_empty():
		CardDB.load_db()
	var main_cards: Array[int] = []
	var fusion_cards: Array[int] = []
	var counts: Dictionary = {}
	var single_copy_ids := {16: true, 17: true, 18: true, 19: true, 20: true, 47: true, 335: true, 347: true, 573: true, 751: true, 939: true, 968: true, 1008: true, 1010: true, 1056: true, 1061: true, 1068: true, 1095: true, 1160: true, 1214: true, 1449: true, 1450: true}
	var core_ids: Array = entry.get("cards", [])
	for raw_id: Variant in core_ids:
		var cid := int(raw_id)
		var cdict := CardDB.by_id(cid)
		if cdict.is_empty() or not CardDB.has_card_art(cdict):
			continue
		var is_fus := CardDB.group_of(cdict) == CardDB.Group.FUSION
		var copies := 1 if single_copy_ids.has(cid) else (2 if is_fus else 3)
		for _i in copies:
			if is_fus:
				if fusion_cards.size() < 15:
					fusion_cards.append(cid)
			else:
				if main_cards.size() < 40 and int(counts.get(cid, 0)) < 3:
					main_cards.append(cid)
					counts[cid] = int(counts.get(cid, 0)) + 1
	# Verified obtainable, Arabic-translated staples with valid card art
	var staples: Array[int] = [
		1008, 335, 1061, 1079, 1056, 1002, 1214, 939, 1095, 968,
		1160, 1068, 347, 1010, 47, 573, 751, 590, 500, 427,
		1055, 1028, 1029, 1030, 1094, 1001, 1023, 1902, 303, 1449,
		1450, 740, 1016, 310, 348, 1162, 1096, 331
	]
	for st_id in staples:
		if main_cards.size() >= 40:
			break
		var st_card := CardDB.by_id(st_id)
		if st_card.is_empty() or not CardDB.has_card_art(st_card) or int(st_card.get("pack", 0)) == 0:
			continue
		var max_c := mini(1 if single_copy_ids.has(st_id) else 2, NativeCardLimits.copy_limit("joey", st_id, {}))
		while main_cards.size() < 40 and int(counts.get(st_id, 0)) < max_c:
			main_cards.append(st_id)
			counts[st_id] = int(counts.get(st_id, 0)) + 1
	return {
		"main": main_cards,
		"fusion": fusion_cards,
		"side": [],
	}


func _build_ready_decks_panel() -> void:
	var panel_box := _panel_style()
	panel_box.set_content_margin_all(14)
	_ready_decks_panel.add_theme_stylebox_override("panel", panel_box)
	_ready_decks_panel.custom_minimum_size = Vector2(720, 480)
	_ready_decks_panel.hide()
	add_child(_ready_decks_panel)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(688, 0)
	root.add_theme_constant_override("separation", 8)
	_ready_decks_panel.add_child(root)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	root.add_child(header_row)

	_ready_decks_title = Label.new()
	_ready_decks_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_decks_title.add_theme_font_override("font", Assets.ui_font(700))
	_ready_decks_title.add_theme_font_size_override("font_size", 19)
	_ready_decks_title.add_theme_color_override("font_color", DialogTheme.GOLD)
	header_row.add_child(_ready_decks_title)

	_ready_decks_wheel_btn = Button.new()
	_ready_decks_wheel_btn.custom_minimum_size = Vector2(150, 32)
	_style_btn(_ready_decks_wheel_btn, false, true)
	_ready_decks_wheel_btn.pressed.connect(open_special_wheel_spin)
	header_row.add_child(_ready_decks_wheel_btn)

	_ready_decks_unlock_all_btn = Button.new()
	_ready_decks_unlock_all_btn.custom_minimum_size = Vector2(230, 32)
	_style_btn(_ready_decks_unlock_all_btn, true, true)
	_ready_decks_unlock_all_btn.pressed.connect(_on_ready_decks_unlock_and_export_all)
	header_row.add_child(_ready_decks_unlock_all_btn)

	_ready_decks_hint = Label.new()
	_ready_decks_hint.custom_minimum_size = Vector2(670, 0)
	_ready_decks_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_decks_hint.add_theme_font_override("font", Assets.ui_font())
	_ready_decks_hint.add_theme_font_size_override("font_size", 12)
	_ready_decks_hint.add_theme_color_override("font_color", DialogTheme.CYAN_SOFT)
	_ready_decks_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_ready_decks_hint)

	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	root.add_child(filter_row)

	_ready_decks_search = LineEdit.new()
	_ready_decks_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_decks_search.custom_minimum_size = Vector2(180, 34)
	_style_input(_ready_decks_search)
	_ready_decks_search.add_theme_font_size_override("font_size", 13)
	_ready_decks_search.text_changed.connect(func(_t: String) -> void: _rebuild_ready_decks_list())
	filter_row.add_child(_ready_decks_search)

	for cat_id in ["all", "special", "yugi", "kaiba", "joey"]:
		var cbtn := Button.new()
		cbtn.custom_minimum_size = Vector2(74, 34)
		var captured_cat := str(cat_id)
		cbtn.pressed.connect(func() -> void:
			_ready_decks_cat = captured_cat
			_refresh_ready_decks_category_buttons()
			_rebuild_ready_decks_list())
		filter_row.add_child(cbtn)
		_ready_decks_cat_btns[cat_id] = cbtn

	var list_panel := PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", _subbox_style())
	list_panel.custom_minimum_size = Vector2(676, 268)
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(list_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(656, 250)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(scroll)

	_ready_decks_list_vbox = VBoxContainer.new()
	_ready_decks_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_decks_list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_ready_decks_list_vbox)

	_ready_decks_status = Label.new()
	_ready_decks_status.custom_minimum_size = Vector2(670, 20)
	_ready_decks_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ready_decks_status.add_theme_font_override("font", Assets.ui_font(700))
	_ready_decks_status.add_theme_font_size_override("font_size", 13)
	_ready_decks_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ready_decks_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_ready_decks_status)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	_ready_decks_open_editor_btn = Button.new()
	_ready_decks_open_editor_btn.custom_minimum_size = Vector2(240, 36)
	_style_btn(_ready_decks_open_editor_btn, true, false)
	_ready_decks_open_editor_btn.pressed.connect(_on_ready_decks_open_editor)
	footer.add_child(_ready_decks_open_editor_btn)

	_ready_decks_close_btn = Button.new()
	_ready_decks_close_btn.custom_minimum_size = Vector2(110, 36)
	_style_btn(_ready_decks_close_btn, false)
	_ready_decks_close_btn.pressed.connect(close_all)
	footer.add_child(_ready_decks_close_btn)


func open_ready_decks() -> void:
	if _spinning:
		return
	_code_panel.hide()
	_wheel_panel.hide()
	_admin_panel.hide()
	_populate_ready_decks_entries()
	_refresh_ready_decks_texts()
	_rebuild_ready_decks_list()
	_backdrop.show()
	_ready_decks_panel.show()
	_center_panel(_ready_decks_panel)
	_center_panel.call_deferred(_ready_decks_panel)


func _refresh_ready_decks_texts() -> void:
	_ready_decks_title.text = _tr(
		"📦 المجموعات الجاهزة وتصدير الدكات (.YDC)",
		"📦 Mazos Listos y Exportación (.YDC)",
		"📦 Ready-Made Decks & .YDC Export"
	)
	var rem_sets := sets_remaining_cooldown_sec()
	if rem_sets <= 0:
		_ready_decks_wheel_btn.text = _tr("👑 عجلة المجموعات · جاهزة!", "👑 Ruleta de Mazos · ¡Lista!", "👑 Sets Wheel · Ready!")
	else:
		_ready_decks_wheel_btn.text = _tr("👑 عجلة المجموعات · %s", "👑 Ruleta · %s", "👑 Sets · %s") % format_duration(rem_sets)
	_ready_decks_unlock_all_btn.text = _tr(
		"🔓 فتح كل البطاقات + تصدير الكل (.YDC)",
		"🔓 Desbloquear todo + Exportar (.YDC)",
		"🔓 Unlock All Cards + Export All (.YDC)"
	)
	_ready_decks_hint.text = _tr(
		"اضغط على أي مجموعة جاهزة بالأسفل لفتح البطاقات كلها تلقائياً وحفظ المجموعة كدكة بصيغة (.YDC) وتصديرها فوراً إلى واجهة الدكات!",
		"Pulsa cualquier mazo para desbloquear todas las cartas, guardarlo como .YDC y exportarlo automáticamente al Editor de Mazos.",
		"Click any ready-made deck below to unlock all cards, save it as a .YDC deck file, and export it directly to the Deck Editor!"
	)
	_ready_decks_search.placeholder_text = _tr("🔍 ابحث عن مجموعة جاهزة...", "🔍 Buscar mazo...", "🔍 Search ready-made deck...")
	_ready_decks_open_editor_btn.text = _tr(
		"🎴 فتح واجهة الدكات الآن",
		"🎴 Abrir Editor de Mazos",
		"🎴 Open Deck Editor Now"
	)
	_ready_decks_close_btn.text = _tr("إغلاق", "Cerrar", "Close")
	_ready_decks_status.add_theme_color_override("font_color", DialogTheme.GOLD_LIGHT)
	_ready_decks_status.text = _tr(
		"متاح %d مجموعة جاهزة · اختر أي مجموعة لحفظها بصيغة .YDC وتفعيلها فوراً.",
		"%d mazos listos disponibles · Elige cualquiera para guardarlo como .YDC y activarlo.",
		"%d ready-made decks available · Click any deck to save as .YDC and activate."
	) % _ready_decks_entries.size()
	_refresh_ready_decks_category_buttons()


func _refresh_ready_decks_category_buttons() -> void:
	var labels := {
		"all": _tr("الكل", "Todos", "All"),
		"special": _tr("★ خاصة", "★ Especial", "★ Special"),
		"yugi": _tr("يوغي", "Yugi", "Yugi"),
		"kaiba": _tr("كايبا", "Kaiba", "Kaiba"),
		"joey": _tr("جوي", "Joey", "Joey"),
	}
	for cat_id in _ready_decks_cat_btns.keys():
		var btn: Button = _ready_decks_cat_btns[cat_id]
		btn.text = str(labels.get(cat_id, cat_id))
		_style_btn(btn, _ready_decks_cat == cat_id, cat_id == "special")


func _populate_ready_decks_entries() -> void:
	_ready_decks_entries.clear()
	if CardDB.cards.is_empty():
		CardDB.load_db()
	for s: Dictionary in SPECIAL_SETS:
		var s_name = _tr(str(s["ar"]), str(s["es"]), str(s["en"]))
		var full_deck := _build_special_set_full_deck(s)
		var exp_name = "Ready_" + str(s.get("id", "set"))
		_ready_decks_entries.append({
			"category": "special",
			"tag": _tr("★ مجموعة خاصة", "★ Especial", "★ Special"),
			"name": s_name,
			"export_name": exp_name,
			"cover_id": int(s.get("cover_id", 34)),
			"accent": s.get("accent", DialogTheme.GOLD),
			"deck": full_deck,
		})
	var ed_tags := {
		"yugi": _tr("يوغي", "Yugi", "Yugi"),
		"kaiba": _tr("كايبا", "Kaiba", "Kaiba"),
		"joey": _tr("جوي", "Joey", "Joey"),
	}
	var ed_accents := {
		"yugi": Color(0.62, 0.32, 0.92),
		"kaiba": Color(0.22, 0.68, 0.98),
		"joey": Color(0.92, 0.56, 0.20),
	}
	for g in ["yugi", "kaiba", "joey"]:
		var presets: Array = _RivalDeckChoice.PRESET_DECKS.get(g, [])
		for raw_entry: Variant in presets:
			if not (raw_entry is Dictionary):
				continue
			var entry: Dictionary = raw_entry
			var p := str(entry.get("path", ""))
			if p.is_empty() or (Paths.has_data() and not Assets.exists(p)):
				continue
			var raw_json: Variant = Assets.read_json(p) if Paths.has_data() else {}
			var deck_dict: Dictionary = {}
			if raw_json is Dictionary:
				deck_dict = raw_json as Dictionary
			elif raw_json is Array:
				deck_dict = {"main": raw_json}
			var main_arr: Array = deck_dict.get("main", [])
			if main_arr.is_empty():
				continue
			var p_name = _tr(str(entry.get("ar", "")), str(entry.get("es", "")), str(entry.get("en", "")))
			var base_file := p.get_file().get_basename()
			var exp_name := "%s_%s" % [g.capitalize(), base_file]
			var cov_id := int(main_arr[0]) if not main_arr.is_empty() else 34
			_ready_decks_entries.append({
				"category": g,
				"tag": str(ed_tags[g]),
				"name": p_name,
				"export_name": exp_name,
				"cover_id": cov_id,
				"accent": ed_accents[g],
				"deck": deck_dict,
			})


func _rebuild_ready_decks_list() -> void:
	if not is_instance_valid(_ready_decks_list_vbox):
		return
	for ch in _ready_decks_list_vbox.get_children():
		ch.queue_free()
	var q := _ready_decks_search.text.strip_edges().to_lower() if is_instance_valid(_ready_decks_search) else ""
	var shown := 0
	for i in _ready_decks_entries.size():
		var item: Dictionary = _ready_decks_entries[i]
		var cat := str(item.get("category", ""))
		if _ready_decks_cat != "all" and cat != _ready_decks_cat:
			continue
		var nm := str(item.get("name", ""))
		var tg := str(item.get("tag", ""))
		var ex := str(item.get("export_name", ""))
		if not q.is_empty() and nm.to_lower().find(q) == -1 and tg.to_lower().find(q) == -1 and ex.to_lower().find(q) == -1:
			continue
		shown += 1
		var row_panel := PanelContainer.new()
		var rbox := StyleBoxFlat.new()
		var acc: Color = item.get("accent", DialogTheme.CYAN)
		rbox.bg_color = Color(0.05, 0.065, 0.14, 0.96)
		rbox.border_color = Color(acc, 0.65)
		rbox.set_border_width_all(1)
		rbox.set_corner_radius_all(8)
		rbox.content_margin_left = 10
		rbox.content_margin_right = 10
		rbox.content_margin_top = 6
		rbox.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", rbox)
		_ready_decks_list_vbox.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row_panel.add_child(row)

		var badge_lbl := Label.new()
		badge_lbl.text = "[%s]" % tg
		badge_lbl.custom_minimum_size = Vector2(96, 0)
		badge_lbl.add_theme_font_override("font", Assets.ui_font(700))
		badge_lbl.add_theme_font_size_override("font_size", 12)
		badge_lbl.add_theme_color_override("font_color", acc.lightened(0.25))
		row.add_child(badge_lbl)

		var deck_dict: Dictionary = item.get("deck", {})
		var m_cnt = (deck_dict.get("main", []) as Array).size()
		var f_cnt = (deck_dict.get("fusion", []) as Array).size()
		var s_cnt = (deck_dict.get("side", []) as Array).size()

		var title_lbl := Label.new()
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.text = "%s   (%d بطاقة · %s.ydc)" % [nm, m_cnt + f_cnt + s_cnt, ex] if Assets.lang == "a" else "%s   (%d cards · %s.ydc)" % [nm, m_cnt + f_cnt + s_cnt, ex]
		title_lbl.add_theme_font_override("font", Assets.ui_font(700))
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", Color.WHITE)
		title_lbl.clip_text = true
		row.add_child(title_lbl)

		var pick_btn := Button.new()
		pick_btn.custom_minimum_size = Vector2(186, 32)
		pick_btn.text = _tr("📥 حفظ (.YDC) + فتح البطاقات", "📥 Guardar (.YDC) + Abrir", "📥 Save (.YDC) + Unlock All")
		_style_btn(pick_btn, true, cat == "special")
		var captured_item: Dictionary = item
		pick_btn.pressed.connect(func() -> void: _on_select_ready_made_deck(captured_item))
		row.add_child(pick_btn)

	if shown == 0:
		var empty_lbl := Label.new()
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", Assets.ui_font())
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.75, 0.80, 0.90))
		empty_lbl.text = _tr("لا توجد مجموعات مطابقة للبحث.", "No hay mazos que coincidan.", "No matching decks found.")
		_ready_decks_list_vbox.add_child(empty_lbl)


func _on_select_ready_made_deck(item: Dictionary) -> void:
	var deck_dict: Dictionary = item.get("deck", {})
	var exp_name := str(item.get("export_name", "Ready_Deck"))
	var disp_name := str(item.get("name", exp_name))
	var res := SaveData.apply_ready_made_deck(deck_dict, exp_name, true)
	# Also export all other ready-made decks to saves/decks/ so the Deck Editor's Load (.YDC) screen has all of them ready!
	SaveData.export_all_ready_made_decks_to_ydc(_ready_decks_entries)
	_ready_decks_status.add_theme_color_override("font_color", Color(0.42, 0.98, 0.66))
	_ready_decks_status.text = _tr(
		"✓ تم فتح جميع البطاقات وحفظ «%s» بصيغة (%s.ydc) وتصدير المجموعات الجاهزة لواجهة الدكات وتفعيلها!",
		"✓ ¡Todas las cartas desbloqueadas! «%s» guardado como (%s.ydc) y exportado al Editor de Mazos.",
		"✓ All cards unlocked! \"%s\" saved as (%s.ydc), exported to Deck Editor, and activated!"
	) % [disp_name, str(res.get("name", exp_name))]
	card_unlocked.emit(int(item.get("cover_id", 34)))


func _on_ready_decks_unlock_and_export_all() -> void:
	if _ready_decks_entries.is_empty():
		_populate_ready_decks_entries()
	SaveData.unlock_all()
	SaveData.data["all_cards_unlocked"] = true
	var opts_root: Dictionary = SaveData.data.get_or_add("options", {})
	for g in SaveData.GAMES:
		var g_opts: Dictionary = opts_root.get_or_add(g, {})
		if g == "joey":
			g_opts["card_set_full"] = true
	SaveData.save()
	var exported_count := SaveData.export_all_ready_made_decks_to_ydc(_ready_decks_entries)
	_ready_decks_status.add_theme_color_override("font_color", Color(0.42, 0.98, 0.66))
	_ready_decks_status.text = _tr(
		"✓ تم فتح جميع البطاقات (100%%) وتصدير %d مجموعة جاهزة بصيغة (.YDC) مباشرة إلى واجهة الدكات!",
		"✓ ¡100%% de cartas desbloqueadas y %d mazos exportados como (.YDC) al Editor de Mazos!",
		"✓ Unlocked 100%% of cards and exported %d ready-made decks as (.YDC) to the Deck Editor!"
	) % exported_count
	card_unlocked.emit(34)


func _on_ready_decks_open_editor() -> void:
	if _ready_decks_entries.is_empty():
		_populate_ready_decks_entries()
	# Ensure all cards are unlocked and all ready-made decks are exported to .ydc before opening the Deck Editor
	SaveData.unlock_all()
	SaveData.export_all_ready_made_decks_to_ydc(_ready_decks_entries)
	close_all()
	var target_game := "joey"
	if not Paths.has_game(target_game):
		for g in ["yugi", "kaiba", "joey"]:
			if Paths.has_game(g):
				target_game = g
				break
	Game.open_deck_editor(target_game)

