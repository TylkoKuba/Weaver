local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local SharedBehavior = Weaver.SharedBehavior

local TestBehavior = SharedBehavior.new({
	Name = "TestBehavior",
})

function TestBehavior:Construct()
	warn("Test behavior construct!", self.Instance)
	self.Server:SomeCoolFunction("Hello Server!", 123)
	print(self.Server.Properties)
end

function TestBehavior:Destroy()
	print("Test behavior destroy!")
end

return TestBehavior
