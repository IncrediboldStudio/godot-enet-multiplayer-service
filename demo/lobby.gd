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
  multiplayer.connection_failed.connect(_on_connection_failed)


func await_upnp() -> void:
  ENetMultiplayerService.upnp_setup_completed.connect(_on_upnp_setup_completed)
  ENetMultiplayerService.upnp_setup_failed.connect(_on_upnp_setup_failed)
  ENetMultiplayerService.init_upnp()


func _start_loading(loading_message: String) -> void:
  container_loading.visible = true
  container_server_connection.visible = false
  container_lobby.visible = false
  label_loading.text = loading_message


func _handle_loading_result(result: Error, error_message: String = "") -> void:
  container_loading.visible = false
  if result == OK:
    container_lobby.visible = true
    label_address.text = ENetMultiplayerService.server_ip
  else:
    container_server_connection.visible = true
    push_warning("[%s]: %s" % [error_string(result), error_message])


func _refresh_player_list() -> void:
  var players: Dictionary = ENetMultiplayerService.client_list
  players.values().sort()
  player_list.clear()
  player_list.add_item("%d (you)" % multiplayer.get_unique_id())
  for key: int in players:
    player_list.add_item(str(players[key]))


#region Signal Callbacks
func on_btn_host_local_pressed() -> void:
  _start_loading("Creating server...")
  _handle_loading_result(ENetMultiplayerService.create_server())


func on_btn_host_upnp_pressed() -> void:
  _start_loading("Waiting for UPnP...")
  await_upnp()


func _on_btn_join_pressed() -> void:
  _start_loading("Waiting for host...")
  ENetMultiplayerService.create_client(line_edit_address.text)


func _on_upnp_setup_completed() -> void:
  _handle_loading_result(ENetMultiplayerService.create_server())


func _on_upnp_setup_failed() -> void:
  line_edit_address.editable = true
  btn_join.disabled = false
  btn_host_local.disabled = false


func _on_connection_failed() -> void:
  _handle_loading_result(ERR_TIMEOUT, "Peer packet connection timeout")


func _on_client_connected_to_server(client_id: int) -> void:
  _handle_loading_result(OK)
  ENetMultiplayerService.print_peer("%d _on_client_connected_to_server" % client_id)


func _on_player_list_changed() -> void:
  _refresh_player_list()
  ENetMultiplayerService.print_peer(ENetMultiplayerService.client_list)

#endregion
