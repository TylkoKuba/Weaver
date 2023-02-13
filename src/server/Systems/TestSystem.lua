local ServerScriptService = game:GetService("ServerScriptService")

local Weaver = require(ServerScriptService.Weaver)

local System = Weaver.System

local TestSystem = System.new({
	Name = "TestSystem",

	Client = {
		TestProperty = System.RemoteProperty(5),
		TestSignal = System.RemoteSignal,
	},
})

function TestSystem.Client:GetMoney()
	return 123456
end

function TestSystem:Init()
	self.Client.TestProperty:SetGlobal(10)
	self.Client.TestSignal:Connect(function(player: Player, ...)
		print("Test signal fired", player, ...)

		self.Client.TestSignal:Fire(player, ...)
	end)
end

return TestSystem
