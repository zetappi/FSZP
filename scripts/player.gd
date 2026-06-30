extends Node3D

@export var bullet_scene:    PackedScene
@export var fire_rate:       float = 0.18
@export var tractor_range:   float = 60.0
@export var tractor_speed:   float = 25.0
@export var cargo_collected: int   = 0

var _throttle:      float = 0.0
var _fire_cooldown: float = 0.0
var _tractor_target: Node3D = null

@onready var _muzzle: Node3D = $Muzzle
@onready var _tractor_beam: MeshInstance3D = $TractorBeam

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.002)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * 0.002)
	if event.is_action_pressed("fire"):
		_try_fire()

func _process(delta: float) -> void:
	rotate_y(-Input.get_axis("look_right", "look_left") * 1.5 * delta)
	rotate_object_local(Vector3.RIGHT, -Input.get_axis("look_down", "look_up") * 1.5 * delta)
	rotate_object_local(Vector3.FORWARD, Input.get_axis("roll_right", "roll_left") * 1.2 * delta)

	if Input.is_action_pressed("throttle_up"):
		_throttle = minf(_throttle + 20.0 * delta, 80.0)
	if Input.is_action_pressed("throttle_down"):
		_throttle = maxf(_throttle - 15.0 * delta, 0.0)

	global_position += -global_transform.basis.z * _throttle * delta

	_fire_cooldown -= delta
	if Input.is_action_pressed("fire") and _fire_cooldown <= 0.0:
		_try_fire()

	# ── Raggio traente ────────────────────────────────────
	if Input.is_action_pressed("tractor"):
		_update_tractor(delta)
	else:
		_stop_tractor()

	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_tractor(delta: float) -> void:
	# cerca il container più vicino nel range
	var best: Node3D = null
	var best_dist := tractor_range
	for c in get_tree().get_nodes_in_group("containers"):
		if c is Node3D:
			var d := global_position.distance_to(c.global_position)
			if d < best_dist:
				best_dist = d
				best = c

	if best != _tractor_target:
		if is_instance_valid(_tractor_target) and _tractor_target.has_method("stop_tractor"):
			_tractor_target.stop_tractor()
		_tractor_target = best
		if is_instance_valid(_tractor_target) and _tractor_target.has_method("start_tractor"):
			_tractor_target.start_tractor()

	if is_instance_valid(_tractor_target):
		# attira il container verso il player
		var dir := (global_position - _tractor_target.global_position).normalized()
		_tractor_target.global_position += dir * tractor_speed * delta

		# controlla se è abbastanza vicino da raccogliere
		if global_position.distance_to(_tractor_target.global_position) < 3.0:
			if _tractor_target.has_method("collect"):
				_tractor_target.collect()
			_tractor_target = null

		# disegna il raggio
		_draw_tractor_beam(_tractor_target)
	else:
		_tractor_beam.visible = false

func _stop_tractor() -> void:
	if is_instance_valid(_tractor_target) and _tractor_target.has_method("stop_tractor"):
		_tractor_target.stop_tractor()
	_tractor_target = null
	_tractor_beam.visible = false

func _draw_tractor_beam(target: Node3D) -> void:
	if not is_instance_valid(target):
		_tractor_beam.visible = false
		return
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# posizioni in spazio locale del TractorBeam (che è figlio del player)
	var local_start := Vector3.ZERO
	var local_end   := _tractor_beam.to_local(target.global_position)
	mesh.surface_add_vertex(local_start)
	mesh.surface_add_vertex(local_end)
	mesh.surface_end()
	_tractor_beam.mesh = mesh
	_tractor_beam.visible = true

func _try_fire() -> void:
	if bullet_scene == null or _fire_cooldown > 0.0:
		return
	_fire_cooldown = fire_rate
	var b: Node3D = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.global_transform = _muzzle.global_transform

func on_cargo_collected() -> void:
	cargo_collected += 1
	print("Cargo raccolto! Totale: ", cargo_collected)
