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
@export var wander_speed: float = 80.0
@export var wander_wait_min: float = 0.5
@export var wander_wait_max: float = 1.5
@export var wander_arrive_dist: float = 4.0
@export var wander_stuck_time: float = 0.6
@export var fade_time: float = 0.3
@export var camera_slide_time: float = 0.4
@export var battle_slide_time: float = 0.4

# Modos de formula (M5a) - todos os coeficientes abaixo sao "valor de teste".
@export var dr_mode: DrMode = DrMode.A
@export var dr_band2_start: int = 20 # valor de teste (B)
@export var dr_band3_start: int = 40 # valor de teste (B)
@export var dr_band2_factor: float = 0.5 # valor de teste (B)
@export var dr_band3_factor: float = 0.25 # valor de teste (B)
@export var dr_smooth_limit: float = 60.0 # valor de teste (C)
@export var dr_smooth_k: float = 30.0 # valor de teste (C)
@export var hp_mode: HpMode = HpMode.A
@export var hp_base: int = 30 # valor de teste (B, C)
@export var hp_vit_a: int = 8 # valor de teste (B, C)
@export var hp_lvl_b: int = 4 # valor de teste (B)
@export var hp_vit_lvl_c: float = 0.4 # valor de teste (B)
@export var hp_c_level_mult: float = 0.08 # valor de teste (C)
@export var ap_mode: ApMode = ApMode.A
@export var ap_aura_a: int = 4 # valor de teste (B, C)
@export var ap_lvl_b: int = 1 # valor de teste (B)
@export var ap_c_level_mult: float = 0.05 # valor de teste (C)
@export var atb_mode: AtbMode = AtbMode.A
@export var atb_turn_time: float = 4.0 # valor de teste (C)
@export var atb_c_r: float = 20.0 # valor de teste (C)
@export var dodge_mode: DodgeMode = DodgeMode.A
@export var damage_mode: DamageMode = DamageMode.A
@export var dmg_ratio_k: float = 20.0 # valor de teste (B)
@export var dmg_c_equip_factor: float = 1.0 # valor de teste (C)
@export var variance_mode: VarianceMode = VarianceMode.A
@export var variance_b: float = 0.06 # valor de teste (B)
@export var variance_c: float = 0.12 # valor de teste (C)
@export var xp_mode: XpMode = XpMode.A
@export var xp_coef_b: int = 25 # valor de teste (B)
@export var xp_coef_c: int = 15 # valor de teste (C)
@export var xp_linear_c: int = 30 # valor de teste (C)
@export var max_level: int = 0 # valor de teste (0 = sem limite; opcoes 50, 99)
@export var revive_mode: ReviveMode = ReviveMode.A
@export var revive_b: float = 0.5 # valor de teste (B)
@export var revive_c_flat: int = 10 # valor de teste (C)
@export var revive_c_pct: float = 0.10 # valor de teste (C)
@export var poison_mode: PoisonMode = PoisonMode.A
@export var poison_pct: float = 0.06 # valor de teste (B, C)
@export var duration_mode: DurationMode = DurationMode.A
@export var duration_table: Dictionary[StringName, int] = {&"poison": 4, &"sleep": 2, &"paralysis": 2, &"haste": 4, &"slow": 3, &"barrier": 4, &"str_up": 3} # valor de teste (B)
@export var sim_tick: float = 0.1 # valor de teste (simulador: passo de tempo por tick)
@export var sim_max_seconds: float = 600.0 # valor de teste (simulador: limite de uma batalha, em segundos de jogo)
