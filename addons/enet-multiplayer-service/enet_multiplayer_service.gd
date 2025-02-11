extends Node

var peer: ENetMultiplayerPeer
var peers_list := {}

var upnp_thread: Thread
var upnp_mutex: Mutex

var config: Dictionary


func _ready() -> void:
  if _use_upnp():
    print("uwu")
    upnp_thread = Thread.new()
    upnp_mutex = Mutex.new()


func _use_upnp() -> bool:
  return ENetMultiplayerServiceConfig.get_plugin_setting(
    ENetMultiplayerServiceConfig.Settings.USE_UPNP
  )
