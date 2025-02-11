class_name ENetMultiplayerServiceConfig
extends RefCounted

#gdlint: disable=max-line-length
enum Settings {
  ## The default port the created server listen to for connections
  DEFAULT_SERVER_PORT,
  ## Maximum number of client connections allowed on the server at once
  MAX_CLIENTS,
  ## Allows to export and deploy the server on a dedicated server
  ## @tutorial https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
  USE_DEDICATED_SERVER,
  ## Allows the use of UPnP to manage external network discovery and port mapping.
  ## @tutorial https://docs.godotengine.org/en/latest/classes/class_upnp.html
  USE_UPNP
}
#gdlint: enable=max-line-length

const _CONFIG_SECTION: StringName = "enet_multiplayer_service"

const DEFAULT_PLUGIN_SETTINGS: Dictionary = {
  Settings.DEFAULT_SERVER_PORT: 31401,
  Settings.MAX_CLIENTS: 32,
  Settings.USE_DEDICATED_SERVER: true,
  Settings.USE_UPNP: true
}


static func init_plugin_settings() -> void:
  for key: int in Settings.values():
    var default_value: Variant = DEFAULT_PLUGIN_SETTINGS.values()[key]
    _add_custom_project_settings(
      _get_project_setting_path(key), default_value, typeof(default_value)
    )
  print("Default enet multiplayer service settings initialized")


static func _add_custom_project_settings(
  name: StringName,
  default_value: Variant,
  type: int,
  hint: int = PROPERTY_HINT_NONE,
  hint_string: String = ""
) -> void:
  if ProjectSettings.has_setting(name):
    ProjectSettings.set_setting(name, ProjectSettings.get_setting(name))
  else:
    ProjectSettings.set_setting(name, default_value)

  var setting_info: Dictionary = {
    "name": name, "type": type, "hint": hint, "hint_string": hint_string
  }
  ProjectSettings.add_property_info(setting_info)
  ProjectSettings.set_initial_value(name, default_value)
  ProjectSettings.set_as_basic(name, true)
  print("Setting %s:%s" % [name, ProjectSettings.get_setting(name)])


static func clear_plugin_settings() -> void:
  for key: int in Settings.values():
    var setting_path := _get_project_setting_path(key)
    if ProjectSettings.has_setting(setting_path):
      ProjectSettings.clear(setting_path)
  _save_plugin_settings()
  print("Cleared enet multiplayer settings")


static func get_plugin_setting(plugin_setting_key: Settings) -> Variant:
  var setting_path := _get_project_setting_path(plugin_setting_key)
  if !ProjectSettings.has_setting(setting_path):
    push_error(
      (
        "Setting %s doesn't exit, available settings are %s"
        % [setting_path, Settings.keys()]
      )
    )
    return null
  return ProjectSettings.get_setting(setting_path)


static func _save_plugin_settings() -> void:
  var result := ProjectSettings.save()
  if !result == OK:
    push_error(
      (
        "%s: Error while trying to save %s plugin settings in project settings"
        % [error_string(result), _CONFIG_SECTION]
      )
    )


static func _get_project_setting_path(setting_key: Settings) -> StringName:
  return "%s/%s" % [_CONFIG_SECTION, Settings.keys()[setting_key].to_lower()]
