extends Control

# ── Barre orizzontali Speed/Roll/Pitch ────────────────────
const BAR_W      := 100.0
const BAR_H      := 12.0
const BAR_GAP    := 8.0
const TICK_W     := 2.0

const COL_BG     := Color(0.05, 0.05, 0.05, 0.8)
const COL_BAR    := Color(0.0,  0.85, 0.35, 1.0)
const COL_BORDER := Color(0.0,  0.6,  0.3,  0.5)
const COL_LABEL  := Color(0.7,  0.9,  0.7,  0.9)
const COL_TICK   := Color(1.0,  1.0,  1.0,  0.6)

# ── Energy Banks ──────────────────────────────────────────
const BANK_W     := 100.0
const BANK_H     := 14.0
const BANK_GAP   := 5.0
const BANK_COUNT := 4
const COL_ENERGY := Color(1.0, 0.55, 0.0, 1.0)

# ── Spia stato ────────────────────────────────────────────
const SPIA_R     := 7.0
const COL_GREEN  := Color(0.0,  0.9,  0.2,  1.0)
const COL_YELLOW := Color(0.95, 0.8,  0.0,  1.0)
const COL_RED    := Color(0.95, 0.1,  0.1,  1.0)

var _blink_timer:   float = 0.0
var _blink_visible: bool  = true

func _process(delta: float) -> void:
	_blink_timer += delta
	if _blink_timer >= 0.35:
		_blink_timer = 0.0
		_blink_visible = not _blink_visible
	queue_redraw()

func _draw() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return

	var throttle: float = player._throttle
	var max_throttle: float = 80.0
	var speed_norm := clampf(throttle / max_throttle, 0.0, 1.0)

	# barre Speed / Roll / Pitch centrate su 0
	var labels := ["SPEED", "ROLL", "PITCH"]
	# speed è 0-1 positivo; roll/pitch sono rate di rotazione (usiamo 0 come centro)
	var values := [speed_norm, 0.0, 0.0]  # roll/pitch: reserved, sempre 0 per ora

	var y := 0.0
	for i in 3:
		draw_string(ThemeDB.fallback_font, Vector2(0, y + BAR_H - 1),
			labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_LABEL)
		var bx := 44.0
		draw_rect(Rect2(bx, y, BAR_W, BAR_H), COL_BG)
		draw_rect(Rect2(bx, y, BAR_W, BAR_H), COL_BORDER, false, 1.0)
		var fill: float = BAR_W * values[i]
		if fill > 0.0:
			draw_rect(Rect2(bx, y, fill, BAR_H), COL_BAR)
		# tacca centrale
		var cx := bx + BAR_W * 0.5
		draw_rect(Rect2(cx - TICK_W * 0.5, y, TICK_W, BAR_H), COL_TICK)
		y += BAR_H + BAR_GAP

	y += 6.0

	# ── Energy Banks ──────────────────────────────────────
	var shields_hud := get_tree().get_first_node_in_group("shields_hud")
	var fs: float = 1.0
	var as_val: float = 1.0
	if shields_hud:
		fs = shields_hud.shield_front
		as_val = shields_hud.shield_aft
	# 4 batterie: prime 2 alimentano FS, ultime 2 AS
	var bank_vals := [
		clampf(fs * 2.0, 0.0, 1.0),
		clampf(fs * 2.0 - 1.0, 0.0, 1.0),
		clampf(as_val * 2.0, 0.0, 1.0),
		clampf(as_val * 2.0 - 1.0, 0.0, 1.0),
	]
	draw_string(ThemeDB.fallback_font, Vector2(0, y + BANK_H - 1),
		"ENRG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_LABEL)
	var ex := 44.0
	for i in BANK_COUNT:
		var by := y + i * (BANK_H + BANK_GAP)
		var bval: float = bank_vals[i]
		draw_rect(Rect2(ex, by, BANK_W, BANK_H), COL_BG)
		draw_rect(Rect2(ex, by, BANK_W, BANK_H), COL_BORDER, false, 1.0)
		if bval > 0.0:
			draw_rect(Rect2(ex, by, BANK_W * bval, BANK_H), COL_ENERGY)

	y += BANK_COUNT * (BANK_H + BANK_GAP) + 8.0

	# ── Spia stato ────────────────────────────────────────
	var enemies := get_tree().get_nodes_in_group("enemies")
	var spia_col := COL_GREEN
	var under_attack := false
	for e in enemies:
		if e is Node3D and player is Node3D:
			var dist: float = player.global_position.distance_to(e.global_position)
			if dist < 80.0:
				spia_col = COL_YELLOW
			if dist < 40.0:
				under_attack = true
				break
	if under_attack:
		spia_col = COL_RED
		if not _blink_visible:
			return

	draw_circle(Vector2(44.0 + SPIA_R, y + SPIA_R), SPIA_R, spia_col)
	draw_arc(Vector2(44.0 + SPIA_R, y + SPIA_R), SPIA_R, 0, TAU, 16, COL_BORDER, 1.0)
