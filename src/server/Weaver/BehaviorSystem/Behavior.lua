local Value = require(script.Parent.Parent.Value)
local FrameworkData = require(script.Parent.Parent.FrameworkData)

local behaviorRegistry = {}
local behaviorsInstanceDataRegistry = {}

local Behavior = {}
Behavior.__index = Behavior

function Behavior.GetAll()
	return behaviorRegistry
end

function Behavior.Get(behaviorName: string)
	return behaviorRegistry[behaviorName]
end

function Behavior.GetInstance(instance: Instance)
	return behaviorsInstanceDataRegistry[instance]
end

function Behavior.new(config: any)
	if not config.Name then
		error("[ Weaver | Behavior ] You cannot create Behavior without a name!")
	end

	local componentEntry = setmetatable({
		Name = config.Name,
		Config = config,
		Client = {},

		__tostring = function(self: any)
			return "Behavior<" .. self.Name .. ">"
		end,
	}, Behavior)
	componentEntry.__index = componentEntry

	behaviorRegistry[config.Name] = componentEntry

	return componentEntry
end

function Behavior:_construct(instance: Instance, properties: any)
	local propertyValues = {}
	if self.Config.Properties then
		for propertyName, propertyData in self.Config.Properties do
			propertyValues[propertyName] = Value.new(properties[propertyName] or propertyData.Default)
			propertyValues[propertyName]:Subscribe(function(newValue: any)
				propertyData[FrameworkData.PropertyRemoteEvent]:FireAllClients(instance, newValue)
			end)
		end
	end

	local behaviorInstance = setmetatable({
		Name = self.Name,
		Instance = instance,
		Properties = propertyValues,
		Client = setmetatable({}, {
			__index = function(_, index)
				return self.Client[index]
			end,
		}),
	}, {
		__index = self,
		__tostring = function()
			return "BehaviorInstance<" .. self.Name .. " / " .. instance.Name .. ">"
		end,
	})
	behaviorInstance.Client.Server = behaviorInstance

	if not behaviorsInstanceDataRegistry[instance] then
		behaviorsInstanceDataRegistry[instance] = {}
	end

	table.insert(behaviorsInstanceDataRegistry[instance], behaviorInstance)

	return behaviorInstance
end

function Behavior:_constructed()
	if type(self.Construct) == "function" then
		self:Construct()
	end
end

function Behavior:_init()
	if type(self.Init) == "function" then
		self:Init()
	end
end

function Behavior:_destroy()
	if type(self.Destroy) == "function" then
		self:Destroy()
	end
end

return Behavior
