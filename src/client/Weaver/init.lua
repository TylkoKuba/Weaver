local RunService = game:GetService("RunService")

local System = require(script.System)
local ModelBehavior = require(script.ModelBehavior)

local Weaver = {
	System = {
		new = System.new,
		Get = System.Get,
	},
	SharedBehavior = {
		new = ModelBehavior.newComponent,
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

		ModelBehavior._prepare()
		ModelBehavior._gather()
		ModelBehavior._init()
	end
end

return Weaver
