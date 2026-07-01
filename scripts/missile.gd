extends Node3D

@export var speed:        float = 45.0
@export var turn_speed:   float = 2.5    # rad/s guida proporzionale
@export var lifetime:     float = 12.0
@export var hit_radius:   float = 18.0

var target: Node3D = null

var _timer:    float = 0.0
@onready var _trail: GPUParticles3D = $Trail

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		_explode()
		return

	# guida proporzionale verso il target
	if is_instance_valid(target):
		var to_target := (target.global_position - global_position).normalized()
		var current_fwd := -global_transform.basis.z
		var new_fwd := current_fwd.slerp(to_target, turn_speed * delta).normalized()
		if new_fwd.length_squared() > 0.001:
			global_transform.basis = Basis.looking_at(new_fwd, global_transform.basis.y)

		# controlla impatto
		if global_position.distance_to(target.global_position) <= hit_radius:
			if target.has_method("take_damage"):
				target.take_damage(2.0)
			elif target.has_method("explode"):
				target.explode()
			_explode()
			return

	global_position += -global_transform.basis.z * speed * delta

func _explode() -> void:
	var fx_scene: PackedScene = load("res://scenes/ExplosionFX.tscn")
	if fx_scene:
		var fx: GPUParticles3D = fx_scene.instantiate()
		fx.scale = Vector3(2.5, 2.5, 2.5)
		get_tree().root.add_child(fx)
		fx.global_position = global_position
		fx.call_deferred("set", "emitting", true)
		get_tree().create_timer(4.0).timeout.connect(fx.queue_free)
	# stacca il trail prima di rimuoversi
	if is_instance_valid(_trail):
		_trail.reparent(get_tree().root)
		_trail.emitting = false
		get_tree().create_timer(2.0).timeout.connect(_trail.queue_free)
	queue_free()
