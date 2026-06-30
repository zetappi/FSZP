extends Node3D

@export var drift_speed: float = 1.5
@export var collect_range: float = 8.0
@export var tractor_range: float = 60.0
@export var tractor_speed: float = 25.0

var _velocity: Vector3
var _being_tractored: bool = false

func _ready() -> void:
	add_to_group("containers")
	_velocity = Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-0.3, 0.3),
		randf_range(-1.0, 1.0)
	).normalized() * drift_speed

func _process(delta: float) -> void:
	if _being_tractored:
		# il movimento è gestito dal player, qui solo rotazione lenta
		rotate_y(delta * 1.5)
	else:
		global_position += _velocity * delta
		rotate_y(delta * 0.8)

func start_tractor() -> void:
	_being_tractored = true

func stop_tractor() -> void:
	_being_tractored = false

func collect() -> void:
	# segnala al player che ha raccolto il cargo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_cargo_collected"):
		player.on_cargo_collected()
	queue_free()
