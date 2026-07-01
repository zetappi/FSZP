extends Control

# ── Scudi FS/AS [0.0 - 1.0] ───────────────────────────────
var shield_front: float = 1.0
var shield_aft:   float = 1.0

const RECHARGE_RATE  := 0.08
const RECHARGE_DELAY := 4.0
var _recharge_timer: float = 0.0

# ── Layout ────────────────────────────────────────────────
const SLOT_W     := 14.0
const SLOT_H     := 20.0
const SLOT_GAP   := 4.0
const LABEL_W    := 34.0

const BAR_W      := 28.0
const BAR_H      := 100.0
const BAR_GAP    := 10.0

const COL_BG     := Color(0.05, 0.05, 0.05, 0.8)
const COL_FULL   := Color(0.0,  0.85, 0.35, 1.0)
const COL_MID    := Color(0.9,  0.7,  0.0,  1.0)
const COL_LOW    := Color(0.9,  0.15, 0.1,  1.0)
const COL_BORDER := Color(0.0,  0.6,  0.3,  0.5)
const COL_LABEL  := Color(0.7,  0.9,  0.7,  0.9)
const COL_MSL    := Color(0.0,  0.85, 0.35, 1.0)
const COL_NUKE   := Color(0.1,  1.0,  0.2,  1.0)
const COL_EMPTY  := Color(0.2,  0.2,  0.2,  0.8)

func _ready() -> void:
	add_to_group("shields_hud")

func _process(delta: float) -> void:
	if _recharge_timer > 0.0:
		_recharge_timer -= delta
	else:
		shield_front = minf(shield_front + RECHARGE_RATE * delta, 1.0)
		shield_aft   = minf(shield_aft   + RECHARGE_RATE * delta, 1.0)
	queue_redraw()

func take_hit(direction_local: Vector3, damage: float) -> void:
	_recharge_timer = RECHARGE_DELAY
	var front_dot := direction_local.dot(Vector3(0, 0, 1))
	if front_dot >= 0.0:
		shield_front = maxf(shield_front - damage, 0.0)
	else:
		shield_aft = maxf(shield_aft - damage, 0.0)

func _draw() -> void:
	var y := 0.0

	# ── Icone missili ──────────────────────────────────────
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var msl_total:  int = player.missiles_count_max
		var nuke_total: int = player.nukes_count_max
		var msl_cur:  int = player.missiles_count
		var nuke_cur: int = player.nukes_count
		y = _draw_slots(y, "MSL", msl_total,  msl_cur,  COL_MSL)
		y += 6.0
		y = _draw_slots(y, "NUK", nuke_total, nuke_cur, COL_NUKE)
		y += 14.0

	# ── Barre scudi FS / AS ────────────────────────────────
	var values := [shield_front, shield_aft]
	var labels := ["FS", "AS"]
	var total_w: float = (BAR_W + BAR_GAP) * 2 - BAR_GAP
	var sx := (size.x - total_w) * 0.5

	for i in 2:
		var x: float = sx + i * (BAR_W + BAR_GAP)
		var val: float = values[i]

		draw_rect(Rect2(x, y, BAR_W, BAR_H), COL_BG)
		draw_rect(Rect2(x, y, BAR_W, BAR_H), COL_BORDER, false, 1.0)

		if val > 0.0:
			var fill_h: float = BAR_H * val
			var col := COL_FULL if val > 0.5 else (COL_MID if val > 0.25 else COL_LOW)
			draw_rect(Rect2(x, y + BAR_H - fill_h, BAR_W, fill_h), col)

		draw_string(ThemeDB.fallback_font,
			Vector2(x + BAR_W * 0.5 - 8, y + BAR_H + 14),
			labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_LABEL)

func _draw_slots(y: float, label: String, total: int, filled: int, col_on: Color) -> float:
	draw_string(ThemeDB.fallback_font, Vector2(0, y + SLOT_H - 3),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_LABEL)
	for i in total:
		var x: float = LABEL_W + i * (SLOT_W + SLOT_GAP)
		var col := col_on if i < filled else COL_EMPTY
		draw_rect(Rect2(x, y, SLOT_W, SLOT_H), col)
		draw_rect(Rect2(x, y, SLOT_W, SLOT_H), COL_BORDER, false, 1.0)
	return y + SLOT_H
