local RunService = game:GetService("RunService")

local System = require(script.System)
local BehaviorSystem = require(script.BehaviorSystem)

local Weaver = {
	System = {
		new = System.new,
		Get = System.Get,
	},
	Behavior = {
		new = BehaviorSystem.newBehavior,
	},
}

function Weaver.Init()
	if RunService:IsClient() then
		System._waitForData()
		System._gather()
		System._sort()
		System._init()
		System._start()
		System._cleanup()

		BehaviorSystem._prepare()
		BehaviorSystem._gather()
		BehaviorSystem._init()
	end
end

return Weaver
