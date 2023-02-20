local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BEHAVIOR_TAG: string = "$_WeaverBehavior"

local Behavior = require(script.Behavior)
local FrameworkData = require(script.Parent.FrameworkData)

local BehaviorSystem = {
	newBehavior = Behavior.new,
	getInstanceBehaviors = Behavior.GetInstanceBehaviors,
}

local modelBehviorFolder, behaviorInstanceStatusEvent, behaviorInstancePropertyEvent
local behaviorsRegistry = {}
local behaviorsRegistryIdMap = {}

local instanceIdCounter = 0
local behaviorLifecycleData = {}

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

function BehaviorSystem:_trackBehaviorLifecycle(instance: Instance)
	if behaviorLifecycleData[instance] then
		warn(
			'[ Weaver | Behavior ] Tried to start tracking lifecycle of Behavior that is already trakced. "'
				.. instance.Name
				.. '"'
		)
		return
	end

	behaviorLifecycleData[instance] = {
		AncestryChanged = instance.AncestryChanged:Connect(function(_, parent)
			-- TODO: Temp fix because ChildAdded gets fired before AncestryChanged
			task.defer(function()
				if parent and instance:IsDescendantOf(workspace) then
					self:_trackInstance(instance)
				else
					self:_stopTrackingInstance(instance)
				end
			end)
		end),
	}

	if instance:IsDescendantOf(workspace) then
		self:_trackInstance(instance)
	end
end

function BehaviorSystem:_stopTrackingBehaviorLifecycle(instance: Instance)
	local modelBehaviorInstanceData = behaviorLifecycleData[instance]
	if not modelBehaviorInstanceData then
		warn(
			'[ Weaver | BehaviorSystem ] Tried to stop tracking Behavior lifecycle of a Model that isnt registered. "'
				.. instance.Name
				.. '"'
		)
		return
	end

	self:_stopTrackingInstance(instance)

	modelBehaviorInstanceData.AncestryChanged:Disconnect()
	modelBehaviorInstanceData.AncestryChanged = nil
	behaviorLifecycleData[instance] = nil
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
		BehaviorSystem:_trackBehaviorLifecycle(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(BEHAVIOR_TAG):Connect(function(instance: Instance)
		BehaviorSystem:_stopTrackingBehaviorLifecycle(instance)
	end)

	for _, instance: Instance in CollectionService:GetTagged(BEHAVIOR_TAG) do
		BehaviorSystem:_trackBehaviorLifecycle(instance)
	end
end

function BehaviorSystem._prepare()
	modelBehviorFolder = Instance.new("Folder")
	modelBehviorFolder.Name = "Behavior"
	modelBehviorFolder.Parent = ReplicatedStorage["$_Weaver"]

	behaviorInstanceStatusEvent = Instance.new("RemoteEvent")
	behaviorInstanceStatusEvent.Name = "Status"
	behaviorInstanceStatusEvent.Parent = modelBehviorFolder

	behaviorInstancePropertyEvent = Instance.new("RemoteEvent")
	behaviorInstancePropertyEvent.Name = "Property"
	behaviorInstancePropertyEvent.Parent = modelBehviorFolder
end

function BehaviorSystem._prepareNetworking()
	for _, registryBehavior in Behavior.GetAll() do
		local behaviorFolder = assertBehaviorFolder(registryBehavior.Name)

		if registryBehavior.Config.Properties then
			for propertyName, propertyData in registryBehavior.Config.Properties do
				local remotePropertyInstance: RemoteEvent = Instance.new("RemoteEvent")
				remotePropertyInstance:SetAttribute("Type", "Property")
				remotePropertyInstance.Name = propertyName
				remotePropertyInstance.Parent = behaviorFolder
				propertyData[FrameworkData.PropertyRemoteEvent] = remotePropertyInstance
				remotePropertyInstance.OnServerEvent:Connect(function(player: Player, instance: Instance)
					local behaviorInstance = behaviorsRegistry[instance]
					if not behaviorInstance then
						return
					end

					for _, behavior in behaviorInstance.Behaviors do
						if behavior.Name == registryBehavior.Name then
							remotePropertyInstance:FireClient(
								player,
								instance,
								behavior.Instance.Properties[propertyName]:Get()
							)
							return
						end
					end
				end)
			end
		end

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
	behaviorInstanceStatusEvent.OnServerEvent:Connect(function(player: Player, instance: Instance, streamedIn: boolean)
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
			behaviorInstanceStatusEvent:FireClient(player, instance, components)
		else
			print("Remove player from streamed clients")
		end
	end)

	for _, behavior in Behavior.GetAll() do
		behavior:_init()
	end
end

function BehaviorSystem._gatherBehaviors()
	local componentsFolder: Folder? = ServerScriptService:FindFirstChild("Behaviors")
	if not componentsFolder then
		return
	end

	for _, instance: Instance in componentsFolder:GetDescendants() do
		if not instance:IsA("ModuleScript") then
			continue
		end

		local success, _ = pcall(require, instance)
		if not success then
			error('[ Weaver | Behavior ] The above component has issues. ("' .. instance.Name .. '")')
		end
	end
end

return BehaviorSystem
