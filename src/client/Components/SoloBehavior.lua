local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local Behavior = Weaver.Behavior

local SoloBehavior = Behavior.new({
	Name = "SoloBehavior",
})

function SoloBehavior:Construct()
	warn("Solo behavior, just on the client!", self.Instance)
end

function SoloBehavior:Destroy()
	print("Solo behavior destroy!")
end

return SoloBehavior
