local ServerScriptService = game:GetService("ServerScriptService")

local Weaver = require(ServerScriptService.Weaver)

local SharedBehavior = Weaver.SharedBehavior

local TestBehavior = SharedBehavior.new({
	Name = "TestBehavior",
	Properties = {
		["Hello"] = {
			Default = 10,
		},
		["TestProp"] = {
			Default = "Test",
		},
	},
})

function TestBehavior.Client:SomeCoolFunction(player: Player, ...)
	print("Client wants to access this cool remote function!", player, ...)
end

return TestBehavior
