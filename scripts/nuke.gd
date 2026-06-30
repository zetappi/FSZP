extends Node3D

@export var speed:       float = 35.0
@export var turn_speed:  float = 1.8
@export var lifetime:    float = 15.0
@export var blast_radius: float = 50.0
@export var hit_radius:  float = 5.0

var target: Node3D = null
var _timer: float = 0.0

@onready var _trail: GPUParticles3D = $Trail

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		_explode()
		return

	if is_instance_valid(target):
		var to_target := (target.global_position - global_position).normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.slerp(to_target, turn_speed * delta).normalized()
		if new_fwd.length_squared() > 0.001:
			global_transform.basis = Basis.looking_at(new_fwd, global_transform.basis.y)

		if global_position.distance_to(target.global_position) <= hit_radius:
			_explode()
			return

	global_position += -global_transform.basis.z * speed * delta

func _explode() -> void:
	# esplosione visiva grande
	var fx_scene: PackedScene = load("res://scenes/ExplosionFX.tscn")
	if fx_scene:
		# onda esplosiva principale
		for i in 3:
			var fx: GPUParticles3D = fx_scene.instantiate()
			fx.scale = Vector3(6.0 + i * 3.0, 6.0 + i * 3.0, 6.0 + i * 3.0)
			get_tree().root.add_child(fx)
			fx.global_position = global_position
			fx.call_deferred("set", "emitting", true)
			get_tree().create_timer(4.0 + i).timeout.connect(fx.queue_free)

	# danno ad area
	for group in ["enemies", "asteroids"]:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node3D:
				var dist := global_position.distance_to(node.global_position)
				if dist <= blast_radius:
					if node.has_method("explode"):
						node.explode()

	# stacca il trail
	if is_instance_valid(_trail):
		_trail.reparent(get_tree().root)
		_trail.emitting = false
		get_tree().create_timer(2.0).timeout.connect(_trail.queue_free)

	queue_free()
