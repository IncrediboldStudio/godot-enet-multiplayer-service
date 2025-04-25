extends Control

@onready var container_server_connection: Container = get_node("%ContainerServerConnection")
@onready var container_lobby: Container = get_node("%ContainerLobby")
@onready var container_loading: Container = get_node("%ContainerLoading")
@onready var btn_host_local: Button = get_node("%BtnHostLocal")
@onready var btn_host_upnp: Button = get_node("%BtnHostUPnP")
@onready var btn_join: Button = get_node("%BtnJoin")
@onready var line_edit_address: LineEdit = get_node("%LineEditAddress")
@onready var label_address: Label = get_node("%LabelAddress")
@onready var label_loading: Label = get_node("%LabelLoading")
@onready var player_list: ItemList = get_node("%PlayerList")


func _ready() -> void:
  line_edit_address.text = ENetMultiplayerService.server_ip
  btn_host_local.pressed.connect(on_btn_host_local_pressed)
  btn_host_upnp.pressed.connect(on_btn_host_upnp_pressed)
  btn_join.pressed.connect(_on_btn_join_pressed)
  ENetMultiplayerService.client_list_changed.connect(_on_player_list_changed)
  ENetMultiplayerService.client_connected.connect(_on_client_connected_to_server)


func await_upnp() -> void:
  ENetMultiplayerService.upnp_setup_completed.connect(_on_upnp_setup_completed)
  ENetMultiplayerService.upnp_setup_failed.connect(_on_upnp_setup_failed)
  ENetMultiplayerService.init_upnp()
  line_edit_address.editable = false
  btn_host_local.disabled = true
  btn_host_upnp.disabled = true
  btn_join.disabled = true


func _show_lobby(result: Error) -> void:
  if result == OK:
    label_address.text = ENetMultiplayerService.server_ip
  _stop_loading(result)


func _start_loading(loading_message: String) -> void:
  container_loading.visible = true
  container_server_connection.visible = false
  container_lobby.visible = false
  label_loading.text = loading_message


func _stop_loading(result: Error, error_message: String = "") -> void:
  container_loading.visible = false
  if result == OK:
    container_lobby.visible = true
  else:
    container_server_connection.visible = true
    push_warning("[%s]: %s" % [error_string(result), error_message])


func _refresh_player_list() -> void:
  var players := ENetMultiplayerService.client_list
  players.values().sort()
  player_list.clear()
  player_list.add_item("%d (you)" % multiplayer.get_unique_id())
  for key: int in players:
    player_list.add_item(str(players[key]))


#region Signal Callbacks
func on_btn_host_local_pressed() -> void:
  _show_lobby(ENetMultiplayerService.create_server())


func on_btn_host_upnp_pressed() -> void:
  await_upnp()
  _start_loading("Waiting for UPnP...")


func _on_btn_join_pressed() -> void:
  _show_lobby(ENetMultiplayerService.create_client(line_edit_address.text))


func _on_upnp_setup_completed() -> void:
  _stop_loading(OK)
  _show_lobby(ENetMultiplayerService.create_server())


func _on_upnp_setup_failed() -> void:
  line_edit_address.editable = true
  btn_join.disabled = false
  btn_host_local.disabled = false


func _on_client_connection_timeout() -> void:
  print(multiplayer.multiplayer_peer.get_connection_status())
  var result := (
    ERR_CANT_CONNECT
    if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
    else OK
  )
  if result != OK:
    multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
  _stop_loading(
    result, "Timeout on client connection to server %s" % ENetMultiplayerService.server_ip
  )


func _on_client_connected_to_server(client_id: int) -> void:
  _stop_loading(OK)
  ENetMultiplayerService.print_client("%d _on_client_connected_to_server" % client_id)


func _on_player_list_changed() -> void:
  _refresh_player_list()
  ENetMultiplayerService.print_client(ENetMultiplayerService.client_list)

#endregion
