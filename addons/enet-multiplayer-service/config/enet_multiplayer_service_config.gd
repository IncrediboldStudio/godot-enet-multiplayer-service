class_name ENetMultiplayerServiceConfig
extends RefCounted

const CONFIG_SECTION: StringName = "enet_multiplayer_service"

const DEFAULT_PLUGIN_SETTINGS: Dictionary = {
  "default_server_address": "localhost",
  "default_server_port": 31401,
  "max_clients": 32,
  "allow_dedicated_server": true,
  "allow_upnp": true
}
# gdlint: disable=max-line-length
const PLUGIN_SETTING_INFO: Dictionary = {
  "default_server_address":
  "The default address used to connect to the server.",
  "default_server_port":
  "The default port the host listens to when creating a server",
  "max_clients":
  "The maximum number of clients allowed to connect to the server at once.",
  "use_dedicated_server":
  "Allows the host to be run on a [url=https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html]dedicated server[/url].",
  "use_upnp": "Allows the use of UPNP to manage remote server setup."
}
# gdlint: enable=max-line-length


static func add_custom_project_settings(
  name: StringName,
  default_value: Variant,
  type: int,
  hint: int = PROPERTY_HINT_NONE
) -> void:
  if ProjectSettings.has_setting(name):
    return
  ProjectSettings.set_setting(name, default_value)
  ProjectSettings.set_initial_value(name, default_value)
  ProjectSettings.set_as_basic(name, true)

  if !PLUGIN_SETTING_INFO.has(name):
    return
  var property_info: Dictionary = {
    "name": name,
    "type": type,
    "hint": hint,
    "hint_string": PLUGIN_SETTING_INFO[name]
  }
  ProjectSettings.add_property_info(property_info)


static func init_default_plugin_settings() -> void:
  for setting_name in DEFAULT_PLUGIN_SETTINGS:
    var setting_value: Variant = DEFAULT_PLUGIN_SETTINGS[setting_name]
    add_custom_project_settings(
      _get_project_setting_path(setting_name),
      setting_value,
      typeof(setting_value)
    )


static func clear_plugin_settings() -> void:
  for setting_name in DEFAULT_PLUGIN_SETTINGS:
    var setting_path := _get_project_setting_path(setting_name)
    if ProjectSettings.has_setting(setting_path):
      ProjectSettings.clear(setting_path)
  save_plugin_settings()


static func save_plugin_settings() -> void:
  var result := ProjectSettings.save()
  if !result == OK:
    push_error(
      (
        "%s: Error while trying to save %s plugin settings in project settings"
        % [error_string(result), CONFIG_SECTION]
      )
    )


static func _get_project_setting_path(name: StringName) -> StringName:
  return "%s/%s" % [CONFIG_SECTION, name]
