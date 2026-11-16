extends Node
## Autoload "EventBus": global facts that interest systems with no relation to
## each other (architecture §5, §7). The list of events is closed: a new one
## needs its row in architecture §7. It holds no state (a test guards it). No
## class_name: it would clash with the autoload name.
## Signals are declared here and emitted by whoever owns the fact, hence the
## unused_signal annotations.

## An enemy died after a player's hit. Emitted by the enemy, once per life.
@warning_ignore("unused_signal")
signal enemy_killed(enemy_id: StringName, killer_uid: String)
