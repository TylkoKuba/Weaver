local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local System = Weaver.System

local OtherSystem = System.new({
	Name = "OtherSystem",
	Priority = 1,
})

function OtherSystem.Start()
	-- local TestSystem = System.Get("TestSystem")
	-- TestSystem.Server.TestSignal:Fire("Hello Server, I'm OtherSystem!")
end

return OtherSystem
