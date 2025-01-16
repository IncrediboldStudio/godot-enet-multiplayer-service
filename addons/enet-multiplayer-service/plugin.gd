@tool
class_name ENetMultiplayerServicePlugin
extends EditorPlugin

const AUTOLOAD_NAME: StringName = "ENetMultiplayerService"
const AUTOLOAD_PATH: StringName = "res://addons/enet-multiplayer-service/enet_multiplayer_service.tscn"
const AUTOLOAD_OPTIONS_PATH: StringName = "autoload/" + AUTOLOAD_NAME


func _enable_plugin() -> void:
  if !ProjectSettings.has_setting(AUTOLOAD_OPTIONS_PATH):
    add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
    print("%s enabled " % AUTOLOAD_NAME)

func _disable_plugin() -> void:
  if ProjectSettings.has_setting(AUTOLOAD_OPTIONS_PATH):
    remove_autoload_singleton(AUTOLOAD_NAME)
    print("%s disabled " % AUTOLOAD_NAME)

func _enter_tree() -> void:
  print("%s initialized " % AUTOLOAD_NAME)


func _exit_tree() -> void:
  pass
