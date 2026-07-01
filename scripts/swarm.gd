extends Node3D

@export var minigun_scene:    PackedScene
@export var speed:            float = 55.0
@export var turn_speed:       float = 3.0
@export var fire_range:       float = 220.0
@export var minigun_rate:     float = 0.08
@export var minigun_cone_dot: float = 0.707  # cos(45°) → cono ±90° totale
@export var min_distance:     float = 60.0
@export var evade_dist:       float = 200.0
@export var max_hull:         float = 1.0

var _hull: float = 1.0

enum State { ATTACK, EVADE, RETURN }
var _state: State = State.ATTACK

var _player:           Node3D  = null
var _minigun_cooldown: float   = 0.0
var _target_dir:       Vector3 = Vector3.ZERO
var _evade_origin:     Vector3 = Vector3.ZERO

@onready var _minigun_right: Node3D = $MinigunRight
@onready var _minigun_left:  Node3D = $MinigunLeft

func _ready() -> void:
	add_to_group("enemies")
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_snap_muzzle(_minigun_right, "rigt-minigun", Vector3( 0.785, -0.099, -0.78))
	_snap_muzzle(_minigun_left,  "left-minigun",  Vector3(-0.772, -0.099, -0.78))
	_target_dir = -global_transform.basis.z

func _snap_muzzle(muzzle_node: Node3D, target_name: String, offset: Vector3 = Vector3.ZERO) -> void:
	var found := _find_node_by_name(self, target_name)
	if found:
		muzzle_node.reparent(found, false)
		muzzle_node.position = offset
		muzzle_node.rotation = Vector3.ZERO

func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target)
		if found:
			return found
	return null

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var to_player: Vector3 = _player.global_position - global_position
	var dist: float        = to_player.length()
	_minigun_cooldown -= delta

	match _state:
		State.ATTACK:
			_target_dir = to_player.normalized()
			if dist <= min_distance:
				_enter_evade()

		State.EVADE:
			# mantieni direzione di evasione
			var traveled: float = global_position.distance_to(_evade_origin)
			if traveled >= evade_dist:
				_state = State.RETURN

		State.RETURN:
			_target_dir = to_player.normalized()
			var fwd: Vector3 = -global_transform.basis.z
			if fwd.dot(to_player.normalized()) > 0.8:
				_state = State.ATTACK

	_rotate_toward_target(delta)
	_move_forward(delta)

	# fuoco: entrambe le minigun simultaneamente se il player è nel cono
	if _minigun_cooldown <= 0.0 and dist <= fire_range:
		var fwd: Vector3 = -global_transform.basis.z
		if fwd.dot(to_player.normalized()) >= minigun_cone_dot:
			_fire()

func _enter_evade() -> void:
	_state = State.EVADE
	_evade_origin = global_position
	# vira di almeno 90° in direzione casuale
	var fwd: Vector3   = -global_transform.basis.z
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01:
		right = fwd.cross(Vector3.RIGHT).normalized()
	var up: Vector3    = right.cross(fwd).normalized()
	var h: float = randf_range(PI * 0.5, PI) * (1.0 if randf() > 0.5 else -1.0)
	var v: float = randf_range(-PI * 0.25, PI * 0.25)
	_target_dir = (fwd + right * tan(h) + up * tan(v)).normalized()

func _rotate_toward_target(delta: float) -> void:
	if _target_dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(_target_dir, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(
		target_basis, clampf(turn_speed * delta, 0.0, 1.0))

func _move_forward(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta

func _fire() -> void:
	if minigun_scene == null:
		return
	_minigun_cooldown = minigun_rate
	for muzzle in [_minigun_right, _minigun_left]:
		var b: Node3D = minigun_scene.instantiate()
		get_tree().root.add_child(b)
		b.global_position = muzzle.global_position
		var dir: Vector3 = (_player.global_position - muzzle.global_position).normalized()
		b.global_transform.basis = Basis.looking_at(dir, Vector3.UP)

func take_damage(amount: float = 1.0) -> void:
	_hull -= amount
	if _hull <= 0.0:
		explode()
	else:
		_enter_evade()

func explode() -> void:
	var fx_scene: PackedScene = load("res://scenes/ExplosionFX.tscn")
	if fx_scene:
		var fx: GPUParticles3D = fx_scene.instantiate()
		fx.scale = Vector3(1.5, 1.5, 1.5)
		get_tree().root.add_child(fx)
		fx.global_position = global_position
		fx.call_deferred("set", "emitting", true)
		get_tree().create_timer(3.0).timeout.connect(fx.queue_free)
	queue_free()
