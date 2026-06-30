extends Node3D

@export var speed:        float = 500.0
@export var lifetime:     float = 3.0
@export var damage:       float = 0.25
@export var hit_radius:   float = 4.0    # distanza di colpo sul player
@export var is_enemy:     bool  = false  # true = proiettile del pirata

var _timer: float = 0.0
var _player: Node3D

func _ready() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	global_position += -global_transform.basis.z * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()
		return

	if is_enemy:
		# proiettile nemico: controlla distanza dal player
		if is_instance_valid(_player):
			if global_position.distance_to(_player.global_position) <= hit_radius:
				_hit_player()
	else:
		# proiettile del player: controlla asteroidi e nemici
		for group in ["asteroids", "enemies"]:
			for target in get_tree().get_nodes_in_group(group):
				if target is Node3D:
					if global_position.distance_to(target.global_position) <= hit_radius * target.scale.x:
						hit_target(target)
						return

func _hit_player() -> void:
	# calcola direzione del proiettile in spazio locale del player
	var bullet_dir_world := -global_transform.basis.z
	var local_dir := _player.global_transform.basis.inverse() * bullet_dir_world

	var shields = get_tree().get_first_node_in_group("shields_hud")
	if shields:
		shields.take_hit(local_dir, damage)
	queue_free()

# chiamato quando colpisce un asteroide o un nemico
func hit_target(target: Node) -> void:
	if target.has_method("take_damage"):
		target.take_damage(1.0)
	elif target.has_method("explode"):
		target.explode()
	queue_free()
