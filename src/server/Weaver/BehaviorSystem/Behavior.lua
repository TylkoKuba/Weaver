local behaviorRegistry = {}

local Behavior = {}
Behavior.__index = Behavior

function Behavior.GetAll()
	return behaviorRegistry
end

function Behavior.Get(behaviorName: string)
	return behaviorRegistry[behaviorName]
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
	local componentInstance = setmetatable({
		Name = self.Name,
		Instance = instance,
		Properties = properties,
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
	componentInstance.Client.Server = componentInstance

	return componentInstance
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
