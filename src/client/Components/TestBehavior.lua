local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local SharedBehavior = Weaver.Behavior

local TestBehavior = SharedBehavior.new({
	Name = "TestBehavior",
})

function TestBehavior:Construct()
	warn("Test behavior construct!", self.Instance)
	self.Server:SomeCoolFunction("Hello Server!", 123)

	for _, instance in self.Instance:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.CFrame = instance.CFrame + instance.CFrame.LookVector * math.random(0, 10)
			instance.Transparency = 0
		end
	end
end

function TestBehavior:Destroy()
	print("Test behavior destroy!")
end

return TestBehavior
