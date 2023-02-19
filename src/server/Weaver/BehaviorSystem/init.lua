local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BEHAVIOR_TAG: string = "$_WeaverModelBehavior"

local Behavior = require(script.Behavior)

local BehaviorSystem = {
	newBehavior = Behavior.new,
}

local modelBehviorFolder, modelBehaviorInstanceStatusEvent
local behaviorsRegistry = {}
local behaviorsRegistryIdMap = {}

local instanceIdCounter = 0

local function getInstanceMetadata(instance: Instance)
	local dataFolder: Folder? = instance:FindFirstChild("$_Metadata")
	if not dataFolder then
		return {}
	end

	local components = {}
	for _, childInstance: Instance in dataFolder:GetChildren() do
		if not childInstance:IsA("Folder") then
			continue
		end

		local componentFolder: Folder = childInstance :: Folder

		local propertiesFolder = componentFolder:FindFirstChild("Properties")
		if not propertiesFolder then
			components[childInstance.Name] = {}
			continue
		end

		local propertiesInstances: { Instance } = propertiesFolder:GetChildren()
		local properties = {}

		for _, propertyInstance: Instance in propertiesInstances do
			-- TODO: Validate the value based on component config
			if not propertyInstance:IsA("Configuration") then
				continue
			end

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

		components[childInstance.Name] = properties
	end

	return components
end

local function assertBehaviorFolder(systemName: string)
	local newSystemFolder = modelBehviorFolder:FindFirstChild(systemName)
	if newSystemFolder then
		return newSystemFolder
	end

	newSystemFolder = Instance.new("Folder")
	newSystemFolder.Name = systemName
	newSystemFolder.Parent = modelBehviorFolder

	return newSystemFolder
end

function BehaviorSystem._callRemoteFunction(
	behaviorName: string,
	instance: Instance,
	functionName: string,
	player: Player,
	...
)
	local behaviorInstance = behaviorsRegistry[instance]
	if not behaviorInstance then
		return
	end

	for _, behavior in behaviorInstance.Behaviors do
		if behavior.Name == behaviorName then
			return behavior.Instance.Client[functionName](behavior.Client, player, ...)
		end
	end
end

function BehaviorSystem:_trackInstance(instance: Instance)
	if instance:IsA("Model") then
		local model: Model = instance :: Model

		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end

	instanceIdCounter += 1

	local instanceId: number = instanceIdCounter
	local existingInstanceId: number? = instance:GetAttribute("_IID")
	if not existingInstanceId then
		local metadataFolder: Folder? = instance:FindFirstChild("$_Metadata")
		if not metadataFolder then
			warn(
				"[ Weaver | ModelBehavior ] Tried to create Behavior instance for instance whos metadata doesn't exist!"
			)
			return
		end

		instance:SetAttribute("_IID", instanceId)

		local instanceData = getInstanceMetadata(instance)
		metadataFolder:Destroy()

		local behaviors = {}
		for componentName, componentData in instanceData do
			local component = Behavior.Get(componentName)
			if component then
				if component.Config.Properties then
					for propName, propConf in component.Config.Properties do
						if componentData[propName] then
							continue
						end

						componentData[propName] = propConf.Default
					end
				end
			end

			table.insert(behaviors, {
				Name = componentName,
				DefaultProperties = componentData,
			})
		end

		for _, modelBehavior in behaviors do
			local behavior = Behavior.Get(modelBehavior.Name)
			if behavior then
				modelBehavior.Instance = behavior:_construct(instance, modelBehavior.DefaultProperties)
			end
		end

		for _, modelBehavior in behaviors do
			if modelBehavior.Instance then
				modelBehavior.Instance:_constructed()
			end
		end

		behaviorsRegistry[instance] = {
			Id = instanceId,
			Behaviors = behaviors,
		}
		behaviorsRegistryIdMap[instanceId] = behaviorsRegistry[instance]
	else
		instance:SetAttribute("_IID", instanceId)

		local oldInstanceData = behaviorsRegistryIdMap[existingInstanceId]

		local behaviors = {}
		for _, behaviorData in oldInstanceData.Behaviors do
			table.insert(behaviors, {
				Name = behaviorData.Name,
				DefaultProperties = behaviorData.DefaultProperties,
			})
		end

		for _, modelBehavior in behaviors do
			local behavior = Behavior.Get(modelBehavior.Name)
			if behavior then
				modelBehavior.Instance = behavior:_construct(instance, instanceId, modelBehavior.DefaultProperties)
			end
		end

		for _, modelBehavior in behaviors do
			if modelBehavior.Instance then
				modelBehavior.Instance:_constructed()
			end
		end

		behaviorsRegistry[instance] = {
			Id = instanceId,
			Behaviors = behaviors,
		}
		behaviorsRegistryIdMap[instanceId] = behaviorsRegistry[instance]
	end
end

function BehaviorSystem:_stopTrackingInstance(instance: Instance)
	local behaviorModelInstance = behaviorsRegistry[instance]
	if not behaviorModelInstance then
		return
	end

	for _, modelBehavior in behaviorModelInstance.Behaviors do
		if modelBehavior.Instance then
			modelBehavior.Instance:_destroy()
		end
	end

	behaviorsRegistryIdMap[behaviorModelInstance.Id] = nil
	behaviorsRegistry[instance] = nil
end

function BehaviorSystem._gatherModels()
	CollectionService:GetInstanceAddedSignal(BEHAVIOR_TAG):Connect(function(instance: Instance)
		BehaviorSystem:_trackInstance(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(BEHAVIOR_TAG):Connect(function(instance: Instance)
		BehaviorSystem:_stopTrackingInstance(instance)
	end)

	for _, instance: Instance in CollectionService:GetTagged(BEHAVIOR_TAG) do
		BehaviorSystem:_trackInstance(instance)

		task.delay(5, function()
			local cI: Model = instance:Clone()
			local rx, ry, rz = cI:GetPivot():ToOrientation()
			cI:PivotTo(CFrame.new(Vector3.new(0, 10, 0)) * CFrame.Angles(rx, ry, rz))
			cI.Parent = workspace

			instance:Destroy()

			-- task.wait(2)
			-- task.spawn(function()
			-- 	local t = 0
			-- 	while t <= 10 do
			-- 		cI:PivotTo(CFrame.new(Vector3.new(0, 10 + t, 0)) * CFrame.Angles(rx, ry, rz))
			-- 		t += task.wait()
			-- 	end
			-- end)

			-- task.wait(5)
			-- instance:Destroy()
			-- task.wait(10)
			-- cI:Destroy()
		end)
	end
end

function BehaviorSystem._prepare()
	modelBehviorFolder = Instance.new("Folder")
	modelBehviorFolder.Name = "ModelBehavior"
	modelBehviorFolder.Parent = ReplicatedStorage["$_Weaver"]

	modelBehaviorInstanceStatusEvent = Instance.new("RemoteEvent")
	modelBehaviorInstanceStatusEvent.Name = "Status"
	modelBehaviorInstanceStatusEvent.Parent = modelBehviorFolder
end

function BehaviorSystem._prepareNetworking()
	for _, registryBehavior in Behavior.GetAll() do
		local behaviorFolder = assertBehaviorFolder(registryBehavior.Name)
		for networkActionName, networkAction in registryBehavior.Client do
			if typeof(networkAction) == "function" then
				local remoteFunctionInstance: RemoteFunction = Instance.new("RemoteFunction")
				remoteFunctionInstance:SetAttribute("Type", "Function")
				remoteFunctionInstance.Name = networkActionName
				remoteFunctionInstance.Parent = behaviorFolder

				remoteFunctionInstance.OnServerInvoke = function(player: Player, instance: Instance, ...)
					return BehaviorSystem._callRemoteFunction(
						registryBehavior.Name,
						instance,
						networkActionName,
						player,
						...
					)
				end
			end
		end
		registryBehavior.Client.Server = registryBehavior
	end
end

function BehaviorSystem._init()
	modelBehaviorInstanceStatusEvent.OnServerEvent:Connect(
		function(player: Player, instance: Instance, streamedIn: boolean)
			local behaviorInstance = behaviorsRegistry[instance]
			if not behaviorInstance then
				return
			end

			if streamedIn then
				local components = {}
				for _, behavior in behaviorInstance.Behaviors do
					table.insert(components, {
						Behavior = behavior.Name,
						Properties = behavior.DefaultProperties,
					})
				end
				modelBehaviorInstanceStatusEvent:FireClient(player, instance, components)
			else
				print("Remove player from streamed clients")
			end
		end
	)

	for _, behavior in Behavior.GetAll() do
		behavior:_init()
	end
end

function BehaviorSystem._gatherBehaviors()
	local componentsFolder: Folder? = ServerScriptService:FindFirstChild("Components")
	if not componentsFolder then
		return
	end

	for _, instance: Instance in componentsFolder:GetDescendants() do
		if not instance:IsA("ModuleScript") then
			continue
		end

		local success, _ = pcall(require, instance)
		if not success then
			error('[ Weaver | Component ] The above component has issues. ("' .. instance.Name .. '")')
		end
	end
end

return BehaviorSystem
