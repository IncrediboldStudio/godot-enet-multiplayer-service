extends Node
## Provides the methods and signal bindings necessary to create a server
## as well as create and register client connections
## All the necessary config options for this class can be found in Project Settings > ENet Multiplayer Service

## Signal emitted when there was an error during the UPnP device discovery or port mapping,
## see [url=https://docs.godotengine.org/en/stable/classes/class_upnp.html#enum-upnp-upnpresult]UPNPResult[/url]
signal upnp_setup_failed(result: UPNP.UPNPResult)
## Signal emitted when the UPnP device discovery and port mapping is successfully completed
## @tutorial https://docs.godotengine.org/en/stable/classes/class_upnp.html#enum-upnp-upnpresult
signal upnp_setup_completed

## Signal emitted on all peers when a new client connects to the server
## [param client_id] The id of the new client
signal client_connected(client_id: int)
## Signal emitted on all peers when a client disconnects from the server
signal client_disconnected
## Signal emitted on all peers when the clients connected to the server changes
signal client_list_changed

var peer := ENetMultiplayerPeer.new()
var client_list := {}

var server_ip := "127.0.0.1"
var server_port: int
var max_client: int

var upnp: UPNP
var upnp_thread: Thread
var upnp_mutex: Mutex


func _enter_tree() -> void:
  PluginSettings.fetch_plugin_settings()

  server_port = PluginSettings.get_plugin_setting(PluginSettings.Settings.SERVER_PORT)
  max_client = PluginSettings.get_plugin_setting(PluginSettings.Settings.MAX_CLIENTS)


func _ready() -> void:
  multiplayer.peer_connected.connect(_on_peer_connected)
  multiplayer.peer_disconnected.connect(_on_peer_disconnected)
  multiplayer.connected_to_server.connect(_on_client_connected_to_server)
  multiplayer.connection_failed.connect(_on_client_connection_failed)
  multiplayer.server_disconnected.connect(_on_server_disconnected)


func _exit_tree() -> void:
  if upnp_thread:
    upnp_thread.wait_to_finish()


#region Server


## Creates server that listens to the port set in
## project setting [i]enet_multiplayer_service/server_port[/i]
## Returns [constant OK] if the server is created successfully,
## [constant ERR_ALREADY_IN_USE] if there is already a server listening on the port or
## [constant ERR_CANT_CREATE] if the server could not be created.
func create_server() -> Error:
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
  var result := peer.create_client(address, server_port)
  if result != OK:
    push_error(
      "[%s] Failed to connect to server %s:%s" % [error_string(result), address, server_port]
    )
    return result

  multiplayer.set_multiplayer_peer(peer)
  server_ip = address
  print("Client connected at address %s:%s" % [server_ip, server_port])
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
  print_client("registered %d on %d" % [client_id, multiplayer.get_unique_id()])


## Removes the client with the specified ID from [member EnetMultiplayerService.client_list].
## Emits [signal EnetMultiplayerService.client_disconnected] and [signal EnetMultiplayerService.client_list_changed]
## [param client_id] The ID of the client to remove.
func _remove_client(client_id: int) -> void:
  client_list.erase(client_id)
  client_disconnected.emit(client_id)
  client_list_changed.emit()


## Prints in the console with a random color for each peer
## [param message] The message to print in the console.
func print_client(message: Variant) -> void:
  var color := Color.from_hsv(
    wrapf(str(multiplayer.get_unique_id()).hash() * 0.001, 0.0, 1.0), 0.6, 1.0
  )
  print_rich(
    "[color=#%s][%d] %s[/color]" % [color.to_html(false), multiplayer.get_unique_id(), message]
  )


#endregion

#region UPnP


class UPNPResponse:
  var result: UPNP.UPNPResult
  var ok: bool:
    get:
      return result == UPNP.UPNP_RESULT_SUCCESS

  func _init(_result: UPNP.UPNPResult, error_message: String):
    result = _result
    if !ok:
      push_error("[%s]: %s" % [_upnp_error_string(result), error_message])

  ## Prints the human-readable [enum UPNP.UPNPResult] value
  func _upnp_error_string(error: UPNP.UPNPResult) -> String:
    return ClassDB.class_get_enum_constants("UPNP", "UPNPResult")[error]


## Initialize a new thread to start UPnP discovery and port mapping asynchronously
func init_upnp() -> void:
  upnp = UPNP.new()
  upnp_thread = Thread.new()
  upnp_thread.start(_upnp_setup)


## Discovers the first valid [class UPNPDevice] and creates TCP and UDP port mappings
## for the port set in project setting [i]enet_multiplayer_service/server_port[/i].
func _upnp_setup() -> void:
  upnp_mutex = Mutex.new()
  if !upnp_mutex.try_lock():
    return

  # UPnP Device discovery
  var upnp_discovery_response := UPNPResponse.new(upnp.discover(), "UPnP discovery error")
  if !upnp_discovery_response.ok:
    upnp_setup_failed.emit.call_deferred(upnp_discovery_response)
    upnp_mutex.unlock()
    return

  var upnp_gateway := upnp.get_gateway()
  if !upnp_gateway || !upnp_gateway.is_valid_gateway():
    upnp_setup_failed.emit.call_deferred(UPNP.UPNP_RESULT_INVALID_GATEWAY)
    upnp_mutex.unlock()
    return

  # Port mapping
  var upnp_udp_mapping_response := UPNPResponse.new(
    upnp.add_port_mapping(
      server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP"
    ),
    "Error while mapping to UDP port"
  )
  if !upnp_udp_mapping_response.ok:
    upnp_setup_failed.emit.call_deferred(upnp_udp_mapping_response)
    upnp_mutex.unlock()
    return

  var upnp_tcp_mapping_response := UPNPResponse.new(
    upnp.add_port_mapping(
      server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP"
    ),
    "Error while mapping to TCP port"
  )
  if !upnp_tcp_mapping_response.ok:
    upnp_setup_failed.emit.call_deferred(upnp_tcp_mapping_response)
    upnp_mutex.unlock()
    return

  server_ip = upnp.query_external_address()
  upnp_setup_completed.emit.call_deferred()
  upnp_mutex.unlock()


#endregion


#region Signals Callbacks
func _on_server_disconnected() -> void:
  multiplayer.multiplayer_peer = null
  client_list.clear()
  print("Server disconnected")


func _on_peer_connected(client_id: int) -> void:
  print_client("%d peer_connected" % client_id)
  _register_client.rpc_id(client_id)


func _on_peer_disconnected(client_id: int) -> void:
  print_client("%d disconnected" % client_id)
  _remove_client(client_id)


func _on_client_connected_to_server() -> void:
  var client_id := multiplayer.get_unique_id()
  client_connected.emit(client_id)
  print_client("%d connected_to_server" % client_id)


func _on_client_connection_failed() -> void:
  multiplayer.multiplayer_peer = null

#endregion
