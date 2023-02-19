local Symbol = require(script.Parent.Symbol)

return {
	BehaviorTag = "$_WeaverModelBehavior",
	BehaviorPrimaryPart = "$_WeaverPrimaryPart",
	BehaviorDataExpriation = 5, -- seconds,

	BehaviorsRegistry = Symbol("BehaviorsRegistry"),
	BehaviorsInstanceDataRegistry = Symbol("BehaviorsRegistry"),

	CreateSharedBehaviorInstance = Symbol("CreateSharedBehaviorInstance"),

	System = Symbol("System"),
}
