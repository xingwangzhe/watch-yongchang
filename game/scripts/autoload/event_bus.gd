extends Node
## 全局信号总线：跨模块解耦，验证版只保留闭环需要的信号。

signal wave_started(wave_index: int, enemy_count: int)
signal unit_spawned(unit_type: StringName, lane_index: int)
signal unit_died(unit_type: StringName, lane_index: int)
signal unit_hit(unit_type: StringName, damage: int)
signal tower_fired(tower_id: StringName, target_type: StringName)
signal tower_halt(reason: String)
signal base_hit(damage: int, hp_left: int)
signal result_decided(victory: bool, reason: String)
signal culture_event(card_id: StringName, description: String)
