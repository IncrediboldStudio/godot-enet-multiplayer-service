extends Node

signal upnp_setup_failed
signal upnp_setup_completed(ip: String)

signal client_connected(client_id: int)
signal client_disconnected
signal server_disconnected
signal client_list_changed

var peer: ENetMultiplayerPeer
var client_list := {}

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
  multiplayer.peer_connected.connect(_on_peer_connected)
  multiplayer.peer_disconnected.connect(_on_peer_disconnected)
  multiplayer.connected_to_server.connect(_on_client_connected_to_server)
  multiplayer.connection_failed.connect(_on_client_connection_failed)
  multiplayer.server_disconnected.connect(_on_server_disconnected)

  if use_upnp:
    _init_upnp()


func _exit_tree() -> void:
  if upnp_thread:
    upnp_thread.wait_to_finish()
  clear_port_mappings()


#region Server
func create_server() -> Error:
  peer = ENetMultiplayerPeer.new()

  var result := peer.create_server(server_port, max_client)
  if result != OK:
    push_error("[%s] Failed to create server" % error_string(result))

  print("Server created at address %s:%s" % [server_ip, server_port])
  multiplayer.set_multiplayer_peer(peer)
  return result


#endregion


#region Client
func create_client(address: String) -> Error:
  peer = ENetMultiplayerPeer.new()

  if address.is_empty():
    address = server_ip
  var result := peer.create_client(address, server_port)
  if result:
    push_error(
      "[%s] Failed to connect to server %s:%s" % [error_string(result), address, server_port]
    )
  multiplayer.set_multiplayer_peer(peer)
  print("client created at address %s" % address)
  return result


@rpc("any_peer", "reliable")
func _register_client() -> void:
  var client_id := multiplayer.get_remote_sender_id()
  client_list[client_id] = client_id
  client_connected.emit(client_id)
  client_list_changed.emit()


func _remove_client(client_id: int) -> void:
  client_list.erase(client_id)
  client_disconnected.emit(client_id)
  client_list_changed.emit()


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

  var upnp_discovery_result := _handle_upnp_error(upnp.discover(), "UPnP discovery error")
  if !upnp_discovery_result["success"]:
    return

  var upnp_gateway := upnp.get_gateway()
  if !upnp_gateway || !upnp_gateway.is_valid_gateway():
    _handle_upnp_error.call_deferred(
      UPNP.UPNP_RESULT_INVALID_GATEWAY, "No valid UPnP gateway found"
    )
  call_thread_safe("_set_upnp_port_mappings")
  upnp_mutex.unlock()


func _set_upnp_port_mappings() -> void:
  var upnp_udp_mapping_result: Dictionary = _handle_upnp_error.call(
    upnp.add_port_mapping(
      server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP"
    ),
    "Error while mapping to UDP port"
  )
  var upnp_tcp_mapping_result: Dictionary = _handle_upnp_error.call(
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
    upnp_setup_failed.emit.call_deferred()
  return {"success": success, "result": result}


func _upnp_error_string(error: UPNP.UPNPResult) -> String:
  return ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[error]


#endregion


#region Signals Callbacks
func _on_server_disconnected() -> void:
  multiplayer.multiplayer_peer = null
  client_list.clear()
  print("Server disconnected")
  server_disconnected.emit()


func _on_peer_connected(client_id: int) -> void:
  print("peer_connected")
  _register_client.rpc_id(client_id)


func _on_peer_disconnected(client_id: int) -> void:
  print("%d disconnected" % client_id)
  _remove_client(client_id)


func _on_client_connected_to_server() -> void:
  print("connected_to_server")
  var client_id := multiplayer.get_unique_id()
  client_connected.emit(client_id)
  client_list_changed.emit()


func _on_client_connection_failed() -> void:
  multiplayer.multiplayer_peer = null


func _on_upnp_setup_completed(ip: String) -> void:
  server_ip = ip

#endregion
