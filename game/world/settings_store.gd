class_name SettingsStore
extends RefCounted

## Persistencia das configuracoes em um ConfigFile (fora de core/: faz IO). Separado do save.

const DEFAULT_PATH: String = "user://settings.cfg"
const SECTION: String = "settings"

## Le `path` para `settings`; arquivo ausente ou ilegivel mantem os padroes. Devolve true se leu.
static func load_into(settings: GameSettings, path: String = DEFAULT_PATH) -> bool:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return false
	var d: Dictionary = {}
	for key: String in cf.get_section_keys(SECTION):
		d[key] = cf.get_value(SECTION, key)
	settings.from_dict(d)
	return true

static func save(settings: GameSettings, path: String = DEFAULT_PATH) -> bool:
	var cf := ConfigFile.new()
	var d: Dictionary = settings.to_dict()
	for key: String in d:
		cf.set_value(SECTION, key, d[key])
	return cf.save(path) == OK
