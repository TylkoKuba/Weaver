local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local System = Weaver.System

local TestSystem = System.new({
	Name = "TestSystem",
})

function TestSystem:Init()
	-- self.Server.TestSignal:Connect(function(...)
	-- 	print("Got signal from server!", ...)
	-- end)
	-- self.Server.TestSignal:Fire("Hello Server, repeat me!")
	-- print("My money is", self.Server:GetMoney())

	-- self.Server.TestProperty:OnReady():await()
	-- print("Property is ready!", self.Server.TestProperty:Get())
	-- self.Server.TestProperty:Subscribe(function(newValue: any)
	-- 	print("New property value!", newValue)
	-- end)
end

return TestSystem
