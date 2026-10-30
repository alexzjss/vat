class_name ConfigPage
extends FieldPage

## Config: ATB (Espera/Ativo), velocidade da batalha, memória do cursor, velocidade do texto, volume geral, volume da música, dos efeitos e o som do texto.
## Esquerda/direita alteram o valor da linha (Enter avança um passo); cada mudança avisa o menu
## (`settings_changed`) para quem hospeda persistir e aplicar.

enum Row { ATB, BATTLE_SPEED, CURSOR_MEMORY, TEXT_SPEED, VOLUME, MUSIC_VOLUME, EFFECTS_VOLUME, TEXT_SOUND }

func enter() -> void:
	super.enter()
	_refresh()

func accept() -> void:
	adjust(1)

func adjust(delta: int) -> void:
	var s: GameSettings = state.settings
	if s == null:
		return
	match cursor:
		Row.ATB:
			s.atb_mode = GameSettings.AtbMode.ACTIVE if s.atb_mode == GameSettings.AtbMode.WAIT else GameSettings.AtbMode.WAIT
		Row.BATTLE_SPEED:
			s.battle_speed += delta
		Row.CURSOR_MEMORY:
			s.cursor_memory = not s.cursor_memory
		Row.TEXT_SPEED:
			s.text_speed += delta
		Row.VOLUME:
			s.volume += delta
		Row.MUSIC_VOLUME:
			s.music_volume += delta
		Row.EFFECTS_VOLUME:
			s.effects_volume += delta
		Row.TEXT_SOUND:
			s.text_sound = not s.text_sound
	_refresh()
	menu.settings_changed.emit()

func _refresh() -> void:
	var s: GameSettings = state.settings
	var texts: Array[String] = []
	var enabled: Array[bool] = []
	if s != null:
		texts.append("ATB: %s" % ("Ativo" if s.atb_mode == GameSettings.AtbMode.ACTIVE else "Espera"))
		texts.append("Velocidade da batalha: %d" % s.battle_speed)
		texts.append("Memória do cursor: %s" % ("Ligada" if s.cursor_memory else "Desligada"))
		texts.append("Velocidade do texto: %d" % s.text_speed)
		texts.append("Volume: %d" % s.volume)
		texts.append("Volume da música: %d" % s.music_volume)
		texts.append("Volume dos efeitos: %d" % s.effects_volume)
		texts.append("Som do texto: %s" % ("Ligado" if s.text_sound else "Desligado"))
	for _t: String in texts:
		enabled.append(true)
	_set_entries(texts, enabled)
