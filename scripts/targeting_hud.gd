extends Control

var active:        bool  = false
var lock_progress: float = 0.0
var locked:        bool  = false
var lock_target:   Node3D = null   # riferimento al bersaglio per l'indicatore
var is_nuke:        bool  = false

var _blink_timer:   float = 0.0
var _blink_visible: bool  = true

const MIRINO_SIZE := 80.0
const COL_SEARCH  := Color(1.0, 1.0, 1.0, 0.9)
const COL_LOCKED  := Color(1.0, 0.15, 0.1, 1.0)
const BLINK_RATE  := 0.12
const IND_SIZE    := 24.0   # dimensione indicatore sul bersaglio

func _ready() -> void:
	add_to_group("targeting_hud")
	# il Control deve coprire tutto lo schermo per disegnare ovunque
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	if not active:
		queue_redraw()
		return
	if not locked:
		_blink_timer += delta
		if _blink_timer >= BLINK_RATE:
			_blink_timer = 0.0
			_blink_visible = not _blink_visible
	else:
		_blink_visible = true
	queue_redraw()

func _draw() -> void:
	if not active:
		return

	var screen_center := size * 0.5
	var half := MIRINO_SIZE * 0.5
	var corner := MIRINO_SIZE * 0.22
	var col_locked := Color(0.1, 1.0, 0.2, 1.0) if is_nuke else COL_LOCKED
	var col := col_locked if locked else COL_SEARCH

	# ── Mirino centrale ──────────────────────────────────
	if _blink_visible:
		var cx := screen_center.x
		var cy := screen_center.y
		draw_line(Vector2(cx - half, cy - half), Vector2(cx - half + corner, cy - half), col, 2.0)
		draw_line(Vector2(cx - half, cy - half), Vector2(cx - half, cy - half + corner), col, 2.0)
		draw_line(Vector2(cx + half, cy - half), Vector2(cx + half - corner, cy - half), col, 2.0)
		draw_line(Vector2(cx + half, cy - half), Vector2(cx + half, cy - half + corner), col, 2.0)
		draw_line(Vector2(cx - half, cy + half), Vector2(cx - half + corner, cy + half), col, 2.0)
		draw_line(Vector2(cx - half, cy + half), Vector2(cx - half, cy + half - corner), col, 2.0)
		draw_line(Vector2(cx + half, cy + half), Vector2(cx + half - corner, cy + half), col, 2.0)
		draw_line(Vector2(cx + half, cy + half), Vector2(cx + half, cy + half - corner), col, 2.0)

		# arco progresso lock
		if not locked and lock_progress > 0.0:
			draw_arc(screen_center, half * 0.6, -PI * 0.5, -PI * 0.5 + TAU * lock_progress, 32, col, 2.0)

		if locked:
			var label := "NUKE LOCKED" if is_nuke else "LOCKED"
			draw_string(ThemeDB.fallback_font, Vector2(cx - 30, cy + half + 18),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col_locked)

	# ── Indicatore sul bersaglio ─────────────────────────
	if is_instance_valid(lock_target):
		var camera := get_viewport().get_camera_3d()
		if camera and not camera.is_position_behind(lock_target.global_position):
			var sp := camera.unproject_position(lock_target.global_position)
			var h := IND_SIZE * 0.5
			var ind_col_locked := Color(0.1, 1.0, 0.2, 1.0) if is_nuke else COL_LOCKED
			var ind_col := ind_col_locked if locked else Color(1.0, 0.8, 0.0, 0.9)
			# rombo attorno al bersaglio
			draw_line(sp + Vector2(0, -h),  sp + Vector2(h, 0),   ind_col, 1.5)
			draw_line(sp + Vector2(h, 0),   sp + Vector2(0, h),   ind_col, 1.5)
			draw_line(sp + Vector2(0, h),   sp + Vector2(-h, 0),  ind_col, 1.5)
			draw_line(sp + Vector2(-h, 0),  sp + Vector2(0, -h),  ind_col, 1.5)
			# etichetta distanza
			if lock_target is Node3D:
				var player := get_tree().get_first_node_in_group("player")
				if player:
					var dist := int(player.global_position.distance_to(lock_target.global_position))
					draw_string(ThemeDB.fallback_font, sp + Vector2(h + 4, 4),
						str(dist) + "m", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ind_col)
