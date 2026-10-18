# VALORES DE TESTE — NÃO CANÔNICOS (spec v4.0 §8)
class_name BalanceConfig
extends Resource

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
