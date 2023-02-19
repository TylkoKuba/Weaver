local ServerScriptService = game:GetService("ServerScriptService")

local Weaver = require(ServerScriptService.Weaver)

local Behavior = Weaver.Behavior

local ServerBehavior = Behavior.new({
	Name = "ServerBehavior",
})

function ServerBehavior:Construct()
	print("ServerBehavior constructed!")
end

function ServerBehavior:Destroy()
	print("ServerBehavior destroyed!")
end

return ServerBehavior
