extends Node3D

@export var rotation_rpm:    float = 1.0
@export var alert_range:     float = 400.0
@export var swarm_count:     int   = 5

var _swarm_launched: bool = false
var _player: Node3D = null
var _swarm_scene: PackedScene = null

func _ready() -> void:
	add_to_group("structures")
	rotation = Vector3(
		randf_range(0.0, TAU),
		randf_range(0.0, TAU),
		randf_range(0.0, TAU)
	)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_swarm_scene = load("res://scenes/Swarm.tscn")

func _process(delta: float) -> void:
	rotate_object_local(Vector3.UP, rotation_rpm / 60.0 * TAU * delta)

	if _swarm_launched or not is_instance_valid(_player):
		return

	var dist: float = global_position.distance_to(_player.global_position)
	if dist <= alert_range:
		_launch_swarm()

func _launch_swarm() -> void:
	_swarm_launched = true
	if _swarm_scene == null:
		return

	# trova il nodo ingressobase per usarlo come punto di spawn
	var ingresso := _find_node_by_name(self, "ingressobase")
	var spawn_pos: Vector3 = ingresso.global_position if ingresso else global_position

	for i in swarm_count:
		var s: Node3D = _swarm_scene.instantiate()
		get_tree().root.add_child(s)
		# posizioni leggermente sfalsate attorno all'ingresso
		var offset := Vector3(
			randf_range(-20.0, 20.0),
			randf_range(-20.0, 20.0),
			randf_range(-20.0, 20.0)
		)
		s.global_position = spawn_pos + offset
		s.global_transform.basis = global_transform.basis

func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, target)
		if found:
			return found
	return null
