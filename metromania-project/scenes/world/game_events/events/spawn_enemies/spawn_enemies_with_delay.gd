extends GameEvent

@export var spawn_locations: Array[Marker3D]
@export var enemies: Array[EnemyWave]
@export var number_of_activations : int = 1
@export var delay: float = 1.0

var active_enemies : int = 0

func activate() -> void:
	if number_of_activations == 0 or active_enemies > 0:
		return
	await get_tree().create_timer(delay).timeout
	
	
	var wave_number = number_of_activations - 1
	if wave_number < 0:
		wave_number = 0
	
	for i : Marker3D in spawn_locations:
		await get_tree().create_timer(delay).timeout
		var random_index : int = randi_range(0, enemies.size() -1)
		var random_enemy : Node3D = enemies[wave_number].enemies[random_index].instantiate()
		random_enemy.death.connect(reduce_active_enemies)
		active_enemies += 1
		SignalManager.spawn_enemies.emit(random_enemy, i.global_position)
	
	number_of_activations -= 1


func reduce_active_enemies(_body : Node3D) -> void:
	active_enemies -= 1
