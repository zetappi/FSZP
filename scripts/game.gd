extends Node3D

@export var asteroid_scene: PackedScene
@export var asteroid_count: int   = 0
@export var field_radius:   float = 300.0
@export var min_distance:   float = 30.0

func _ready() -> void:
	_spawn_field()
	_spawn_hud()
	_spawn_pirate()

func _spawn_pirate() -> void:
	var pirate_scene: PackedScene = load("res://scenes/Pirate.tscn")
	if pirate_scene == null:
		push_error("Pirate.tscn non trovato")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 5:
		var p: Node3D = pirate_scene.instantiate()
		add_child(p)
		p.global_position = Vector3(
			rng.randf_range(-150.0, 150.0),
			rng.randf_range(-30.0, 30.0),
			rng.randf_range(-150.0, 150.0)
		)

func _spawn_hud() -> void:
	var hud_scene: PackedScene = load("res://scenes/HUD.tscn")
	if hud_scene:
		add_child(hud_scene.instantiate())
	else:
		push_error("HUD.tscn non trovato")

func _spawn_field() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var spawned := 0
	var attempts := 0

	while spawned < asteroid_count and attempts < asteroid_count * 10:
		attempts += 1
		var pos := Vector3(
			rng.randf_range(-field_radius, field_radius),
			rng.randf_range(-field_radius * 0.4, field_radius * 0.4),
			rng.randf_range(-field_radius, field_radius)
		)
		if pos.length() < min_distance:
			continue

		var a: Node3D = asteroid_scene.instantiate()
		add_child(a)
		a.global_position = pos
		var s := rng.randf_range(2.0, 12.0)
		a.scale = Vector3(s, s, s)
		spawned += 1
