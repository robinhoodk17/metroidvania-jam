extends Node

#const SETTINGS_PATH : String = "user://settings.tres"
#var settings : Settings
 
#func _ready() -> void:
	#if ResourceLoader.exists(SETTINGS_PATH):
		#settings = ResourceLoader.load(SETTINGS_PATH)
	#else:
		#settings = Settings.new()
		#ResourceSaver.save(settings, SETTINGS_PATH)
 #
#func save_settings() -> void:
	#ResourceSaver.save(settings, SETTINGS_PATH)
	
	
const Save_PATH : String = "user://save.res"
var progress : Progress

func save_file_exists() -> bool:
	return ResourceLoader.exists(Save_PATH)
	
func new_game() -> void:
	progress = Progress.new()
	
func save_game() -> void:
	ResourceSaver.save(progress, Save_PATH)
	
func load_game() -> void:
	progress = ResourceLoader.load(Save_PATH)
