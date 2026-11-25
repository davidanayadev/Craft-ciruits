class_name StatModifier
extends Resource
## One change to one stat (architecture §9.4, spec 015): pieces carry a list of
## them and StatsCalculator applies every SET, then every ADD, then every MULTIPLY.

enum Op { SET, ADD, MULTIPLY }

## A StatIds constant.
@export var stat: StringName
@export var op: Op = Op.SET
@export var value: float = 0.0
