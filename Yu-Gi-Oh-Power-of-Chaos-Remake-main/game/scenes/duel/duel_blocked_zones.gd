extends Node2D
## Joey4497d0/449850: diez estados de3 bits; entrada1..7, dibujo chinka[q/2].
## 569e10/569fc0 comprueban inutilizacion, nunca ocupacion. Se leen los vinculos
## equivalentes del nucleo compartido Yugi, sin cambiar su memoria ni su RNG.
var states := PackedInt32Array()
var _sprites: Array[Sprite2D] = []
var _textures: Array[Texture2D] = []
var _last_tick := -1
var _anim_accum := 0.0

func _init() -> void:
	states.resize(10)
	for index in 10:
		var sprite := Sprite2D.new()
		sprite.position = DuelGeometry.zone(index / 5, index % 5)
		sprite.visible = false
		add_child(sprite)
		_sprites.append(sprite)

func _ready() -> void:
	for index in 4:
		var rel := "joey/duel/effect/chinka%d.yga" % (index + 1)
		var tex: Texture2D = Assets.texture(rel) if Assets.exists(rel) else null
		if tex == null:
			tex = _fallback_crack_texture(index)
		_textures.append(tex)

func _process(delta: float) -> void:
	if _textures.size() != 4:
		return
	var need_step := false
	for index in 10:
		if states[index] > 0 and states[index] < 7:
			need_step = true
			break
	if not need_step:
		_anim_accum = 0.0
		return
	_anim_accum += delta
	while _anim_accum >= 0.05:
		_anim_accum -= 0.05
		for index in 10:
			if states[index] > 0 and states[index] < 7:
				states[index] = mini(7, states[index] + 1)
				_sprites[index].texture = _textures[states[index] / 2]

static func _fallback_crack_texture(stage: int) -> Texture2D:
	var w := 64
	var h := 78
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var alpha := 0.55 + float(stage) * 0.13
	var fill_col := Color(0.08, 0.03, 0.04, alpha)
	var edge_col := Color(0.95, 0.24, 0.16, minf(1.0, alpha + 0.25))
	var glow_col := Color(1.0, 0.72, 0.22, minf(1.0, alpha + 0.2))
	var crack_col := Color(0.16, 0.06, 0.06, minf(0.98, alpha + 0.3))
	for y in range(3, h - 3):
		for x in range(3, w - 3):
			var on_outer := x <= 6 or x >= w - 7 or y <= 6 or y >= h - 7
			var on_inner := x == 7 or x == w - 8 or y == 7 or y == h - 8
			if on_outer:
				img.set_pixel(x, y, edge_col)
			elif on_inner:
				img.set_pixel(x, y, glow_col)
			else:
				img.set_pixel(x, y, fill_col)
	var span := int(float(mini(w, h) - 14) * float(stage + 1) / 4.0)
	var half := span / 2
	var cx := w / 2
	var cy := h / 2
	for d in range(-half, half + 1):
		for thick in range(-3, 4):
			var x1 := clampi(cx + d + thick, 4, w - 5)
			var y1 := clampi(cy + d, 4, h - 5)
			var x2 := clampi(cx + d + thick, 4, w - 5)
			var y2 := clampi(cy - d, 4, h - 5)
			var c := glow_col if thick == 0 else (edge_col if absi(thick) <= 2 else crack_col)
			img.set_pixel(x1, y1, c)
			img.set_pixel(x2, y2, c)
	return ImageTexture.create_from_image(img)

static func blocked(duel: Duel, p: int, z: int) -> bool:
	if duel is JoeyPresentationAdapter:
		var adapter := duel as JoeyPresentationAdapter
		if adapter.engine != null:
			return adapter.engine.f569e10(adapter._native_player(p), z) == 0
	if (duel.m.u8(DuelMem.pl(p) + 0x12) & (1 << z)) != 0: return true
	var at := DuelMem.zone(p, z)
	for index in duel.m.u16(at + 0x88):
		if duel.m.u8(at + 0x48 + index * 2) != 2: continue
		var link = duel.m.u16(at + 8 + index * 2)
		var source := DuelMem.zone(link & 1, (link >> 8) & 255)
		var card = duel.m.u16(source) & 4095
		if card == 0: continue
		var cid: int = duel.effect_card_id(card) if duel.has_method("effect_card_id") else duel.cards.id_of(card)
		if cid != 0x528: continue
		# 569e10: Colapso del terreno boca arriba, sin bits de anulacion1/5.
		var flags = duel.m.u8(source + 0x90)
		if (duel.m.u8(source + 6) & 2) != 0 and (flags & 0x22) == 0: return true
	return false

static func mask_for(duel: Duel) -> int:
	var mask := 0
	for p in 2:
		for z in 5:
			if blocked(duel, p, z): mask |= 1 << (p * 5 + z)
	return mask

func refresh(duel: Duel, tick: int) -> void:
	var elapsed := maxi(0, tick - _last_tick) if _last_tick >= 0 else 0
	if tick < _last_tick: states.fill(0)
	_last_tick = tick
	var mask := mask_for(duel)
	for index in 10:
		var enabled := (mask & (1 << index)) != 0
		if not enabled: states[index] = 0
		elif states[index] == 0: states[index] = 1
		elif elapsed > 0: states[index] = mini(7, states[index] + elapsed)
		_sprites[index].visible = enabled
		if enabled and _textures.size() == 4:
			_sprites[index].texture = _textures[states[index] / 2]
