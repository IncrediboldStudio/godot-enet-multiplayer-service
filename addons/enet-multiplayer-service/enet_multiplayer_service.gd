extends Node
## Provides the methods and signal bindings necessary to create a server
## as well as create and register client connections
## All the necessary config options for this class can be found in Project Settings > ENet Multiplayer Service

## Signal emitted when there was an error during the UPnP device discovery or port mapping,
## see [url=https://docs.godotengine.org/en/stable/classes/class_upnp.html#enum-upnp-upnpresult]UPNPResult[/url]
signal upnp_setup_failed
## Signal emitted when the UPnP device discovery and port mapping is successfully completed
## @tutorial https://docs.godotengine.org/en/stable/classes/class_upnp.html#enum-upnp-upnpresult
## [param ip] The external IP adress discovered by UPnP where ports have been mapped
signal upnp_setup_completed(ip: String)

## Signal emitted on all peers when a new client connects to the server
## [param client_id] The id of the new client
signal client_connected(client_id: int)
## Signal emitted on all peers when a client disconnects from the server
signal client_disconnected
## Signal emitted when the server disconnects
signal server_disconnected
## Signal emitted on all peers when the clients connected to the server changes
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


#region Server


## Creates server that listens to the port set in
## project setting [i]enet_multiplayer_service/server_port[/i]
## Returns the [constant OK] if the server is created successfully,
## [constant ERR_ALREADY_IN_USE] if there is already a server listening on the port or
## [constant ERR_CANT_CREATE] if the server could not be created.
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


## Creates client that connects to the [param address] using the port specified in
## project setting [i]enet_multiplayer_service/server_port[/i]
## Returns the [constant OK] if the client is created successfully,
## [constant ERR_ALREADY_IN_USE] if the peer is already connected to a server or
## [constant ERR_CANT_CREATE] if the client could not be created.
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


## RPC method sent when a new client connects to the server 
## to register the new client connection to all other peers connected to the server
## and add it to each peer's local [member EnetMultiplayerService.client_list].
## Emits [signal EnetMultiplayerService.client_connected] and [signal EnetMultiplayerService.client_list_changed]
@rpc("any_peer", "reliable")
func _register_client() -> void:
  var client_id := multiplayer.get_remote_sender_id()
  client_list[client_id] = client_id
  client_connected.emit(client_id)
  client_list_changed.emit()



## Removes the client with the specified ID from [member EnetMultiplayerService.client_list].
## Emits [signal EnetMultiplayerService.client_disconnected] and [signal EnetMultiplayerService.client_list_changed]
## [param client_id] The ID of the client to remove.
func _remove_client(client_id: int) -> void:
  client_list.erase(client_id)
  client_disconnected.emit(client_id)
  client_list_changed.emit()


#endregion


#region UPnP

## Initialize a new thread to start UPnP discovery and port mapping asynchronously
func _init_upnp() -> void:
  upnp = UPNP.new()
  upnp_thread = Thread.new()
  upnp_setup_completed.connect(_on_upnp_setup_completed)
  upnp_thread.start(_upnp_setup)

## Discovers the first valid [class UPNPDevice] and creates TCP and UDP port mappings 
## for the port set in project setting [i]enet_multiplayer_service/server_port[/i].
func _upnp_setup() -> void:
  upnp_mutex = Mutex.new()
  upnp_mutex.lock()

  # UPnP Device discovery
  var upnp_discovery_result := _handle_upnp_error(upnp.discover(), "UPnP discovery error")
  if !upnp_discovery_result:
    return

  var upnp_gateway := upnp.get_gateway()
  if !upnp_gateway || !upnp_gateway.is_valid_gateway():
    _handle_upnp_error.call_deferred(
      UPNP.UPNP_RESULT_INVALID_GATEWAY, "No valid UPnP gateway found"
    )
    
  # Port mapping
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
  upnp_mutex.unlock()


## Pushes an error with the human-readable [enum UPNP.UPNPResult] and provided error message.
## Emits [signal EnetMultiplayerService.upnp_setup_failed]
## [param error_message]: String The error message to push.
func _handle_upnp_error(result: UPNP.UPNPResult, error_message: String) -> UPNP.UPNPResult:
  if result != UPNP.UPNP_RESULT_SUCCESS:
    push_error("[%s]: %s" % [_upnp_error_string(result), error_message])
    upnp_setup_failed.emit.call_deferred()
  return result

## Prints the human-readable [enum UPNP.UPNPResult] value 
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
