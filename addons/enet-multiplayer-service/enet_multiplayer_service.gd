extends Node

signal upnp_setup_failed(error: UPNP.UPNPResult)
signal upnp_setup_completed(ip: String)

var peer := ENetMultiplayerPeer.new()
var peers_list := {}

var server_ip := "localhost"
var server_port: int
var max_client: int
var use_dedicated_server: bool
var use_upnp: bool

var upnp: UPNP
var upnp_thread: Thread
var upnp_mutex: Mutex


func _enter_tree() -> void:
  ENetMultiplayerServiceConfig.fetch_plugin_settings()

  server_port = ENetMultiplayerServiceConfig.get_plugin_setting(
    ENetMultiplayerServiceConfig.Settings.SERVER_PORT
  )
  max_client = ENetMultiplayerServiceConfig.get_plugin_setting(
    ENetMultiplayerServiceConfig.Settings.MAX_CLIENTS
  )
  use_dedicated_server = ENetMultiplayerServiceConfig.get_plugin_setting(
    ENetMultiplayerServiceConfig.Settings.USE_DEDICATED_SERVER
  )
  use_upnp = ENetMultiplayerServiceConfig.get_plugin_setting(
    ENetMultiplayerServiceConfig.Settings.USE_UPNP
  )


func _ready() -> void:
  if use_upnp:
    _init_upnp()


func _exit_tree() -> void:
  if upnp_thread && upnp_thread.is_alive():
    upnp_thread.wait_to_finish()


#region Server
func create_server() -> void:
  var result := peer.create_server(server_port, max_client)
  if result != OK:
    push_error("[%s] Failed to create server" % error_string(result))
    return
  print("Server created at address %s:%s" % [server_ip, server_port])
  multiplayer.set_multiplayer_peer(peer)


#endregion


#region Client
func create_client() -> void:
  var result := peer.create_client(server_ip, server_port)
  if result != OK:
    push_error(
      "[%s] Failed to connect to server %s:%s" % [error_string(result), server_ip, server_port]
    )
    return
  print("Connected to address %s:%s" % [server_ip, server_port])
  multiplayer.set_multiplayer_peer(peer)


#endregion


#region UPnP
func _init_upnp() -> void:
  upnp = UPNP.new()
  upnp_thread = Thread.new()
  upnp_setup_completed.connect(_on_upnp_setup_completed)
  upnp_thread.start(_upnp_setup)


func _upnp_setup() -> void:
  upnp_mutex = Mutex.new()
  upnp_mutex.lock()

  var upnp_discover_result = _handle_upnp_error(upnp.discover(), "UPnP discovery error")

  var upnp_gateway = upnp.get_gateway()
  if !upnp_gateway || !upnp_gateway.is_valid_gateway():
    _handle_upnp_error.call_deferred(
      UPNP.UPNP_RESULT_INVALID_GATEWAY, "No valid UPnP gateway found"
    )
  call_thread_safe("_set_upnp_port_mappings")
  upnp_mutex.unlock()


func _set_upnp_port_mappings() -> void:
  var upnp_udp_mapping_result = _handle_upnp_error.call(
    upnp.add_port_mapping(
      server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP"
    ),
    "Error while mapping to UDP port"
  )
  var upnp_tcp_mapping_result = _handle_upnp_error.call(
    upnp.add_port_mapping(
      server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP"
    ),
    "Error while mapping to TCP port"
  )

  if upnp_udp_mapping_result["success"] && upnp_tcp_mapping_result["success"]:
    upnp_setup_completed.emit(upnp.query_external_address())


func clear_port_mappings() -> void:
  upnp.delete_port_mapping(server_port, "TCP")
  upnp.delete_port_mapping(server_port, "UDP")


func _handle_upnp_error(result: UPNP.UPNPResult, error_message: String) -> Dictionary:
  var success: bool = result == UPNP.UPNP_RESULT_SUCCESS
  if !success:
    push_error("[%s]: %s" % [_upnp_error_string(result), error_message])
    upnp_setup_failed.emit(result)
  return {"success": success, "result": result}


func _upnp_error_string(error: UPNP.UPNPResult) -> String:
  return ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[error]


#endregion

#region Signals Callbacks


func _on_upnp_setup_completed(ip: String) -> void:
  server_ip = ip
  if use_dedicated_server:
    create_server()
  else:
    create_client()

#endregion
