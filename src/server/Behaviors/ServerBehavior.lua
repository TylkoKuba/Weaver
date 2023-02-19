local ServerScriptService = game:GetService("ServerScriptService")

local Weaver = require(ServerScriptService.Weaver)

local Behavior = Weaver.Behavior

local ServerBehavior = Behavior.new({
	Name = "ServerBehavior",
})

return ServerBehavior
