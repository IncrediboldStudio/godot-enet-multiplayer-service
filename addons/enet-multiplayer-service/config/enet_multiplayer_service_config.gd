class_name ENetMultiplayerServiceConfig
extends RefCounted

const _CONFIG_SECTION: StringName = "enet_multiplayer_service"

#gdlint: disable=max-line-length
const _DEFAULT_PLUGIN_SETTINGS: Dictionary = {
  ## The default port the created server listen to for connections
  "default_server_port": 31401,
  ## Maximum number of client connections allowed on the server at once
  "max_clients": 32,
  ## Allows to export and deploy the server on a dedicated server
  ## @tutorial https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
  "use_dedicated_server": true,
  ## Allows the use of UPnP to manage external network discovery and port mapping.
  ## @tutorial https://docs.godotengine.org/en/latest/classes/class_upnp.html
  "use_upnp": true
}
#gdlint: enable=max-line-length


static func add_custom_project_settings(
  name: StringName,
  default_value: Variant,
  type: int,
  hint: int = PROPERTY_HINT_NONE,
  hint_string: String = ""
) -> void:
  if ProjectSettings.has_setting(name):
    return
  ProjectSettings.set_setting(name, default_value)
  var setting_info: Dictionary = {
    "name": name, "type": type, "hint": hint, "hint_string": hint_string
  }
  ProjectSettings.add_property_info(setting_info)
  ProjectSettings.set_initial_value(name, default_value)
  ProjectSettings.set_as_basic(name, true)


static func init_default_plugin_settings() -> void:
  for plugin_setting_key in _DEFAULT_PLUGIN_SETTINGS:
    var setting_value: Variant = _DEFAULT_PLUGIN_SETTINGS[plugin_setting_key]
    add_custom_project_settings(
      _get_project_setting_path(plugin_setting_key),
      setting_value,
      typeof(setting_value)
    )


static func clear_plugin_settings() -> void:
  for plugin_setting_key in _DEFAULT_PLUGIN_SETTINGS:
    var setting_path := _get_project_setting_path(plugin_setting_key)
    if ProjectSettings.has_setting(setting_path):
      ProjectSettings.clear(setting_path)
  save_plugin_settings()


static func save_plugin_settings() -> void:
  var result := ProjectSettings.save()
  if !result == OK:
    push_error(
      (
        "%s: Error while trying to save %s plugin settings in project settings"
        % [error_string(result), _CONFIG_SECTION]
      )
    )


static func try_get_plugin_setting(plugin_setting_key: StringName) -> Variant:
  var setting_path := _get_project_setting_path(plugin_setting_key)
  if !ProjectSettings.has_setting(setting_path):
    push_error(
      (
        "Setting %s doesn't exit, available settings are %s"
        % [plugin_setting_key, _DEFAULT_PLUGIN_SETTINGS.keys()]
      )
    )
    return null
  return ProjectSettings.get_setting(setting_path)


static func _get_project_setting_path(name: StringName) -> StringName:
  return "%s/%s" % [_CONFIG_SECTION, name]
