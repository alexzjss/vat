class_name PlayMusicStep
extends EventStep

## Troca a musica de fundo (M19): `@musica id [fade]` / `@musica parar [fade]`. Vale ate o fim do mapa (a troca de mapa
## limpa); durante uma batalha so volta a valer depois dela. Apresentacao instantanea: o evento nao espera o fade.
@export var music_id: StringName = &""
## Segundos do fade; padrao igual ao da troca de mapa (AudioRules.MAP_FADE).
@export var fade: float = 0.5
## true: silencio ate o evento trocar a musica (`music_id` e ignorado).
@export var stop: bool = false
