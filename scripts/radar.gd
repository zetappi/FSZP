extends Control

# ── Configurazione visiva ──────────────────────────────────
@export var radar_radius:    float = 80.0   # raggio disco in pixel
@export var radar_range:     float = 300.0  # distanza massima nel mondo 3D
@export var ellipse_y_scale: float = 0.35   # schiacciamento verticale (prospettiva)
@export var line_max_height: float = 40.0   # altezza max linea verticale in pixel

# Colori
const COL_DISK_RING  := Color(0.0, 0.8, 0.3, 0.25)
const COL_DISK_FILL  := Color(0.0, 0.4, 0.15, 0.18)
const COL_CROSS      := Color(0.0, 0.8, 0.3, 0.35)
const COL_ABOVE      := Color(0.0, 1.0, 0.4, 1.0)   # bersaglio sopra il piano
const COL_BELOW      := Color(1.0, 0.4, 0.0, 1.0)   # bersaglio sotto il piano
const COL_LINE       := Color(0.0, 0.8, 0.3, 0.7)

var _player: Node3D

func _ready() -> void:
	# trova il player nella scena
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(_player):
		return

	var center := Vector2(radar_radius, radar_radius * ellipse_y_scale + line_max_height * 0.5)

	_draw_disk(center)
	_draw_targets(center)

func _draw_disk(center: Vector2) -> void:
	# Riempi ellisse
	_draw_ellipse_filled(center, radar_radius, radar_radius * ellipse_y_scale, COL_DISK_FILL)

	# Anelli concentrici: 100% e 50%
	for r_frac in [1.0, 0.5]:
		_draw_ellipse(center, radar_radius * r_frac, radar_radius * ellipse_y_scale * r_frac, COL_DISK_RING, 1.5)

	# Croce centrale
	draw_line(center + Vector2(-radar_radius, 0), center + Vector2(radar_radius, 0), COL_CROSS, 1.0)
	draw_line(center + Vector2(0, -radar_radius * ellipse_y_scale), center + Vector2(0, radar_radius * ellipse_y_scale), COL_CROSS, 1.0)

func _draw_targets(center: Vector2) -> void:
	if not is_instance_valid(_player):
		return
	var player_basis := _player.global_transform.basis

	var targets := []
	for n in get_tree().get_nodes_in_group("asteroids"):
		targets.append({"node": n, "type": "asteroid"})
	for n in get_tree().get_nodes_in_group("enemies"):
		targets.append({"node": n, "type": "enemy"})
	for n in get_tree().get_nodes_in_group("containers"):
		targets.append({"node": n, "type": "container"})
	for n in get_tree().get_nodes_in_group("structures"):
		targets.append({"node": n, "type": "structure"})

	for t in targets:
		var node: Node3D = t["node"]
		if not node is Node3D:
			continue

		var world_offset: Vector3 = node.global_position - _player.global_position
		var local: Vector3 = player_basis.inverse() * world_offset

		var dist_xz := Vector2(local.x, local.z).length()
		if dist_xz > radar_range and absf(local.y) > radar_range:
			continue

		var scale_factor := minf(dist_xz / radar_range, 1.0)
		var angle := atan2(local.x, -local.z)

		var px := sin(angle) * scale_factor * radar_radius
		var py := -cos(angle) * scale_factor * radar_radius * ellipse_y_scale

		var dot_pos := center + Vector2(px, py)

		var y_norm := clampf(local.y / radar_range, -1.0, 1.0)
		var line_h := y_norm * line_max_height

		# colore per tipo
		var col: Color
		match t["type"]:
			"enemy":
				col = Color(1.0, 0.15, 0.15, 1.0)
			"container":
				col = Color(0.3, 0.85, 1.0, 1.0)
			"structure":
				col = Color(1.0, 0.8, 0.0, 1.0)
			_:
				col = COL_ABOVE if local.y >= 0.0 else COL_BELOW

		draw_line(dot_pos, dot_pos + Vector2(0, -line_h), COL_LINE, 1.0)
		draw_rect(Rect2(dot_pos - Vector2(3, 3), Vector2(6, 6)), col)
		if absf(line_h) > 4.0:
			draw_rect(Rect2(dot_pos + Vector2(-2, -line_h - 2), Vector2(4, 4)), col)

# ── Helpers ellisse ────────────────────────────────────────
func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 64
	for i in steps + 1:
		var a := TAU * i / steps
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	for i in steps:
		draw_line(points[i], points[i + 1], color, width)

func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 64
	for i in steps:
		var a := TAU * i / steps
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)
