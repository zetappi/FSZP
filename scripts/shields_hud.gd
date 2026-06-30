extends Control

# ── Valori scudi [0.0 - 1.0] ──────────────────────────────
var shield_left:  float = 1.0
var shield_front: float = 1.0
var shield_back:  float = 1.0
var shield_right: float = 1.0

# ── Ricarica ───────────────────────────────────────────────
const RECHARGE_RATE  := 0.08   # per secondo
const RECHARGE_DELAY := 4.0    # secondi dopo un colpo prima di ricaricare
var _recharge_timer: float = 0.0

# ── Layout barre ──────────────────────────────────────────
const BAR_WIDTH   := 18.0
const BAR_HEIGHT  := 120.0
const BAR_SPACING := 12.0
const LABELS      := ["L", "F", "B", "R"]

const COL_BG      := Color(0.1,  0.1,  0.1,  0.7)
const COL_FULL    := Color(0.0,  0.85, 0.35, 1.0)
const COL_MID     := Color(0.9,  0.7,  0.0,  1.0)
const COL_LOW     := Color(0.9,  0.15, 0.1,  1.0)
const COL_LABEL   := Color(0.7,  0.9,  0.7,  0.9)
const COL_BORDER  := Color(0.0,  0.6,  0.3,  0.5)

func _ready() -> void:
	# registra questo nodo come riferimento globale accessibile dal player
	add_to_group("shields_hud")

func _process(delta: float) -> void:
	# ricarica lenta dopo delay
	if _recharge_timer > 0.0:
		_recharge_timer -= delta
	else:
		shield_left  = minf(shield_left  + RECHARGE_RATE * delta, 1.0)
		shield_front = minf(shield_front + RECHARGE_RATE * delta, 1.0)
		shield_back  = minf(shield_back  + RECHARGE_RATE * delta, 1.0)
		shield_right = minf(shield_right + RECHARGE_RATE * delta, 1.0)
	queue_redraw()

func take_hit(direction_local: Vector3, damage: float) -> void:
	# direction_local: direzione del proiettile in spazio locale del player
	# determina quale scudo colpire dal dot product con gli assi
	_recharge_timer = RECHARGE_DELAY

	var fwd  :=  direction_local.dot(Vector3(0, 0,  1))  # front: proiettile arriva da -Z, va verso +Z
	var back :=  direction_local.dot(Vector3(0, 0, -1))  # back:  proiettile arriva da +Z
	var left :=  direction_local.dot(Vector3( 1, 0, 0))  # left
	var right := direction_local.dot(Vector3(-1, 0, 0))  # right

	var mx := maxf(maxf(fwd, back), maxf(left, right))

	if mx == fwd:
		shield_front = maxf(shield_front - damage, 0.0)
	elif mx == back:
		shield_back  = maxf(shield_back  - damage, 0.0)
	elif mx == left:
		shield_left  = maxf(shield_left  - damage, 0.0)
	else:
		shield_right = maxf(shield_right - damage, 0.0)

func _draw() -> void:
	var values := [shield_left, shield_front, shield_back, shield_right]
	var total_w := (BAR_WIDTH + BAR_SPACING) * 4 - BAR_SPACING
	var start_x := (size.x - total_w) * 0.5

	for i in 4:
		var x := start_x + i * (BAR_WIDTH + BAR_SPACING)
		var val: float = values[i]

		# sfondo barra
		draw_rect(Rect2(x, 0, BAR_WIDTH, BAR_HEIGHT), COL_BG)
		draw_rect(Rect2(x, 0, BAR_WIDTH, BAR_HEIGHT), COL_BORDER, false, 1.0)

		# barra colorata — cresce dal basso
		if val > 0.0:
			var fill_h := BAR_HEIGHT * val
			var col := COL_FULL if val > 0.5 else (COL_MID if val > 0.25 else COL_LOW)
			draw_rect(Rect2(x, BAR_HEIGHT - fill_h, BAR_WIDTH, fill_h), col)

		# etichetta
		draw_string(
			ThemeDB.fallback_font,
			Vector2(x + BAR_WIDTH * 0.5 - 5, BAR_HEIGHT + 16),
			LABELS[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, COL_LABEL
		)
