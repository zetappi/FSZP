extends Node3D

@export var bullet_scene:   PackedScene
@export var missile_scene:  PackedScene
@export var nuke_scene:     PackedScene
@export var fire_rate:      float = 0.18
@export var tractor_range:  float = 60.0
@export var tractor_speed:  float = 25.0
@export var lock_time:      float = 3.0
@export var lock_cone_dot:  float = 0.92
@export var missiles_count: int   = 4
@export var nukes_count:    int   = 2

var cargo_collected: int   = 0
var _throttle:       float = 0.0
var _fire_cooldown:  float = 0.0
var _tractor_target: Node3D = null

# ── Lock state (condiviso tra missile e nuke) ─────────────
enum WeaponMode { NONE, MISSILE, NUKE }
var _weapon_mode:  WeaponMode = WeaponMode.NONE
var _lock_target:  Node3D = null
var _lock_timer:   float  = 0.0
var _locked:       bool   = false

@onready var _muzzle:       Node3D         = $Muzzle
@onready var _tractor_beam: MeshInstance3D = $TractorBeam
@onready var _camera:       Camera3D       = $Camera3D
var _targeting_hud: Control = null

func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	_targeting_hud = get_tree().get_first_node_in_group("targeting_hud")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * 0.002)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * 0.002)
	if event.is_action_pressed("fire"):
		_try_fire()
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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

	if Input.is_action_pressed("tractor"):
		_update_tractor(delta)
	else:
		_stop_tractor()

	# ── Targeting missile (R) ─────────────────────────────
	if Input.is_action_pressed("missile_lock") and missiles_count > 0:
		_update_lock(delta, WeaponMode.MISSILE)
	elif not Input.is_action_pressed("missile_lock") and _weapon_mode == WeaponMode.MISSILE and not _locked:
		_reset_lock()

	# ── Targeting nuke (Y) ────────────────────────────────
	if Input.is_action_pressed("nuke_lock") and nukes_count > 0:
		_update_lock(delta, WeaponMode.NUKE)
	elif not Input.is_action_pressed("nuke_lock") and _weapon_mode == WeaponMode.NUKE and not _locked:
		_reset_lock()

	# ── Lancio missile (F) ────────────────────────────────
	if Input.is_action_just_pressed("missile_fire") and _locked:
		match _weapon_mode:
			WeaponMode.MISSILE:
				if missiles_count > 0:
					_launch(missile_scene)
					missiles_count -= 1
			WeaponMode.NUKE:
				if nukes_count > 0:
					_launch(nuke_scene)
					nukes_count -= 1
		_reset_lock()

func _update_lock(delta: float, mode: WeaponMode) -> void:
	# se stiamo già lockando con l'altra arma, ignora
	if _weapon_mode != WeaponMode.NONE and _weapon_mode != mode:
		return
	_weapon_mode = mode

	if _locked:
		_update_targeting_hud(true, 1.0, true, mode)
		return

	# cerca nemico nel mirino
	var best: Node3D = null
	var best_dot := lock_cone_dot
	var screen_size   := get_viewport().get_visible_rect().size
	var screen_center := screen_size * 0.5
	var mirino_half   := 100.0

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D:
			continue
		if _camera.is_position_behind(enemy.global_position):
			continue
		var sp := _camera.unproject_position(enemy.global_position)
		if (sp - screen_center).abs().x > mirino_half or (sp - screen_center).abs().y > mirino_half:
			continue
		var dir: Vector3 = (enemy.global_position - global_position).normalized()
		var d := (-global_transform.basis.z).dot(dir)
		if d > best_dot:
			best_dot = d
			best = enemy

	if best != _lock_target:
		_lock_target = best
		_lock_timer  = 0.0

	if is_instance_valid(_lock_target):
		_lock_timer += delta
		if _lock_timer >= lock_time:
			_locked = true
		_update_targeting_hud(true, clampf(_lock_timer / lock_time, 0.0, 1.0), _locked, mode)
	else:
		_lock_timer = 0.0
		_update_targeting_hud(true, 0.0, false, mode)

func _launch(scene: PackedScene) -> void:
	if scene == null or not is_instance_valid(_lock_target):
		return
	var m: Node3D = scene.instantiate()
	m.target = _lock_target
	get_tree().root.add_child(m)
	m.global_transform = _muzzle.global_transform

func _reset_lock() -> void:
	_weapon_mode = WeaponMode.NONE
	_lock_target = null
	_lock_timer  = 0.0
	_locked      = false
	_update_targeting_hud(false, 0.0, false, WeaponMode.NONE)

func _update_targeting_hud(active: bool, progress: float, locked: bool, mode: WeaponMode) -> void:
	if not is_instance_valid(_targeting_hud):
		return
	_targeting_hud.active        = active
	_targeting_hud.lock_progress = progress
	_targeting_hud.locked        = locked
	_targeting_hud.lock_target   = _lock_target
	_targeting_hud.is_nuke       = (mode == WeaponMode.NUKE)

# ── Tractor ───────────────────────────────────────────────
func _update_tractor(delta: float) -> void:
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
		var dir := (global_position - _tractor_target.global_position).normalized()
		_tractor_target.global_position += dir * tractor_speed * delta
		if global_position.distance_to(_tractor_target.global_position) < 3.0:
			if _tractor_target.has_method("collect"):
				_tractor_target.collect()
			_tractor_target = null
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
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(_tractor_beam.to_local(target.global_position))
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
