local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local SharedBehavior = Weaver.Behavior

local TestBehavior = SharedBehavior.new({
	Name = "TestBehavior",
})

function TestBehavior:Construct()
	self.Server:SomeCoolFunction("Hello Server!", 123)

	for _, instance in self.Instance:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.CFrame = instance.CFrame + instance.CFrame.LookVector * math.random(0, 10)
			instance.Transparency = 0
		end
	end

	self.Server.Properties["Hello"]:Observe(function(newValue: any)
		print("New val", newValue)
	end)
end

return TestBehavior
