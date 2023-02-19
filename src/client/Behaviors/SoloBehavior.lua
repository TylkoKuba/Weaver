local Players = game:GetService("Players")

local Weaver = require(Players.LocalPlayer.PlayerScripts.Weaver)

local Behavior = Weaver.Behavior

local SoloBehavior = Behavior.new({
	Name = "SoloBehavior",
})

return SoloBehavior
