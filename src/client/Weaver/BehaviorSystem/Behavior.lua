local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FrameworkData = require(script.Parent.Parent.FrameworkData)

local behaviorsInstanceDataRegistry = {}

local ServerBehaviors = {}

local Behavior = {
	[FrameworkData.BehaviorsRegistry] = {},
}
Behavior.__index = Behavior

local function assertBehavior(behavior: string)
	if not ServerBehaviors[behavior] then
		local serviceInstance: Folder? = ReplicatedStorage["$_Weaver"]["ModelBehavior"]:FindFirstChild(behavior)
		if not serviceInstance then
			return
		end

		ServerBehaviors[behavior] = {}
		for _, instance: Instance in serviceInstance:GetChildren() do
			if not instance:IsA("RemoteEvent") and not instance:IsA("RemoteFunction") then
				continue
			end

			local networkActionType: string? = instance:GetAttribute("Type")
			if not networkActionType then
				continue
			end

			if networkActionType == "Function" then
				ServerBehaviors[behavior][instance.Name] = function(...)
					return (instance :: RemoteFunction):InvokeServer(...)
				end
			end
		end
	end

	return ServerBehaviors[behavior]
end

function Behavior.new(config: any)
	local name: string? = config.Name
	if not name then
		error("[ Weaver | Behavior ] You cannot create Behavior without a name!")
	end

	assertBehavior(name)

	local self = setmetatable({
		Name = name,
		__tostring = function(s: any)
			return "Behavior<" .. s.Name .. ">"
		end,
	}, Behavior)
	self.__index = self

	self.ServerActions = ServerBehaviors[name]

	Behavior[FrameworkData.BehaviorsRegistry][name] = self
	return self
end

function Behavior:GetBehaviors(instance: Instance)
	return behaviorsInstanceDataRegistry[instance]
end

function Behavior:_construct(instance: Instance, clientProperties: any, serverProperties: any)
	local behaviorInstance: any = setmetatable({
		Name = self.Name,
		Instance = instance,
		Properties = clientProperties,
	}, {
		__index = self,
		__tostring = function()
			return "BehaviorInstance<" .. self.Name .. " / " .. instance.Name .. ">"
		end,
	})

	if ServerBehaviors[self.Name] then
		behaviorInstance.Server = {}
		for actionName, action in self.ServerActions do
			behaviorInstance.Server[actionName] = setmetatable({}, {
				__call = function(_, _, ...)
					action(instance, ...)
				end,
			})
		end
		behaviorInstance.Server.Properties = serverProperties
	end

	if not behaviorsInstanceDataRegistry[instance] then
		behaviorsInstanceDataRegistry[instance] = {}
	end

	table.insert(behaviorsInstanceDataRegistry[instance], behaviorInstance)

	return behaviorInstance
end

function Behavior:_init()
	if type(self.Init) == "function" then
		self:Init()
	end
end

function Behavior:_constructed()
	if type(self.Construct) == "function" then
		self:Construct()
	end
end

function Behavior:_destroy()
	if type(self.Destroy) == "function" then
		self:Destroy()
	end

	for index, behaviorInstance in behaviorsInstanceDataRegistry[self.Instance] do
		if behaviorInstance == self then
			table.remove(behaviorsInstanceDataRegistry[self.Instance], index)

			if #behaviorsInstanceDataRegistry[self.Instance] == 0 then
				behaviorsInstanceDataRegistry[self.Instance] = nil
			end
			return
		end
	end
end

return Behavior
