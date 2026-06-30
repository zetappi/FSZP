extends RigidBody3D

@export var drift_speed_min: float = 0.5
@export var drift_speed_max: float = 3.0
@export var rotation_speed_max: float = 0.8

# 0 = asteroide padre (si spacca), 1 = figlio (esplode e basta)
var generation: int = 0
var _override_velocity: Vector3 = Vector3.ZERO  # se != zero, usa questa invece del drift casuale

func _ready() -> void:
	add_to_group("asteroids")
	gravity_scale = 0.0
	lock_rotation = false

	if _override_velocity != Vector3.ZERO:
		linear_velocity = _override_velocity
		angular_velocity = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * rotation_speed_max
		_randomize_color()
		return

	linear_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	).normalized() * randf_range(drift_speed_min, drift_speed_max)

	angular_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * rotation_speed_max

	_randomize_color()

func _randomize_color() -> void:
	var mesh_instance: MeshInstance3D = $MeshInstance3D
	if mesh_instance == null:
		return
	var mat := StandardMaterial3D.new()
	var base := Color(0.35, 0.32, 0.28)
	mat.albedo_color = Color(
		clampf(base.r + randf_range(-0.08, 0.12), 0.0, 1.0),
		clampf(base.g + randf_range(-0.06, 0.10), 0.0, 1.0),
		clampf(base.b + randf_range(-0.05, 0.08), 0.0, 1.0)
	)
	mat.roughness = randf_range(0.7, 1.0)
	mat.metallic  = randf_range(0.0, 0.15)
	mesh_instance.material_override = mat

func explode() -> void:
	_spawn_fx(global_position, scale)

	if generation == 0:
		_spawn_children()

	queue_free()

func _spawn_fx(pos: Vector3, fx_scale: Vector3) -> void:
	var fx_scene: PackedScene = load("res://scenes/ExplosionFX.tscn")
	if fx_scene:
		var fx: GPUParticles3D = fx_scene.instantiate()
		fx.scale = fx_scale * 0.6
		get_tree().root.add_child(fx)
		fx.global_position = pos
		fx.call_deferred("set", "emitting", true)
		get_tree().create_timer(4.0).timeout.connect(fx.queue_free)

func _spawn_children() -> void:
	var child_scene: PackedScene = load("res://scenes/Asteroid.tscn")
	if child_scene == null:
		return

	for i in 2:
		var child: RigidBody3D = child_scene.instantiate()
		child.generation = 1

		# scala dimezzata rispetto al padre
		var child_scale := scale * 0.5
		child.scale = child_scale

		# direzione casuale divergente
		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.5, 0.5),
			randf_range(-1.0, 1.0)
		).normalized()
		# offset iniziale per non sovrapporsi
		var spawn_pos := global_position + dir * (scale.x * 0.6)

		child._override_velocity = dir * randf_range(3.0, 8.0)
		get_tree().root.add_child(child)
		child.global_position = spawn_pos
