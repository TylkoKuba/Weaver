local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Behavior = require(script.Behavior)
local FrameworkData = require(script.Parent.FrameworkData)

local behaviorInstancesCallbacks = {}
local modelBehaviorLifecycleData = {}
local modelBehaviorInstanceStatusEvent

local BehaviorsSystem = {}

function BehaviorsSystem._trackBehaviorLifecycle(model: Model)
	if modelBehaviorLifecycleData[model] then
		warn(
			'[ Weaver | ModelBehavior ] Tried to start tracking lifecycle of Behavior that is already trakced. "'
				.. model.Name
				.. '"'
		)
		return
	end

	modelBehaviorLifecycleData[model] = {
		AncestryChanged = model.AncestryChanged:Connect(function(_, parent)
			-- TODO: Temp fix because ChildAdded gets fired before AncestryChanged
			task.defer(function()
				if parent and model:IsDescendantOf(workspace) then
					BehaviorsSystem._createComponentInstance(model)
				else
					BehaviorsSystem._destroyComponentInstances(model)
				end
			end)
		end),
	}

	if model:IsDescendantOf(workspace) then
		BehaviorsSystem._createComponentInstance(model)
	end
end

function BehaviorsSystem._stopTrackingBehaviorLifecycle(model: Model)
	local modelBehaviorInstanceData = modelBehaviorLifecycleData[model]
	if not modelBehaviorInstanceData then
		warn(
			'[ Weaver | ModelBehavior ] Tried to stop tracking ModelBehavior lifecycle of a Model that isnt registered. "'
				.. model.Name
				.. '"'
		)
		return
	end

	BehaviorsSystem._destroyComponentInstances(model)

	modelBehaviorInstanceData.AncestryChanged:Disconnect()
	modelBehaviorInstanceData.AncestryChanged = nil
	modelBehaviorLifecycleData[model] = nil
end

function BehaviorsSystem._createComponentInstance(instance: Instance)
	local instanceData = modelBehaviorLifecycleData[instance]
	if not instanceData then
		warn("[ Weaver | Component ] Tried to create component instance for instance whos lifecycle isn't tracked!")
		return
	end

	if instanceData.startTrackingTask then
		return
	end

	instanceData.startTrackingTask = task.spawn(function()
		modelBehaviorInstanceStatusEvent:FireServer(instance, true)

		repeat
			task.wait()
		until behaviorInstancesCallbacks[instance] ~= nil

		local behaviorInstanceData = behaviorInstancesCallbacks[instance]
		behaviorInstanceData.Processing = true

		instanceData.Components = table.create(#behaviorInstanceData)
		for _, componentData in behaviorInstanceData.Data do
			local behavior: any = Behavior[FrameworkData.BehaviorsRegistry][componentData.Behavior]
			if behavior then
				local newBehaviorInstance = behavior:_construct(instance, componentData.Properties)
				newBehaviorInstance:_constructed()
				table.insert(instanceData.Components, newBehaviorInstance)
			end
		end

		behaviorInstancesCallbacks[instance] = nil
	end)
end

function BehaviorsSystem._destroyComponentInstances(instance: Instance)
	local instanceData = modelBehaviorLifecycleData[instance]
	if not instanceData then
		warn(
			"[ Weaver | ModelBehavior ] Tried to destroy component instance for instance whos lifecycle isn't tracked!"
		)
		return
	end

	modelBehaviorInstanceStatusEvent:FireServer(instance, false)

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

function BehaviorsSystem._prepare()
	modelBehaviorInstanceStatusEvent =
		ReplicatedStorage:WaitForChild("$_Weaver"):WaitForChild("ModelBehavior"):WaitForChild("Status")
	modelBehaviorInstanceStatusEvent.OnClientEvent:Connect(function(instanceId: number, data: any)
		behaviorInstancesCallbacks[instanceId] = {
			Data = data,
			ReceivedOn = tick(),
		}
	end)
end

function BehaviorsSystem._init()
	for _, behavior in Behavior[FrameworkData.BehaviorsRegistry] do
		behavior:_init()
	end

	CollectionService:GetInstanceAddedSignal(FrameworkData.BehaviorTag):Connect(function(instance: Instance)
		BehaviorsSystem._trackBehaviorLifecycle(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(FrameworkData.BehaviorTag):Connect(function(instance: Instance)
		BehaviorsSystem._stopTrackingBehaviorLifecycle(instance)
	end)

	for _, instance: Instance in CollectionService:GetTagged(FrameworkData.BehaviorTag) do
		BehaviorsSystem._trackBehaviorLifecycle(instance)
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
					or (currentTick - instanceData.ReceivedOn) < FrameworkData.BehaviorDataExpriation
				then
					continue
				end

				behaviorInstancesCallbacks[instanceId] = nil
			end
		end
	end)
end

function BehaviorsSystem._gather()
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

BehaviorsSystem.newBehavior = Behavior.new

return BehaviorsSystem
