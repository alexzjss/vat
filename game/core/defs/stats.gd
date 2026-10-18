class_name Stats
extends Resource

const ATTRS: Array[StringName] = [&"strength", &"speed", &"vitality", &"aura"]

@export var strength: int = 0
@export var speed: int = 0
@export var vitality: int = 0
@export var aura: int = 0

func get_attr(attr_name: StringName) -> int:
	match attr_name:
		&"strength": return strength
		&"speed": return speed
		&"vitality": return vitality
		&"aura": return aura
	push_error("Stats.get_attr: atributo desconhecido %s" % attr_name)
	return 0

func plus(o: Stats) -> Stats:
	return Stats.make(strength + o.strength, speed + o.speed, vitality + o.vitality, aura + o.aura)

static func make(str: int, spd: int, vit: int, aur: int) -> Stats:
	var s := Stats.new()
	s.strength = str
	s.speed = spd
	s.vitality = vit
	s.aura = aur
	return s
