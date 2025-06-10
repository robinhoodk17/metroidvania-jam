extends Area3D

var showing_which : Node3D

func _process(delta: float) -> void:
	var overlapping_bodies : Array[Node3D] = get_overlapping_bodies()
	
	var interacting_with : Node3D = null
	var current_distance : float = 10000
	for i : Node3D in overlapping_bodies:
		if i.is_in_group("hook"):
			var candidate_distance : float = i.global_position.distance_squared_to(global_position)
			if candidate_distance < current_distance:
				current_distance = candidate_distance
				interacting_with = i

	if showing_which != null and showing_which != interacting_with:
		SignalbusPlayer.stoppedaiming.emit(showing_which)
		showing_which = null

	if interacting_with == null:
		showing_which = null
		return
	
	SignalbusPlayer.startedaiming.emit(interacting_with)
	showing_which = interacting_with
