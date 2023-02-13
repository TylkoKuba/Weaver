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
		error("[ Weaver | Component ] You cannot create component without a name!")
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

function Behavior:_construct(instance: Instance, instanceId: number, properties: any)
	local componentInstance = setmetatable({
		Name = self.Name,
		Instance = instance,
		InstanceId = instanceId,
		Properties = properties,
		Client = setmetatable({}, {
			__index = function(_, index)
				return self.Client[index]
			end,
		}),
	}, {
		__index = self,
		__tostring = function()
			return "BehaviorInstance<" .. self.Name .. " [" .. instance.Name .. "]>"
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

function Behavior:GetProperties(instance: Instance)
	local dataFolder: Folder? = instance:FindFirstChild("$_Metadata")
	if not dataFolder then
		return {}
	end

	local componentFolder: Folder? = dataFolder:FindFirstChild(self.Name)
	if not componentFolder then
		return {}
	end

	local propertiesFolder = componentFolder:FindFirstChild("Properties")
	if not propertiesFolder then
		return {}
	end

	local properties = {}
	for _, propertyInstance: Instance in propertiesFolder:GetChildren() do
		-- TODO: Validate the value based on component config
		if not propertyInstance:IsA("Configuration") then
			local propertyValue = propertyInstance:GetAttribute("Value")
			local propertyName = propertyInstance:GetAttribute("Property")
			--local propertyLink = instance:GetAttribute("Link")

			-- if propertyLink then
			-- 	local databaseValue = database.GetValue(propertyLink)
			-- 	if databaseValue then
			-- 		propertyValue = databaseValue
			-- 	end
			-- end
			-- TODO: Display warning if the value isn't specified in Component Properties
			properties[propertyName] = propertyValue
		end
	end

	for propName, propConf in self.Config.Properties do
		if properties[propName] then
			continue
		end

		properties[propName] = propConf.Default
	end

	return properties
end

return Behavior
