extends Node 

@export var zone_scene : PackedScene  
@export var zone_size_x : float = 50.0   
@export var load_distance_ahead : int = 2 
@export var unload_distance_behind : int = 1
@onready var player: Node3D = get_tree().get_first_node_in_group("Player")

var loaded_zones = {} 
 
func _ready():
	_update_zones()

func _process(delta):
	_update_zones()

func _update_zones():
	var player_pos = player.global_transform.origin
	var current_chunk_x : int = floor(player_pos.x / zone_size_x)
 
	var min_chunk = current_chunk_x - unload_distance_behind
	var max_chunk = current_chunk_x + load_distance_ahead
 
	for chunk_x in range(min_chunk, max_chunk + 1):
		if not loaded_zones.has(chunk_x):
			var instance = zone_scene.instantiate()
			add_child(instance)
			instance.global_position = Vector3(chunk_x * zone_size_x, 0, 0)
			loaded_zones[chunk_x] = instance
 
	var chunks_to_remove = []
	for chunk_x in loaded_zones.keys():
		if chunk_x < min_chunk or chunk_x > max_chunk:
			chunks_to_remove.append(chunk_x)

	for chunk_x in chunks_to_remove:
		loaded_zones[chunk_x].queue_free()
		loaded_zones.erase(chunk_x)
