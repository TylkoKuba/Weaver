local ServerScriptService = game:GetService("ServerScriptService")

local Weaver = require(ServerScriptService.Weaver)

local Behavior = Weaver.Behavior

local TestBehavior = Behavior.new({
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

function TestBehavior:Construct()
	for _, instance in self.Instance:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.Transparency = 1
		end
	end

	task.delay(2, function()
		self.Properties["Hello"]:Set(math.random(0, 100))
	end)

	task.delay(5, function()
		self.Instance:Clone().Parent = workspace
	end)
end

return TestBehavior
