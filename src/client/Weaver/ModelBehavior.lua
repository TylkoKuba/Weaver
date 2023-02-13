local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MODEL_BEHAVIOR_TAG: string = "$_WeaverModelBehavior"
local MODEL_BEHAVIOR_PRIMARY_PART: string = "$_WeaverPrimaryPart"
local MODEL_INSTANCE_DATA_EXPIRATION: number = 5

local modelBehaviorLifecycleData = {}
local modelBehaviorInstancesFolder, modelBehaviorInstanceStatusEvent

local componentRegistry = {}
local behaviorInstancesCallbacks = {}

local ModelBehaviorSystem = {}
local BehaviorServerSystems = {}
local ModelBehavior = {}
ModelBehavior.__index = ModelBehavior

local function assertBehavior(behavior: string)
	if not BehaviorServerSystems[behavior] then
		local serviceInstance: Folder? = ReplicatedStorage["$_Weaver"]["ModelBehavior"]:FindFirstChild(behavior)
		if not serviceInstance then
			print("No service instance")
			return
		end

		BehaviorServerSystems[behavior] = {}
		for _, instance: Instance in serviceInstance:GetChildren() do
			if not instance:IsA("RemoteEvent") and not instance:IsA("RemoteFunction") then
				continue
			end

			local networkActionType: string? = instance:GetAttribute("Type")
			if not networkActionType then
				continue
			end

			if networkActionType == "Function" then
				BehaviorServerSystems[behavior][instance.Name] = function(...)
					return (instance :: RemoteFunction):InvokeServer(...)
				end
			end
		end
	end

	return BehaviorServerSystems[behavior]
end

function ModelBehavior.new(config: any)
	if not config.Name then
		error("[ Weaver | ModelBehavior ] You cannot create ModelBehavior without a name!")
	end

	assertBehavior(config.Name)

	local componentEntry = setmetatable({
		__tostring = function(self: any)
			return "ComponentRegistry<" .. self.Name .. ">"
		end,
	}, ModelBehavior)
	componentEntry.__index = componentEntry
	componentEntry.Name = config.Name
	componentEntry.ServerActions = BehaviorServerSystems[config.Name]

	componentRegistry[config.Name] = componentEntry

	return componentEntry
end

function ModelBehavior:_construct(instance: Instance, instanceId: number, properties: any)
	local componentInstance = setmetatable({
		Name = self.Name,
		Instance = instance,
		InstanceId = instanceId,
	}, {
		__index = self,
		__tostring = function()
			return "ComponentInstance<" .. self.Name .. " [" .. instance.Name .. "]>"
		end,
	})
	componentInstance.Server = {}
	for actionName, action in self.ServerActions do
		componentInstance.Server[actionName] = setmetatable({}, {
			__call = function(_, _, ...)
				action(instanceId, ...)
			end,
		})
	end
	componentInstance.Server.Properties = properties

	return componentInstance
end

function ModelBehavior:_constructed()
	if type(self.Construct) == "function" then
		self:Construct()
	end
end

function ModelBehavior:_init()
	if type(self.Init) == "function" then
		self:Init()
	end
end

function ModelBehavior:_streamIn()
	if type(self.StreamIn) == "function" then
		self:StreamIn()
	end
end

function ModelBehavior:_streamOut()
	if type(self.StreamOut) == "function" then
		self:StreamOut()
	end
end

function ModelBehavior:_destroy()
	if type(self.Destroy) == "function" then
		self:Destroy()
	end
end

function ModelBehaviorSystem._trackModelBehaviorLifecycle(model: Model)
	if modelBehaviorLifecycleData[model] then
		warn(
			'[ Weaver | ModelBehavior ] Tried to start tracking lifecycle of ModelBehavior that is already trakced. "'
				.. model.Name
				.. '"'
		)
		return
	end

	modelBehaviorLifecycleData[model] = {
		AncestryChanged = model.AncestryChanged:Connect(function(_, parent)
			-- TODO: Temp fix because ChildAdded gets fired before AncestryChanged
			task.defer(function()
				if parent and model:IsDescendantOf(workspace) and model:FindFirstChild(MODEL_BEHAVIOR_PRIMARY_PART) then
					ModelBehaviorSystem._createComponentInstance(model)
				else
					ModelBehaviorSystem._destroyComponentInstances(model)
				end
			end)
		end),
		ChildAdded = model.ChildAdded:Connect(function(child: Instance)
			if not model:IsDescendantOf(workspace) then
				return
			end

			if child.Name == MODEL_BEHAVIOR_PRIMARY_PART then
				ModelBehaviorSystem._createComponentInstance(model)
			end
		end),
		ChildRemoved = model.ChildRemoved:Connect(function(child: Instance)
			if not model:IsDescendantOf(workspace) then
				return
			end

			if child.Name == MODEL_BEHAVIOR_PRIMARY_PART then
				ModelBehaviorSystem._destroyComponentInstances(model)
			end
		end),
	}

	if model:IsDescendantOf(workspace) and model:FindFirstChild(MODEL_BEHAVIOR_PRIMARY_PART) then
		ModelBehaviorSystem._createComponentInstance(model)
	end
end

function ModelBehaviorSystem._stopTrackingModelBehaviorLifecycle(model: Model)
	local modelBehaviorInstanceData = modelBehaviorLifecycleData[model]
	if not modelBehaviorInstanceData then
		warn(
			'[ Weaver | ModelBehavior ] Tried to stop tracking ModelBehavior lifecycle of a Model that isnt registered. "'
				.. model.Name
				.. '"'
		)
		return
	end

	ModelBehaviorSystem._destroyComponentInstances(model)

	modelBehaviorInstanceData.AncestryChanged:Disconnect()
	modelBehaviorInstanceData.AncestryChanged = nil
	modelBehaviorInstanceData.ChildAdded:Disconnect()
	modelBehaviorInstanceData.ChildAdded = nil
	modelBehaviorInstanceData.ChildRemoved:Disconnect()
	modelBehaviorInstanceData.ChildRemoved = nil
	modelBehaviorInstanceData[model] = nil
end

function ModelBehaviorSystem._createComponentInstance(model: Model)
	local instanceData = modelBehaviorLifecycleData[model]
	if not instanceData then
		warn("[ Weaver | Component ] Tried to create component instance for instance whos lifecycle isn't tracked!")
		return
	end

	if instanceData.startTrackingTask then
		return
	end

	local prefabId: number? = model:GetAttribute("_PrefabId")
	if not prefabId then
		warn("[ Weaver | Component ] Tried to create ModelBehavior instance of a model that doesn't have a Prefab Id")
		return
	end

	local instanceId: number? = model:GetAttribute("_WMBId")
	if not instanceId then
		warn("[ Weaver | Component ] Tried to create ModelBehavior instance of a model that doesn't have a Instance Id")
		return
	end

	instanceData.startTrackingTask = task.spawn(function()
		modelBehaviorInstanceStatusEvent:FireServer(instanceId, true)

		repeat
			task.wait()
		until behaviorInstancesCallbacks[instanceId] ~= nil

		local behaviorInstanceData = behaviorInstancesCallbacks[instanceId]
		behaviorInstanceData.Processing = true

		local prefab: Model? = ReplicatedStorage["$_Weaver"]["ModelBehavior"]:WaitForChild(prefabId)
		local prefabClone: Model = prefab:Clone()
		prefabClone:PivotTo(model:GetPivot())
		prefabClone.Name = tostring(instanceId)
		prefabClone.Parent = modelBehaviorInstancesFolder

		instanceData.ClientInstance = prefabClone

		instanceData.PivotChangedSignal = model:GetPropertyChangedSignal("WorldPivot"):Connect(function()
			prefabClone:PivotTo(model:GetPivot())
		end)

		instanceData.Components = table.create(#behaviorInstanceData)
		for _, componentData in behaviorInstanceData.Data do
			if componentRegistry[componentData.Behavior] then
				local newComponentInstance =
					componentRegistry[componentData.Behavior]:_construct(model, instanceId, componentData.Properties)
				newComponentInstance:_constructed()
				table.insert(instanceData.Components, newComponentInstance)
			end
		end

		behaviorInstancesCallbacks[instanceId] = nil
	end)
end

function ModelBehaviorSystem._destroyComponentInstances(model: Model)
	local instanceData = modelBehaviorLifecycleData[model]
	if not instanceData then
		warn(
			"[ Weaver | ModelBehavior ] Tried to destroy component instance for instance whos lifecycle isn't tracked!"
		)
		return
	end

	local instanceId: number? = model:GetAttribute("_WMBId")
	if not instanceId then
		warn(
			"[ Weaver | Component ] Tried to destroy ModelBehavior instance of a model that doesn't have a Instance Id"
		)
		return
	end

	modelBehaviorInstanceStatusEvent:FireServer(instanceId, false)

	if instanceData.startTrackingTask then
		task.cancel(instanceData.startTrackingTask)
		instanceData.startTrackingTask = nil
	end

	if instanceData.PivotChangedSignal then
		instanceData.PivotChangedSignal:Disconnect()
		instanceData.PivotChangedSignal = nil
	end

	if instanceData.ClientInstance then
		instanceData.ClientInstance:Destroy()
		instanceData.ClientInstance = nil
	end

	if instanceData.Components then
		for _, componentInstance in instanceData.Components do
			componentInstance:_destroy()
		end
		instanceData.Components = nil
	end
end

function ModelBehaviorSystem._prepare()
	modelBehaviorInstancesFolder = Instance.new("Folder")
	modelBehaviorInstancesFolder.Name = "$_ModelBehaviorInstances"
	modelBehaviorInstancesFolder.Parent = workspace

	modelBehaviorInstanceStatusEvent =
		ReplicatedStorage:WaitForChild("$_Weaver"):WaitForChild("ModelBehavior"):WaitForChild("Status")
	modelBehaviorInstanceStatusEvent.OnClientEvent:Connect(function(instanceId: number, data: any)
		behaviorInstancesCallbacks[instanceId] = {
			Data = data,
			ReceivedOn = tick(),
		}
	end)
end

function ModelBehaviorSystem._init()
	for _, component in componentRegistry do
		component:_init()
	end

	CollectionService:GetInstanceAddedSignal(MODEL_BEHAVIOR_TAG):Connect(function(instance: Instance)
		ModelBehaviorSystem._trackModelBehaviorLifecycle(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(MODEL_BEHAVIOR_TAG):Connect(function(instance: Instance)
		ModelBehaviorSystem._stopTrackingModelBehaviorLifecycle(instance)
	end)

	for _, instance: Instance in CollectionService:GetTagged(MODEL_BEHAVIOR_TAG) do
		ModelBehaviorSystem._trackModelBehaviorLifecycle(instance)
	end

	local accumulatedHeartBeat: number = 0
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local currentTick: number = tick()
		accumulatedHeartBeat += deltaTime
		if accumulatedHeartBeat >= 1 then
			accumulatedHeartBeat -= 1

			for instanceId, instanceData in behaviorInstancesCallbacks do
				if
					instanceData.Processing
					or (currentTick - instanceData.ReceivedOn) < MODEL_INSTANCE_DATA_EXPIRATION
				then
					continue
				end

				behaviorInstancesCallbacks[instanceId] = nil
			end
		end
	end)
end

function ModelBehaviorSystem._gather()
	local localPlayerScripts: PlayerScripts = Players.LocalPlayer.PlayerScripts
	local componentsFolder: Folder? = localPlayerScripts:FindFirstChild("Components")
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

ModelBehaviorSystem.newComponent = ModelBehavior.new

return ModelBehaviorSystem
