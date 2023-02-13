local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MODEL_BEHAVIOR_TAG: string = "$_WeaverModelBehavior"

local Behavior = require(script.Behavior)

local modelBehviorFolder, modelBehaviorInstanceStatusEvent
local behaviorInstances = {}
local prefabMap = {}
local behaviorIdInstanceMap = {}
local behaviorIdCounter = 0
local prefabIdCounter = 0

local BehaviorSystem = {}

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

function BehaviorSystem._prepare()
	modelBehviorFolder = Instance.new("Folder")
	modelBehviorFolder.Name = "ModelBehavior"
	modelBehviorFolder.Parent = ReplicatedStorage["$_Weaver"]

	modelBehaviorInstanceStatusEvent = Instance.new("RemoteEvent")
	modelBehaviorInstanceStatusEvent.Name = "Status"
	modelBehaviorInstanceStatusEvent.Parent = modelBehviorFolder
end

function BehaviorSystem._callRemoteFunction(
	behaviorName: string,
	instanceId: number,
	functionName: string,
	player: Player,
	...
)
	local behaviorInstance = behaviorIdInstanceMap[instanceId]
	if not behaviorInstance then
		return
	end

	for _, behavior in behaviorInstance do
		if behavior.Name == behaviorName then
			return behavior.Client[functionName](behavior.Client, player, ...)
		end
	end
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

				remoteFunctionInstance.OnServerInvoke = function(player: Player, instanceId: number, ...)
					return BehaviorSystem._callRemoteFunction(
						registryBehavior.Name,
						instanceId,
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
		function(player: Player, instanceId: number, streamedIn: boolean)
			local behaviorInstance = behaviorIdInstanceMap[instanceId]
			if not behaviorInstance then
				warn("[ Weaver | ModelBehavior ] Player tried to do an action on an instance that doesn't exist!")
				return
			end

			if streamedIn then
				local components = table.create(#behaviorInstance)
				for _, behavior in behaviorInstance do
					table.insert(components, {
						Behavior = behavior.Name,
						Properties = behavior.Properties,
					})
				end
				modelBehaviorInstanceStatusEvent:FireClient(player, instanceId, components)
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

function BehaviorSystem._createPrefab(prefabModel: Model)
	prefabIdCounter += 1
	local pId = prefabIdCounter
	prefabMap[pId] = {
		Model = prefabModel,
		Listeners = 1,
	}
	return pId
end

function BehaviorSystem._addPrefabListener(prefabId: number)
	prefabMap[prefabId].Listeners += 1
end

function BehaviorSystem._removePrefabListener(prefabId: number)
	prefabMap[prefabId].Listeners -= 1

	if prefabMap[prefabId].Listeners <= 0 then
		prefabMap[prefabId].Model:Destroy()
		prefabMap[prefabId] = nil
	end
end

function BehaviorSystem._trackModelLifecycle(model: Model)
	local modelId: number? = model:GetAttribute("_WMBId")
	if modelId then
		behaviorIdCounter += 1
		local instanceId: number = behaviorIdCounter
		local prefabId: number? = model:GetAttribute("_PrefabId")

		model:SetAttribute("_WMBId", instanceId)
		BehaviorSystem._addPrefabListener(prefabId)

		local storedBehavior = behaviorIdInstanceMap[modelId]

		behaviorInstances[model] = table.create(#storedBehavior)
		behaviorIdInstanceMap[instanceId] = behaviorInstances[model]

		for _, modelBehavior in storedBehavior do
			local behavior = Behavior.Get(modelBehavior.Name)
			local newComponentInstance = behavior:_construct(model, instanceId, modelBehavior.Properties)
			table.insert(behaviorInstances[model], newComponentInstance)
		end

		for _, modelBehaviorInstance in behaviorInstances[model] do
			modelBehaviorInstance:_constructed()
		end
	else
		local metadataFolder: Folder? = model:FindFirstChild("$_Metadata")
		if not metadataFolder then
			warn(
				"[ Weaver | ModelBehavior ] Tried to create ModelBehavior instance for instance whos metadata doesn't exist!"
			)
			return
		end

		behaviorIdCounter += 1
		local instanceId: number = behaviorIdCounter
		local cframe: CFrame, size: Vector3 = model:GetBoundingBox()

		model:SetAttribute("_WMBId", instanceId)

		local behaviors = {}
		for _, child: Instance in metadataFolder:GetChildren() do
			local behavior = Behavior.Get(child.Name)
			if behavior then
				table.insert(behaviors, {
					Behavior = behavior,
					Properties = behavior:GetProperties(model),
				})
			end
		end

		metadataFolder:Destroy()

		local modelClone = model:Clone()
		CollectionService:RemoveTag(modelClone, MODEL_BEHAVIOR_TAG)
		modelClone.Name = instanceId
		modelClone.Parent = modelBehviorFolder

		local prefabId = BehaviorSystem._createPrefab(modelClone)
		model:SetAttribute("_PrefabId", prefabId)

		model:ClearAllChildren()

		local modelBoundingBox: Part = Instance.new("Part")
		modelBoundingBox.CanCollide = false
		modelBoundingBox.CanTouch = false
		modelBoundingBox.CanQuery = false
		modelBoundingBox.Anchored = true
		modelBoundingBox.Transparency = 1.0
		modelBoundingBox.CastShadow = false
		modelBoundingBox.Name = "$_WeaverPrimaryPart"
		modelBoundingBox.CFrame = cframe
		modelBoundingBox.Size = size
		modelBoundingBox.Parent = model

		behaviorInstances[model] = table.create(#behaviors)
		behaviorIdInstanceMap[instanceId] = behaviorInstances[model]

		for _, modelBehavior in behaviors do
			local newComponentInstance = modelBehavior.Behavior:_construct(model, instanceId, modelBehavior.Properties)
			table.insert(behaviorInstances[model], newComponentInstance)
		end

		for _, modelBehaviorInstance in behaviorInstances[model] do
			modelBehaviorInstance:_constructed()
		end
	end
end

function BehaviorSystem._stopTrackingModelLifecycle(model: Model)
	local behaviorModelInstance = behaviorInstances[model]
	if not behaviorInstances[model] then
		return
	end

	local prefabId: number = model:GetAttribute("_PrefabId")

	for _, modelBehavior in behaviorModelInstance do
		modelBehavior:_destroy()
	end

	BehaviorSystem._removePrefabListener(prefabId)

	behaviorInstances[model] = nil
end

function BehaviorSystem._gatherModels()
	CollectionService:GetInstanceAddedSignal(MODEL_BEHAVIOR_TAG):Connect(function(instance: Instance)
		if not instance:IsA("Model") then
			return
		end

		BehaviorSystem._trackModelLifecycle(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(MODEL_BEHAVIOR_TAG):Connect(function(instance: Instance)
		if not instance:IsA("Model") then
			return
		end

		BehaviorSystem._stopTrackingModelLifecycle(instance)
	end)

	for _, instance: Instance in CollectionService:GetTagged(MODEL_BEHAVIOR_TAG) do
		if not instance:IsA("Model") then
			return
		end

		BehaviorSystem._trackModelLifecycle(instance)

		task.delay(5, function()
			local cI: Model = instance:Clone()
			local rx, ry, rz = cI:GetPivot():ToOrientation()
			cI:PivotTo(CFrame.new(Vector3.new(0, 10, 0)) * CFrame.Angles(rx, ry, rz))
			cI.Parent = workspace

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

BehaviorSystem.newBehavior = Behavior.new

return BehaviorSystem
