extends Node3D

# ── Hull ──────────────────────────────────────────────────
@export var max_hull:         float = 3.0   # colpi necessari per distruggerla
var _hull: float = 3.0
@onready var _smoke: GPUParticles3D = $DamageSmoke

# ── Parametri ──────────────────────────────────────────────
@export var bullet_scene:     PackedScene
@export var speed_approach:   float = 18.0
@export var speed_retreat:    float = 22.0
@export var attack_range:     float = 80.0   # distanza a cui inizia ad avvicinarsi
@export var fire_range:       float = 40.0   # distanza a cui spara
@export var retreat_distance: float = 120.0  # distanza a cui smette di ritirarsi
@export var turn_speed:       float = 2.0    # rad/s di rotazione verso il player
@export var fire_rate:        float = 1.2    # secondi tra un colpo e l'altro

# ── Stato AI ──────────────────────────────────────────────
enum State { IDLE, APPROACH, ATTACK, RETREAT }
var _state: State = State.IDLE

# ── Durate fasi (randomizzate) ─────────────────────────────
var _idle_timer:    float = 0.0
var _attack_timer:  float = 0.0   # quanto rimane in ATTACK prima di RETREAT
var _fire_cooldown: float = 0.0

var _player: Node3D
var _velocity: Vector3 = Vector3.ZERO

@onready var _muzzle: Node3D = $Muzzle

func _ready() -> void:
	add_to_group("enemies")
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_enter_idle()
	# fumo spento finché non subisce danni
	if is_instance_valid(_smoke):
		_smoke.speed_scale = 0.0

# ── Macchina a stati ───────────────────────────────────────
func _enter_idle() -> void:
	_state = State.IDLE
	_idle_timer = randf_range(1.5, 3.5)

func _enter_approach() -> void:
	_state = State.APPROACH

func _enter_attack() -> void:
	_state = State.ATTACK
	_attack_timer = randf_range(3.0, 6.0)

func _enter_retreat() -> void:
	_state = State.RETREAT

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	var dist      := to_player.length()
	_fire_cooldown -= delta

	match _state:
		State.IDLE:
			_idle_timer -= delta
			if _idle_timer <= 0.0:
				_enter_approach()

		State.APPROACH:
			_face_target(_player.global_position, delta)
			_velocity = -global_transform.basis.z * speed_approach
			if dist <= fire_range:
				_enter_attack()

		State.ATTACK:
			_face_target(_player.global_position, delta)
			# avanza lentamente durante l'attacco
			_velocity = -global_transform.basis.z * speed_approach * 0.3
			_attack_timer -= delta
			if _fire_cooldown <= 0.0:
				_fire()
			if _attack_timer <= 0.0:
				_enter_retreat()

		State.RETREAT:
			# si allontana nella direzione opposta al player
			var away := -to_player.normalized()
			var retreat_target := global_position + away * 10.0
			_face_target(retreat_target, delta)
			_velocity = -global_transform.basis.z * speed_retreat
			if dist >= retreat_distance:
				_enter_idle()

	global_position += _velocity * delta

func _face_target(target_pos: Vector3, delta: float) -> void:
	var dir := (target_pos - global_position).normalized()
	if dir.length_squared() < 0.001:
		return
	var target_basis := Basis.looking_at(dir, Vector3.UP)
	var current_basis := global_transform.basis
	# Slerp verso la direzione target
	global_transform.basis = current_basis.slerp(target_basis, clampf(turn_speed * delta, 0.0, 1.0))

func _fire() -> void:
	if bullet_scene == null:
		return
	_fire_cooldown = fire_rate
	var b: Node3D = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.global_transform = _muzzle.global_transform

func take_damage(amount: float = 1.0) -> void:
	_hull -= amount
	var t := clampf(_hull / max_hull, 0.0, 1.0)

	# feedback visivo colore
	var mesh := get_node_or_null("MeshInstance3D")
	if mesh:
		var mat := mesh.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = Color(0.55 * t + 0.4, 0.1 * t, 0.05 * t, 1.0)

	# fumo proporzionale al danno tramite speed_scale e alpha
	if is_instance_valid(_smoke):
		var damage_ratio := 1.0 - t   # 0 = integro, 1 = quasi distrutto
		_smoke.speed_scale = damage_ratio * 2.0
		var proc_mat := _smoke.process_material as ParticleProcessMaterial
		if proc_mat:
			proc_mat.initial_velocity_min = damage_ratio * 2.0
			proc_mat.initial_velocity_max = damage_ratio * 8.0
			proc_mat.color = Color(0.6, 0.6, 0.6, damage_ratio * 0.8)

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
