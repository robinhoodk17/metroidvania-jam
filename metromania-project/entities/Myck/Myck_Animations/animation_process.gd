# Referenced From: https://forum.godotengine.org/t/how-to-set-all-3d-animation-tracks-to-nearest-interpolation/22056
@tool     # makes script run from within the editor
extends EditorScript    # gives you access to editor functions

func _run():   # this is the main function
	var selection = EditorInterface.get_selection() # the selected node. In your case, select the AnimationPlayer
	selection = selection.get_selected_nodes()  # get the actual AnimationPlayer node
	if selection.size()!=1 and not selection is AnimationPlayer: # if the wrong node is selected, do nothing
		return
	else:
		process_animation(selection) # run the funstion in question

func process_animation(selection):
	var anim_track = selection[0].get_animation("Myck_Walk_24")
	var anim_track_keyCount = roundi(anim_track.length/anim_track.step)
	for i in anim_track.get_track_count():
		anim_track.track_set_interpolation_type(i, 0)
		for t in range(1, anim_track_keyCount + 1, 2):
			var time = t * anim_track.step
			anim_track.track_remove_key_at_time(i, time)
