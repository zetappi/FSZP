extends Node3D

# ── Hull ───────────────────────────────────────────────────
@export var max_hull:         float = 3.0
var _hull: float = 3.0
@onready var _smoke: GPUParticles3D = $DamageSmoke

# ── Parametri cannoni principali ───────────────────────────
@export var bullet_scene:     PackedScene
@export var fire_range:       float = 180.0
@export var fire_rate:        float = 0.6
@export var cannon_cone_dot:  float = 0.966  # cos(15°) → cono ±30° totale

# ── Parametri minigun ──────────────────────────────────────
@export var minigun_scene:    PackedScene
@export var minigun_range:    float = 220.0
@export var minigun_rate:     float = 0.08
@export var minigun_cone_dot: float = 0.5    # cos(60°) → cono ±120° totale

# ── Parametri movimento ────────────────────────────────────
@export var speed:            float = 35.0
@export var turn_speed:       float = 1.6
@export var min_distance:     float = 120.0
@export var strafe_dist:      float = 300.0
@export var jink_interval:    float = 4.0

# ── Stato AI ───────────────────────────────────────────────
enum State { APPROACH, STRAFE, RETURN }
var _state: State = State.APPROACH

var _player:           Node3D  = null
var _fire_cooldown:    float   = 0.0
var _minigun_cooldown: float   = 0.0
var _jink_timer:       float   = 0.0
var _strafe_origin:    Vector3 = Vector3.ZERO
var _target_dir:       Vector3 = Vector3.ZERO

# nodi placeholder posizionati sui muzzle del modello
@onready var _muzzle_right:   Node3D = $MuzzleRight
@onready var _muzzle_left:    Node3D = $MuzzleLeft
@onready var _minigun_right:  Node3D = $MinigunRight
@onready var _minigun_left:   Node3D = $MinigunLeft
@onready var _minigun_tail:   Node3D = $MinigunTail
var _muzzle_toggle: bool = false

func _ready() -> void:
	add_to_group("enemies")
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_snap_muzzle(_muzzle_right,  "muzzleright")
	_snap_muzzle(_muzzle_left,   "muzzleleft")
	_snap_muzzle(_minigun_right, "right-minigun")
	_snap_muzzle(_minigun_left,  "right-minigun.001")
	_snap_muzzle(_minigun_tail,  "tail-minigun")
	if is_instance_valid(_smoke):
		_smoke.speed_scale = 0.0
	_jink_timer = jink_interval
	_target_dir = -global_transform.basis.z

func _snap_muzzle(muzzle_node: Node3D, target_name: String) -> void:
	# reparenta mantenendo la posizione world — il nodo del modello
	# ha già lo scale 3.2 applicato, quindi global_position è corretta
	var found := _find_node_by_name(self, target_name)
	if found:
		# aggancia il placeholder come figlio del nodo del modello
		# usando keep_global_transform=false e impostando position=zero
		# così segue il nodo del modello esattamente
		muzzle_node.reparent(found, false)
		muzzle_node.position = Vector3.ZERO
		muzzle_node.rotation = Vector3.ZERO

func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target)
		if found:
			return found
	return null

# ── Loop principale ────────────────────────────────────────
func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var to_player: Vector3 = _player.global_position - global_position
	var dist: float = to_player.length()
	_fire_cooldown    -= delta
	_minigun_cooldown -= delta
	_jink_timer       -= delta

	if _jink_timer <= 0.0:
		_jink_timer = randf_range(3.0, 5.0)
		_apply_jink()

	match _state:
		State.APPROACH:
			_target_dir = to_player.normalized()
			if dist <= min_distance:
				_enter_strafe()

		State.STRAFE:
			var traveled: float = global_position.distance_to(_strafe_origin)
			if traveled >= strafe_dist:
				_state = State.RETURN

		State.RETURN:
			_target_dir = to_player.normalized()
			var fwd: Vector3 = -global_transform.basis.z
			if fwd.dot(to_player.normalized()) > 0.85:
				_state = State.APPROACH

	_rotate_toward_target(delta)
	_move_forward(delta)

	# cannoni principali — cono ±30° frontale
	if _fire_cooldown <= 0.0 and dist <= fire_range:
		if _in_cone(to_player, -global_transform.basis.z, cannon_cone_dot):
			_fire_cannon()

	# minigun — ciascuna valutata nel proprio cono locale
	if _minigun_cooldown <= 0.0 and dist <= minigun_range:
		_try_minigun(to_player)

func _in_cone(to_target: Vector3, axis: Vector3, min_dot: float) -> bool:
	return axis.dot(to_target.normalized()) >= min_dot

func _try_minigun(to_player: Vector3) -> void:
	# right minigun — asse +X locale, cono ±60°
	if _in_cone(to_player, global_transform.basis.x, minigun_cone_dot):
		_fire_minigun(_minigun_right)
		return
	# left minigun — asse -X locale, cono ±60°
	if _in_cone(to_player, -global_transform.basis.x, minigun_cone_dot):
		_fire_minigun(_minigun_left)
		return
	# tail minigun — asse +Z locale (coda), cono ±60°
	if _in_cone(to_player, global_transform.basis.z, minigun_cone_dot):
		_fire_minigun(_minigun_tail)

func _fire_cannon() -> void:
	if bullet_scene == null:
		return
	_fire_cooldown = fire_rate
	var muzzle: Node3D = _muzzle_right if _muzzle_toggle else _muzzle_left
	_muzzle_toggle = not _muzzle_toggle
	_spawn_bullet(bullet_scene, muzzle)

func _fire_minigun(muzzle: Node3D) -> void:
	if minigun_scene == null:
		return
	_minigun_cooldown = minigun_rate
	_spawn_bullet(minigun_scene, muzzle, true)

func _spawn_bullet(scene: PackedScene, muzzle: Node3D, aim_at_player: bool = false) -> void:
	var b: Node3D = scene.instantiate()
	get_tree().root.add_child(b)
	b.global_position = muzzle.global_position
	if aim_at_player and is_instance_valid(_player):
		var dir: Vector3 = (_player.global_position - muzzle.global_position).normalized()
		b.global_transform.basis = Basis.looking_at(dir, Vector3.UP)
	else:
		b.global_transform.basis = muzzle.global_transform.basis

func _enter_strafe() -> void:
	_state = State.STRAFE
	_strafe_origin = global_position
	_target_dir = _random_offset_dir(-global_transform.basis.z, PI * 0.5, PI * 0.25)

func _apply_jink() -> void:
	var base_dir: Vector3 = _target_dir if _target_dir.length_squared() > 0.01 \
		else -global_transform.basis.z
	_target_dir = _random_offset_dir(base_dir, 0.0, PI * 0.25)

func _random_offset_dir(base: Vector3, h_bias: float, spread: float) -> Vector3:
	var right: Vector3 = base.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = base.cross(Vector3.RIGHT).normalized()
	var up: Vector3 = right.cross(base).normalized()
	var h: float = h_bias + randf_range(-spread, spread)
	if h_bias != 0.0 and randf() > 0.5:
		h = -h
	var v: float = randf_range(-spread, spread)
	return (base + right * tan(h) + up * tan(v)).normalized()

func _rotate_toward_target(delta: float) -> void:
	if _target_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(_target_dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(
		target_basis, clampf(turn_speed * delta, 0.0, 1.0))

func _move_forward(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

# ── Danno ──────────────────────────────────────────────────
func take_damage(amount: float = 1.0) -> void:
	_hull -= amount
	var t: float = clampf(_hull / max_hull, 0.0, 1.0)

	if is_instance_valid(_smoke):
		var damage_ratio: float = 1.0 - t
		_smoke.speed_scale = damage_ratio * 2.0
		var proc_mat := _smoke.process_material as ParticleProcessMaterial
		if proc_mat:
			proc_mat.initial_velocity_min = damage_ratio * 2.0
			proc_mat.initial_velocity_max = damage_ratio * 8.0
			proc_mat.color = Color(0.6, 0.6, 0.6, damage_ratio * 0.8)

	_enter_strafe()

	if _hull <= 0.0:
		explode()

func explode() -> void:
	var fx_scene: PackedScene = load("res://scenes/ExplosionFX.tscn")
	if fx_scene:
		var fx: GPUParticles3D = fx_scene.instantiate()
		fx.scale = Vector3(3, 3, 3)
		get_tree().root.add_child(fx)
		fx.global_position = global_position
		fx.call_deferred("set", "emitting", true)
		get_tree().create_timer(4.0).timeout.connect(fx.queue_free)

	var container_scene: PackedScene = load("res://scenes/Container.tscn")
	if container_scene:
		var c: Node3D = container_scene.instantiate()
		get_tree().root.add_child(c)
		c.global_position = global_position

	queue_free()
