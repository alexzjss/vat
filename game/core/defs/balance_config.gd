# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8)
class_name BalanceConfig
extends Resource

enum DrMode { A, B, C }
enum HpMode { A, B, C }
enum ApMode { A, B, C }
enum AtbMode { A, B, C }
enum DodgeMode { A, B, C }
enum DamageMode { A, B, C }
enum VarianceMode { A, B, C }
enum XpMode { A, B, C }
enum ReviveMode { A, B, C }
enum PoisonMode { A, B, C }
enum DurationMode { A, B }

@export var hp_per_vitality: int = 10
@export var hp_per_level: int = 5
@export var ap_per_aura: int = 5
@export var atb_base_rate: float = 0.2
@export var atb_rate_per_speed: float = 0.02
@export var atb_min_rate: float = 0.05
@export var dodge_per_speed: float = 0.005
@export var dodge_cap: float = 0.15
@export var dr_soft_cap: int = 20
@export var dr_factor: float = 0.5
@export var defense_per_vitality: float = 0.5
@export var xp_coef: int = 10
@export var control_value_per_turn: int = 10
@export var item_cast_time: float = 0.6
@export var item_impact_time: float = 0.3
@export var player_speed: float = 220.0
@export var run_mult: float = 1.8 # valor de teste (M7: multiplicador da velocidade ao segurar correr)
@export var follow_spacing: float = 28.0 # valor de teste (M7: px andados entre amostras do rastro)
@export var follow_gap: int = 1 # valor de teste (M7: amostras entre seguidores)
@export var flee_base_rate: float = 0.25 # valor de teste (M7: barra de fuga por segundo)
@export var flee_decay: float = 0.5 # valor de teste (M7: esvaziamento da barra por segundo)
@export var flee_cooldown: float = 3.0 # valor de teste (M7: segundos sem toque do inimigo apos a fuga)
@export var backstab_angle: float = 120.0 # valor de teste (M7: graus; acima disso o toque e pelas costas)
@export var limit_fill_mult: float = 1.5 # valor de teste (M8: barra de Limite ganha dano/hp_max x isto)
@export var support_cost: float = 0.5 # valor de teste (M8.5: Limite gasto ao chamar o Suporte)
@export var support_fade_time: float = 0.3 # valor de teste (M8.5: segundos do fade-in do reserva na tela)
@export var banner_time: float = 1.2 # valor de teste (M7: segundos da faixa Ataque surpresa/Emboscada)
@export var patrol_wait: float = 0.6 # valor de teste (M7: pausa em cada ponto da patrulha, s)
@export var vision_range: float = 220.0 # valor de teste (M7: alcance do cone de visao, px)
@export var vision_angle: float = 70.0 # valor de teste (M7: abertura TOTAL do cone, graus)
@export var chase_speed: float = 150.0 # valor de teste (M7: velocidade perseguindo, px/s)
@export var chase_give_up: float = 380.0 # valor de teste (M7: distancia em que o perseguidor desiste, px)
@export var ambush_reveal_dist: float = 90.0 # valor de teste (M7: distancia em que o escondido aparece, px)
@export var group_join_dist: float = 200.0 # valor de teste (M7: raio em que o grupo se junta a batalha, px)
@export var wander_speed: float = 80.0
@export var wander_wait_min: float = 0.5
@export var wander_wait_max: float = 1.5
@export var wander_arrive_dist: float = 4.0
@export var wander_stuck_time: float = 0.6
@export var fade_time: float = 0.3
@export var camera_slide_time: float = 0.4
@export var battle_slide_time: float = 0.4

# Modos de formula (M5a) - todos os coeficientes abaixo sao "valor de teste".
@export var dr_mode: DrMode = DrMode.B
@export var dr_band2_start: int = 20 # valor de teste (B)
@export var dr_band3_start: int = 40 # valor de teste (B)
@export var dr_band2_factor: float = 0.5 # valor de teste (B)
@export var dr_band3_factor: float = 0.25 # valor de teste (B)
@export var dr_smooth_limit: float = 60.0 # valor de teste (C)
@export var dr_smooth_k: float = 30.0 # valor de teste (C)
@export var hp_mode: HpMode = HpMode.B
@export var hp_base: int = 30 # valor de teste (B, C)
@export var hp_vit_a: int = 8 # valor de teste (B, C)
@export var hp_lvl_b: int = 4 # valor de teste (B)
@export var hp_vit_lvl_c: float = 0.4 # valor de teste (B)
@export var hp_c_level_mult: float = 0.08 # valor de teste (C)
@export var ap_mode: ApMode = ApMode.B
@export var ap_aura_a: int = 4 # valor de teste (B, C)
@export var ap_lvl_b: int = 1 # valor de teste (B)
@export var ap_c_level_mult: float = 0.05 # valor de teste (C)
@export var atb_mode: AtbMode = AtbMode.A
@export var atb_turn_time: float = 4.0 # valor de teste (C)
@export var atb_c_r: float = 20.0 # valor de teste (C)
@export var dodge_mode: DodgeMode = DodgeMode.B
@export var damage_mode: DamageMode = DamageMode.B
@export var dmg_ratio_k: float = 20.0 # valor de teste (B)
@export var dmg_c_equip_factor: float = 1.0 # valor de teste (C)
@export var variance_mode: VarianceMode = VarianceMode.B
@export var variance_b: float = 0.06 # valor de teste (B)
@export var variance_c: float = 0.12 # valor de teste (C)
@export var xp_mode: XpMode = XpMode.C
@export var xp_coef_b: int = 25 # valor de teste (B)
@export var xp_coef_c: int = 15 # valor de teste (C)
@export var xp_linear_c: int = 30 # valor de teste (C)
@export var max_level: int = 99 # valor de teste (0 = sem limite; opcoes 50, 99)
@export var revive_mode: ReviveMode = ReviveMode.A
@export var revive_b: float = 0.5 # valor de teste (B)
@export var revive_c_flat: int = 10 # valor de teste (C)
@export var revive_c_pct: float = 0.10 # valor de teste (C)
@export var poison_mode: PoisonMode = PoisonMode.B
@export var poison_pct: float = 0.06 # valor de teste (B, C)
@export var duration_mode: DurationMode = DurationMode.A
@export var duration_table: Dictionary[StringName, int] = {&"poison": 4, &"sleep": 2, &"paralysis": 2, &"haste": 4, &"slow": 3, &"barrier": 4, &"str_up": 3, &"str_down": 3, &"vit_up": 3, &"vit_down": 3, &"spd_up": 3, &"spd_down": 3, &"confusion": 3, &"silence": 3, &"blind": 3, &"regen": 4} # valor de teste (B)
# Estados (M11).
@export var blind_miss_chance: float = 0.5 # valor de teste (M11: chance extra de errar de quem esta Cego; so dano de Forca)
@export var regen_pct: float = 0.05 # valor de teste (M11: fracao do HP maximo curada por ATB cheio, minimo 1)
# Chefes (M11).
@export var core_shield_mult: float = 0.25 # valor de teste (M11: multiplicador de dano no nucleo enquanto uma parte protetora esta de pe)
@export var same_element_bonus: float = 1.2 # valor de teste (M13: multiplicador de dano quando o elemento efetivo e nativo do atacante)
@export var blood_lifesteal: float = 0.25 # valor de teste (M13 Sangue: fracao do dano efetivo devolvida ao atacante como HP)
@export var blood_low_hp_bonus: float = 0.5 # valor de teste (M13 Sangue: bonus de dano = 1 + isto x (1 - hp/hp_max) do atacante)
@export var rad_threshold: int = 3 # valor de teste (M13 Radioativo: contaminacao que faz estourar)
@export var rad_burst_pct: float = 0.15 # valor de teste (M13 Radioativo: fracao do HP maximo do alvo no estouro, minimo 1)
@export var rad_decay_actions: int = 2 # valor de teste (M13 Radioativo: acoes do alvo para perder 1 de contaminacao)
@export var rad_corrode_per_stack: float = 0.1 # valor de teste (M13 Radioativo: queda da Vitalidade efetiva por nivel de contaminacao)
@export var rad_self_pct: float = 0.1 # valor de teste (M13 Radioativo: fracao do dano efetivo que fere o atacante, nunca abaixo de 1 HP)
@export var sim_tick: float = 0.1 # valor de teste (simulador: passo de tempo por tick)
@export var sim_max_seconds: float = 600.0 # valor de teste (simulador: limite de uma batalha, em segundos de jogo)

# Configuracoes (M6). Indice 1-based em GameSettings.battle_speed; padrao 3 = x1.0.
@export var battle_speed_mults: Array[float] = [0.6, 0.8, 1.0, 1.25, 1.5] # valor de teste
@export var default_battle_speed: int = 3 # valor de teste
@export var text_speed_max: int = 3 # valor de teste
@export var default_text_speed: int = 2 # valor de teste
@export var volume_max: int = 10 # valor de teste
@export var default_volume: int = 10 # valor de teste

# Eventos e dialogo (M10).
@export var event_max_steps: int = 1000 # valor de teste (M10: passos seguidos sem apresentacao antes de abortar o evento)
@export var text_speeds: Array[float] = [30.0, 60.0, 120.0] # valor de teste (M10: caracteres por segundo; indice = text_speed - 1)
@export var event_actor_speed: float = 120.0 # valor de teste (M10: px/s do MoveActor quando o passo nao define velocidade)
@export var event_camera_time: float = 0.8 # valor de teste (M10: segundos do CameraTo)
@export var trap_damage_pct: float = 0.1 # valor de teste (M10: fracao do HP maximo que a armadilha de dano tira dos ativos; nunca mata)

# Economia (M12).
@export var currency_name: String = "Moedas" # valor de teste (M12: nome exibido da moeda)
@export var sell_ratio: float = 0.5 # valor de teste (M12: vender rende floor(preco x isto))
@export var max_stack: int = 99 # valor de teste (M12: limite de uma pilha de item/equipamento ao comprar)
@export var inn_price: int = 20 # valor de teste (M12: preco da pousada)
