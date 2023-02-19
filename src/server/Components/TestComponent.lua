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
	print("TestBehavior constructed!")
	for _, instance in self.Instance:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.Transparency = 1
		end
	end
end

function TestBehavior:Destroy()
	print("TestBehavior destroyed!")
end

return TestBehavior
