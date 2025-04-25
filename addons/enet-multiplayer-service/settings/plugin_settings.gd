class_name PluginSettings
extends Object
## Static class responsible for the initialization and cleanup of the plugin project settings

#gdlint: disable=max-line-length
enum Settings {
  ## The default port the created server listen to for connections
  SERVER_PORT,
  ## Maximum number of client connections allowed on the server at once.
  ## Note that if the server is also a player, it won't count towards the maximum connection limit
  MAX_CLIENTS,
  ## Timeout for a client peer trying to connect to a server
  CLIENT_CONNECTION_TIMEOUT,
  ## Allows to export and deploy the server on a dedicated server
  ## @tutorial https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html
  USE_DEDICATED_SERVER
}
#gdlint: enable=max-line-length

## The name of the project setting section
const _CONFIG_SECTION: StringName = "plugins/enet_multiplayer_service"

## Default values for the plugin settings.
const DEFAULT_PLUGIN_SETTINGS: Dictionary = {
  Settings.SERVER_PORT: 31401,
  Settings.MAX_CLIENTS: 3,
  Settings.CLIENT_CONNECTION_TIMEOUT: 4000,
  Settings.USE_DEDICATED_SERVER: false
}


## Initializes the default plugin setting in Godot's Project Settings and sets their default values
static func init_plugin_settings() -> void:
  for key: int in Settings.values():
    var default_value: Variant = DEFAULT_PLUGIN_SETTINGS.values()[key]
    _add_custom_project_settings(
      _get_project_setting_path(key), default_value, typeof(default_value)
    )
  _save_plugin_settings()
  print("Enet multiplayer service settings initialized")


## Fetches the plugin settings values from local cache
## to circumvent [url=https://github.com/godotengine/godot/issues/56598#issuecomment-1904100640] this issue[/url]
static func fetch_plugin_settings() -> void:
  for key: int in Settings.values():
    var default_value: Variant = DEFAULT_PLUGIN_SETTINGS.values()[key]
    _fetch_custom_project_settings(_get_project_setting_path(key), default_value)


## Adds a custom project settings and its property info
## [param name]: StringName => The name of the setting
## [param default_value]: Variant => The default value of the project setting
## [param type]: int => The type of the project setting value, see [enum Type]
## [param hint]: int => The type of the project setting value, see [enum PropertyHint]
## [param hint_string]: int => The editor hint formatting for the project setting value, see [enum PropertyHint]
static func _add_custom_project_settings(
  name: StringName,
  default_value: Variant,
  type: int,
  hint := PROPERTY_HINT_NONE,
  hint_string: String = ""
) -> void:
  if ProjectSettings.has_setting(name):
    ProjectSettings.set_setting(name, ProjectSettings.get_setting_with_override(name))
  else:
    ProjectSettings.set_setting(name, default_value)

  var setting_info: Dictionary = {
    "name": name, "type": type, "hint": hint, "hint_string": hint_string
  }
  ProjectSettings.add_property_info(setting_info)
  ProjectSettings.set_initial_value(name, default_value)
  ProjectSettings.set_as_basic(name, true)


## Sets the provided plugin setting value from the local cache,
## or sets the default value if not found
static func _fetch_custom_project_settings(name: StringName, default_value: Variant) -> void:
  if ProjectSettings.has_setting(name):
    ProjectSettings.set_setting(name, ProjectSettings.get_setting_with_override(name))
  else:
    ProjectSettings.set_setting(name, default_value)


## Remove all plugin settings from the project
static func clear_plugin_settings() -> void:
  for key: int in Settings.values():
    var setting_path := _get_project_setting_path(key)
    if ProjectSettings.has_setting(setting_path):
      ProjectSettings.clear(setting_path)
  _save_plugin_settings()
  print("Cleared enet multiplayer settings")


## Returns the plugin setting value for the provided key
## [param plugin_setting_key]: PluginSettings.Settings => The setting to fetch value from
static func get_plugin_setting(plugin_setting_key: Settings) -> Variant:
  var setting_path := _get_project_setting_path(plugin_setting_key)
  if !ProjectSettings.has_setting(setting_path):
    push_error(
      (
        "Setting %s doesn't exit, available settings are %s"
        % [setting_path, _get_valid_settings_paths()]
      )
    )
    return null
  return ProjectSettings.get_setting(setting_path)


## Saves the current plugin setting values
static func _save_plugin_settings() -> void:
  var result := ProjectSettings.save()
  if !result == OK:
    push_error(
      (
        "%s: Error while trying to save %s plugin settings in project settings"
        % [error_string(result), _CONFIG_SECTION]
      )
    )


## Gets the full project setting path for the provided setting key.
## [param plugin_setting_key]: PluginSettings.Settings => The setting to get path
static func _get_project_setting_path(setting_key: Settings) -> StringName:
  return "%s/%s" % [_CONFIG_SECTION, Settings.keys()[setting_key].to_lower()]


## Returns valid project setting paths for each plugin setting
static func _get_valid_settings_paths() -> String:
  var paths = ""
  for key in Settings.keys():
    paths += "%s/%s\r" % [_CONFIG_SECTION, key.to_lower()]
  return paths
