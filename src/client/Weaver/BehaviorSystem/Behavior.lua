local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Libraries: Folder = script.Parent.Parent.Libraries

local Value = require(script.Parent.Parent.Value)
local RemoteProperty = require(script.Parent.RemoteProperty)
local Promise = require(Libraries:FindFirstChild("Promise"))

local behaviorsRegistry = {}
local behaviorsInstanceDataRegistry = {}

local ServerBehaviors = {}

local Behavior = {}
Behavior.__index = Behavior

local function assertBehavior(behavior: string)
	if not ServerBehaviors[behavior] then
		local serviceInstance: Folder? = ReplicatedStorage["$_Weaver"]["Behavior"]:FindFirstChild(behavior)
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
				ServerBehaviors[behavior][instance.Name] = {
					Type = "Function",
					Instance = instance,
					Action = function(...)
						return (instance :: RemoteFunction):InvokeServer(...)
					end,
				}
			elseif networkActionType == "Property" then
				local remoteEvent: RemoteEvent = instance :: RemoteEvent
				ServerBehaviors[behavior][instance.Name] = {
					Type = "Property",
					Instance = instance,
					Action = function(inst: Instance)
						remoteEvent:FireServer(inst)
					end,
				}
			end
		end
	end

	return ServerBehaviors[behavior]
end

function Behavior.GetAll()
	return behaviorsRegistry
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

	behaviorsRegistry[name] = self
	return self
end

function Behavior:GetBehaviors(instance: Instance)
	return behaviorsInstanceDataRegistry[instance]
end

function Behavior:_construct(instance: Instance, clientProperties: any)
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
		behaviorInstance._serverPropertiesInitTask = Promise.try(function()
			behaviorInstance.Server = {
				Properties = {},
			}
			for actionName, action in self.ServerActions do
				if action.Type == "Function" then
					behaviorInstance.Server[actionName] = function(_, ...)
						action.Action(instance, ...)
					end
				elseif action.Type == "Property" then
					behaviorInstance.Server.Properties[actionName] = RemoteProperty.new(action.Instance, instance)
					behaviorInstance.Server.Properties[actionName]:OnReady():await()
				end
			end
			behaviorInstance._serverPropertiesInitTask = nil
		end)
		behaviorInstance._serverPropertiesInitTask:await()
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
	if self.Server then
		for _, remoteProperty in self.Server.Properties do
			remoteProperty:Destroy()
		end
		self.Server.Properties = nil
	end

	if self._serverPropertiesInitTask then
		self._serverPropertiesInitTask:cancel()
		self._serverPropertiesInitTask = nil
		return
	end

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
