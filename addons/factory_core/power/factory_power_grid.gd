class_name FactoryPowerGrid
extends RefCounted
## Lite power stub: machines always run at full power. Same API as the Pro
## FactoryPowerGrid (generators, supply/demand, brownout), so code written
## against Lite keeps working after upgrading to Pro.

## Never emitted in Lite (no brownouts). Kept for API compatibility.
signal brownout_changed(active: bool)

var supply_w: int = 0
## Sum of consumers' power_demand() (informational only in Lite).
var demand_w: int = 0
## Always 1000 (= 100 %) in Lite.
var satisfaction_permille: int = 1000
var brownout: bool = false

## Called by FactorySim before node ticks. Lite: records demand, never limits it.
func update(nodes: Array[FactoryNode]) -> void:
	demand_w = 0
	for n: FactoryNode in nodes:
		demand_w += n.power_demand()
	supply_w = demand_w
	satisfaction_permille = 1000
	brownout = false
