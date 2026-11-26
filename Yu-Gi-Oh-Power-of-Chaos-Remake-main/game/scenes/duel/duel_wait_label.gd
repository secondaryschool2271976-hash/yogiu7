class_name DuelWaitLabel
extends Node2D
## Duelo LAN de Joey (D17): cartel "El oponente esta haciendo un movimiento" (objeto con
## update 456360, duel/effect/layerfont.txt indice 1 = wait_?.bmp). Mientras se espera a la red
## (5bdad0) y no hay objetos de presentacion activos (44ba10), el contador sube de 4 en 4 hasta
## 0x100; si no, baja de 4 en 4 hasta 0. Por encima de 0xe0 el cartel baja desde arriba con la
## tabla de cosenos (a52ee8): x = 0x20d - ancho / 2, y = (alto + 0x10) * T >> 16 - alto, con
## T = cos[((c * 8 - 0x700) / 2 - 0x80) & 0x1ff]; queda en y = 16 con el contador lleno.

var waiting := false
var top_offset := 0
var _tex: Texture2D
var _counter := 0
var _clock := 0.0
var _blend := NativeBlend.new()


var _font: Font


func setup(game: String) -> void:
	_font = Assets.ui_font(700)
	_tex = Assets.texture("%s/duel/effect/wait_?.bmp" % game)
	if _tex == null and Paths.has_game("joey"):
		_tex = Assets.texture("joey/duel/effect/wait_?.bmp")
	z_index = 85


func _process(delta: float) -> void:
	_clock += NativeClock.ticks(delta)
	while _clock >= 1.0:
		_clock -= 1.0
		if waiting:
			if _counter <= 0xff: _counter += 4
		elif _counter >= 1:
			_counter -= 4
		_blend.tick()
	_blend.fraction = _clock
	queue_redraw()


func _draw() -> void:
	if _counter <= 0xe0:
		return
	if _tex != null:
		var w := _tex.get_width()
		var h := _tex.get_height()
		var t := DuelVisualMath.cos_fx((((_counter * 8 - 0x700) / 2) - 0x80) & 0x1ff)
		var y := ((h + 0x10) * t >> 16) - h
		draw_texture(_tex, Vector2(0x20d - w / 2, _blend.at("y", y) + top_offset))
		return
	var msg: String = "في انتظار حركة الخصم..." if Assets.lang == "a" else ("Esperando al oponente..." if Assets.lang == "s" else "Waiting for opponent...")
	var rect := Rect2(370, 14 + top_offset, 310, 34)
	draw_rect(rect, Color(0.08, 0.05, 0.12, 0.92), true)
	draw_rect(rect, Color(0.95, 0.78, 0.30, 0.95), false, 2.0)
	var mw: float = _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(_font, Vector2(rect.get_center().x - mw * 0.5, rect.position.y + 23.0), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.93, 0.70))
